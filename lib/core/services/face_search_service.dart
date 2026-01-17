import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Face Search Service for FindBack
/// 
/// This service provides face-based item search functionality:
/// - Detect faces in uploaded images
/// - Search for items containing similar faces
/// - Generate face descriptors for comparison

// Provider for the face search service
final faceSearchServiceProvider = Provider<FaceSearchService>((ref) {
  return FaceSearchService();
});

// Provider for search results
final faceSearchResultsProvider = StateProvider<List<FaceSearchResult>>((ref) => []);

// Provider for search loading state
final faceSearchLoadingProvider = StateProvider<bool>((ref) => false);

// Provider for face detection status
final faceDetectedProvider = StateProvider<bool?>((ref) => null);

/// Result of a face search operation
class FaceSearchResult {
  final String itemId;
  final String title;
  final String description;
  final String? imageUrl;
  final String category;
  final String? district;
  final String type; // 'lost' or 'found'
  final double similarity;
  final String matchConfidence;
  final Map<String, dynamic> faceData;
  final Timestamp? createdAt;
  final String? userId;
  final String? userName;

  FaceSearchResult({
    required this.itemId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.category,
    this.district,
    required this.type,
    required this.similarity,
    required this.matchConfidence,
    required this.faceData,
    this.createdAt,
    this.userId,
    this.userName,
  });

  factory FaceSearchResult.fromMap(Map<String, dynamic> data) {
    final item = data['item'] as Map<String, dynamic>? ?? {};
    final faceData = data['faceData'] as Map<String, dynamic>? ?? {};
    
    return FaceSearchResult(
      itemId: data['itemId'] ?? '',
      title: item['title'] ?? 'Unknown Item',
      description: item['description'] ?? '',
      imageUrl: (item['images'] as List?)?.isNotEmpty == true 
          ? item['images'][0] 
          : null,
      category: item['category'] ?? 'Other',
      district: item['district'],
      type: item['type'] ?? 'found',
      similarity: (data['similarity'] ?? 0).toDouble(),
      matchConfidence: data['matchConfidence'] ?? 'Unknown',
      faceData: faceData,
      createdAt: item['createdAt'],
      userId: item['userId'],
      userName: item['userName'],
    );
  }
}

/// Face detected from image
class DetectedFace {
  final Rect boundingBox;
  final double headEulerAngleY; // Head rotation around vertical axis
  final double headEulerAngleZ; // Head rotation around front-facing axis
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final List<FaceContour?> contours;
  final List<FaceLandmark?> landmarks;

  DetectedFace({
    required this.boundingBox,
    required this.headEulerAngleY,
    required this.headEulerAngleZ,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.contours = const [],
    this.landmarks = const [],
  });

  /// Generate a simplified face vector for comparison
  List<double> generateFaceVector() {
    final vector = <double>[];
    
    // Add bounding box ratios (normalized)
    final aspectRatio = boundingBox.width / boundingBox.height;
    vector.add(aspectRatio);
    
    // Add head angles (normalized to -1 to 1)
    vector.add(headEulerAngleY / 45.0);
    vector.add(headEulerAngleZ / 45.0);
    
    // Add expression probabilities
    vector.add(smilingProbability ?? 0.5);
    vector.add(leftEyeOpenProbability ?? 0.5);
    vector.add(rightEyeOpenProbability ?? 0.5);
    
    // Add landmark positions (normalized to bounding box)
    for (final landmark in landmarks) {
      if (landmark != null) {
        final normalizedX = (landmark.position.x - boundingBox.left) / boundingBox.width;
        final normalizedY = (landmark.position.y - boundingBox.top) / boundingBox.height;
        vector.add(normalizedX);
        vector.add(normalizedY);
      }
    }
    
    return vector;
  }
}

class FaceSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FaceDetector _faceDetector;
  
  FaceSearchService() {
    // Initialize ML Kit Face Detector with all landmarks and contours
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15, // Minimum face size relative to image
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _faceDetector.close();
  }

  /// Detect faces in an image file
  Future<List<DetectedFace>> detectFaces(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      return faces.map((face) => DetectedFace(
        boundingBox: face.boundingBox,
        headEulerAngleY: face.headEulerAngleY ?? 0,
        headEulerAngleZ: face.headEulerAngleZ ?? 0,
        smilingProbability: face.smilingProbability,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        contours: face.contours.values.toList(),
        landmarks: face.landmarks.values.toList(),
      )).toList();
    } catch (e) {
      print('❌ Error detecting faces: $e');
      return [];
    }
  }

  /// Detect faces from image bytes
  Future<List<DetectedFace>> detectFacesFromBytes(Uint8List imageBytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(640, 480), // Will be adjusted by ML Kit
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 640,
        ),
      );
      final faces = await _faceDetector.processImage(inputImage);
      
      return faces.map((face) => DetectedFace(
        boundingBox: face.boundingBox,
        headEulerAngleY: face.headEulerAngleY ?? 0,
        headEulerAngleZ: face.headEulerAngleZ ?? 0,
        smilingProbability: face.smilingProbability,
        leftEyeOpenProbability: face.leftEyeOpenProbability,
        rightEyeOpenProbability: face.rightEyeOpenProbability,
        contours: face.contours.values.toList(),
        landmarks: face.landmarks.values.toList(),
      )).toList();
    } catch (e) {
      print('❌ Error detecting faces from bytes: $e');
      return [];
    }
  }

  /// Search for items containing similar faces
  /// 
  /// [imageFile] - The image file containing the face to search for
  /// [threshold] - Minimum similarity score (0-100), default 60
  /// [limit] - Maximum number of results, default 20
  /// [category] - Optional category filter
  /// [district] - Optional district filter
  Future<List<FaceSearchResult>> searchByFace({
    required File imageFile,
    double threshold = 60,
    int limit = 20,
    String? category,
    String? district,
  }) async {
    try {
      // Step 1: Detect faces in the search image
      final detectedFaces = await detectFaces(imageFile);
      
      if (detectedFaces.isEmpty) {
        print('⚠️ No faces detected in the search image');
        return [];
      }

      // Step 2: Generate face vector from the first detected face
      final searchFace = detectedFaces.first;
      final searchVector = searchFace.generateFaceVector();

      print('🔍 Searching with face vector of length ${searchVector.length}');

      // Step 3: Query items with faces from Firestore
      Query<Map<String, dynamic>> query = _firestore
          .collection('items')
          .where('status', isEqualTo: 'active')
          .where('hasFaces', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      if (district != null && district.isNotEmpty) {
        query = query.where('district', isEqualTo: district);
      }

      final itemsSnapshot = await query.limit(50).get();
      
      if (itemsSnapshot.docs.isEmpty) {
        print('⚠️ No items with faces found');
        return [];
      }

      // Step 4: Get all face data for matching items
      final List<FaceSearchResult> results = [];

      for (final itemDoc in itemsSnapshot.docs) {
        final itemData = itemDoc.data();
        final itemId = itemDoc.id;

        // Get faces for this item
        final facesSnapshot = await _firestore
            .collection('faces')
            .where('itemId', isEqualTo: itemId)
            .get();

        for (final faceDoc in facesSnapshot.docs) {
          final faceData = faceDoc.data();
          final storedVector = List<double>.from(faceData['faceVector'] ?? []);
          
          // Step 5: Calculate similarity
          final similarity = _calculateCosineSimilarity(searchVector, storedVector);
          
          if (similarity >= threshold) {
            results.add(FaceSearchResult(
              itemId: itemId,
              title: itemData['title'] ?? 'Unknown',
              description: itemData['description'] ?? '',
              imageUrl: (itemData['images'] as List?)?.isNotEmpty == true 
                  ? itemData['images'][0]
                  : null,
              category: itemData['category'] ?? 'Other',
              district: itemData['district'],
              type: itemData['type'] ?? 'found',
              similarity: similarity,
              matchConfidence: _getMatchConfidence(similarity),
              faceData: faceData,
              createdAt: itemData['createdAt'],
              userId: itemData['userId'],
              userName: itemData['userName'],
            ));
          }
        }
      }

      // Sort by similarity and limit results
      results.sort((a, b) => b.similarity.compareTo(a.similarity));
      
      print('✅ Found ${results.length} matching items');
      
      return results.take(limit).toList();
    } catch (e) {
      print('❌ Face search error: $e');
      rethrow;
    }
  }

  /// Search items by face using cloud function
  /// This is more accurate as it uses the backend Vision API
  Future<List<FaceSearchResult>> searchByFaceCloud({
    required String imageUrl,
    double threshold = 60,
    int limit = 20,
    String? category,
    String? district,
  }) async {
    try {
      // Call the Cloud Function
      final response = await http.post(
        Uri.parse('https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/searchByFace'),
        headers: {'Content-Type': 'application/json'},
        body: '''{
          "imageUrl": "$imageUrl",
          "threshold": $threshold,
          "limit": $limit
          ${category != null ? ', "category": "$category"' : ''}
          ${district != null ? ', "district": "$district"' : ''}
        }''',
      );

      if (response.statusCode == 200) {
        // TODO: Parse response.body into FaceSearchResult list
        // final jsonData = json.decode(response.body);
        return [];
      } else {
        throw Exception('Cloud function error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Cloud face search error: $e');
      rethrow;
    }
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0;
    
    // Pad shorter vector with zeros
    final maxLen = v1.length > v2.length ? v1.length : v2.length;
    while (v1.length < maxLen) v1.add(0);
    while (v2.length < maxLen) v2.add(0);

    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      norm1 += v1[i] * v1[i];
      norm2 += v2[i] * v2[i];
    }

    final magnitude = (norm1 * norm2);
    if (magnitude == 0) return 0;

    final similarity = dotProduct / magnitude;
    
    // Convert to percentage (0-100)
    return ((similarity + 1) * 50).clamp(0, 100);
  }

  /// Get match confidence label based on similarity score
  String _getMatchConfidence(double similarity) {
    if (similarity >= 90) return 'Very High';
    if (similarity >= 75) return 'High';
    if (similarity >= 60) return 'Medium';
    if (similarity >= 45) return 'Low';
    return 'Very Low';
  }

  /// Get color for match confidence
  static int getConfidenceColor(String confidence) {
    switch (confidence) {
      case 'Very High':
        return 0xFF10B981; // Green
      case 'High':
        return 0xFF22C55E; // Light Green
      case 'Medium':
        return 0xFFF59E0B; // Orange
      case 'Low':
        return 0xFFEF4444; // Red
      default:
        return 0xFF6B7280; // Gray
    }
  }
}
