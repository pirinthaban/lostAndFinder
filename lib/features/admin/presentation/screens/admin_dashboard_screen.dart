import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;
  bool _isLoading = true;

  // Stats
  int _totalUsers = 0;
  int _totalItems = 0;
  int _lostItems = 0;
  int _foundItems = 0;
  int _resolvedItems = 0;
  int _totalMatches = 0;
  int _totalChats = 0;
  int _pendingReports = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
      return;
    }

    try {
      // Hardcoded admin emails
      final adminEmails = [
        'pirinthaban@gmail.com',
        'www.pirinthaban@gmail.com',
      ];

      final userEmail = user.email?.toLowerCase();
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      // Auto-promote hardcoded admins if they don't have the role yet
      // This works because standard users can update their own profile
      if (adminEmails.contains(userEmail)) {
        if (userDoc.data()?['role'] != 'admin' || userDoc.data()?['isAdmin'] != true) {
           await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
             'role': 'admin',
             'isAdmin': true,
           });
           debugPrint('Auto-promoted user $userEmail to admin');
        }
      }

      final isAdmin = userDoc.data()?['isAdmin'] == true ||
          userDoc.data()?['role'] == 'admin' ||
          adminEmails.contains(userEmail);

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });

      // Always load stats (we trust admin login screen authenticated them)
      _loadStats();
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      // On error, still allow access and load stats (trust admin login)
      setState(() {
        _isLoading = false;
        _isAdmin = true; // Trust admin login authentication
      });
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    // Users
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').count().get();
      _totalUsers = usersSnapshot.count ?? 0;
      debugPrint('Stats - Users: $_totalUsers');
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }

    // Items
    try {
      final itemsQuery = await FirebaseFirestore.instance.collection('items').get();
      _totalItems = itemsQuery.size;
      
      _lostItems = 0;
      _foundItems = 0;
      _resolvedItems = 0;

      for (var doc in itemsQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'lost') _lostItems++;
        if (data['status'] == 'found') _foundItems++;
        if (data['isResolved'] == true) _resolvedItems++;
      }
      debugPrint('Stats - Items: $_totalItems (L:$_lostItems, F:$_foundItems, R:$_resolvedItems)');
    } catch (e) {
      debugPrint('Error loading item stats: $e');
    }

    // Matches
    try {
      final matchesSnapshot =
          await FirebaseFirestore.instance.collection('matches').count().get();
      _totalMatches = matchesSnapshot.count ?? 0;
      debugPrint('Stats - Matches: $_totalMatches');
    } catch (e) {
      debugPrint('Error loading match stats: $e');
    }

    // Chats
    try {
      final chatsSnapshot =
          await FirebaseFirestore.instance.collection('chats').count().get();
      _totalChats = chatsSnapshot.count ?? 0;
      debugPrint('Stats - Chats: $_totalChats');
    } catch (e) {
      debugPrint('Error loading chat stats: $e');
    }

    // Reports
    try {
      // Try with count() first, fallback to get() if index error
      try {
        final reportsSnapshot = await FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        _pendingReports = reportsSnapshot.count ?? 0;
      } catch (e) {
        debugPrint('Reports count index error, falling back to get(): $e');
        final reportsQuery = await FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .get();
        _pendingReports = reportsQuery.size;
      }
      debugPrint('Stats - Pending Reports: $_pendingReports');
    } catch (e) {
      debugPrint('Error loading report stats: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Admin Access Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'You do not have permission to access this area.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.inventory), text: 'Items'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildItemsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Total Items',
                  _totalItems.toString(),
                  Icons.inventory_2,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Lost Items',
                  _lostItems.toString(),
                  Icons.search_off,
                  Colors.red,
                ),
                _buildStatCard(
                  'Found Items',
                  _foundItems.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Resolved',
                  _resolvedItems.toString(),
                  Icons.verified,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Matches',
                  _totalMatches.toString(),
                  Icons.auto_awesome,
                  Colors.amber,
                ),
                _buildStatCard(
                  'Active Chats',
                  _totalChats.toString(),
                  Icons.chat,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Pending Reports',
                  _pendingReports.toString(),
                  Icons.report_problem,
                  _pendingReports > 0 ? Colors.red : Colors.grey,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.people),
                  label: const Text('Manage Users'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.inventory),
                  label: const Text('Manage Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_pendingReports > 0)
                  ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(3),
                    icon: const Icon(Icons.warning),
                    label: Text('Review Reports ($_pendingReports)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final isBanned = user['isBanned'] == true;
            final isAdmin = user['isAdmin'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAdmin
                      ? Colors.indigo
                      : (isBanned ? Colors.red : Colors.blue),
                  backgroundImage: user['photoUrl'] != null
                      ? NetworkImage(user['photoUrl'])
                      : null,
                  child: user['photoUrl'] == null
                      ? Text(
                          (user['name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user['name'] ?? user['email'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    if (isBanned)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'BANNED',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(user['email'] ?? userId),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: isBanned ? 'unban' : 'ban',
                      child: Row(
                        children: [
                          Icon(
                            isBanned ? Icons.check_circle : Icons.block,
                            color: isBanned ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(isBanned ? 'Unban User' : 'Ban User'),
                        ],
                      ),
                    ),
                    if (!isAdmin)
                      const PopupMenuItem(
                        value: 'make_admin',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: Colors.indigo),
                            SizedBox(width: 8),
                            Text('Make Admin'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'view_items',
                      child: Row(
                        children: [
                          Icon(Icons.inventory, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('View Items'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleUserAction(userId, value),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleUserAction(String userId, String action) async {
    try {
      switch (action) {
        case 'ban':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({'isBanned': true});
          _showSnackBar('User banned', Colors.red);
          break;
        case 'unban':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({'isBanned': false});
          _showSnackBar('User unbanned', Colors.green);
          break;
        case 'make_admin':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Make Admin?'),
              content:
                  const Text('This will give the user full admin privileges.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .update({'isAdmin': true, 'role': 'admin'});
            _showSnackBar('User is now an admin', Colors.indigo);
          }
          break;
        case 'view_items':
          _showUserItems(userId);
          break;
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showUserItems(String userId) async {
    final items = await FirebaseFirestore.instance
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Items (${items.docs.length})',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: items.docs.length,
                  itemBuilder: (context, index) {
                    final item =
                        items.docs[index].data();
                    return ListTile(
                      title: Text(item['title'] ?? 'No title'),
                      subtitle: Text(item['status'] ?? 'unknown'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(items.docs[index].id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

        final items = snapshot.data?.docs ?? [];

        if (items.isEmpty) {
          return const Center(child: Text('No items found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index].data() as Map<String, dynamic>;
            final itemId = items[index].id;
            final isLost = item['status'] == 'lost';
            final isResolved = item['isResolved'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isLost
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item['images'] != null &&
                          (item['images'] as List).isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['images'][0],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              isLost ? Icons.search : Icons.check_circle,
                              color: isLost ? Colors.red : Colors.green,
                            ),
                          ),
                        )
                      : Icon(
                          isLost ? Icons.search : Icons.check_circle,
                          color: isLost ? Colors.red : Colors.green,
                        ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? 'Untitled',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLost ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isLost ? 'LOST' : 'FOUND',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    if (isResolved)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RESOLVED',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['category'] ?? 'Unknown category'),
                    Text(
                      item['location'] ?? 'Unknown location',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (!isResolved)
                      const PopupMenuItem(
                        value: 'resolve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Mark Resolved'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Item'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleItemAction(itemId, value),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  void _handleItemAction(String itemId, String action) async {
    try {
      switch (action) {
        case 'view':
          context.push('/item/$itemId');
          break;
        case 'resolve':
          await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .update({'isResolved': true});
          _showSnackBar('Item marked as resolved', Colors.green);
          _loadStats();
          break;
        case 'delete':
          await _deleteItem(itemId);
          break;
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This action cannot be undone.'),
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

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('items').doc(itemId).delete();
      _showSnackBar('Item deleted', Colors.red);
      _loadStats();
    }
  }

  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'No Reports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No reports to review at this time.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            final status = report['status'] ?? 'pending';
            final isPending = status == 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isPending ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(
                  Icons.report_problem,
                  color: isPending ? Colors.red : Colors.grey,
                  size: 32,
                ),
                title: Text(
                  report['reason'] ?? 'No reason provided',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type: ${report['type'] ?? 'Unknown'}'),
                    Text('Status: $status'),
                    if (report['description'] != null)
                      Text(
                        report['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: isPending
                    ? PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'resolve',
                            child: Row(
                              children: [
                                Icon(Icons.check, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Mark Resolved'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'dismiss',
                            child: Row(
                              children: [
                                Icon(Icons.close, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Dismiss'),
                              ],
                            ),
                          ),
                          if (report['itemId'] != null)
                            const PopupMenuItem(
                              value: 'delete_item',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Reported Item'),
                                ],
                              ),
                            ),
                          if (report['reportedUserId'] != null)
                            const PopupMenuItem(
                              value: 'ban_user',
                              child: Row(
                                children: [
                                  Icon(Icons.block, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Ban Reported User'),
                                ],
                              ),
                            ),
                        ],
                        onSelected: (value) =>
                            _handleReportAction(reportId, report, value),
                      )
                    : Icon(
                        status == 'resolved'
                            ? Icons.check_circle
                            : Icons.cancel,
                        color:
                            status == 'resolved' ? Colors.green : Colors.grey,
                      ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  void _handleReportAction(
      String reportId, Map<String, dynamic> report, String action) async {
    try {
      switch (action) {
        case 'resolve':
          await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportId)
              .update({'status': 'resolved'});
          _showSnackBar('Report marked as resolved', Colors.green);
          _loadStats();
          break;
        case 'dismiss':
          await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportId)
              .update({'status': 'dismissed'});
          _showSnackBar('Report dismissed', Colors.grey);
          _loadStats();
          break;
        case 'delete_item':
          if (report['itemId'] != null) {
            await _deleteItem(report['itemId']);
            await FirebaseFirestore.instance
                .collection('reports')
                .doc(reportId)
                .update({'status': 'resolved'});
          }
          break;
        case 'ban_user':
          if (report['reportedUserId'] != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(report['reportedUserId'])
                .update({'isBanned': true});
            await FirebaseFirestore.instance
                .collection('reports')
                .doc(reportId)
                .update({'status': 'resolved'});
            _showSnackBar('User banned and report resolved', Colors.red);
            _loadStats();
          }
          break;
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}
