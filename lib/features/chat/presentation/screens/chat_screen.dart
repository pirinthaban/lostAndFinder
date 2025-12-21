import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic>? extra;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    this.extra,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen opens
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in messages.docs) {
        doc.reference.update({'isRead': true});
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Stream<List<Map<String, dynamic>>> _getMessagesStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['text'] ?? '',
          'senderId': data['senderId'] ?? '',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'isRead': data['isRead'] ?? false,
        };
      }).toList();
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      
      // Add message to subcollection
      await chatRef.collection('messages').add({
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat document with last message info
      await chatRef.update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Send notification to the other user
      final otherUserId = widget.extra?['otherUserId'] as String?;
      final otherUserName = widget.extra?['otherUserName'] as String? ?? 'User';
      final itemTitle = widget.extra?['itemTitle'] as String? ?? '';
      
      if (otherUserId != null && otherUserId.isNotEmpty) {
        // Get current user's name
        String senderName = 'Someone';
        try {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          if (currentUserDoc.exists) {
            senderName = currentUserDoc.data()?['name'] ?? 
                        currentUserDoc.data()?['email']?.split('@')[0] ?? 
                        'Someone';
          }
        } catch (e) {
          debugPrint('Error getting sender name: $e');
        }

        // Save notification to Firestore for the OTHER user
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': otherUserId, // Notify the OTHER user, not ourselves
          'title': 'New message from $senderName',
          'body': text.length > 50 ? '${text.substring(0, 50)}...' : text,
          'type': 'chat_message',
          'data': {
            'chatId': widget.chatId,
            'senderId': currentUserId,
            'senderName': senderName,
            'itemTitle': itemTitle,
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Show local notification (only works if user has app open)
        await NotificationService().showLocalNotification(
          title: 'New message from $senderName',
          body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
          payload: 'chat_${widget.chatId}',
        );
      }

      _messageController.clear();
      
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // Today - show time
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.extra?['otherUserName'] ?? 'User';
    final itemTitle = widget.extra?['itemTitle'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherUserName,
              style: const TextStyle(fontSize: 16),
            ),
            if (itemTitle.isNotEmpty)
              Text(
                itemTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final itemId = widget.extra?['itemId'];
              if (itemId != null && itemId.isNotEmpty) {
                // TODO: Navigate to item details
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto scroll to bottom when messages change
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] == currentUserId;
                    final showTimestamp = index == 0 ||
                        messages[index - 1]['timestamp']
                            .difference(message['timestamp'])
                            .inMinutes
                            .abs() >
                            30;

                    return Column(
                      children: [
                        if (showTimestamp)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _formatMessageTime(message['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        _MessageBubble(
                          message: message['text'],
                          isMe: isMe,
                          timestamp: message['timestamp'],
                          isRead: message['isRead'],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Message Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      // TODO: Add attachment
                    },
                    color: Colors.grey[600],
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  CircleAvatar(
                    backgroundColor: _isSending
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, size: 20),
                            color: Colors.white,
                            onPressed: _sendMessage,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final bool isRead;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.timestamp,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue[200] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
