import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image/image.dart' as img;

/// 🤖 Enhanced On-Device AI Service using Google ML Kit
/// 
/// Features:
/// - OCR Text Extraction
/// - Face Detection
/// - NIC/Passport Detection
/// - Smart Text Matching with TF-IDF
/// - Color & Brand Detection
/// - Multi-language Support (EN, SI, TA)
class FreeAIService {
  static final FreeAIService _instance = FreeAIService._internal();
  factory FreeAIService() => _instance;
  FreeAIService._internal();

  // ML Kit instances
  final TextRecognizer _textRecognizer = TextRecognizer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: false,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  // Translation support
  OnDeviceTranslator? _sinhalaTranslator;
  OnDeviceTranslator? _tamilTranslator;
  bool _translationInitialized = false;
  
  void dispose() {
    _textRecognizer.close();
    _faceDetector.close();
    _sinhalaTranslator?.close();
    _tamilTranslator?.close();
  }

  // ========================================
  // 1. OCR TEXT EXTRACTION (Enhanced)
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
  
  /// Extract structured data from text
  Future<ExtractedItemData> extractItemData(File imageFile) async {
    final text = await extractText(imageFile);
    return ExtractedItemData(
      rawText: text,
      nicNumbers: detectNICNumbers(text),
      phoneNumbers: _extractPhoneNumbers(text),
      emails: _extractEmails(text),
      colors: _extractColors(text).toList(),
      brands: _extractBrands(text),
      keywords: _extractKeywords(text),
    );
  }

  // ========================================
  // 2. FACE DETECTION (Enhanced)
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
  
  /// Check if image contains faces (for privacy blur)
  Future<bool> hasFaces(File imageFile) async {
    final faces = await detectFaces(imageFile);
    return faces.isNotEmpty;
  }

  // ========================================
  // 3. NIC & DOCUMENT DETECTION (Enhanced)
  // ========================================
  static final RegExp _nicPatternOld = RegExp(r'\d{9}[VXvx]');
  static final RegExp _nicPatternNew = RegExp(r'\d{12}');
  static final RegExp _passportPattern = RegExp(r'[A-Z]{1,2}\d{7}');
  static final RegExp _licensePattern = RegExp(r'[A-Z]\d{7}');
  
  List<String> detectNICNumbers(String text) {
    final matches = <String>[];
    matches.addAll(_nicPatternOld.allMatches(text).map((m) => m.group(0)!));
    matches.addAll(_nicPatternNew.allMatches(text).map((m) => m.group(0)!));
    return matches;
  }
  
