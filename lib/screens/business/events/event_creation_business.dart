import 'dart:io';
import 'package:capstone_app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:capstone_app/models/event_model.dart';
import 'package:capstone_app/services/event_service.dart';
import 'package:capstone_app/utils/images_imgbb.dart';

class EventCreationScreen extends StatefulWidget {
  const EventCreationScreen({super.key});

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers for better text management
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String title = '';
  String description = '';
  String location = '';
  String municipality = '';
  String eventType = 'Promotion';
  DateTime? startDate;
  DateTime? endDate;
  File? imageFile;
  bool isUploading = false;

  final List<String> _eventTypes = ['Promotion', 'Event', 'Sale', 'Festival'];

  final List<String> _municipalities = [
    'Malaybalay City', 'Valencia City', 'Maramag', 'Quezon', 'Don Carlos',
    'Kitaotao', 'Dangcagan', 'Kadingilan', 'Pangantucan', 'Talakag',
    'Lantapan', 'Baungon', 'Impasug-ong', 'Sumilao', 'Manolo Fortich',
    'Libona', 'Cabanglasan', 'San Fernando', 'Malitbog', 'Kalilangan',
    'Kibawe', 'Damulog',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () => _pickImageFromSource(ImageSource.camera),
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.green,
                    onTap: () => _pickImageFromSource(ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    Navigator.pop(context);
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart 
        ? (startDate ?? now)
        : (endDate ?? startDate ?? now);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryTeal,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          // Reset end date if it's before start date
          if (endDate != null && endDate!.isBefore(picked)) {
            endDate = null;
          }
        } else {
          // Ensure end date is not before start date
          if (startDate != null && picked.isBefore(startDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End date cannot be before start date'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image for your event'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();

      if (!userDoc.exists) throw Exception('User document not found.');

      final userData = userDoc.data()!;
      final name = userData['name'] ?? '';
      final email = userData['email'] ?? '';
      final contact = userData['contact'] ?? '';

      String role = 'unknown';
      final baseRole = userData['role'] ?? '';
      if (baseRole == 'BusinessOwner') {
        role = 'business owner';
      } else if (baseRole == 'Administrator') {
        final adminType = userData['admin_type'] ?? '';
        if (adminType == 'Provincial Administrator') {
          role = 'Provincial Administrator';
        } else if (adminType == 'Municipal Administrator') {
          role = 'Municipal Administrator';
        }
      }

      final imageUrl = await uploadImageToImgbb(imageFile!);
      if (imageUrl == null) throw Exception('Image upload failed');

      final event = Event(
        eventId: '', // Firestore will generate this
        title: title,
        description: description,
        startDate: startDate!,
        endDate: endDate!,
        location: location,
        municipality: municipality,
        createdBy: uid,
        thumbnailUrl: imageUrl,
        createdAt: DateTime.now(),
        role: role,
        creatorName: name,
        creatorContact: contact,
        creatorEmail: email,
      );

      await EventService.addEvent(event);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '$eventType created successfully!',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('Create Event Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Failed to create event. Please try again.')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Create Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryTeal,
        elevation: 0,
        actions: [
          if (!isUploading)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                _showHelpDialog();
              },
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AbsorbPointer(
              absorbing: isUploading,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildSectionHeader('Event Details', Icons.event),
                    const SizedBox(height: 16),

                    // Event Type Selection
                    _buildEventTypeSelector(),
                    const SizedBox(height: 20),

                    // Title Field
                    _buildTextFormField(
                      controller: _titleController,
                      label: 'Event Title',
                      hint: 'Enter a catchy title for your event',
                      icon: Icons.title,
                      validator: (val) => val!.isEmpty ? 'Please enter a title' : null,
                      onSaved: (val) => title = val!,
                    ),
                    const SizedBox(height: 20),

                    // Description Field
                    _buildTextFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe what makes your event special',
                      icon: Icons.description,
                      maxLines: 4,
                      validator: (val) => val!.isEmpty ? 'Please enter a description' : null,
                      onSaved: (val) => description = val!,
                    ),
                    const SizedBox(height: 32),

                    // Location Section
                    _buildSectionHeader('Location Details', Icons.location_on),
                    const SizedBox(height: 16),

                    // Barangay Field
                    _buildTextFormField(
                      controller: _locationController,
                      label: 'Barangay',
                      hint: 'Enter the barangay name',
                      icon: Icons.place,
                      validator: (val) => val!.isEmpty ? 'Please enter the barangay' : null,
                      onSaved: (val) => location = val!,
                    ),
                    const SizedBox(height: 20),

                    // Municipality Dropdown
                    _buildMunicipalityDropdown(),
                    const SizedBox(height: 32),

                    // Date Section
                    _buildSectionHeader('Event Schedule', Icons.schedule),
                    const SizedBox(height: 16),

                    // Date Selection Cards
                    Row(
                      children: [
                        Expanded(child: _buildDateCard(true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDateCard(false)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Image Section
                    _buildSectionHeader('Event Image', Icons.image),
                    const SizedBox(height: 16),
                    _buildImageSelector(),
                    const SizedBox(height: 32),

                    // Submit Button
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryTeal, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _eventTypes.map((type) {
          final isSelected = eventType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  eventType = type;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryTeal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildMunicipalityDropdown() {
    return DropdownButtonFormField<String>(
      value: municipality.isEmpty ? null : municipality,
      decoration: InputDecoration(
        labelText: 'Municipality',
        prefixIcon: const Icon(Icons.location_city, color: AppColors.primaryTeal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _municipalities.map((mun) {
        return DropdownMenuItem<String>(
          value: mun,
          child: Text(mun),
        );
      }).toList(),
      onChanged: (val) => setState(() => municipality = val ?? ''),
      validator: (val) => (val == null || val.isEmpty) ? 'Please select a municipality' : null,
    );
  }

  Widget _buildDateCard(bool isStart) {
    final date = isStart ? startDate : endDate;
    final label = isStart ? 'Start Date' : 'End Date';
    final color = isStart ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: () => _pickDate(isStart: isStart),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? color : Colors.grey[300]!,
            width: date != null ? 2 : 1,
          ),
          boxShadow: [
            if (date != null)
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today,
              color: date != null ? color : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null 
                  ? DateFormat.MMMd().format(date)
                  : 'Not selected',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: date != null ? color : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: imageFile != null ? AppColors.primaryTeal : Colors.grey[300]!,
            width: imageFile != null ? 2 : 1,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            if (imageFile != null)
              BoxShadow(
                color: AppColors.primaryTeal.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      size: 40,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add Event Image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select from gallery or camera',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      imageFile!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isUploading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: isUploading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Creating Event...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Text(
                'Create $eventType',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help, color: AppColors.primaryTeal),
            SizedBox(width: 8),
            Text('Help & Tips'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📝 Title: Make it catchy and descriptive'),
            SizedBox(height: 8),
            Text('📅 Dates: End date must be after start date'),
            SizedBox(height: 8),
            Text('📍 Location: Be specific about the venue'),
            SizedBox(height: 8),
            Text('🖼️ Image: High-quality photos get more attention'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}