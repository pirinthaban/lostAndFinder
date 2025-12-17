import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final List<Map<String, dynamic>> activities = [];

      // Get user's posted items
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      for (var doc in itemsSnapshot.docs) {
        final data = doc.data();
        activities.add({
          'type': 'post',
          'title': 'Posted: ${data['title']}',
          'subtitle': data['status'] == 'lost' ? 'Lost Item' : 'Found Item',
          'itemId': doc.id,
          'timestamp': data['createdAt'],
          'icon': Icons.post_add,
          'color': Colors.blue,
          'isResolved': data['isResolved'] == true,
        });

        // Add resolved activity if item was resolved
        if (data['isResolved'] == true && data['resolvedAt'] != null) {
          activities.add({
            'type': 'resolved',
            'title': 'Resolved: ${data['title']}',
            'subtitle': 'Item marked as resolved',
            'itemId': doc.id,
            'timestamp': data['resolvedAt'],
            'icon': Icons.check_circle,
            'color': Colors.green,
          });
        }
      }

      // Get user's claims/notifications sent
      final claimsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('claimantId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      for (var doc in claimsSnapshot.docs) {
        final data = doc.data();
        activities.add({
          'type': 'claim',
          'title': 'Claimed: ${data['itemTitle'] ?? 'Item'}',
          'subtitle': data['itemStatus'] == 'lost' ? 'Found this item' : 'This is mine',
          'itemId': data['itemId'],
          'timestamp': data['createdAt'],
          'icon': Icons.verified,
          'color': Colors.purple,
        });
      }

      // Get saved items activity
      final savedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('savedItems')
          .orderBy('savedAt', descending: true)
          .limit(20)
          .get();

      for (var doc in savedSnapshot.docs) {
        final data = doc.data();
        // Fetch item title
        String itemTitle = 'Item';
        try {
          final itemDoc = await FirebaseFirestore.instance
              .collection('items')
              .doc(data['itemId'])
              .get();
          if (itemDoc.exists) {
            itemTitle = itemDoc.data()?['title'] ?? 'Item';
          }
        } catch (_) {}

        activities.add({
          'type': 'saved',
          'title': 'Saved: $itemTitle',
          'subtitle': 'Added to saved items',
          'itemId': data['itemId'],
          'timestamp': data['savedAt'],
          'icon': Icons.bookmark,
          'color': Colors.orange,
        });
      }

      // Get chat activities (messages sent)
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .limit(20)
          .get();

      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        activities.add({
          'type': 'chat',
          'title': 'Chat: ${data['itemTitle'] ?? 'Item'}',
          'subtitle': data['lastMessage'] ?? 'Started conversation',
          'itemId': data['itemId'],
          'chatId': doc.id,
          'timestamp': data['lastMessageTime'],
          'icon': Icons.chat_bubble,
          'color': Colors.teal,
        });
      }

      // Sort all activities by timestamp
      activities.sort((a, b) {
        final aTime = a['timestamp'];
        final bTime = b['timestamp'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        DateTime aDate;
        DateTime bDate;

        if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else if (aTime is DateTime) {
          aDate = aTime;
        } else {
          return 0;
        }

        if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else if (bTime is DateTime) {
          bDate = bTime;
        } else {
          return 0;
        }

        return bDate.compareTo(aDate);
      });

      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity History')),
        body: const Center(child: Text('Please sign in to view activity')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadActivities();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No activity yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your activity will appear here',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadActivities,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];
                      final isLast = index == _activities.length - 1;

                      return InkWell(
                        onTap: () {
                          if (activity['chatId'] != null) {
                            context.push('/chat/${activity['chatId']}');
                          } else if (activity['itemId'] != null) {
                            context.push('/item/${activity['itemId']}');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeline indicator
                              Column(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (activity['color'] as Color).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      activity['icon'] as IconData,
                                      color: activity['color'] as Color,
                                      size: 20,
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 50,
                                      color: Colors.grey[300],
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              activity['title'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (activity['isResolved'] == true)
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        activity['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(activity['timestamp']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
