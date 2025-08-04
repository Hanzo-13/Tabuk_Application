// ignore_for_file: unnecessary_null_comparison, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:intl/intl.dart';

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

  bool isLoading = true;

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
      isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('Users').doc(user.uid).update({
      'name': name,
      'username': username,
      'contact': contact,
      'country': country,
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
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

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage('assets/images/tourist_icon.png'), // Placeholder
            backgroundColor: Colors.grey,
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.edit, size: 20),
          ),
        ],
      ),
    );
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
