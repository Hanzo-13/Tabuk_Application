//Tourist Registration Flow
// This file handles the registration flow for tourists, allowing them to input personal information and travel preferences
// It includes two steps: personal information and travel preferences, with form validation and Firestore integration
// The user can navigate back to the login screen or complete the registration process
// It also supports loading existing user data if the user is already registered
// The registration flow is designed to be user-friendly and intuitive, guiding the user through the necessary
// steps to complete their profile as a tourist.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/screens/login_screen.dart';
import 'package:capstone_app/screens/tourist/main_tourist_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/widgets/custom_button.dart';
import 'package:capstone_app/widgets/custom_text_field.dart';

class TouristRegistrationFlow extends StatefulWidget {
  const TouristRegistrationFlow({super.key});

  @override
  State<TouristRegistrationFlow> createState() => _TouristRegistrationFlowState();
}

class _TouristRegistrationFlowState extends State<TouristRegistrationFlow> {
  final _formKey = GlobalKey<FormState>();

  // Step 1 controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  String? _gender;
  DateTime? _dob;
  final _countryController = TextEditingController();
  String? _email;
  bool _isPasswordVisible = false;

  // Step 2 controllers
  final _interestsController = TextEditingController();
  String? _travelStyle;
  String? _travelFrequency;
  final Map<String, Set<String>> _selectedPreferences = {};
  bool _agreeToTerms = false;

  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;
  bool _isExisting = false;
  bool _showTermsError = false;

