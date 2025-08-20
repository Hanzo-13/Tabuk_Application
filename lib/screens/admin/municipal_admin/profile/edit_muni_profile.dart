// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class EditAdminProfileScreen extends StatefulWidget {
  const EditAdminProfileScreen({super.key});

  @override
  State<EditAdminProfileScreen> createState() => _EditAdminProfileScreenState();
}

class _EditAdminProfileScreenState extends State<EditAdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = '';
  String username = '';
  String contact = '';
  String location = '';
  String department = '';
  String email = '';
  String adminType = '';
  String status = '';

  bool isLoading = true;

  final List<String> _municipalities = [
    'Malaybalay City', 'Valencia City', 'Maramag', 'Quezon', 'Don Carlos', 'Kitaotao',
    'Dangcagan', 'Kadingilan', 'Pangantucan', 'Talakag', 'Lantapan', 'Baungon',
    'Impasug-ong', 'Sumilao', 'Manolo Fortich', 'Libona', 'Cabanglasan', 'San Fernando',
    'Malitbog', 'Kalilangan', 'Kibawe', 'Damulog'
  ];

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
      location = data['location'] ?? '';
      department = data['department'] ?? '';
      email = data['email'] ?? '';
      adminType = data['admin_type'] ?? '';
      status = data['status'] ?? 'Active';
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
      'location': location,
      'department': department,
      'admin_type': adminType,
      'status': status,
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

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage('assets/images/default_avatar.png'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryOrange,
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

                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: location.isEmpty ? null : location,
                      decoration: InputDecoration(
                        labelText: 'Municipality',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _municipalities.map((mun) {
                        return DropdownMenuItem<String>(
                          value: mun,
                          child: Text(mun),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => location = value ?? ''),
                      validator: (value) => value == null || value.isEmpty ? 'Select a municipality' : null,
                    ),

                    const SizedBox(height: 16),
                    _buildEditableField('Department', department, (val) => department = val),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: adminType.isEmpty ? null : adminType,
                      decoration: InputDecoration(
                        labelText: 'Administrator Type',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Municipal Administrator', child: Text('Municipal Administrator')),
                        DropdownMenuItem(value: 'Provincial Administrator', child: Text('Provincial Administrator')),
                      ],
                      onChanged: (value) => setState(() => adminType = value ?? ''),
                      validator: (val) => val == null || val.isEmpty ? 'Select admin type' : null,
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status.isEmpty ? 'Active' : status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Not Active', child: Text('Not Active')),
                      ],
                      onChanged: (value) => setState(() => status = value ?? 'Active'),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
