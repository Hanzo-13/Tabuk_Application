// Admin Registration Form
// This file handles the registration form for administrators, allowing them to input their details and submit for approval
// It includes form validation, Firestore integration, and navigation to the pending approval screen
// The user can also navigate back to the login screen if needed
// The form includes fields for full name, username, password, contact number, department, status, municipality, and administrator type
// The admin type can be either "Municipal Administrator" or "Provincial Administrator"
// The form also handles existing admin data loading and updates if the user is already registered.

// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:capstone_app/screens/admin/admin_approval_screen.dart';
import 'package:capstone_app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class AdminSurveyScreen extends StatefulWidget {
  const AdminSurveyScreen({super.key});

  @override
  State<AdminSurveyScreen> createState() => _AdminSurveyScreenState();
}

class _AdminSurveyScreenState extends State<AdminSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _status = 'Active';

  String _adminType = 'Municipal Administrator';
  bool _isLoading = false;
  bool _isExisting = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // Load existing admin data if available
  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _nameController.text = data['name'] ?? '';
    _usernameController.text = data['username'] ?? '';
    _contactController.text = data['contact'] ?? '';
    _departmentController.text = data['department'] ?? '';
    _locationController.text = data['location'] ?? '';
    _status = data['status'] ?? 'Active';
    _adminType = data['admin_type'] ?? 'Municipal Administrator';

    setState(() => _isExisting = true);
  }
  // Handle form submission
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (!user.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email before submitting.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final uid = user.uid;

      // Check if the user is already registered as an admin
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        // Never store plaintext passwords in Firestore
        'contact': _contactController.text.trim(),
        'department': _departmentController.text.trim(),
        'location': _locationController.text.trim(),
        'status': _status,
        // Store only vetted values for admin_type
        'admin_type': (_adminType == 'Municipal Administrator' || _adminType == 'Provincial Administrator')
            ? _adminType
            : 'Municipal Administrator',
        'form_completed': true,
        'admin_status': 'pending',
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (!_isExisting) {
        // Only include these if it's a fresh admin doc
        updates.addAll({
          'uid': uid,
          'email': user.email ?? '',
          'role': 'Administrator',
          'app_email_verified': user.emailVerified,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // Save or update the admin data in Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .set(updates, SetOptions(merge: true));
      // Navigate to the pending approval screen
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PendingAdminApprovalScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Error saving admin data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to complete registration"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _municipalities = [
      'Malaybalay City',
      'Valencia City',
      'Maramag',
      'Quezon',
      'Don Carlos',
      'Kitaotao',
      'Dangcagan',
      'Kadingilan',
      'Pangantucan',
      'Talakag',
      'Lantapan',
      'Baungon',
      'Impasug-ong',
      'Sumilao',
      'Manolo Fortich',
      'Libona',
      'Cabanglasan',
      'San Fernando',
      'Malitbog',
      'Kalilangan',
      'Kibawe',
      'Damulog',
      'Cabanglasan',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Registration'),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Full Name field
              _buildTextField(_nameController, 'Full Name'),
              const SizedBox(height: 12),
              // Username field
              _buildTextField(_usernameController, 'username'),
              const SizedBox(height: 12),
              
              // Removed password collection/storage (handled by Firebase Auth only)
              // Contact number field
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Required';
                  final digits = v.replaceAll(RegExp(r'[^0-9+]'), '');
                  if (digits.length < 10) return 'Enter a valid contact number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Department field
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 15),

              // Dropdown for status selection
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(labelText: 'Status',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Not Active',child: Text('Not Active'),),
                  ],
                  onChanged:(value) => setState(() => _status = (value == 'Active' || value == 'Not Active') ? value! : _status),)
              ),
              const SizedBox(height: 15),

              // Dropdown for municipality selection
              SizedBox(
                width: 250, // Adjust width as needed
                child: DropdownButtonFormField<String>(
                  value: _locationController.text.isEmpty ? 'Select Municipality' : _locationController.text,
                  decoration: InputDecoration(
                    labelText: 'Municipality',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'Select Municipality',
                      child: Text('Select Municipality',style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    ..._municipalities.map(
                      (mun) => DropdownMenuItem<String>(
                        value: mun,
                        child: Text(mun, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null && value != 'Select Municipality') {
                      setState(() {
                        _locationController.text = value;});
                    }
                  },
                  validator: (value) =>
                    value == null || value == 'Select Municipality'
                      ? 'Please select a municipality': null,
                ),
              ),
              const SizedBox(height: 15),

              // Dropdown for admin type
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child:DropdownButtonFormField<String>(
                value: _adminType,
                decoration: InputDecoration(labelText: 'Administrator Type',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(8),),
                ),
                items: const [
                  DropdownMenuItem(value: 'Municipal Administrator',child: Text('Municipal Administrator')),
                  DropdownMenuItem(value: 'Provincial Administrator',child: Text('Provincial Administrator')),
                ],
                onChanged:
                  (value) => setState(() => _adminType = (value == null)
                      ? _adminType
                      : (value == 'Municipal Administrator' || value == 'Provincial Administrator')
                          ? value
                          : _adminType),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit and Continue'),
              ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }
}
