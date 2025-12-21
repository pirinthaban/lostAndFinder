import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/free_ai_service.dart';
import '../../../../core/services/matching_service.dart';
import 'package:geolocator/geolocator.dart'; // Add import
import '../../../../core/services/notification_service.dart';

class PostItemScreen extends StatefulWidget {
  final String? itemType; // 'lost' or 'found'
  const PostItemScreen({super.key, this.itemType});

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  
  // AI Services (FREE - On-Device)
  final FreeAIService _aiService = FreeAIService();
  final MatchingService _matchingService = MatchingService();
  final NotificationService _notificationService = NotificationService();
  
  // Privacy warnings
  bool _hasPrivacyWarning = false;
  String _privacyWarningMessage = '';
  
  String _selectedCategory = 'Electronics';
  final List<String> _categories = [
    'Electronics',
    'Documents',
    'Keys',
    'Pets',
    'Bags',
    'Jewelry',
    'Clothing',
    'Other',
  ];
  
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  DateTime _selectedDate = DateTime.now();
  String? _extractedText; 
  
  // GPS Location
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  // Process image for text extraction
  Future<void> _processImageForText(File imageFile) async {
    setState(() => _isSubmitting = true); 
    try {
      final text = await _aiService.extractText(imageFile);
      if (text.isNotEmpty) {
        setState(() {
          _extractedText = (_extractedText ?? '') + '\n' + text;
          _extractedText = _extractedText!.trim();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ OCR Text Extracted!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _aiService.dispose();
    super.dispose();
  }

  /// Check image for privacy concerns (NIC, faces)
  Future<void> _checkImagePrivacy(File imageFile) async {
    try {
      // Check for NIC numbers (returns list of detected NICs)
      final nicNumbers = await _aiService.detectNICInImage(imageFile);
      final hasNIC = nicNumbers.isNotEmpty;
      
      // Check for faces (returns list of face bounding boxes)
      final faces = await _aiService.detectFaces(imageFile);
      final hasFaces = faces.isNotEmpty;
      
      if (hasNIC || hasFaces) {
        String warning = '';
        if (hasNIC && hasFaces) {
          warning = '⚠️ This image contains NIC number and faces. Consider blurring sensitive information.';
        } else if (hasNIC) {
          warning = '⚠️ This image may contain NIC number. Consider blurring it for privacy.';
        } else {
          warning = '⚠️ This image contains ${faces.length} face(s). Consider if this is appropriate.';
        }
        
        setState(() {
          _hasPrivacyWarning = true;
          _privacyWarningMessage = warning;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(warning),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Privacy check error: $e');
    }
  }
  
  /// Get current GPS location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get position
      final position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        // Optionally update text field to show "GPS Location Set"
        if (_locationController.text.isEmpty) {
          _locationController.text = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Location set via GPS!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  /// Generate search keywords for better matching
  List<String> _generateSearchKeywords() {
    final keywords = <String>{};
    
    // Add title words
    final titleWords = _titleController.text.trim().toLowerCase().split(RegExp(r'\s+'));
    keywords.addAll(titleWords.where((w) => w.length > 2));
    
    // Add description words
    final descWords = _descriptionController.text.trim().toLowerCase().split(RegExp(r'\s+'));
    keywords.addAll(descWords.where((w) => w.length > 2));
    
    // Add category
    keywords.add(_selectedCategory.toLowerCase());
    
    // Add location words
    final locWords = _locationController.text.trim().toLowerCase().split(RegExp(r'\s+'));
    keywords.addAll(locWords.where((w) => w.length > 2));
    
    return keywords.toList();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return; // Prevent multiple calls
    
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed')),
      );
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        for (final image in images) {
          if (_selectedImages.length >= 5) break;
          final imageFile = File(image.path);
          setState(() {
            _selectedImages.add(imageFile);
          });
          // Process for OCR immediately
          await _processImageForText(imageFile);
          // Check privacy
          await _checkImagePrivacy(imageFile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_isPickingImage) return; // Prevent multiple calls
    
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed')),
      );
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final photoFile = File(photo.path);
        setState(() {
          _selectedImages.add(photoFile);
        });
        // Process for OCR immediately
        await _processImageForText(photoFile);
        // Check privacy
        await _checkImagePrivacy(photoFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitPost() async {
    final extractedText = _extractedText ?? '';
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload images to Cloudinary
      final List<String> imageUrls = [];
      for (final imageFile in _selectedImages) {
        try {
          final cloudinaryUrl = Uri.parse('https://api.cloudinary.com/v1_1/dh6mb70f5/image/upload');
          final request = http.MultipartRequest('POST', cloudinaryUrl);
          
          request.fields['upload_preset'] = 'lost_and_finder_profile';
          request.fields['folder'] = 'item_images';
          
          final file = await http.MultipartFile.fromPath('file', imageFile.path);
          request.files.add(file);
          
          final response = await request.send();
          
          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonResponse = json.decode(responseData);
            imageUrls.add(jsonResponse['secure_url'] as String);
          } else {
            throw Exception('Failed to upload image');
          }
        } catch (e) {
          debugPrint('Error uploading image: $e');
          // Continue with other images even if one fails
        }
      }
      
      if (imageUrls.isEmpty) {
        throw Exception('Failed to upload any images');
      }

      // Create item document in Firestore
      // Extract text from images for AI matching (FREE - On Device OCR)
      String extractedText = _extractedText ?? '';
      debugPrint('Using extracted text: ${extractedText.length} chars');
      
      final itemData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'location': _locationController.text.trim(),
        'contact': _contactController.text.trim(),
        'status': widget.itemType ?? 'lost',
        'images': imageUrls,
        'date': Timestamp.fromDate(_selectedDate),
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isResolved': false,
        // AI-extracted data for better matching
        'extractedText': extractedText.trim(),
        'latitude': _latitude, // Save GPS lat
        'longitude': _longitude, // Save GPS lon
        'searchKeywords': _generateSearchKeywords(),
      };

      debugPrint('Posting item with data: ${itemData.keys}');
      final docRef = await FirebaseFirestore.instance.collection('items').add(itemData);
      debugPrint('Item posted successfully');
      
      // 🤖 AI MATCHING: Find potential matches (FREE - Runs on device)
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🤖 AI is searching for matches...')),
        );

        final matches = await _matchingService.findMatches(
          itemId: docRef.id,
          itemType: widget.itemType ?? 'lost',
          description: '${_titleController.text} ${_descriptionController.text} $extractedText',
          category: _selectedCategory,
          location: _locationController.text.trim(),
          latitude: _latitude, // Pass GPS lat
          longitude: _longitude, // Pass GPS lon
          createdAt: _selectedDate,
        );
        
        // Show result dialog if matches found
        if (matches.isNotEmpty && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false, // User must tap button
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text('AI Matches Found!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('We found ${matches.length} potential matches for your item!'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final m = matches[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: m.confidenceColor,
                              child: Text('${m.confidenceScore.toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                            title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(m.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                  },
                  child: const Text('View Matches Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    // Navigate to matches screen (optional, for now just go back)
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else if (mounted) {
          // Optional: Show "No matches" toast if you want, or just silent
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item posted! No immediate matches found.')),
          );
        }
        
        if (matches.isNotEmpty) {
          // Save matches to Firestore (for both users)
          await _matchingService.saveMatches(
            docRef.id,
            matches,
            itemTitle: _titleController.text.trim(),
            itemDescription: _descriptionController.text.trim(),
            itemType: widget.itemType,
          );
          
          // Notify user about matches
          for (final match in matches) {
            await _notificationService.showMatchNotification(
              title: '🎯 Potential Match Found!',
              body: 'Your ${widget.itemType == 'lost' ? 'lost' : 'found'} item "${_titleController.text.trim()}" has a ${match.confidenceScore.toStringAsFixed(0)}% match with "${match.title}"',
              payload: match.matchedItemId,
            );
          }
        }
      } catch (matchError) {
        debugPrint('Matching error (non-fatal): $matchError');
      }

      if (mounted) {
        final isLostItem = widget.itemType == 'lost';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isLostItem ? "Lost" : "Found"} item posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to Home Screen
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      debugPrint('Error posting item: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLost = widget.itemType == 'lost';
    final title = isLost ? 'I Lost Something' : 'I Found Something';
    final color = isLost ? theme.colorScheme.secondary : theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            Card(
              color: color.withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: color.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLost ? Icons.search_off : Icons.check_circle_outline,
                        color: color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLost
                                ? 'Help others identify your lost item'
                                : 'Help reunite this item with its owner',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Image Picker Section
            // ... (existing image picker code) ...
            
            // Extracted Text Display (New)
            if (_extractedText != null && _extractedText!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_snippet, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Extracted Text',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () => setState(() => _extractedText = ''),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _extractedText,
                      maxLines: null, // Auto expand
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Text from image will appear here...',
                      ),
                      onChanged: (value) {
                        _extractedText = value;
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Item Title *',
                hintText: 'e.g., Black Leather Wallet',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Provide detailed description...',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Location
            // Location with GPS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location *',
                      hintText: 'City, Area (or use GPS)',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56, // Match text field height
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue,
                    ),
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact Number *',
                hintText: 'Enter your phone number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a contact number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Images Section
            Text(
              'Photos (${_selectedImages.length}/5) *',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Privacy Warning Card (AI-Powered)
            if (_hasPrivacyWarning)
              Card(
                color: Colors.orange.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🤖 AI Privacy Warning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _privacyWarningMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _hasPrivacyWarning = false),
                      ),
                    ],
                  ),
                ),
              ),
            if (_hasPrivacyWarning) const SizedBox(height: 8),
            
            // Image Grid
            if (_selectedImages.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),

            // Add Photo Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Post Item',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class PostItemDetailScreen extends StatelessWidget {
  final String itemId;
  const PostItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: Center(child: Text('Item Detail: $itemId')),
    );
  }
}
