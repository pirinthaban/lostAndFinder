import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Screen to display AI-matched items
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final Set<String> _deletedMatchIds = {};
  
  /// Check if a matched item still exists and is not resolved
  Future<bool> _isMatchValid(String matchedItemId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('items')
          .doc(matchedItemId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data();
      if (data?['isResolved'] == true) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete invalid match from Firestore
  Future<void> _deleteMatch(String matchId) async {
    try {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).delete();
    } catch (e) {
      debugPrint('Error deleting match: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 AI Matches'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _deletedMatchIds.clear();
              });
            },
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Please sign in to view matches'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('userId', isEqualTo: userId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  // Check if it's an index error
                  final errorStr = snapshot.error.toString();
                  final isIndexError = errorStr.contains('failed-precondition') || 
                                      errorStr.contains('requires an index');
                                      
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isIndexError ? Icons.build_circle : Icons.error_outline, 
                            size: 64, 
                            color: Colors.red
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError ? 'Missing Database Index' : 'Something went wrong',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          if (isIndexError) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Check your debug console for a URL to create the required index.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                
                final allMatches = snapshot.data?.docs ?? [];
                
                // Filter out already deleted matches
                final matches = allMatches.where((doc) => !_deletedMatchIds.contains(doc.id)).toList();
                
                if (matches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matches yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When you post items, AI will find\npotential matches automatically!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final doc = matches[index];
                    final match = doc.data() as Map<String, dynamic>;
                    final matchedItemId = match['matchedItemId'] as String?;
                    
                    // Check if matched item is still valid
                    return FutureBuilder<bool>(
                      future: _isMatchValid(matchedItemId ?? ''),
                      builder: (context, validSnapshot) {
                        // While checking, show the card normally
                        if (validSnapshot.connectionState == ConnectionState.waiting) {
                          return _MatchCard(match: match);
                        }
                        
                        // If match is invalid, hide it and mark for deletion
                        if (validSnapshot.data == false) {
                          // Schedule deletion
                          Future.microtask(() {
                            if (!_deletedMatchIds.contains(doc.id)) {
                              _deletedMatchIds.add(doc.id);
                              _deleteMatch(doc.id);
                              if (mounted) setState(() {});
                            }
                          });
                          return const SizedBox.shrink();
                        }
                        
                        return _MatchCard(match: match);
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  
  const _MatchCard({required this.match});

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final score = (match['confidenceScore'] as num?)?.toDouble() ?? 0;
    final textSimilarity = (match['textSimilarity'] as num?)?.toDouble() ?? 0;
    final title = match['matchedItemTitle'] as String? ?? 'Unknown Item';
    final description = match['matchedItemDescription'] as String? ?? '';
    final category = match['category'] as String? ?? '';
    final matchedUserName = match['matchedUserName'] as String? ?? 'Anonymous';
    final imageUrl = match['imageUrl'] as String?;
    final createdAt = (match['createdAt'] as Timestamp?)?.toDate();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to item details or chat
          _showMatchDetails(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and score
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Match score badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(score),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${score.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Category
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Footer: user and date
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          matchedUserName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM d, h:mm a').format(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                    // Text similarity indicator
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Text Match: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: textSimilarity / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                _getScoreColor(textSimilarity),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${textSimilarity.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Future<void> _contactOwner(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to chat')),
      );
      return;
    }

    final otherUserId = match['matchedUserId'] as String?;
    final otherUserName = match['matchedUserName'] as String? ?? 'User';
    final itemId = match['matchedItemId'] as String?;
    final itemTitle = match['matchedItemTitle'] as String? ?? 'Matched Item';

    if (otherUserId == null || itemId == null) {
      // Fallback: try standard userId/itemId if not found (just in case)
      debugPrint('Missing matchedUserId/matchedItemId. match keys: ${match.keys}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start chat: Missing details')),
      );
      return;
    }
    
    if (otherUserId == currentUser.uid) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You matched with your own item!')),
      );
      return;     
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting chat...'), duration: Duration(seconds: 1)),
    );

    try {
      final chatsRef = FirebaseFirestore.instance.collection('chats');
      
      final existingChats = await chatsRef
          .where('itemId', isEqualTo: itemId)
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String chatId = '';
      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId.isEmpty) {
        final newChat = await chatsRef.add({
          'participants': [currentUser.uid, otherUserId],
          'itemId': itemId,
          'itemTitle': itemTitle,
          'itemStatus': 'match',
          'lastMessage': 'Chat started from AI match',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = newChat.id;

        await chatsRef.doc(chatId).collection('messages').add({
          'text': 'Hi, I found a match for your item: $itemTitle',
          'senderId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (context.mounted) {
        context.push('/chat/$chatId', extra: {
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'itemTitle': itemTitle,
          'itemId': itemId,
        });
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showMatchDetails(BuildContext parentContext) {
    final score = (match['confidenceScore'] as num?)?.toDouble() ?? 0;
    final textSimilarity = (match['textSimilarity'] as num?)?.toDouble() ?? 0;
    final locationProximity = (match['locationProximity'] as num?)?.toDouble() ?? 0;
    final timeDifference = (match['timeDifference'] as num?)?.toDouble() ?? 0;
    
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                match['matchedItemTitle'] as String? ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Overall score
              _buildScoreSection(
                'Overall Match Score',
                score,
                Icons.auto_awesome,
              ),
              const SizedBox(height: 12),
              // Text similarity
              _buildScoreSection(
                'Text Similarity',
                textSimilarity,
                Icons.text_fields,
              ),
              const SizedBox(height: 12),
              // Location proximity
              _buildScoreSection(
                'Location Proximity',
                locationProximity,
                Icons.location_on,
              ),
              const SizedBox(height: 12),
              // Time relevance
              _buildScoreSection(
                'Time Relevance',
                timeDifference,
                Icons.access_time,
              ),
              const SizedBox(height: 24),
              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                match['matchedItemDescription'] as String? ?? 'No description',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Contact button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _contactOwner(parentContext);
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Contact Owner'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(String label, double score, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