  List<String> detectPassportNumbers(String text) {
    return _passportPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
  
  List<String> detectLicenseNumbers(String text) {
    return _licensePattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
  
  /// Detect document type from image
  Future<DocumentType> detectDocumentType(File imageFile) async {
    final text = await extractText(imageFile);
    final textLower = text.toLowerCase();
    
    if (detectNICNumbers(text).isNotEmpty || 
        textLower.contains('national identity') ||
        textLower.contains('ජාතික හැඳුනුම්පත')) {
      return DocumentType.nic;
    }
    if (detectPassportNumbers(text).isNotEmpty || 
        textLower.contains('passport')) {
      return DocumentType.passport;
    }
    if (detectLicenseNumbers(text).isNotEmpty || 
        textLower.contains('driving') ||
        textLower.contains('license')) {
      return DocumentType.drivingLicense;
    }
    if (textLower.contains('bank') || textLower.contains('credit') || 
        textLower.contains('debit') || textLower.contains('visa') ||
        textLower.contains('mastercard')) {
      return DocumentType.bankCard;
    }
    return DocumentType.other;
  }

  // ========================================
  // 4. PHONE & EMAIL EXTRACTION
  // ========================================
  static final RegExp _phonePattern = RegExp(r'(?:\+94|0)?[0-9]{9,10}');
  static final RegExp _emailPattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  
  List<String> _extractPhoneNumbers(String text) {
    return _phonePattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
  
  List<String> _extractEmails(String text) {
    return _emailPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  // ========================================
  // 5. COLOR DETECTION (Enhanced)
  // ========================================
  final Map<String, List<String>> _colorVariants = {
    'red': ['red', 'maroon', 'crimson', 'scarlet', 'ruby', 'cherry', 'රතු'],
    'blue': ['blue', 'navy', 'azure', 'cobalt', 'sapphire', 'cyan', 'turquoise', 'නිල්'],
    'green': ['green', 'olive', 'lime', 'emerald', 'jade', 'mint', 'teal', 'කොළ'],
    'black': ['black', 'charcoal', 'ebony', 'onyx', 'jet', 'කළු'],
    'white': ['white', 'ivory', 'cream', 'pearl', 'snow', 'සුදු'],
    'yellow': ['yellow', 'gold', 'golden', 'amber', 'mustard', 'lemon', 'කහ'],
    'orange': ['orange', 'tangerine', 'peach', 'apricot', 'coral'],
    'purple': ['purple', 'violet', 'lavender', 'plum', 'magenta', 'lilac'],
    'pink': ['pink', 'rose', 'salmon', 'fuchsia', 'blush'],
    'grey': ['grey', 'gray', 'silver', 'ash', 'slate', 'charcoal'],
    'brown': ['brown', 'tan', 'beige', 'chocolate', 'coffee', 'caramel', 'දුඹුරු'],
  };

  Set<String> _extractColors(String text) {
    final textLower = text.toLowerCase();
    final foundColors = <String>{};
    
    for (final entry in _colorVariants.entries) {
      for (final variant in entry.value) {
        if (textLower.contains(variant)) {
          foundColors.add(entry.key);
          break;
        }
      }
    }
    return foundColors;
  }
  
  /// Get primary color from text
  String? getPrimaryColor(String text) {
    final colors = _extractColors(text);
    return colors.isNotEmpty ? colors.first : null;
  }

  // ========================================
  // 6. BRAND DETECTION
  // ========================================
  final Set<String> _knownBrands = {
    // Phones
    'iphone', 'samsung', 'huawei', 'xiaomi', 'oppo', 'vivo', 'realme', 
    'oneplus', 'google', 'pixel', 'nokia', 'motorola', 'lg', 'sony',
    // Laptops
    'macbook', 'dell', 'hp', 'lenovo', 'asus', 'acer', 'msi', 'surface',
    // Bags
    'nike', 'adidas', 'puma', 'jansport', 'samsonite', 'american tourister',
    // Wallets
    'louis vuitton', 'coach', 'fossil', 'tommy hilfiger',
    // Watches
    'rolex', 'casio', 'seiko', 'citizen', 'tissot', 'omega', 'tag heuer',
    'apple watch', 'fitbit', 'garmin', 'mi band',
    // Cards
    'visa', 'mastercard', 'amex', 'american express',
    // Banks (Sri Lanka)
    'commercial bank', 'peoples bank', 'boc', 'hsbc', 'sampath', 'hnb', 'ndb',
    // Glasses & Fashion
    'ray-ban', 'rayban', 'oakley', 'gucci', 'prada', 'versace',
  };
  
  List<String> _extractBrands(String text) {
    final textLower = text.toLowerCase();
    return _knownBrands.where((brand) => textLower.contains(brand)).toList();
  }

  // ========================================
  // 7. KEYWORD EXTRACTION (TF-IDF inspired)
  // ========================================
  final Set<String> _stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
    'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
    'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above',
    'below', 'between', 'under', 'again', 'further', 'then', 'once', 'here',
    'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few', 'more',
    'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
    'same', 'so', 'than', 'too', 'very', 's', 't', 'just', 'don', 'now',
    'i', 'my', 'me', 'we', 'our', 'you', 'your', 'he', 'him', 'his', 'she',
    'her', 'it', 'its', 'they', 'them', 'their', 'this', 'that', 'these',
    'lost', 'found', 'missing', 'please', 'help', 'contact', 'call', 'reward',
  };
  
  List<String> _extractKeywords(String text) {
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
    
    // Count frequency
    final freq = <String, int>{};
    for (final word in words) {
      freq[word] = (freq[word] ?? 0) + 1;
    }
    
    // Sort by frequency and return top keywords
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(10).map((e) => e.key).toList();
  }

  // ========================================
  // 8. ENHANCED SYNONYM MATCHING
  // ========================================
  final Map<String, List<String>> _synonyms = {
    'phone': ['mobile', 'smartphone', 'cellphone', 'cellular', 'handphone', 'cell'],
    'laptop': ['computer', 'notebook', 'macbook', 'pc', 'chromebook'],
    'bag': ['backpack', 'handbag', 'purse', 'suitcase', 'briefcase', 'rucksack', 'tote'],
    'wallet': ['purse', 'moneybag', 'cardholder', 'billfold', 'pocketbook'],
    'keys': ['keychain', 'fob', 'smartkey', 'car key', 'house key'],
    'glasses': ['spectacles', 'sunglasses', 'shades', 'eyeglasses', 'specs'],
    'watch': ['smartwatch', 'clock', 'timepiece', 'wristwatch'],
    'document': ['id', 'nic', 'passport', 'license', 'certificate', 'card', 'paper'],
    'camera': ['dslr', 'mirrorless', 'gopro', 'camcorder'],
    'headphones': ['earphones', 'earbuds', 'airpods', 'headset', 'earpods'],
    'tablet': ['ipad', 'tab', 'kindle', 'e-reader'],
    'jewelry': ['ring', 'necklace', 'bracelet', 'earring', 'chain', 'pendant'],
    'charger': ['adapter', 'cable', 'power bank', 'charging'],
  };

  String? _findSynonymGroup(String word) {
    word = word.toLowerCase();
    for (final entry in _synonyms.entries) {
      if (entry.key == word || entry.value.contains(word)) {
        return entry.key;
      }
    }
    return null;
  }

  bool _areSynonyms(String word1, String word2) {
    word1 = word1.toLowerCase();
    word2 = word2.toLowerCase();
    if (word1 == word2) return true;
    
    final group1 = _findSynonymGroup(word1);
    final group2 = _findSynonymGroup(word2);
    
    if (group1 != null && group2 != null && group1 == group2) return true;
    
    for (var group in _synonyms.values) {
      if (group.contains(word1) && group.contains(word2)) return true;
    }
    return false;
  }

  // ========================================
  // 9. DISTANCE & SIMILARITY CALCULATIONS
  // ========================================
  
  /// Calculate distance between two points using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi/180
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + 
              math.cos(lat1 * p) * math.cos(lat2 * p) * 
              (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * Earth's radius in km
  }
  
  /// Levenshtein distance for fuzzy matching
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
  
  /// Calculate color matching score
  double _calculateColorScore(String text1, String text2) {
    final colors1 = _extractColors(text1);
    final colors2 = _extractColors(text2);
    if (colors1.isEmpty || colors2.isEmpty) return 0.0;
    
    final common = colors1.intersection(colors2);
    if (common.isNotEmpty) return 15.0; // Bonus for matching colors
    return -10.0; // Small penalty for conflicting colors
  }

  // ========================================
  // 10. TEXT SIMILARITY (Enhanced Jaccard + Fuzzy)
  // ========================================
  
  double calculateTextSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();
    
    // Exact match or containment
    if (s1.contains(s2) || s2.contains(s1)) return 1.0;
    
    // Tokenize and filter stop words
    final tokens1 = s1.split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
    final tokens2 = s2.split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
    
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    // Enhanced matching with synonyms and fuzzy matching
    double intersection = 0;
    for (var t1 in tokens1) {
      bool localMatch = false;
      for (var t2 in tokens2) {
        // Exact match
        if (t1 == t2) {
          localMatch = true;
          break;
        }
        // Synonym match
        if (_areSynonyms(t1, t2)) {
          localMatch = true;
          break;
        }
        // Fuzzy match (Levenshtein distance <= 2)
        if (t1.length > 3 && t2.length > 3 && _levenshtein(t1, t2) <= 2) {
          localMatch = true;
          break;
        }
      }
      if (localMatch) intersection++;
    }
    
    // Jaccard similarity
    return intersection / (tokens1.length + tokens2.length - intersection);
  }
  
  /// Calculate brand matching bonus
  double calculateBrandScore(String text1, String text2) {
    final brands1 = _extractBrands(text1);
    final brands2 = _extractBrands(text2);
    
    if (brands1.isEmpty || brands2.isEmpty) return 0.0;
    
    final common = brands1.toSet().intersection(brands2.toSet());
    if (common.isNotEmpty) return 20.0; // Big bonus for brand match
    return -5.0; // Small penalty for different brands
  }

  // ========================================
  // 11. TRANSLATION (Tamil only - Sinhala not supported by ML Kit)
  // ========================================
  
  /// Initialize translation models
  /// Note: Google ML Kit does NOT support Sinhala translation
  /// Only Tamil is available for Sri Lankan languages
  Future<void> initializeTranslation() async {
    if (_translationInitialized) return;
    
    try {
      // Tamil translator (Sinhala NOT supported by Google ML Kit)
      _tamilTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.tamil,
        targetLanguage: TranslateLanguage.english,
      );
      _translationInitialized = true;
      debugPrint('Translation initialized (Tamil only - Sinhala not supported by ML Kit)');
    } catch (e) {
      debugPrint('Translation init error: $e');
    }
  }
  
  /// Detect language (simple heuristic)
  String detectLanguage(String text) {
    // Sinhala Unicode range: U+0D80-U+0DFF
    final sinhalaPattern = RegExp(r'[\u0D80-\u0DFF]');
    // Tamil Unicode range: U+0B80-U+0BFF
    final tamilPattern = RegExp(r'[\u0B80-\u0BFF]');
    
    if (sinhalaPattern.hasMatch(text)) return 'si';
    if (tamilPattern.hasMatch(text)) return 'ta';
    return 'en';
  }
  
  /// Translate text to English
  Future<String> translateToEnglish(String text) async {
    if (text.isEmpty) return '';
    
    final lang = detectLanguage(text);
    if (lang == 'en') return text;
    
    try {
      await initializeTranslation();
      
      // Only Tamil translation is supported by Google ML Kit
      // Sinhala text will be kept as-is (matching relies on extracted keywords)
      if (lang == 'ta' && _tamilTranslator != null) {
        return await _tamilTranslator!.translateText(text);
      }
      
      // For Sinhala, we can't translate but we can still match based on:
      // - NIC numbers, phone numbers (language-agnostic)
      // - English keywords that might be mixed in
      // - Category matching
      if (lang == 'si') {
        debugPrint('Sinhala detected - translation not available, using original text');
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    }
    
    return text; // Fallback to original
  }

  // ========================================
  // 12. MAIN MATCHING ALGORITHM (Enhanced)
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
    String? category1,
    String? category2,
  }) async {
    
    // A. IMPOSSIBLE LOGIC FILTERS - Early rejection
    if (time1 != null && time2 != null) {
      final daysDiff = time1.difference(time2).inDays.abs();
      if (daysDiff > 365) return _emptyMatch();
    }
    
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      final distanceKm = calculateDistance(lat1, lon1, lat2, lon2);
      if (distanceKm > 150) return _emptyMatch(); // Reject if > 150km
    }

