import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'free_ai_service.dart';

/// Service for image processing with FREE on-device AI
class ImageProcessingService {
  static final ImageProcessingService _instance = ImageProcessingService._internal();
  factory ImageProcessingService() => _instance;
  ImageProcessingService._internal();

  final _aiService = FreeAIService();
  final _imagePicker = ImagePicker();

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return picked != null ? File(picked.path) : null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<File?> pickFromCamera() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return picked != null ? File(picked.path) : null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  /// Process image for privacy (detect and blur sensitive data)
  Future<ProcessedImageResult> processForPrivacy(File imageFile) async {
    final result = ProcessedImageResult();
    
    try {
      // 1. Extract text using OCR
      final extractedText = await _aiService.extractText(imageFile);
      result.extractedText = extractedText;
      
      // 2. Detect NIC numbers
      final nicNumbers = _aiService.detectNICNumbers(extractedText);
      result.detectedNICs = nicNumbers;
      result.hasNIC = nicNumbers.isNotEmpty;
      
      // 3. Detect faces
      final faces = await _aiService.detectFaces(imageFile);
      result.faceCount = faces.length;
      result.hasFaces = faces.isNotEmpty;
      
      // 4. Apply blur if needed
      if (result.hasFaces || result.hasNIC) {
        final blurredBytes = await _aiService.autoBlurSensitiveData(imageFile);
        if (blurredBytes != null) {
          result.blurredImageBytes = blurredBytes;
          result.wasBlurred = true;
        }
      }
      
      result.success = true;
    } catch (e) {
      debugPrint('Error processing image: $e');
      result.error = e.toString();
    }
    
    return result;
  }

  /// Create thumbnail for an image
  Future<Uint8List?> createThumbnail(File imageFile, {int size = 300}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      final thumbnail = img.copyResizeCropSquare(image, size: size);
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 80));
    } catch (e) {
      debugPrint('Error creating thumbnail: $e');
      return null;
    }
  }

  /// Resize image to reduce file size
  Future<Uint8List?> resizeImage(
    File imageFile, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 85,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Only resize if larger than max dimensions
      img.Image resized;
      if (image.width > maxWidth || image.height > maxHeight) {
        resized = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
        );
      } else {
        resized = image;
      }
      
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }

  /// Extract dominant colors from image
  Future<List<Color>> extractDominantColors(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return [];
      
      // Simple color extraction: sample pixels
      final colors = <Color>[];
      final sampleSize = 10;
      final stepX = image.width ~/ sampleSize;
      final stepY = image.height ~/ sampleSize;
      
      final colorCounts = <int, int>{};
      
      for (int x = 0; x < image.width; x += stepX) {
        for (int y = 0; y < image.height; y += stepY) {
          final pixel = image.getPixel(x, y);
          // Round to reduce unique colors
          final r = (pixel.r.toInt() ~/ 32) * 32;
          final g = (pixel.g.toInt() ~/ 32) * 32;
          final b = (pixel.b.toInt() ~/ 32) * 32;
          final colorKey = (r << 16) | (g << 8) | b;
          colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1;
        }
      }
      
      // Sort by frequency and take top 5
      final sortedColors = colorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (int i = 0; i < 5 && i < sortedColors.length; i++) {
        final colorKey = sortedColors[i].key;
        colors.add(Color.fromRGBO(
          (colorKey >> 16) & 0xFF,
          (colorKey >> 8) & 0xFF,
          colorKey & 0xFF,
          1.0,
        ));
      }
      
      return colors;
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      return [];
    }
  }
}

/// Result of image processing
class ProcessedImageResult {
  bool success = false;
  String? error;
  
  // OCR results
  String extractedText = '';
  
  // NIC detection
  List<String> detectedNICs = [];
  bool hasNIC = false;
  
  // Face detection
  int faceCount = 0;
  bool hasFaces = false;
  
  // Blurred image
  Uint8List? blurredImageBytes;
  bool wasBlurred = false;
  
  /// Check if image contains sensitive data
  bool get hasSensitiveData => hasNIC || hasFaces;
  
  /// Get privacy warning message
  String get privacyWarning {
    final warnings = <String>[];
    if (hasNIC) warnings.add('NIC number detected');
    if (hasFaces) warnings.add('$faceCount face(s) detected');
    return warnings.isEmpty ? 'No sensitive data detected' : warnings.join(', ');
  }
}
