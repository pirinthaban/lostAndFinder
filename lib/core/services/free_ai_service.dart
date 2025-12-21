import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image/image.dart' as img;

/// Free On-Device AI Service using Google ML Kit
class FreeAIService {
  static final FreeAIService _instance = FreeAIService._internal();
  factory FreeAIService() => _instance;
  FreeAIService._internal();

  // ML Kit instances
  final TextRecognizer _textRecognizer = TextRecognizer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: false,
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  // Translator placeholder (requires model management for full locale support)
  final _onDeviceTranslator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.english,
  );
  
  void dispose() {
    _textRecognizer.close();
    _faceDetector.close();
    _onDeviceTranslator.close();
  }

  // ========================================
  // 1. OCR TEXT EXTRACTION
  // ========================================
  Future<String> extractText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR Error: $e');
      return '';
    }
  }

  // ========================================
  // 2. FACE DETECTION
  // ========================================
  Future<List<Face>> detectFaces(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('Face Check Error: $e');
      return [];
    }
  }

  // ========================================
  // 3. NIC DETECTION
  // ========================================
  static final RegExp _nicPattern = RegExp(r'\d{9}[VXvx]|\d{12}');
  
  List<String> detectNICNumbers(String text) {
    final matches = _nicPattern.allMatches(text);
    return matches.map((m) => m.group(0)!).toList();
  }

  // ========================================
  // 4. TRANSLATION (LOCAL HERO)
  // ========================================
  Future<String> _translateToEnglish(String text) async {
    if (text.isEmpty) return '';
    try {
      // NOTE: For full support, use LanguageIdentifier to detect source, 
      // then download model, then translate. 
      // Current implementation is a pass-through to ensure stability.
      return text; 
    } catch (e) {
      return text;
    }
  }

  // ========================================
  // 5. SMART MATCHING HELPERS
  // ========================================
  final Map<String, List<String>> _synonyms = {
    'phone': ['mobile', 'smartphone', 'cellphone', 'cellular'],
    'laptop': ['computer', 'notebook', 'macbook', 'pc'],
    'bag': ['backpack', 'handbag', 'purse', 'suitcase', 'briefcase'],
    'wallet': ['purse', 'moneybag', 'cardholder'],
    'keys': ['keychain', 'fob', 'smartkey'],
    'glasses': ['spectacles', 'sunglasses', 'shades'],
    'watch': ['smartwatch', 'clock', 'timepiece'],
    'document': ['id', 'nic', 'passport', 'license', 'certificate', 'card'],
  };

  final Set<String> _colors = {
    'red', 'blue', 'green', 'black', 'white', 'yellow', 'orange', 'purple', 'pink', 'grey', 'gray', 'silver', 'gold', 'brown'
  };

  bool _areSynonyms(String word1, String word2) {
    word1 = word1.toLowerCase();
    word2 = word2.toLowerCase();
    if (word1 == word2) return true;
    for (var group in _synonyms.values) {
      if (group.contains(word1) && group.contains(word2)) return true;
    }
    return false;
  }

  Set<String> _extractColors(String text) {
    return text.toLowerCase().split(RegExp(r'\s+'))
      .where((w) => _colors.contains(w.replaceAll(RegExp(r'[^a-z]'), '')))
      .toSet();
  }

  double _calculateColorScore(String text1, String text2) {
    final colors1 = _extractColors(text1);
    final colors2 = _extractColors(text2);
    if (colors1.isEmpty || colors2.isEmpty) return 0.0;
    
    final common = colors1.intersection(colors2);
    if (common.isNotEmpty) return 15.0; // Bonus
    return -20.0; // Penalty
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + 
              math.cos(lat1 * p) * math.cos(lat2 * p) * 
              (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  double calculateTextSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();
    if (s1.contains(s2) || s2.contains(s1)) return 1.0;
    
    final tokens1 = s1.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final tokens2 = s2.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    double intersection = 0;
    for (var t1 in tokens1) {
      bool localMatch = false;
      for (var t2 in tokens2) {
        if (t1 == t2 || _areSynonyms(t1, t2) || _levenshtein(t1, t2) <= 1) {
          localMatch = true;
          break;
        }
      }
      if (localMatch) intersection++;
    }
    return intersection / (tokens1.length + tokens2.length - intersection);
  }

  // ========================================
  // 6. MAIN MATCHING ALGORITHM (SMART FILTER)
  // ========================================
  Future<MatchResult> calculateMatchScore({
    required String description1,
    required String description2,
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
    DateTime? time1,
    DateTime? time2,
    required String itemType1,
  }) async {
    // A. IMPOSSIBLE LOGIC FILTERS
    if (time1 != null && time2 != null) {
      final daysDiff = time1.difference(time2).inDays.abs();
      if (daysDiff > 365) return _emptyMatch();
    }
    
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      final distanceKm = calculateDistance(lat1, lon1, lat2, lon2);
      if (distanceKm > 100) return _emptyMatch(); // Reject if > 100km
    }

    // B. TRANSLATION (Placeholder for Future Update)
    final text1 = await _translateToEnglish(description1);
    final text2 = await _translateToEnglish(description2);

    // C. SCORING
    final textScore = calculateTextSimilarity(text1, text2) * 100;
    
    double locationScore = 50.0;
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      final distance = calculateDistance(lat1, lon1, lat2, lon2);
      locationScore = (100 - (distance * 2)).clamp(0, 100);
    }
    
    double timeScore = 50.0;
    if (time1 != null && time2 != null) {
      final hoursDiff = time1.difference(time2).inHours.abs();
      timeScore = (100 - (hoursDiff / 24 * 10)).clamp(0, 100);
    }
    
    double colorAdjustment = _calculateColorScore(text1, text2);
    
    double confidenceScore = (textScore * 0.60) + (locationScore * 0.30) + (timeScore * 0.10);
    confidenceScore += colorAdjustment;
    confidenceScore = confidenceScore.clamp(0.0, 100.0);
    
    return MatchResult(
      confidenceScore: confidenceScore,
      textSimilarity: textScore,
      locationProximity: locationScore,
      timeDifference: timeScore,
      imageSimilarity: 0.0,
    );
  }

  MatchResult _emptyMatch() => MatchResult(
    confidenceScore: 0, 
    textSimilarity: 0, 
    locationProximity: 0, 
    timeDifference: 0, 
    imageSimilarity: 0
  );

  // ========================================
  // 7. PRIVACY HELPERS
  // ========================================

  Future<List<String>> detectNICInImage(File imageFile) async {
    final text = await extractText(imageFile);
    return detectNICNumbers(text);
  }

  Future<Uint8List?> autoBlurSensitiveData(File imageFile) async {
     // Placeholder for auto-blur logic depending on image package
     // For now, return null (indicating no blur applied) to satisfy build
     return null; 
  }
}

/// Result of a match calculation
class MatchResult {
  final double confidenceScore;
  final double textSimilarity;
  final double locationProximity;
  final double timeDifference;
  final double imageSimilarity;
  
  MatchResult({
    required this.confidenceScore,
    required this.textSimilarity,
    required this.locationProximity,
    required this.timeDifference,
    required this.imageSimilarity,
  });
  
  bool get isHighConfidence => confidenceScore >= 70;
  bool get isMediumConfidence => confidenceScore >= 40 && confidenceScore < 70;
  bool get isLowConfidence => confidenceScore < 40;
  
  @override
  String toString() => 
    'MatchResult(confidence: ${confidenceScore.toStringAsFixed(1)}%, '
    'text: ${textSimilarity.toStringAsFixed(1)}%)';
}
