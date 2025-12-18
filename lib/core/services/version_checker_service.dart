import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final List<String> releaseNotes;
  final String minSupportedVersion;
  final bool forceUpdate;
  final String releaseDate;

  VersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.minSupportedVersion,
    required this.forceUpdate,
    required this.releaseDate,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      latestVersion: json['latestVersion'] as String,
      latestBuildNumber: json['latestBuildNumber'] as int,
      downloadUrl: json['downloadUrl'] as String,
      releaseNotes: (json['releaseNotes'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      minSupportedVersion: json['minSupportedVersion'] as String,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      releaseDate: json['releaseDate'] as String,
    );
  }
}

class VersionCheckerService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/pirinthaban/findback/main/version.json';
  static const String _lastCheckKey = 'last_version_check';
  static const String _dismissedVersionKey = 'dismissed_version';

  /// Check if update is available
  Future<VersionInfo?> checkForUpdate() async {
    try {
      // Fetch version info from GitHub
      final response = await http.get(Uri.parse(_versionUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final versionInfo = VersionInfo.fromJson(json);

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      // Update available if latest build number is greater
      if (versionInfo.latestBuildNumber > currentBuildNumber) {
        return versionInfo;
      }

      return null;
    } catch (e) {
      print('Error checking version: $e');
      return null;
    }
  }

  /// Check if we should show update dialog (respects user dismissal)
  Future<bool> shouldShowUpdateDialog(VersionInfo versionInfo) async {
    final prefs = await SharedPreferences.getInstance();

    // If force update, always show
    if (versionInfo.forceUpdate) {
      return true;
    }

    // Check if user dismissed this version
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    if (dismissedVersion == versionInfo.latestVersion) {
      return false;
    }

    // Check last check time (show once per day)
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayInMs = 24 * 60 * 60 * 1000;

    if (now - lastCheck < dayInMs) {
      return false;
    }

    return true;
  }

  /// Mark version check as done
  Future<void> markVersionChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Mark version as dismissed by user
  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
    await markVersionChecked();
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