  final Map<String, List<String>> _categories = {
    'Natural Attractions': [
      'Waterfalls', 'Mountains', 'Caves', 'Hot Springs', 'Cold Springs',
      'Lakes', 'Rivers', 'Forests', 'Natural Pools', 'Nature Trails',
    ],
    'Recreational Facilities': [
      'Resorts', 'Theme Parks', 'Sports Complexes', 'Adventure Parks', 'Entertainment Venues', 'Golf Courses',
    ],
    'Cultural & Historical': [
      'Churches', 'Temples', 'Museums', 'Festivals', 'Heritage Sites', 'Archaeological Sites',
    ],
    'Agri-Tourism & Industrial': [
      'Farms', 'Agro-Forestry', 'Industrial Tours', 'Ranches',
    ],
    'Culinary & Shopping': [
      'Local Restaurants', 'Souvenir Shops', 'Food Festivals', 'Markets',
    ],
    'Events & Education': [
      'Workshops', 'Educational Tours', 'Conferences', 'Local Events',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadTouristData();
  }

  Future<void> _loadTouristData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _usernameController.text = data['username'] ?? '';
      _passwordController.text = data['password'] ?? '';
      _contactController.text = data['contact'] ?? '';
      _gender = data['gender'];
      _dob = data['dob'] != null ? DateTime.tryParse(data['dob']) : null;
      _countryController.text = data['country'] ?? '';
      _email = data['email'] ?? user.email;
      _isExisting = true;
      setState(() {});
    } else {
      _email = user.email;
      setState(() {});
    }
  }

  void _togglePreference(String category, String type) {
    setState(() {
      _selectedPreferences.putIfAbsent(category, () => {});
      if (_selectedPreferences[category]!.contains(type)) {
        _selectedPreferences[category]!.remove(type);
      } else {
        _selectedPreferences[category]!.add(type);
      }
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'User not authenticated.');
      return;
    }

    if (!_agreeToTerms) {
      setState(() {
        _showTermsError = true;
      });
      return;
    }


    setState(() {
      _isLoading = true;
      _error = null;
    });

    final updates = {
      'uid': user.uid,
      'username': _usernameController.text.trim(),
      'password': _passwordController.text,
      'name': _nameController.text.trim(),
      'contact': _contactController.text.trim(),
      'gender': _gender,
      'dob': _dob?.toIso8601String(),
      'country': _countryController.text.trim(),
      'role': 'Tourist',
      'form_completed': true,
      'app_email_verified': user.emailVerified,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (!_isExisting) {
      updates['email'] = _email ?? '';
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).set(updates, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('tourist_preferences').doc(user.uid).set({
        'uid': user.uid,
        'interests': _interestsController.text.trim(),
        'travel_style': _travelStyle,
        'travel_frequency': _travelFrequency,
        'preferences': _selectedPreferences.map((k, v) => MapEntry(k, v.toList())),
        'isRegistered': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainTouristScreen()),
      );
    } catch (e) {
      setState(() {
        _error = 'Registration failed. Please try again.';
        _isLoading = false;
        _showTermsError = false;
      });
    }
  }

  Widget _buildStepOne() {
    return Column(
      children: [
        if (_email != null)
          TextFormField(
            initialValue: _email,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        const SizedBox(height: 12),
        CustomTextField(controller: _nameController, hintText: 'Full Name'),
        const SizedBox(height: 12),
        CustomTextField(controller: _usernameController, hintText: 'Username'),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _passwordController,
          hintText: 'Re-enter Password',
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Please enter a password' : null,
        ),
        const SizedBox(height: 12),
        CustomTextField(controller: _contactController, hintText: 'Contact Number'),
        const SizedBox(height: 12),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child:DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(labelText: 'Gender',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder( borderRadius: BorderRadius.circular(8),),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Prefer not to say.', child: Text('Prefer not to say.')),
          ],
          onChanged: (val) => setState(() => _gender = val),
        ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Date of Birth'),
          readOnly: true,
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
            if (picked != null) {
              setState(() => _dob = picked);
            }
          },
        ),
        const SizedBox(height: 12),
        CustomTextField(controller: _countryController, hintText: 'Nationality'),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(controller: _interestsController, hintText: 'Interests (e.g., hiking, food, adventure)'),
        const SizedBox(height: 12),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child:DropdownButtonFormField<String>(
          value: _travelStyle,
          decoration: InputDecoration(labelText: 'Preferred Travel Style',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder( borderRadius: BorderRadius.circular(8),),
          ),
          items: const [
            DropdownMenuItem(value: 'Solo', child: Text('Solo')),
            DropdownMenuItem(value: 'Group', child: Text('Group')),
            DropdownMenuItem(value: 'Family', child: Text('Family')),
            DropdownMenuItem(value: 'Couple', child: Text('Couple')),
          ],
          onChanged: (val) => setState(() => _travelStyle = val),
        ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child:DropdownButtonFormField<String>(
          value: _travelFrequency,
          decoration: InputDecoration(labelText: 'Travel Frequency',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder( borderRadius: BorderRadius.circular(8),),
          ),
          items: const [
            DropdownMenuItem(value: 'Rarely', child: Text('Rarely')),
            DropdownMenuItem(value: 'Occasionally', child: Text('Occasionally')),
            DropdownMenuItem(value: 'Frequently', child: Text('Frequently')),
          ],
          onChanged: (val) => setState(() => _travelFrequency = val),
        ),
        ),
        const SizedBox(height: 20),
        ..._categories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 6,
                children: entry.value.map((type) {
                  final selected = _selectedPreferences[entry.key]?.contains(type) ?? false;
                  return FilterChip(
                    label: Text(type),
                    selected: selected,
                    onSelected: (_) => _togglePreference(entry.key, type),
                    selectedColor: AppColors.primaryTeal.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryTeal,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: _agreeToTerms,
              onChanged: (val) => setState(() {
                _agreeToTerms = val ?? false;
                _showTermsError = false; // clear error when toggled
              }),
              title: const Text('I agree to the Terms and Privacy Policy'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_showTermsError)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4),
                child: Text(
                  '               You must agree to the Terms & Privacy Policy.',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.submitbutton,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomButton(
        text: _isLoading ? 'Processing...' : (_currentStep == 0 ? 'Next' : 'Complete Registration'),
        onPressed: _isLoading
            ? null
            : () {
                if (_currentStep == 0) {
                  setState(() => _currentStep = 1);
                } else {
                  _submit();
                }
              },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            } else {
              setState(() => _currentStep = 0);
            }
          },
        ),
        title: Text(_currentStep == 0 ? 'Tourist Information' : 'Travel Preferences'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              _currentStep == 0 ? _buildStepOne() : _buildStepTwo(),
              const SizedBox(height: 10),
              _buildNavigationButton(),
              const SizedBox(height: 40)
            ],
          ),
        ),
      ),
    );
  }
}