    // B. TRANSLATION - Convert to English for matching
    final text1 = await translateToEnglish(description1);
    final text2 = await translateToEnglish(description2);

    // C. SCORING COMPONENTS
    
    // 1. Text Similarity (40%)
    final textScore = calculateTextSimilarity(text1, text2) * 100;
    
    // 2. Location Score (25%)
    double locationScore = 50.0;
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      final distance = calculateDistance(lat1, lon1, lat2, lon2);
      // Score decreases by 2 points per km, max 100
      locationScore = (100 - (distance * 2)).clamp(0, 100).toDouble();
    }
    
    // 3. Time Score (15%)
    double timeScore = 50.0;
    if (time1 != null && time2 != null) {
      final hoursDiff = time1.difference(time2).inHours.abs();
      // Score decreases over 10 days
      timeScore = (100 - (hoursDiff / 24 * 10)).clamp(0, 100).toDouble();
    }
    
    // 4. Category Score (10%)
    double categoryScore = 50.0;
    if (category1 != null && category2 != null) {
      if (category1.toLowerCase() == category2.toLowerCase()) {
        categoryScore = 100.0;
      } else if (_areSynonyms(category1, category2)) {
        categoryScore = 80.0;
      } else {
        categoryScore = 20.0;
      }
    }
    
    // 5. Adjustments
    final colorAdjustment = _calculateColorScore(text1, text2);
    final brandAdjustment = calculateBrandScore(text1, text2);
    
    // D. FINAL WEIGHTED SCORE
    double confidenceScore = 
        (textScore * 0.40) + 
        (locationScore * 0.25) + 
        (timeScore * 0.15) + 
        (categoryScore * 0.10) +
        colorAdjustment +
        brandAdjustment;
    
    // Apply NIC/Document bonus
    final nics1 = detectNICNumbers(text1);
    final nics2 = detectNICNumbers(text2);
    if (nics1.isNotEmpty && nics2.isNotEmpty) {
      for (var nic in nics1) {
        if (nics2.contains(nic)) {
          confidenceScore += 30.0; // Big bonus for matching NIC
          break;
        }
      }
    }
    
    confidenceScore = confidenceScore.clamp(0.0, 100.0);
    
    return MatchResult(
      confidenceScore: confidenceScore,
      textSimilarity: textScore,
      locationProximity: locationScore,
      timeDifference: timeScore,
      categoryScore: categoryScore,
      imageSimilarity: 0.0,
      colorMatch: colorAdjustment > 0,
      brandMatch: brandAdjustment > 0,
    );
  }

  MatchResult _emptyMatch() => MatchResult(
    confidenceScore: 0, 
    textSimilarity: 0, 
    locationProximity: 0, 
    timeDifference: 0, 
    categoryScore: 0,
    imageSimilarity: 0,
    colorMatch: false,
    brandMatch: false,
  );

  // ========================================
  // 13. PRIVACY HELPERS (Enhanced)
  // ========================================

  Future<List<String>> detectNICInImage(File imageFile) async {
    final text = await extractText(imageFile);
    return detectNICNumbers(text);
  }
  
  /// Detect all sensitive data in image
  Future<SensitiveDataResult> detectSensitiveData(File imageFile) async {
    final text = await extractText(imageFile);
    final faces = await detectFaces(imageFile);
    
    return SensitiveDataResult(
      hasFaces: faces.isNotEmpty,
      faceCount: faces.length,
      nicNumbers: detectNICNumbers(text),
      passportNumbers: detectPassportNumbers(text),
      licenseNumbers: detectLicenseNumbers(text),
      phoneNumbers: _extractPhoneNumbers(text),
      emails: _extractEmails(text),
    );
  }

  /// Auto-blur sensitive data in image (placeholder - needs image processing)
  Future<Uint8List?> autoBlurSensitiveData(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      
      // Detect faces and blur them
      final faces = await detectFaces(imageFile);
      if (faces.isEmpty) return bytes;
      
      // Apply blur to each face region
      for (final face in faces) {
        final rect = face.boundingBox;
        final x = rect.left.toInt().clamp(0, image.width - 1);
        final y = rect.top.toInt().clamp(0, image.height - 1);
        final w = rect.width.toInt().clamp(1, image.width - x);
        final h = rect.height.toInt().clamp(1, image.height - y);
        
        // Extract face region and blur
        final faceRegion = img.copyCrop(image, x: x, y: y, width: w, height: h);
        final blurred = img.gaussianBlur(faceRegion, radius: 15);
        
        // Paste blurred region back
        img.compositeImage(image, blurred, dstX: x, dstY: y);
      }
      
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      debugPrint('Auto-blur error: $e');
      return null;
    }
  }
}

