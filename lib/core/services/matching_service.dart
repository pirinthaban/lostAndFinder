import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'free_ai_service.dart';

/// Service to find matches for lost/found items using FREE AI
class MatchingService {
  static final MatchingService _instance = MatchingService._internal();
  factory MatchingService() => _instance;
  MatchingService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _aiService = FreeAIService();

  /// Find potential matches for an item
  Future<List<ItemMatch>> findMatches({
    required String itemId,
    required String itemType, // 'lost' or 'found'
    required String description,
    required String category,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    int limit = 10,
  }) async {

    try {
      // Search for opposite type (if lost, search found items)
      final searchType = itemType == 'lost' ? 'found' : 'lost';
      
      print('\n\n================================================================');
      print('🔍 AI MATCHING STARTED FOR ITEM: $itemId');
      print('================================================================');
      print('👉 My Item Type: $itemType');
      print('� Searching For: $searchType');
      print('� My Category: $category');
      print('� My Description: $description');
      print('� My Location: $location');
      
      // STEP 1: Smart Search - Filter by Category first!
      Query query = _firestore
          .collection('items')
          .where('status', isEqualTo: searchType)
          .where('category', isEqualTo: category); // STRICT CATEGORY MATCH
      
      // Limit results
      query = query.limit(50); // Fetch top 50 relevant items

      
      print('⏳ Executing Firestore query...');
      final snapshot = await query.get();
      print('✅ Query complete. Found ${snapshot.docs.length} documents.');
      
      if (snapshot.docs.isEmpty) {
        print('❌ NO ITEMS FOUND in database with status=$searchType');
        print('   (Try posting an item of type "$searchType" first)');
        return [];
      }
      
      final matches = <ItemMatch>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('----------------------------------------------------------------');
        print('📄 Checking Document ID: ${doc.id}');
        
        // Skip if already resolved
        if (data['isResolved'] == true) {
          print('   ⏭️ SKIPPED: Item is resolved');
          continue;
        }
        
        // Skip same user's items - only match between DIFFERENT users
        final userId = FirebaseAuth.instance.currentUser?.uid;
        print('   👤 My User ID: $userId');
        print('   👤 Item User ID: ${data['userId']}');
        
        // Only match items from OTHER users (not your own items)
        if (data['userId'] == userId) {
          print('   ⏭️ SKIPPED: This is your own item');
          continue;
        }
        print('   ✓ Different user - checking for match...');
        
        // Get item details
        final otherDescription = data['description'] as String? ?? '';
        final otherTitle = data['title'] as String? ?? '';
        final otherLocation = data['location'] as String? ?? '';
        final otherCategory = data['category'] as String? ?? '';
        final otherExtractedText = data['extractedText'] as String? ?? ''; // Get OCR text
        final otherTime = (data['createdAt'] as Timestamp?)?.toDate();
        
        print('   🏷️ Title: $otherTitle');
        print('   📂 Category: $otherCategory');
        print('   📝 Description: $otherDescription');
        
        // Prepare comparison strings
        final myText = '$description $category ${location ?? ''}';
        // Include OCR text in comparison
        final otherText = '$otherDescription $otherTitle $otherLocation $otherCategory $otherExtractedText';
        
        print('   🔍 COMPARING:');
        print('      MY TEXT: "$myText"');
        print('      OTHER TEXT: "$otherText"');
        
        // Calculate match score using text similarity
        // Calculate match score using text similarity
        final result = await _aiService.calculateMatchScore(
          description1: myText,
          description2: otherText,
          lat1: latitude,
          lon1: longitude,
          lat2: (data['latitude'] as num?)?.toDouble(),
          lon2: (data['longitude'] as num?)?.toDouble(),
          time1: createdAt,
          time2: otherTime,
          itemType1: itemType,
        );
        
        // Boost score if category matches
        double finalScore = result.confidenceScore;
        if (category.toLowerCase() == otherCategory.toLowerCase()) {
          finalScore += 15; // Bonus for same category
          print('   ✨ BONUS: Category match (+15%)');
        }
        
        print('   📊 CALCULATION:');
        print('      - Text Similarity: ${result.textSimilarity.toStringAsFixed(1)}%');
        print('      - Base Score: ${result.confidenceScore.toStringAsFixed(1)}%');
        print('      - Final Score: ${finalScore.toStringAsFixed(1)}%');
        
        // Lower threshold to 20% to catch more potential matches
        if (finalScore > 20) {
          print('   ✅ MATCH ACCEPTED! (Score > 20%)');
          matches.add(ItemMatch(
            itemId: doc.id,
            matchedItemId: itemId,
            title: data['title'] as String? ?? 'Unknown',
            description: otherDescription,
            category: otherCategory,
            imageUrl: (data['images'] as List?)?.firstOrNull as String?,
            confidenceScore: finalScore.clamp(0, 100),
            textSimilarity: result.textSimilarity,
            locationProximity: result.locationProximity,
            timeDifference: result.timeDifference,
            userId: data['userId'] as String? ?? '',
            userName: data['userName'] as String? ?? 'Anonymous',
            createdAt: otherTime ?? DateTime.now(),
          ));
        } else {
          print('   ❌ MATCH REJECTED (Score too low)');
        }
      }
      
      // Sort by confidence score (highest first)
      matches.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
      
      print('================================================================');
      print('🎯 MATCHING COMPLETE. Returning ${matches.length} matches.');
      print('================================================================\n\n');
      
      return matches.take(limit).toList();
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in findMatches: $e');
      print(stackTrace);
      return [];
    }
  }

  /// Save matches to Firestore
  Future<void> saveMatches(String itemId, List<ItemMatch> matches, {
    String? itemTitle,
    String? itemDescription,
    String? itemType,
  }) async {
    if (matches.isEmpty) return;
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';
    final batch = _firestore.batch();
    
    for (final match in matches) {
      final matchRef = _firestore.collection('matches').doc();
      batch.set(matchRef, {
        // IDs
        'itemId': itemId,
        'matchedItemId': match.itemId,
        
        // Current user info (who posted and triggered the match)
        'userId': currentUserId,
        'userName': currentUserName,
        'itemTitle': itemTitle ?? 'Unknown',
        'itemDescription': itemDescription ?? '',
        'itemType': itemType ?? 'unknown',
        
        // Matched item info
        'matchedItemTitle': match.title,
        'matchedItemDescription': match.description,
        'matchedUserId': match.userId,
        'matchedUserName': match.userName,
        'category': match.category,
        'imageUrl': match.imageUrl,
        
        // Scores
        'confidenceScore': match.confidenceScore,
        'textSimilarity': match.textSimilarity,
        'locationProximity': match.locationProximity,
        'timeDifference': match.timeDifference,
        
        // Status
        'status': 'pending',
        'notificationSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Also save a copy for the OTHER user (so they see the match too)
      final matchRefOther = _firestore.collection('matches').doc();
      batch.set(matchRefOther, {
        // IDs (reversed)
        'itemId': match.itemId,
        'matchedItemId': itemId,
        
        // Other user info
        'userId': match.userId,
        'userName': match.userName,
        'itemTitle': match.title,
        'itemDescription': match.description,
        'itemType': itemType == 'lost' ? 'found' : 'lost',
        
        // Current user becomes the matched user
        'matchedItemTitle': itemTitle ?? 'Unknown',
        'matchedItemDescription': itemDescription ?? '',
        'matchedUserId': currentUserId,
        'matchedUserName': currentUserName,
        'category': match.category,
        'imageUrl': null, // We don't have the current item's image URL here
        
        // Same scores
        'confidenceScore': match.confidenceScore,
        'textSimilarity': match.textSimilarity,
        'locationProximity': match.locationProximity,
        'timeDifference': match.timeDifference,
        
        // Status
        'status': 'pending',
        'notificationSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    try {
      await batch.commit();
      debugPrint('💾 SUCCESS: Saved ${matches.length * 2} match records to Firestore');
    } catch (e) {
      debugPrint('❌ ERROR SAVING MATCHES: $e');
      throw e; // Re-throw to let caller know
    }
  }

  /// Get saved matches for an item
  Future<List<Map<String, dynamic>>> getSavedMatches(String itemId) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('lostItemId', isEqualTo: itemId)
          .orderBy('confidenceScore', descending: true)
          .get();
      
      if (snapshot.docs.isEmpty) {
        final snapshot2 = await _firestore
            .collection('matches')
            .where('foundItemId', isEqualTo: itemId)
            .orderBy('confidenceScore', descending: true)
            .get();
        return snapshot2.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      }
      
      return snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      debugPrint('Error getting saved matches: $e');
      return [];
    }
  }
}

/// Represents a matched item
class ItemMatch {
  final String itemId;
  final String matchedItemId;
  final String title;
  final String description;
  final String category;
  final String? imageUrl;
  final double confidenceScore;
  final double textSimilarity;
  final double locationProximity;
  final double timeDifference;
  final String userId;
  final String userName;
  final DateTime createdAt;

  ItemMatch({
    required this.itemId,
    required this.matchedItemId,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    required this.confidenceScore,
    required this.textSimilarity,
    required this.locationProximity,
    required this.timeDifference,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  bool get isHighConfidence => confidenceScore >= 70;
  bool get isMediumConfidence => confidenceScore >= 40 && confidenceScore < 70;
  
  String get confidenceLabel {
    if (isHighConfidence) return 'High Match';
    if (isMediumConfidence) return 'Medium Match';
    return 'Low Match';
  }
  
  Color get confidenceColor {
    if (isHighConfidence) return Colors.green;
    if (isMediumConfidence) return Colors.orange;
    return Colors.grey;
  }
}
