import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/version_checker_service.dart';
import '../../../../core/widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _versionChecker = VersionCheckerService();

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Check for app updates
    await _checkForUpdates();
    
    if (!mounted) return;
    
    // Check SharedPreferences for first-time user status
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;
    final hasAcceptedTerms = prefs.getBool('terms_accepted') ?? false;
    
    // Check if user is already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (!hasCompletedOnboarding) {
      // First time user - show onboarding
      context.go('/onboarding');
    } else if (!hasAcceptedTerms) {
      // Onboarding done but terms not accepted
      context.go('/terms-acceptance');
    } else if (currentUser != null) {
      // User is logged in and has completed onboarding/terms
      context.go('/home');
    } else {
      // User has completed onboarding/terms but not logged in
      context.go('/login');
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final versionInfo = await _versionChecker.checkForUpdate();
      
      if (versionInfo == null) return;
      
      final shouldShow = await _versionChecker.shouldShowUpdateDialog(versionInfo);
      
      if (!shouldShow || !mounted) return;

      // Mark as checked immediately to prevent spamming (24h cooldown)
      // This ensures even if user clicks outside/kills app, it won't show again immediately
      await _versionChecker.markVersionChecked();

      // Show update dialog
      await showDialog(
        context: context,
        barrierDismissible: !versionInfo.forceUpdate,
        builder: (context) => UpdateDialog(
          versionInfo: versionInfo,
          onDismiss: () {
            _versionChecker.dismissVersion(versionInfo.latestVersion);
            Navigator.of(context).pop();
          },
        ),
      );
    } catch (e) {
      // Silently fail - don't block app startup
      print('Update check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search,
                size: 60,
                color: Color(0xFF1976D2),
              ),
            )
                .animate()
                .scale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(),
            
            const SizedBox(height: 30),
            
            // App Name
            const Text(
              'FindBack',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 400))
                .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 10),
            
            // Tagline
            const Text(
              'Reuniting People with Their Belongings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 600))
                .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 50),
            
            // Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 1000)),
          ],
        ),
      ),
    );
  }
}