// ========================================
// DATA CLASSES
// ========================================

/// Result of a match calculation
class MatchResult {
  final double confidenceScore;
  final double textSimilarity;
  final double locationProximity;
  final double timeDifference;
  final double categoryScore;
  final double imageSimilarity;
  final bool colorMatch;
  final bool brandMatch;
  
  MatchResult({
    required this.confidenceScore,
    required this.textSimilarity,
    required this.locationProximity,
    required this.timeDifference,
    this.categoryScore = 0.0,
    required this.imageSimilarity,
    this.colorMatch = false,
    this.brandMatch = false,
  });
  
  bool get isHighConfidence => confidenceScore >= 70;
  bool get isMediumConfidence => confidenceScore >= 40 && confidenceScore < 70;
  bool get isLowConfidence => confidenceScore < 40;
  
  Map<String, dynamic> toMap() => {
    'confidenceScore': confidenceScore,
    'textSimilarity': textSimilarity,
    'locationProximity': locationProximity,
    'timeDifference': timeDifference,
    'categoryScore': categoryScore,
    'imageSimilarity': imageSimilarity,
    'colorMatch': colorMatch,
    'brandMatch': brandMatch,
  };
  
  @override
  String toString() => 
    'MatchResult(confidence: ${confidenceScore.toStringAsFixed(1)}%, '
    'text: ${textSimilarity.toStringAsFixed(1)}%, '
    'location: ${locationProximity.toStringAsFixed(1)}%)';
}

