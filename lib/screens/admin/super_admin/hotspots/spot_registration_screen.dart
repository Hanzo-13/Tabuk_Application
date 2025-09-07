// Enhanced Admin Business Registration Screen
// ignore_for_file: prefer_final_fields, unused_field

import 'package:capstone_app/screens/admin/provincial_admin/hotspots/spot_screen.dart';
import 'package:capstone_app/screens/admin/provincial_admin/hotspots/media_location_form.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminBusinessRegistrationScreen extends StatefulWidget {
  final String adminRole;
  final String municipality;

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
  final _pageController = PageController();
  int _currentStep = 0;

  // Controllers
  final _businessNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _distanceFromHighwayController = TextEditingController();
  final _suggestedItemsController = TextEditingController();

  // Form data
  String _status = 'Open';
  String? _category;
  String? _type;
  String? _municipality;
  String? _transportationAccess;
  String? _localGuide;
  String? _restroom;
  String? _foodAccess;
  String? _waterAccess;

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

  bool _isSubmitting = false;

  final List<String> _municipalities = [
    'Malaybalay City', 'Valencia City', 'Maramag', 'Quezon', 'Don Carlos',
    'Kitaotao', 'Dangcagan', 'Kadingilan', 'Pangantucan', 'Talakag',
    'Lantapan', 'Baungon', 'Impasug-ong', 'Sumilao', 'Manolo Fortich',
    'Libona', 'Cabanglasan', 'San Fernando', 'Malitbog', 'Kalilangan',
    'Kibawe', 'Damulog',
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
      setState(() {
        _operatingHours[day]![type] = picked;
      });
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep < 2) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      await _handleSubmit();
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _businessNameController.text.isNotEmpty &&
              _category != null &&
              _type != null &&
              _contactController.text.isNotEmpty &&
              _municipality != null;
      case 1:
        return _addressController.text.isNotEmpty &&
              _descriptionController.text.isNotEmpty;
      case 2:
        final hasEmptyFee = _entranceFees.values.any((fee) => fee.trim().isEmpty);
        return !hasEmptyFee && _transportationAccess != null;
      default:
        return true;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_validateCurrentStep()) return;
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPickerScreen(documentId: docRef.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Spot Registration'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SpotsScreen()),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildDetailsStep(),
                _buildFacilitiesStep(),
              ],
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _buildStepIndicator(i),
            if (i < 2) _buildStepConnector(i),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.primaryTeal : (isActive ? AppColors.primaryTeal : Colors.grey[300]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted 
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    return Expanded(
      child: Container(
        height: 2,
        color: step < _currentStep ? AppColors.primaryTeal : Colors.grey[300],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Basic Information',
            'Enter the essential details about your spot',
            Icons.info_outline,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _businessNameController,
            label: 'Spot Name',
            hint: 'Enter the name of your tourism spot',
            icon: Icons.business,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Category',
            value: _category,
            items: _categories.keys.toList(),
            onChanged: (val) => setState(() {
              _category = val;
              _type = null; // Reset type when category changes
            }),
            icon: Icons.category,
            required: true,
          ),
          const SizedBox(height: 16),
          if (_category != null)
            _buildDropdownField(
              label: 'Type',
              value: _type,
              items: _categories[_category!]!,
              onChanged: (val) => setState(() => _type = val),
              icon: Icons.label,
              required: true,
            ),
          if (_category != null) const SizedBox(height: 16),
          _buildTextField(
            controller: _contactController,
            label: 'Contact Number',
            hint: 'Enter business contact number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter business email (optional)',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Municipality',
            value: _municipality,
            items: _municipalities,
            onChanged: (val) => setState(() => _municipality = val),
            icon: Icons.location_city,
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Location & Details',
            'Provide specific location and description',
            Icons.location_on,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _addressController,
            label: 'Street/Barangay',
            hint: 'Enter specific address or barangay',
            icon: Icons.home,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your tourism spot in detail',
            icon: Icons.description,
            maxLines: 4,
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _websiteController,
            label: 'Website',
            hint: 'Enter website URL (optional)',
            icon: Icons.web,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Status',
            value: _status,
            items: const ['Open', 'Temporary Close', 'Permanently Close'],
            onChanged: (val) => setState(() => _status = val ?? _status),
            icon: Icons.access_time,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _distanceFromHighwayController,
            label: 'Distance from Highway',
            hint: 'e.g. 500m, 1km, near highway',
            icon: Icons.directions_car,
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Facilities & Services',
            'Configure operating hours, fees, and amenities',
            Icons.settings,
          ),
          const SizedBox(height: 24),
          _buildDropdownField(
            label: 'Transportation Access',
            value: _transportationAccess,
            items: const ['4-wheel', '2-wheel', 'Walking only'],
            onChanged: (val) => setState(() => _transportationAccess = val),
            icon: Icons.directions,
            required: true,
          ),
          const SizedBox(height: 24),
          _buildOperatingHours(),
          const SizedBox(height: 24),
          _buildEntranceFees(),
          const SizedBox(height: 24),
          _buildFacilitiesSection(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _suggestedItemsController,
            label: 'Suggested Items to Bring',
            hint: 'Enter items separated by commas',
            icon: Icons.checklist,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryTeal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryTeal) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: AppColors.primaryTeal),
        ),
        validator: required ? (value) => value?.isEmpty == true ? 'This field is required' : null : null,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    bool required = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items.map((e) => DropdownMenuItem<T>(
          value: e,
          child: Text(e.toString()),
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryTeal) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: AppColors.primaryTeal),
        ),
      ),
    );
  }

  Widget _buildOperatingHours() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Text(
                'Operating Hours',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._operatingHours.keys.map((day) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(day, 'open'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: Text(
                              _formatTimeOfDay(_operatingHours[day]?['open']),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(day, 'close'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            child: Text(
                              _formatTimeOfDay(_operatingHours[day]?['close']),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEntranceFees() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monetization_on, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Text(
                'Entrance Fees (₱)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._entranceFees.keys.map((group) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              initialValue: _entranceFees[group],
              decoration: InputDecoration(
                labelText: '$group Fee ₱',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              onChanged: (val) => _entranceFees[group] = val,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFacilitiesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.room_service, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Text(
                'Available Facilities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Local Guide Available',
            value: _localGuide,
            items: const ['Yes', 'No'],
            onChanged: (val) => setState(() => _localGuide = val),
            icon: Icons.person_pin,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Restroom Available',
            value: _restroom,
            items: const ['Yes', 'No'],
            onChanged: (val) => setState(() => _restroom = val),
            icon: Icons.wc,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Food Access',
            value: _foodAccess,
            items: const ['Inside', 'Near', 'None'],
            onChanged: (val) => setState(() => _foodAccess = val),
            icon: Icons.restaurant,
          ),
          const SizedBox(height: 12),
          _buildDropdownField(
            label: 'Water Access',
            value: _waterAccess,
            items: const ['Inside', 'Near', 'None'],
            onChanged: (val) => setState(() => _waterAccess = val),
            icon: Icons.water_drop,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primaryTeal),
                  foregroundColor: AppColors.primaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleNext,
              icon: _isSubmitting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_currentStep == 2 ? Icons.check : Icons.arrow_forward),
              label: Text(_currentStep == 2 ? 'Complete Basic Info' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
