// ignore_for_file: prefer_final_fields

import 'package:capstone_app/screens/admin/municipal_admin/hotspots/muni_spot_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/hotspots/muni_media_location_form_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminBusinessRegistrationScreen extends StatefulWidget {
  final String adminRole;
  final String municipality; // For Municipal Admins, required

  const AdminBusinessRegistrationScreen({
    super.key,
    required this.adminRole,
    required this.municipality,
  });

  @override
  State<AdminBusinessRegistrationScreen> createState() => _AdminBusinessRegistrationScreenState();
}

class _AdminBusinessRegistrationScreenState extends State<AdminBusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Business Info
  final _businessNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _distanceFromHighwayController = TextEditingController();
  final _suggestedItemsController = TextEditingController();
  String _status = 'Open';
  String? _category;
  String? _type;
  String? _municipality;

  // Business Details
  String? _transportationAccess;
  final Map<String, Map<String, TimeOfDay?>> _operatingHours = {
    'Monday': {'open': null, 'close': null},
    'Tuesday': {'open': null, 'close': null},
    'Wednesday': {'open': null, 'close': null},
    'Thursday': {'open': null, 'close': null},
    'Friday': {'open': null, 'close': null},
    'Saturday': {'open': null, 'close': null},
    'Sunday': {'open': null, 'close': null},
  };
  final Map<String, String> _entranceFees = {
    'Adult': '', 'Child': '', 'Senior/PWD': ''
  };
  String? _localGuide;
  String? _restroom;
  String? _foodAccess;
  String? _waterAccess;

  bool _isSubmitting = false;

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

  String _formatTimeOfDay(TimeOfDay? time) {
  if (time == null) return '--:--';
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
}

Future<void> _pickTime(String day, String type) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (picked != null) {
    setState(() {
      _operatingHours[day]![type] = picked;
    });
  }
}

  Future<void> _handleNextStep() async {
        final hasEmptyFee = _entranceFees.values.any((fee) => fee.trim().isEmpty);
    if (hasEmptyFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all entrance fee fields.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final businessData = {
        'owner_uid': user.uid,
        'business_name': _businessNameController.text.trim(),
        'status': _status,
        'category': _category,
        'type': _type,
        'contact_info': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'municipality': _municipality,
        'province': 'Bukidnon',
        'distance_from_highway': _distanceFromHighwayController.text.trim(),
        'transportation': _transportationAccess,
        'operating_hours': _operatingHours.map((day, times) => MapEntry(
          day,
          {
            'open': _formatTimeOfDay(times['open']),
            'close': _formatTimeOfDay(times['close']),
          },
        )),
        'entrance_fees': _entranceFees.map((key, value) => MapEntry(key, double.tryParse(value) ?? 0.0)),
        'local_guide': _localGuide,
        'restroom': _restroom == 'Yes',
        'food_access': _foodAccess,
        'water_access': _waterAccess,
        'suggested_items': _suggestedItemsController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance.collection('destination').add(businessData);

      if (!mounted) return;
    // Navigate to media and location screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminMediaAndLocationScreen(documentId: docRef.id),
      ),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    setState(() => _isSubmitting = false);
  }
}

  Widget _buildDropdown<T>({required String label, required T? value, required List<T> items, required ValueChanged<T?> onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Spot Registration'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminBusinessesScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _businessNameController, decoration: const InputDecoration(labelText: 'Business Name')), const SizedBox(height: 12),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Category', value: _category, items: _categories.keys.toList(), onChanged: (val) => setState(() => _category = val)),
              const SizedBox(height: 12),
              if (_category != null)
                _buildDropdown(label: 'Type', value: _type, items: _categories[_category!]!, onChanged: (val) => setState(() => _type = val)),
              const SizedBox(height: 12),
              TextFormField(controller: _contactController, decoration: const InputDecoration(labelText: 'Business Contact')), const SizedBox(height: 12),
              const SizedBox(height: 12),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Business Email (optional)')), const SizedBox(height: 12),
              const SizedBox(height: 12),
              TextFormField(controller: _websiteController, decoration: const InputDecoration(labelText: 'Website (optional)')), const SizedBox(height: 12),
              const SizedBox(height: 12),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Street/Barangay')), const SizedBox(height: 12),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Municipality', value: _municipality, items: _municipalities, onChanged: (val) => setState(() => _municipality = val)),
              const SizedBox(height: 12),
              TextFormField(controller: _descriptionController, maxLines: 4, decoration: const InputDecoration(labelText: 'Business Description')), const SizedBox(height: 12),
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
                    DropdownMenuItem(value: 'Open', child: Text('Open')),
                    DropdownMenuItem(value: 'Temporary Close',child: Text('Temporary Close'),),
                    DropdownMenuItem(value: 'Permanently Close',child: Text('Permanently Close'),),
                  ],
                  onChanged:(value) => setState(() => _status = value ?? _status),)
              ),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Transportation Access', value: _transportationAccess, items: ['4-wheel', '2-wheel', 'Walking only'], onChanged: (val) => setState(() => _transportationAccess = val)),
              const SizedBox(height: 12),
              TextFormField(controller: _distanceFromHighwayController, decoration: const InputDecoration(labelText: 'Distance from Highway (e.g. 500m, 1km, near highway)')),
              const SizedBox(height: 12),
              const Text('Operating Hours'),
                ..._operatingHours.keys.map((day) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(day)),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _pickTime(day, 'open'),
                            child: Text(
                              _formatTimeOfDay(_operatingHours[day]?['open']),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        const Text(' - '),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _pickTime(day, 'close'),
                            child: Text(
                              _formatTimeOfDay(_operatingHours[day]?['close']),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text('Entrance Fee ₱'),
              ..._entranceFees.keys.map((group) => TextFormField(
                initialValue: _entranceFees[group],
                decoration: InputDecoration(labelText: '$group Fee ₱'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                onChanged: (val) => _entranceFees[group] = val,
              )),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Local Guide Available', value: _localGuide, items: ['Yes', 'No'], onChanged: (val) => setState(() => _localGuide = val)),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Restroom Available', value: _restroom, items: ['Yes', 'No'], onChanged: (val) => setState(() => _restroom = val)),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Food Access', value: _foodAccess, items: ['Inside', 'Near', 'None'], onChanged: (val) => setState(() => _foodAccess = val)),
              const SizedBox(height: 12),
              _buildDropdown(label: 'Water Access', value: _waterAccess, items: ['Inside', 'Near', 'None'], onChanged: (val) => setState(() => _waterAccess = val)),
              const SizedBox(height: 12),
              TextFormField(controller: _suggestedItemsController, decoration: const InputDecoration(labelText: 'Suggested Items to Bring. (comma-separated)')),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Next', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}