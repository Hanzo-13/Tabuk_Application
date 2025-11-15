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
  String? _status = 'Active';
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
      _status = data['status'] ?? 'Active';
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
      'status': _status,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryTeal.withOpacity(0.1),
                AppColors.primaryOrange.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryTeal.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primaryTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Let\'s get started!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell us about yourself',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_email != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_rounded, color: AppColors.primaryTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_email != null) const SizedBox(height: 16),
        CustomTextField(controller: _nameController, hintText: 'Full Name'),
        const SizedBox(height: 16),
        CustomTextField(controller: _usernameController, hintText: 'Username'),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _passwordController,
          hintText: 'Re-enter Password',
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: AppColors.primaryTeal,
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
        const SizedBox(height: 16),
        CustomTextField(controller: _contactController, hintText: 'Contact Number'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: InputDecoration(
            labelText: 'Gender',
            labelStyle: TextStyle(color: AppColors.textLight),
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryTeal),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Prefer not to say.', child: Text('Prefer not to say.')),
          ],
          onChanged: (val) => setState(() => _gender = val),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.primaryTeal,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _dob = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primaryTeal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dob == null
                            ? 'Select your date of birth'
                            : '${_dob!.toLocal()}'.split(' ')[0],
                        style: TextStyle(
                          fontSize: 16,
                          color: _dob == null ? AppColors.textLight : AppColors.textDark,
                          fontWeight: _dob == null ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(controller: _countryController, hintText: 'Nationality'),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preferences Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryOrange.withOpacity(0.1),
                AppColors.primaryTeal.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: AppColors.primaryOrange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Travel Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help us personalize your experience',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomTextField(controller: _interestsController, hintText: 'Interests (e.g., hiking, food, adventure)'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _travelStyle,
          decoration: InputDecoration(
            labelText: 'Preferred Travel Style',
            labelStyle: TextStyle(color: AppColors.textLight),
            prefixIcon: const Icon(Icons.group, color: AppColors.primaryOrange),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'Solo', child: Text('Solo')),
            DropdownMenuItem(value: 'Group', child: Text('Group')),
            DropdownMenuItem(value: 'Family', child: Text('Family')),
            DropdownMenuItem(value: 'Couple', child: Text('Couple')),
          ],
          onChanged: (val) => setState(() => _travelStyle = val),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _travelFrequency,
          decoration: InputDecoration(
            labelText: 'Travel Frequency',
            labelStyle: TextStyle(color: AppColors.textLight),
            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primaryOrange),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'Rarely', child: Text('Rarely')),
            DropdownMenuItem(value: 'Occasionally', child: Text('Occasionally')),
            DropdownMenuItem(value: 'Frequently', child: Text('Frequently')),
          ],
          onChanged: (val) => setState(() => _travelFrequency = val),
        ),
        const SizedBox(height: 24),
        const Text(
          'Select Your Interests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose all that apply to personalize your recommendations',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 16),
        ..._categories.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getCategoryIcon(entry.key),
                      color: AppColors.primaryOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((type) {
                    final selected = _selectedPreferences[entry.key]?.contains(type) ?? false;
                    return FilterChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (_) => _togglePreference(entry.key, type),
                      selectedColor: AppColors.primaryOrange.withOpacity(0.2),
                      checkmarkColor: AppColors.primaryOrange,
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primaryOrange : AppColors.textDark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _showTermsError ? Colors.red.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _showTermsError ? Colors.red : AppColors.primaryOrange.withOpacity(0.3),
              width: _showTermsError ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (val) => setState(() {
                  _agreeToTerms = val ?? false;
                  _showTermsError = false;
                }),
                activeColor: AppColors.primaryOrange,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'I agree to the Terms and Privacy Policy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (_showTermsError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'You must agree to the Terms & Privacy Policy to continue.',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Natural Attractions':
        return Icons.landscape;
      case 'Recreational Facilities':
        return Icons.sports_soccer;
      case 'Cultural & Historical':
        return Icons.museum;
      case 'Agri-Tourism & Industrial':
        return Icons.agriculture;
      case 'Culinary & Shopping':
        return Icons.restaurant;
      case 'Events & Education':
        return Icons.event;
      default:
        return Icons.category;
    }
  }

  Widget _buildNavigationButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_currentStep == 0 ? AppColors.primaryTeal : AppColors.primaryOrange)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_currentStep == 0) {
                    setState(() => _currentStep = 1);
                  } else {
                    _submit();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentStep == 0
                ? AppColors.primaryTeal
                : AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStep == 0 ? 'Continue to Preferences' : 'Complete Registration',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _currentStep == 0
                          ? Icons.arrow_forward_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 22,
                    ),
                  ],
                ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced AppBar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryTeal,
                      AppColors.primaryTeal.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentStep == 0 ? 'Tourist Information' : 'Travel Preferences',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Progress indicator
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _currentStep >= 1
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
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
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _currentStep == 0 ? _buildStepOne() : _buildStepTwo(),
                        const SizedBox(height: 24),
                        _buildNavigationButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

