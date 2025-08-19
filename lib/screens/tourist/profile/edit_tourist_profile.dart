// ignore_for_file: unnecessary_null_comparison, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:capstone_app/services/user_service.dart';
import 'package:capstone_app/screens/tourist/profile/visited_destinations_screen.dart';
import 'package:capstone_app/screens/tourist/profile/favorites_screen.dart';
import 'package:capstone_app/screens/tourist/profile/reviews_screen.dart';
import 'package:capstone_app/screens/tourist/profile/faq_screen.dart';
import 'package:capstone_app/screens/tourist/preferences/tourist_registration_flow.dart';

class EditTouristProfileScreen extends StatefulWidget {
  const EditTouristProfileScreen({super.key});

  @override
  State<EditTouristProfileScreen> createState() => _EditTouristProfileScreenState();
}

class _EditTouristProfileScreenState extends State<EditTouristProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = '';
  String username = '';
  String contact = '';
  String country = '';
  String gender = '';
  String email = '';
  String dob = '';
  String profilePhoto = '';

  bool isLoading = true;
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('Users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      name = data['name'] ?? '';
      username = data['username'] ?? '';
      contact = data['contact'] ?? '';
      country = data['country'] ?? '';
      gender = data['gender'] ?? '';
      email = data['email'] ?? '';
      dob = data['dob'] ?? '';
      profilePhoto = data['profilePhoto'] ?? '';
      isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    String photoUrl = profilePhoto;
    if (_pickedImage != null) {
      // Upload the picked image
      photoUrl = await _uploadToImgBB();
      if (photoUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Use UserService for better error handling and consistency
    final success = await UserService.updateUserProfile(
      name: name,
      username: username,
      contact: contact,
      country: country,
      profilePhoto: photoUrl,
    );

    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    }
  }

  Future<String> _uploadToImgBB() async {
    try {
      const apiKey = 'aae8c93b12878911b39dd9abc8c73376';
      final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
      
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await _pickedImage!.readAsBytes();
      } else {
        bytes = await File(_pickedImage!.path).readAsBytes();
      }
      
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        url,
        body: {
          'image': base64Image,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String? ?? '';
      } else {
        debugPrint('ImgBB upload failed: ${response.body}');
        return '';
      }
    } catch (e) {
      debugPrint('Error uploading to ImgBB: $e');
      return '';
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEditableField(String label, String initialValue, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (val) => val == null || val.trim().isEmpty ? 'This field is required' : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReadOnlyUnderlineField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
          const Divider(thickness: 1),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primaryTeal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        label: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey,
            backgroundImage: _getProfileImage(),
            child: _getProfileImage() == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryTeal,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImage != null) {
      return kIsWeb 
          ? null // For web, we'll handle this differently
          : FileImage(File(_pickedImage!.path));
    } else if (profilePhoto.isNotEmpty) {
      return NetworkImage(profilePhoto);
    }
    return null;
  }

  String getFormattedDOB() {
    try {
      final parsed = DateTime.parse(dob);
      return DateFormat('MMMM dd, yyyy').format(parsed);
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Tourist Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryTeal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildAvatarPlaceholder(),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField('Full Name', name, (val) => name = val),
                    _buildEditableField('Username', username, (val) => username = val),
                    _buildEditableField('Contact Number', contact, (val) => contact = val),
                    _buildEditableField('Nationality', country, (val) => country = val),
                    _buildReadOnlyUnderlineField('Gender', gender),
                    _buildReadOnlyUnderlineField('Date of Birth', getFormattedDOB()),

                    const SizedBox(height: 10),
                    // Navigation buttons to full-page screens
                    _buildNavButton(
                      label: 'Visited Destinations',
                      icon: Icons.check_circle_outline,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VisitedDestinationsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      label: 'Favorites',
                      icon: Icons.favorite_border,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      label: 'Preferences',
                      icon: Icons.tune,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TouristRegistrationFlow()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      label: 'My Reviews',
                      icon: Icons.rate_review_outlined,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReviewsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildNavButton(
                      label: 'FAQ',
                      icon: Icons.help_outline,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FAQScreen()),
                        );
                      },
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }
}
