// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/screens/login_screen.dart';
import 'package:capstone_app/screens/business/main_business_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/widgets/custom_button.dart';
import 'package:capstone_app/widgets/custom_text_field.dart';

class BusinessOwnerRegistrationForm extends StatefulWidget {
  const BusinessOwnerRegistrationForm({super.key});

  @override
  State<BusinessOwnerRegistrationForm> createState() =>
      _BusinessOwnerRegistrationFormState();
}

class _BusinessOwnerRegistrationFormState
    extends State<BusinessOwnerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _countryController = TextEditingController();
  final _municipalityController = TextEditingController();
  String _status = 'Active';

  String? _gender;
  DateTime? _dob;
  String? _email;
  bool _isLoading = false;
  String? _error;
  bool _isExisting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _email = user?.email;
    _loadBusinessOwnerData();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'User not authenticated.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = {
        'uid': user.uid,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'gender': _gender,
        'dob': _dob?.toIso8601String(),
        'country': _countryController.text.trim(),
        'role': 'BusinessOwner',
        'form_completed': true,
        'app_email_verified': user.emailVerified,
        'location': _municipalityController.text.trim(),
        'status': _status,
      };

      if (!_isExisting) {
        // For new users only
        data['email'] = _email ?? '';
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true)); // merge = update if existing

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainBusinessOwnerScreen()),
      );
    } catch (e) {
      setState(() {
        _error = 'Registration failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBusinessOwnerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      _status = data['status'] ?? 'Active';
      _nameController.text = data['name'] ?? '';
      _usernameController.text = data['username'] ?? '';
      _passwordController.text = data['password'] ?? '';
      _contactController.text = data['contact'] ?? '';
      _municipalityController.text = data['location'] ?? '';
      _gender = data['gender'];
      _dob = data['dob'] != null ? DateTime.tryParse(data['dob']) : null;
      _countryController.text = data['country'] ?? '';
      _email = data['email'] ?? user.email;
      _isExisting = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _countryController.dispose();
    super.dispose();
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
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('Business Owner Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_email != null)
                TextFormField(
                  initialValue: _email,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _nameController,
                hintText: 'Full Name',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _usernameController,
                hintText: 'Username',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _passwordController,
                hintText: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _contactController,
                hintText: 'Contact Number',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 350, // Adjust width as needed
                child: DropdownButtonFormField<String>(
                  value: _municipalityController.text.isEmpty ? 'Select Municipality' : _municipalityController.text,
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
                        _municipalityController.text = value;});
                    }
                  },
                  validator: (value) =>
                    value == null || value == 'Select Municipality'
                      ? 'Please select a municipality': null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(
                    value: 'Prefer not to say.',
                    child: Text('Prefer not to say.'),
                  ),
                ],
                onChanged: (val) => setState(() => _gender = val),
              ),
              const SizedBox(height: 12),
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
                  onChanged:(value) => setState(() => _status = value ?? _status),)
              ),
              const SizedBox(height: 15),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date of Birth'),
                controller: TextEditingController(
                  text: _dob == null ? '' : '${_dob!.toLocal()}'.split(' ')[0],
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _countryController,
                hintText: 'Country of Origin',
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _isLoading ? 'Processing...' : 'Complete Registration',
                onPressed: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