/// Extracted data from an item image
class ExtractedItemData {
  final String rawText;
  final List<String> nicNumbers;
  final List<String> phoneNumbers;
  final List<String> emails;
  final List<String> colors;
  final List<String> brands;
  final List<String> keywords;
  
  ExtractedItemData({
    required this.rawText,
    required this.nicNumbers,
    required this.phoneNumbers,
    required this.emails,
    required this.colors,
    required this.brands,
    required this.keywords,
  });
  
  bool get hasIdentifiableInfo => 
      nicNumbers.isNotEmpty || 
      phoneNumbers.isNotEmpty || 
      emails.isNotEmpty;
  
  Map<String, dynamic> toMap() => {
    'rawText': rawText,
    'nicNumbers': nicNumbers,
    'phoneNumbers': phoneNumbers,
    'emails': emails,
    'colors': colors,
    'brands': brands,
    'keywords': keywords,
  };
}

/// Sensitive data detection result
class SensitiveDataResult {
  final bool hasFaces;
  final int faceCount;
  final List<String> nicNumbers;
  final List<String> passportNumbers;
  final List<String> licenseNumbers;
  final List<String> phoneNumbers;
  final List<String> emails;
  
  SensitiveDataResult({
    required this.hasFaces,
    required this.faceCount,
    required this.nicNumbers,
    required this.passportNumbers,
    required this.licenseNumbers,
    required this.phoneNumbers,
    required this.emails,
  });
  
  bool get hasSensitiveData => 
      hasFaces || 
      nicNumbers.isNotEmpty || 
      passportNumbers.isNotEmpty ||
      licenseNumbers.isNotEmpty ||
      phoneNumbers.isNotEmpty;
      
  int get sensitivityLevel {
    int level = 0;
    if (hasFaces) level += 3;
    if (nicNumbers.isNotEmpty) level += 3;
    if (passportNumbers.isNotEmpty) level += 3;
    if (licenseNumbers.isNotEmpty) level += 2;
    if (phoneNumbers.isNotEmpty) level += 1;
    if (emails.isNotEmpty) level += 1;
    return level;
  }
}

/// Document type enum
enum DocumentType {
  nic,
  passport,
  drivingLicense,
  bankCard,
  other,
}
