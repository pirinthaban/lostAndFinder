import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  // State variables
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isActionLoading = false;
  Map<String, dynamic>? _itemData;
  Map<String, dynamic>? _ownerData;
  int _currentImageIndex = 0;
  
  // Firebase references
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;
  
  String get _currentUserId => _currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    debugPrint('ItemDetailScreen initialized with ID: ${widget.itemId}');
    _loadAllData();
  }

  /// Load item data, owner data, and saved status
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('Loading item data...');
      // Load item data
      final itemDoc = await _firestore.collection('items').doc(widget.itemId).get();
      
      if (!itemDoc.exists) {
        debugPrint('Item document does not exist');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _itemData = null;
          });
        }
        return;
      }

      final itemData = {'id': widget.itemId, ...itemDoc.data()!};
      debugPrint('Item data loaded: ${itemData['title']}');
      
      // Load owner data
      Map<String, dynamic>? ownerData;
      final ownerId = itemData['userId'] as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        debugPrint('Loading owner data for: $ownerId');
        final ownerDoc = await _firestore.collection('users').doc(ownerId).get();
        if (ownerDoc.exists) {
          ownerData = ownerDoc.data();
        }
      }

      // Check if saved
      bool isSaved = false;
      if (_currentUserId.isNotEmpty) {
        final savedDocs = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('savedItems')
            .where('itemId', isEqualTo: widget.itemId)
            .limit(1)
            .get();
        isSaved = savedDocs.docs.isNotEmpty;
      }

      if (mounted) {
        setState(() {
          _itemData = itemData;
          _ownerData = ownerData;
          _isSaved = isSaved;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading item: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load item details');
      }
    }
  }

  /// Get owner display name
  String _getOwnerName() {
    if (_ownerData != null) {
      final name = _ownerData!['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
      
      final email = _ownerData!['email']?.toString();
      if (email != null && email.isNotEmpty) return email.split('@')[0];
    }
    return 'Unknown User';
  }

  /// Format timestamp to readable string with date, hour and minutes
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recently';
      }
      
      // Format: Dec 17, 2025 at 10:30 AM
      final dateFormat = DateFormat('MMM dd, yyyy');
      final timeFormat = DateFormat('hh:mm a');
      
      return '${dateFormat.format(date)} at ${timeFormat.format(date)}';
    } catch (e) {
      return 'Recently';
    }
  }

  /// Toggle save/bookmark item
  Future<void> _toggleSaveItem() async {
    if (_currentUserId.isEmpty) {
      _showError('Please sign in to save items');
      return;
    }

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('savedItems');

      if (_isSaved) {
        // Remove from saved
        final docs = await savedRef.where('itemId', isEqualTo: widget.itemId).get();
        for (var doc in docs.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          setState(() => _isSaved = false);
          _showSuccess('Removed from saved items');
        }
      } else {
        // Add to saved
        await savedRef.add({
          'itemId': widget.itemId,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _isSaved = true);
          _showSuccess('Added to saved items');
        }
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  /// Contact the item owner - create chat and navigate
  Future<void> _contactOwner() async {
    if (_itemData == null || _currentUserId.isEmpty) return;
    
    setState(() => _isActionLoading = true);

    try {
      final ownerId = _itemData!['userId'] as String;
      final itemTitle = _itemData!['title'] ?? 'Item';
      final itemStatus = _itemData!['status'] ?? 'lost';
      
      // Check for existing chat
      final existingChats = await _firestore
          .collection('chats')
          .where('itemId', isEqualTo: widget.itemId)
          .where('participants', arrayContains: _currentUserId)
          .get();

      String chatId = '';
      
      // Filter locally to find chat with specific owner
      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(ownerId)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId.isEmpty) {
        // Create new chat
        final chatRef = await _firestore.collection('chats').add({
          'participants': [_currentUserId, ownerId],
          'itemId': widget.itemId,
          'itemTitle': itemTitle,
          'itemStatus': itemStatus,
          'lastMessage': 'Chat started',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = chatRef.id;

        // Send initial message
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add({
          'text': 'Hi, I\'m interested in your ${itemStatus == 'lost' ? 'lost' : 'found'} item: $itemTitle',
          'senderId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      setState(() => _isActionLoading = false);

      if (mounted) {
        context.push('/chat/$chatId', extra: {
          'otherUserId': ownerId,
          'otherUserName': _getOwnerName(),
          'itemTitle': itemTitle,
          'itemId': widget.itemId,
        });
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showError('Error starting chat: $e');
    }
  }

  /// Verify/Claim item or mark as resolved
  Future<void> _verifyItem() async {
    if (_itemData == null || _currentUserId.isEmpty) return;

    final isOwner = _itemData!['userId'] == _currentUserId;
    final isLost = _itemData!['status'] == 'lost';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwner ? 'Mark as Resolved?' : (isLost ? 'Found this item?' : 'Is this yours?')),
        content: Text(
          isOwner
              ? 'Are you sure you want to mark this item as resolved? This action cannot be undone.'
              : isLost
                  ? 'Do you want to claim that you found this item? The owner will be notified.'
                  : 'Is this item yours? The person who found it will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(isOwner ? 'Resolve' : 'Yes, Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);

    try {
      if (isOwner) {
        // Owner marking as resolved
        await _firestore.collection('items').doc(widget.itemId).update({
          'isResolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': _currentUserId,
        });

        _showSuccess('Item marked as resolved!');
        if (mounted) context.pop();
      } else {
        // Create claim notification
        await _firestore.collection('notifications').add({
          'type': 'claim',
          'itemId': widget.itemId,
          'itemTitle': _itemData!['title'],
          'itemStatus': _itemData!['status'],
          'claimantId': _currentUserId,
          'ownerId': _itemData!['userId'],
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // Also start a chat
        await _contactOwner();
        _showSuccess('Claim sent! You can now chat with the owner.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Delete post and all related data
  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This will permanently delete this post and all related chats and notifications. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);

    try {
      // Delete related chats
      try {
        final chats = await _firestore
            .collection('chats')
            .where('itemId', isEqualTo: widget.itemId)
            .get();
        
        for (var chat in chats.docs) {
          try {
            // Delete messages in this chat
            final messages = await _firestore
                .collection('chats')
                .doc(chat.id)
                .collection('messages')
                .get();
            
            for (var message in messages.docs) {
              await message.reference.delete();
            }
          } catch (e) {
            debugPrint('Error deleting messages: $e');
          }
          
          // Delete chat document
          await chat.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting chats: $e');
      }

      // Delete related notifications
      try {
        final notifications = await _firestore
            .collection('notifications')
            .where('itemId', isEqualTo: widget.itemId)
            .get();
        
        for (var notification in notifications.docs) {
          await notification.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting notifications: $e');
      }

      // Delete from current user's saved items only
      try {
        if (_currentUserId.isNotEmpty) {
          final savedItems = await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('savedItems')
              .where('itemId', isEqualTo: widget.itemId)
              .get();
          
          for (var savedItem in savedItems.docs) {
            await savedItem.reference.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting saved items: $e');
      }

      // Finally, delete the item itself
      await _firestore.collection('items').doc(widget.itemId).delete();

      if (mounted) {
        _showSuccess('Post deleted successfully');
        context.pop();
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      _showError('Error deleting post: $e');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building ItemDetailScreen. isLoading: $_isLoading');

    // Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Item Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.blue,
            ),
          ),
        ),
      );
    }

    // Item not found
    if (_itemData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Item Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Item not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'This item may have been deleted',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Item data available
    final isOwner = _itemData!['userId'] == _currentUserId;
    final isResolved = _itemData!['isResolved'] == true;
    final isLost = _itemData!['status'] == 'lost';
    final statusColor = isLost ? Colors.orange : Colors.green;
    
    // Safely get images
    List<String> images = [];
    try {
      final rawImages = _itemData!['images'];
      if (rawImages is List) {
        images = rawImages.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error parsing images: $e');
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Save button (only for non-owners)
          if (!isOwner)
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? Colors.orange : null,
              ),
              onPressed: _toggleSaveItem,
              tooltip: _isSaved ? 'Remove from saved' : 'Save item',
            ),
          // Delete button (only for owners)
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isActionLoading ? null : _deletePost,
              tooltip: 'Delete post',
            ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              _showSuccess('Share coming soon');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Gallery
              _buildImageGallery(images),
              
              // Main Content Card
              Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    _buildStatusBadge(isLost, isResolved, statusColor),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        (_itemData!['title'] ?? 'No Title').toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Owner Info
                    _buildOwnerInfo(isOwner),
                    
                    const Divider(height: 32),
                    
                    // Details Section
                    _buildDetailsSection(),
                    
                    const Divider(height: 32),
                    
                    // Description
                    _buildDescription(),
                    
                    const SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Bottom Action Buttons
      bottomNavigationBar: _buildBottomButtons(isOwner, isResolved, isLost),
    );
  }

  /// Image Gallery Widget
  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.image_outlined, size: 80, color: Colors.grey[500]),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.broken_image, size: 64)),
                  );
                },
              );
            },
          ),
          // Image indicator dots
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentImageIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? Colors.white
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  /// Status Badge Widget
  Widget _buildStatusBadge(bool isLost, bool isResolved, Color statusColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLost ? Icons.search : Icons.favorite,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isLost ? 'LOST ITEM' : 'FOUND ITEM',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (isResolved) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 4),
            const Text(
              'RESOLVED',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Owner Info Widget
  Widget _buildOwnerInfo(bool isOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: _ownerData?['photoUrl'] != null &&
                    _ownerData!['photoUrl'].toString().isNotEmpty
                ? NetworkImage(_ownerData!['photoUrl'].toString())
                : null,
            child: _ownerData?['photoUrl'] == null ||
                    _ownerData!['photoUrl'].toString().isEmpty
                ? Text(
                    _getOwnerName().isNotEmpty
                        ? _getOwnerName()[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Name and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getOwnerName(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Posted ${_formatDate(_itemData!['createdAt'])}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Owner badge
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Your Post',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Details Section Widget
  Widget _buildDetailsSection() {
    return Column(
      children: [
        _buildDetailRow(Icons.category, 'Category', (_itemData!['category'] ?? 'Other').toString()),
        _buildDetailRow(Icons.location_on, 'Location', (_itemData!['location'] ?? 'Unknown').toString()),
        _buildDetailRow(Icons.calendar_today, 'Date', (_itemData!['date'] ?? 'Unknown').toString()),
        if (_itemData!['contact'] != null && _itemData!['contact'].toString().isNotEmpty)
          _buildDetailRow(Icons.phone, 'Contact', _itemData!['contact'].toString()),
      ],
    );
  }

  /// Single Detail Row
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Description Widget
  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (_itemData!['description'] ?? 'No description provided.').toString(),
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Action Buttons
  Widget _buildBottomButtons(bool isOwner, bool isResolved, bool isLost) {
    if (isResolved) {
      // Resolved state - show resolved message
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: const SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'This item has been resolved',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active item - show action buttons
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Contact Button (non-owners only)
            if (!isOwner) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading ? null : _contactOwner,
                  icon: _isActionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Action Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _verifyItem,
                icon: Icon(
                  isOwner
                      ? Icons.check_circle
                      : (isLost ? Icons.check : Icons.favorite),
                ),
                label: Text(
                  isOwner
                      ? 'Mission Complete'
                      : (isLost ? 'I Found It' : 'It\'s Mine'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
