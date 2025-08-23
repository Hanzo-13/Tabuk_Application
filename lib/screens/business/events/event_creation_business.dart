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

class _EventCreationScreenState extends State<EventCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  String title = '';
  String description = '';
  String location = '';
  String municipality = '';
  DateTime? startDate;
  DateTime? endDate;
  File? imageFile;
  bool isUploading = false;

  final List<String> _municipalities = [
    'Malaybalay City', 'Valencia City', 'Maramag', 'Quezon', 'Don Carlos',
    'Kitaotao', 'Dangcagan', 'Kadingilan', 'Pangantucan', 'Talakag',
    'Lantapan', 'Baungon', 'Impasug-ong', 'Sumilao', 'Manolo Fortich',
    'Libona', 'Cabanglasan', 'San Fernando', 'Malitbog', 'Kalilangan',
    'Kibawe', 'Damulog',
  ];

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || startDate == null || endDate == null || imageFile == null) return;

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
        const SnackBar(
          content: Text('Event created successfully!', style: TextStyle(color: AppColors.white),),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    } catch (e) {
      debugPrint('Create Event Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create event.')),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event or Promotion for your Business')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AbsorbPointer(
          absorbing: isUploading,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (val) => val!.isEmpty ? 'Enter title' : null,
                  onSaved: (val) => title = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: (val) => val!.isEmpty ? 'Enter description' : null,
                  onSaved: (val) => description = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Barangay'),
                  validator: (val) => val!.isEmpty ? 'Enter location' : null,
                  onSaved: (val) => location = val!,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: municipality.isEmpty ? null : municipality,
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
                  onChanged: (val) => setState(() => municipality = val ?? ''),
                  validator: (val) => (val == null || val.isEmpty) ? 'Select a municipality' : null,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Start Date: Not selected'
                            : 'Start: ${DateFormat.yMMMd().format(startDate!)}',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: const Text('Pick Start'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        endDate == null
                            ? 'End Date: Not selected'
                            : 'End: ${DateFormat.yMMMd().format(endDate!)}',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: const Text('Pick End'),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 350,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: imageFile == null
                        ? const Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey)
                        : Image.file(imageFile!, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                isUploading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submitForm,
                        child: const Text('Submit Event'),
                      ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
