import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'legal_document_screen.dart';
import 'legal_document_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploadingImage = false;
  int myItemsCount = 0;
  int resolvedItemsCount = 0;
  int savedItemsCount = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Load user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        userData = userDoc.data();
      } else {
        // Create basic user data if doesn't exist
        userData = {
          'name': currentUser!.displayName ?? currentUser!.email?.split('@')[0] ?? 'User',
          'email': currentUser!.email ?? '',
          'phone': currentUser!.phoneNumber ?? '',
          'joinedDate': FieldValue.serverTimestamp(),
        };
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .set(userData!);
        
        // Reload to get the actual timestamp
        final newDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (newDoc.exists) {
          userData = newDoc.data();
        }
      }

      // Count user's items
      debugPrint('Counting items for user: ${currentUser!.uid}');
      try {
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('items')
            .where('userId', isEqualTo: currentUser!.uid)
            .get();
        
        debugPrint('Items found: ${itemsSnapshot.docs.length}');
        myItemsCount = itemsSnapshot.docs.length;
        resolvedItemsCount = itemsSnapshot.docs
            .where((doc) => doc.data()['isResolved'] == true)
            .length;
        debugPrint('Resolved items: $resolvedItemsCount');
      } catch (e) {
        debugPrint('Error counting items: $e');
      }

      // Count saved items
      try {
        final savedSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('savedItems')
            .get();
        
        savedItemsCount = savedSnapshot.docs.length;
        debugPrint('Saved items: $savedItemsCount');
      } catch (e) {
        debugPrint('Error counting saved items: $e');
      }

    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => isUploadingImage = true);

      // Upload to Cloudinary
      final cloudinaryUrl = Uri.parse('https://api.cloudinary.com/v1_1/dh6mb70f5/image/upload');
      final request = http.MultipartRequest('POST', cloudinaryUrl);
      
      // Add upload preset - configured in Cloudinary Console
      request.fields['upload_preset'] = 'lost_and_finder_profile';
      request.fields['folder'] = 'profile_images';
      
      // Add the image file
      final imageFile = await http.MultipartFile.fromPath('file', image.path);
      request.files.add(imageFile);

      // Send request
      final response = await request.send();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to upload image to Cloudinary');
      }

      // Parse response
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);
      final imageUrl = jsonResponse['secure_url'] as String;

      // Update Firestore with Cloudinary image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'photoUrl': imageUrl});

      // Reload user data
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: userData?['name'] ?? currentUser?.displayName ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && result != userData?['name']) {
      try {
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'name': result.trim()});

        // Update Firebase Auth profile
        await currentUser!.updateDisplayName(result.trim());

        // Reload user data
        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    nameController.dispose();
  }

  void _showTermsAndConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegalDocumentScreen(
          title: 'Terms and Conditions',
          content: '''FindBack - Terms and Conditions\n\nBy using FindBack, you agree to:\n\n• Be at least 13 years old (16 in EU)\n• Provide accurate information about lost/found items\n• Not post illegal, fraudulent, or harmful content\n• Respect other users and use appropriate language\n• Meet in safe public places for item exchanges\n• Verify ownership before claiming items\n\nYou understand that:\n\n• FindBack is a platform only, not responsible for transactions\n• You are responsible for verifying other users\n• False claims may result in account termination\n• We may share data with authorities if legally required\n\nLimitations of Liability:\n\n• We are not liable for lost, stolen, or damaged items\n• We do not guarantee recovery of items\n• Users are responsible for their own safety\n• Service provided "as is" without warranties\n\nFor complete terms, visit:\ngithub.com/pirinthaban/lostAndFinder''',
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegalDocumentScreen(
          title: 'Privacy Policy',
          content: '''FindBack - Privacy Policy\n\nWe collect:\n\n• Account info: Phone number, email, display name\n• Item data: Photos, descriptions, locations (approximate)\n• Communication: Encrypted in-app messages\n• Usage data: Analytics, device info\n\nHow we protect you:\n\n• Auto-blur sensitive data (NIC numbers, faces)\n• End-to-end encryption for messages\n• Never sell your data\n• Comply with GDPR, CCPA, local laws\n\nYour rights:\n\n• Access and download your data\n• Edit or delete your information\n• Control privacy settings\n• Delete account anytime\n\nData retention:\n\n• Active items: Until deleted or 90 days inactive\n• Deleted accounts: 30 days recovery period\n• Audit logs: 2 years for security\n\nThird-party services:\n\n• Firebase (Google): Auth, database, storage\n• Cloudinary: Image hosting\n• Google Maps: Location services\n\nFor complete privacy policy, visit:\ngithub.com/pirinthaban/lostAndFinder''',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Not signed in',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final name = userData?['name'] ?? currentUser!.displayName ?? currentUser!.email?.split('@')[0] ?? 'User';
    final email = userData?['email'] ?? currentUser!.email ?? '';
    final phone = userData?['phone'] ?? currentUser!.phoneNumber ?? '';
    
    DateTime joinedDate = DateTime.now();
    try {
      if (userData?['joinedDate'] != null) {
        if (userData!['joinedDate'] is Timestamp) {
          joinedDate = (userData!['joinedDate'] as Timestamp).toDate();
        } else if (userData!['joinedDate'] is DateTime) {
          joinedDate = userData!['joinedDate'] as DateTime;
        }
      }
    } catch (e) {
      debugPrint('Error parsing joinedDate: $e');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _loadUserData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editProfile,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  // Avatar with upload button
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: userData?['photoUrl'] != null && 
                                        userData!['photoUrl'].toString().isNotEmpty
                            ? NetworkImage(userData!['photoUrl'].toString())
                            : null,
                        child: userData?['photoUrl'] == null || 
                               userData!['photoUrl'].toString().isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
                      if (isUploadingImage)
                        Positioned.fill(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black54,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: isUploadingImage ? null : _uploadProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Stats Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.post_add,
                      label: 'My Posts',
                      value: myItemsCount.toString(),
                      color: Colors.blue,
                      onTap: () => context.push('/my-posts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Resolved',
                      value: resolvedItemsCount.toString(),
                      color: Colors.green,
                      onTap: () => context.push('/my-posts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.bookmark,
                      label: 'Saved',
                      value: savedItemsCount.toString(),
                      color: Colors.orange,
                      onTap: () => context.push('/saved-items'),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            _buildMenuSection(
              context,
              title: 'My Activity',
              items: [
                _MenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Posts',
                  subtitle: '$myItemsCount items posted',
                  onTap: () {
                    context.push('/my-posts');
                  },
                ),
                _MenuItem(
                  icon: Icons.bookmark_outline,
                  title: 'Saved Items',
                  subtitle: '$savedItemsCount items saved',
                  onTap: () {
                    context.push('/saved-items');
                  },
                ),
                _MenuItem(
                  icon: Icons.history,
                  title: 'Activity History',
                  subtitle: 'View all your activity',
                  onTap: () {
                    context.push('/activity-history');
                  },
                ),
              ],
            ),

            _buildMenuSection(
              context,
              title: 'Settings',
              items: [
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    // TODO: Navigate to notification settings
                  },
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Security',
                  onTap: () {
                    // TODO: Navigate to privacy settings
                  },
                ),
                _MenuItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    // TODO: Navigate to help
                  },
                ),
              ],
            ),

            _buildMenuSection(
              context,
              title: 'About',
              items: [
                _MenuItem(
                  icon: Icons.info_outline,
                  title: 'About App',
                  subtitle: 'Version 1.0.0',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'FindBack',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.find_in_page_rounded, size: 48, color: Colors.blue),
                      children: [
                        const Text(
                          'A trusted Lost & Found community app. Connect with people who found what you lost, or help return items to their rightful owners.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Open-source project under MIT License.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.article_outlined,
                  title: 'Terms & Conditions',
                  onTap: _showTermsAndConditions,
                ),
                _MenuItem(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy',
                  onTap: _showPrivacyPolicy,
                ),
              ],
            ),

            // Account joined date
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Member since ${joinedDate.day}/${joinedDate.month}/${joinedDate.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // Sign Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.title),
                    subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: item.onTap,
                  ),
                  if (index < items.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
