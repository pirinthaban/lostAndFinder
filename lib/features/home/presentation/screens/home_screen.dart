import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../chat/data/chat_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../matches/presentation/screens/matches_screen.dart';
import '../../../../core/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeFeedScreen(),
    const MatchesScreen(), // Changed from Search to Matches
    Container(), // Post screen handled by FAB
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Request notification permission AFTER login
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Small delay to let the home screen render first
    await Future.delayed(const Duration(milliseconds: 500));
    await NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            // Show post dialog
            _showPostOptions(context);
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 32),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What would you like to post?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.search,
                  color: theme.colorScheme.secondary,
                ),
              ),
              title: const Text('I Lost Something'),
              subtitle: const Text('Post details about your lost item'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/post-item', extra: {'itemType': 'lost'});
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('I Found Something'),
              subtitle: const Text('Help someone find their lost item'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/post-item', extra: {'itemType': 'found'});
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost & Found'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Lost'),
            Tab(text: 'Found'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FeedList(filter: 'all'),
          _FeedList(filter: 'lost'),
          _FeedList(filter: 'found'),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Nearby Items'),
              subtitle: const Text('Within 5 km'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Recent Items'),
              subtitle: const Text('Last 7 days'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Category'),
              subtitle: const Text('Electronics, Documents, etc.'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatefulWidget {
  final String filter;

  const _FeedList({required this.filter});

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> {
  Stream<List<Map<String, dynamic>>> _getItemsStream() {
    Query query = FirebaseFirestore.instance
        .collection('items')
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    // Apply filter
    if (widget.filter != 'all') {
      query = query.where('status', isEqualTo: widget.filter);
    }

    return query.snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> items = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String?;
        
        // Fetch user data
        String userName = 'Unknown User';
        String userAvatar = '';
        if (userId != null && userId.isNotEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              userName = userData?['name']?.toString() ?? 
                         userData?['email']?.toString().split('@')[0] ?? 
                         'Unknown User';
              userAvatar = userData?['photoUrl']?.toString() ?? '';
            } else {
              // User document doesn't exist, use email from item data
              userName = data['userEmail']?.toString().split('@')[0] ?? 'Unknown User';
            }
          } catch (e) {
            debugPrint('Error fetching user data: $e');
            // Use email from item data if available
            userName = data['userEmail']?.toString().split('@')[0] ?? 'Unknown User';
          }
        } else {
          // No userId, try to use email from item
          userName = data['userEmail']?.toString().split('@')[0] ?? 'Unknown User';
        }

        // Format date
        String dateText = 'Just now';
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          final difference = DateTime.now().difference(date);
          
          if (difference.inMinutes < 60) {
            dateText = '${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            dateText = '${difference.inHours}h ago';
          } else if (difference.inDays < 7) {
            dateText = '${difference.inDays}d ago';
          } else {
            dateText = '${date.day}/${date.month}/${date.year}';
          }
        }

        items.add({
          'id': doc.id,
          'type': data['status'] ?? 'lost',
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? '',
          'category': data['category'] ?? 'Other',
          'location': data['location'] ?? 'Unknown',
          'date': dateText,
          'imageUrl': (data['images'] as List?)?.isNotEmpty == true ? data['images'][0] : null,
          'userName': userName,
          'userAvatar': userAvatar,
          'userId': userId,
          'contact': data['contact'] ?? '',
        });
      }
      
      return items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final items = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild to refresh stream
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to post!',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(item: item);
                  },
                ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLost = item['type'] == 'lost';
    final statusColor = isLost ? theme.colorScheme.secondary : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/item/${item['id']}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: item['userAvatar'] != null && item['userAvatar'].toString().isNotEmpty
                        ? NetworkImage(item['userAvatar'])
                        : null,
                    child: item['userAvatar'] == null || item['userAvatar'].toString().isEmpty
                        ? Text(
                            (item['userName'] ?? 'U').toString().isNotEmpty 
                                ? (item['userName'].toString()[0].toUpperCase())
                                : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['userName'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          item['date'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLost ? Icons.search : Icons.check_circle,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLost ? 'LOST' : 'FOUND',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Item image (if available)
            if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
              Image.network(
                item['imageUrl'],
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 240,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  image: DecorationImage(
                    image: const AssetImage('assets/images/pattern_bg.png'), // Fallback pattern if available
                    fit: BoxFit.cover,
                    opacity: 0.1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLost ? Icons.search_off : Icons.inventory_2_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No image provided',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

            // Item details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['location'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['category'],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (item['id'] != null) {
                              context.push('/item/${item['id']}');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error: Item ID not found')),
                              );
                            }
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            if (currentUserId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login to contact owner')),
                              );
                              return;
                            }

                            final ownerId = item['userId'] as String?;
                            if (ownerId == null || ownerId == currentUserId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cannot contact yourself')),
                              );
                              return;
                            }

                            try {
                              // Show loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening chat...')),
                              );

                              // Fetch owner name from Firestore
                              String ownerName = 'User';
                              try {
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(ownerId)
                                    .get();
                                if (userDoc.exists) {
                                  final userData = userDoc.data();
                                  ownerName = userData?['name']?.toString() ??
                                             userData?['displayName']?.toString() ??
                                             userData?['email']?.toString().split('@')[0] ??
                                             'User';
                                }
                              } catch (e) {
                                debugPrint('Error fetching user name: $e');
                              }

                              // Create or get chat using ChatService
                              final chatId = await ChatService.createOrGetChat(
                                itemId: item['id'],
                                itemTitle: item['title'] ?? 'Item',
                                itemStatus: item['type'] ?? 'lost',
                                otherUserId: ownerId,
                              );

                              // Send initial message
                              await ChatService.sendInitialMessage(
                                chatId: chatId,
                                message: 'Hi, I\'m interested in your ${item['type'] == 'lost' ? 'lost' : 'found'} item: ${item['title']}',
                              );

                              // Navigate to chat
                              if (context.mounted) {
                                context.push('/chat/$chatId', extra: {
                                  'otherUserId': ownerId,
                                  'otherUserName': ownerName,
                                  'itemTitle': item['title'],
                                  'itemId': item['id'],
                                });
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Contact'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: Colors.white,
                          ),
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
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedType = 'All';
  bool _isSearching = false;

  final List<String> _categories = [
    'All',
    'Electronics',
    'Documents',
    'Keys',
    'Pets',
    'Bags',
    'Jewelry',
    'Clothing',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search items...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _isSearching = false;
                      });
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            setState(() {
              _isSearching = value.isNotEmpty;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                setState(() => _isSearching = true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Type Filter
                _buildFilterChip(
                  label: 'All',
                  isSelected: _selectedType == 'All',
                  onSelected: () => setState(() => _selectedType = 'All'),
                ),
                _buildFilterChip(
                  label: 'Lost',
                  isSelected: _selectedType == 'Lost',
                  onSelected: () => setState(() => _selectedType = 'Lost'),
                  color: const Color(0xFFFFA726),
                ),
                _buildFilterChip(
                  label: 'Found',
                  isSelected: _selectedType == 'Found',
                  onSelected: () => setState(() => _selectedType = 'Found'),
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 16),
                // Category Filters
                ..._categories.map((category) => _buildFilterChip(
                      label: category,
                      isSelected: _selectedCategory == category,
                      onSelected: () => setState(() => _selectedCategory = category),
                    )),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        backgroundColor: Colors.grey[200],
        selectedColor: (color ?? Theme.of(context).primaryColor).withOpacity(0.2),
        checkmarkColor: color ?? Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? (color ?? Theme.of(context).primaryColor) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching && _searchController.text.isEmpty && 
        _selectedCategory == 'All' && _selectedType == 'All') {
      return _buildEmptyState();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getSearchResultsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return _SearchResultCard(item: item);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for Lost or Found Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Try searching for "phone", "wallet", "keys", etc.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or filters',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getSearchResultsStream() {
    Query query = FirebaseFirestore.instance
        .collection('items')
        .where('isResolved', isEqualTo: false);

    // Apply type filter (Lost/Found)
    if (_selectedType != 'All') {
      query = query.where('status', isEqualTo: _selectedType.toLowerCase());
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    query = query.orderBy('createdAt', descending: true).limit(50);

    return query.snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> items = [];
      final searchQuery = _searchController.text.toLowerCase();
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Apply text search filter
        if (searchQuery.isNotEmpty) {
          final title = (data['title'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();
          
          if (!title.contains(searchQuery) && 
              !description.contains(searchQuery) &&
              !location.contains(searchQuery)) {
            continue;
          }
        }
        
        final userId = data['userId'] as String?;
        
        // Fetch user data
        String userName = 'Unknown User';
        String userAvatar = '';
        if (userId != null && userId.isNotEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              userName = userData?['name']?.toString() ?? 
                         userData?['email']?.toString().split('@')[0] ?? 
                         'Unknown User';
              userAvatar = userData?['photoUrl']?.toString() ?? '';
            }
          } catch (e) {
            userName = data['userEmail']?.toString().split('@')[0] ?? 'Unknown User';
          }
        }

        // Format date
        String dateText = 'Just now';
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          final difference = DateTime.now().difference(date);
          
          if (difference.inMinutes < 60) {
            dateText = '${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            dateText = '${difference.inHours}h ago';
          } else if (difference.inDays < 7) {
            dateText = '${difference.inDays}d ago';
          } else {
            dateText = '${date.day}/${date.month}/${date.year}';
          }
        }

        items.add({
          'id': doc.id,
          'type': data['status'] ?? 'lost',
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? '',
          'category': data['category'] ?? 'Other',
          'location': data['location'] ?? 'Unknown',
          'date': dateText,
          'imageUrl': (data['images'] as List?)?.isNotEmpty == true ? data['images'][0] : null,
          'userName': userName,
          'userAvatar': userAvatar,
          'userId': userId,
          'contact': data['contact'] ?? '',
        });
      }
      
      return items;
    });
  }

}

class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SearchResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLost = item['type'] == 'lost';
    final statusColor = isLost ? const Color(0xFFFFA726) : const Color(0xFF4CAF50);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              context.push('/item/${item['id']}');
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(item['category']),
                      color: statusColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['title'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isLost ? 'LOST' : 'FOUND',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['location'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              item['date'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
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

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      debugPrint('Search View button pressed for item: ${item['id']}');
                      debugPrint('Item title: ${item['title']}');
                      if (item['id'] != null) {
                        context.push('/item/${item['id']}');
                      } else {
                        debugPrint('ERROR: Item ID is null!');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error: Item ID not found')),
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please login to contact owner')),
                        );
                        return;
                      }

                      final ownerId = item['userId'] as String?;
                      if (ownerId == null || ownerId == currentUserId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot contact yourself')),
                        );
                        return;
                      }

                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening chat...')),
                        );

                        // Fetch owner name from Firestore
                        String ownerName = 'User';
                        try {
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(ownerId)
                              .get();
                          if (userDoc.exists) {
                            final userData = userDoc.data();
                            ownerName = userData?['name']?.toString() ??
                                       userData?['displayName']?.toString() ??
                                       userData?['email']?.toString().split('@')[0] ??
                                       'User';
                          }
                        } catch (e) {
                          debugPrint('Error fetching user name: $e');
                        }

                        final chatId = await ChatService.createOrGetChat(
                          itemId: item['id'],
                          itemTitle: item['title'] ?? 'Item',
                          itemStatus: item['type'] ?? 'lost',
                          otherUserId: ownerId,
                        );

                        await ChatService.sendInitialMessage(
                          chatId: chatId,
                          message: 'Hi, I\'m interested in your ${item['type'] == 'lost' ? 'lost' : 'found'} item: ${item['title']}',
                        );

                        if (context.mounted) {
                          context.push('/chat/$chatId', extra: {
                            'otherUserId': ownerId,
                            'otherUserName': ownerName,
                            'itemTitle': item['title'],
                            'itemId': item['id'],
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electronics':
        return Icons.phone_android;
      case 'Documents':
        return Icons.description;
      case 'Keys':
        return Icons.vpn_key;
      case 'Pets':
        return Icons.pets;
      case 'Bags':
        return Icons.work;
      case 'Jewelry':
        return Icons.diamond;
      case 'Clothing':
        return Icons.checkroom;
      default:
        return Icons.category;
    }
  }
}


