// lib/screens/business/business_media_and_location_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:capstone_app/screens/admin/provincial_admin/hotspots/spot_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/images_imgbb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminMediaAndLocationScreen extends StatefulWidget {
  final String documentId;

  const AdminMediaAndLocationScreen({super.key, required this.documentId});

  @override
  State<AdminMediaAndLocationScreen> createState() =>
      _AdminMediaAndLocationScreenState();
}

class _AdminMediaAndLocationScreenState
    extends State<AdminMediaAndLocationScreen> {
  List<PlatformFile> _pickedFiles = [];
  bool _isUploading = false;
  LatLng? _location;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFiles = result.files;
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) => _LocationPicker(initialLocation: _location),
    );
    if (result != null) {
      setState(() => _location = result);
    }
  }

  Future<void> _submit() async {
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pin the Spot location.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<String> uploadedImageUrls = [];

      for (final file in _pickedFiles) {
        String? url;
        if (kIsWeb && file.bytes != null) {
          final base64 = base64Encode(file.bytes!);
          url = await uploadImageToImgbbWeb(base64);
        } else {
          url = await uploadImageToImgbb(File(file.path!));
        }

        uploadedImageUrls.add(url!);
      }

      final updateData = {
        'images': uploadedImageUrls,
        'latitude': _location!.latitude,
        'longitude': _location!.longitude,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('destination')
          .doc(widget.documentId)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business Photo and location added!')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SpotsScreen()), // or MainAdminScreen
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildImagePreview() {
    if (_pickedFiles.isEmpty) {
      return const Icon(Icons.add_a_photo, size: 40, color: Colors.black26);
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pickedFiles.length,
        itemBuilder: (context, index) {
          final file = _pickedFiles[index];
          return kIsWeb
              ? Image.memory(file.bytes!, width: 100, fit: BoxFit.cover)
              : Image.file(File(file.path!), width: 100, fit: BoxFit.cover);
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Photo & Location'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Business Photos'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: _buildImagePreview()),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _location == null
                        ? 'No location selected'
                        : 'Lat: ${_location!.latitude.toStringAsFixed(5)}, Lng: ${_location!.longitude.toStringAsFixed(5)}',
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Pin Location'),
                  onPressed: _pickLocation,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Finish Registration',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  const _LocationPicker({this.initialLocation});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  LatLng? _selectedLocation;
  final _bukidnonBounds = LatLngBounds(
    southwest: LatLng(7.5, 124.3),
    northeast: LatLng(8.9, 125.7),
  );

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick Location (Inside Bukidnon Only)'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialLocation ?? const LatLng(8.1500, 125.1000),
            zoom: 10,
          ),
          markers:
              _selectedLocation != null
                  ? {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _selectedLocation!,
                    ),
                  }
                  : {},
          onTap: (latLng) {
            if (_isInBounds(latLng)) {
              setState(() => _selectedLocation = latLng);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select location within Bukidnon'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          cameraTargetBounds: CameraTargetBounds(_bukidnonBounds),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              _selectedLocation != null
                  ? () => Navigator.pop(context, _selectedLocation)
                  : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  bool _isInBounds(LatLng latLng) {
    return latLng.latitude >= _bukidnonBounds.southwest.latitude &&
        latLng.latitude <= _bukidnonBounds.northeast.latitude &&
        latLng.longitude >= _bukidnonBounds.southwest.longitude &&
        latLng.longitude <= _bukidnonBounds.northeast.longitude;
  }
}
