import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create or get existing chat between current user and item owner
  /// Returns the chat ID
  static Future<String> createOrGetChat({
    required String itemId,
    required String itemTitle,
    required String itemStatus,
    required String otherUserId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (currentUserId == otherUserId) {
      throw Exception('Cannot chat with yourself');
    }

    // Create a consistent chat ID using sorted user IDs and item ID
    final participants = [currentUserId, otherUserId]..sort();
    final chatId = '${participants[0]}_${participants[1]}_$itemId';

    // Check if chat already exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // Create new chat
      await _firestore.collection('chats').doc(chatId).set({
        'participants': participants,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'itemStatus': itemStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  /// Send the first message in a chat (optional helper)
  static Future<void> sendInitialMessage({
    required String chatId,
    required String message,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final chatRef = _firestore.collection('chats').doc(chatId);

    // Add message
    await chatRef.collection('messages').add({
      'text': message,
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Update chat document
    await chatRef.update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  /// Get other user's name from user document or email
  static Future<String> getOtherUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? 
               userDoc.data()?['email']?.split('@')[0] ?? 
               'User';
      }
    } catch (e) {
      // Ignore errors
    }
    return 'User';
  }
}
