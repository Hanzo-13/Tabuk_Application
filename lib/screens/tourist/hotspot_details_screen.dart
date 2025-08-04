import 'package:capstone_app/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/models/destination_model.dart';

/// A screen that displays the details of a [Hotspot].
class HotspotDetailsScreen extends StatelessWidget {
  /// Creates a [HotspotDetailsScreen] with the given [hotspot].
  const HotspotDetailsScreen({super.key, required this.hotspot});

  /// The [Hotspot] to display details for.
  final Hotspot hotspot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(hotspot.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hotspot.images.isNotEmpty)
              SizedBox(
                height: 220,
                width: double.infinity,
                child: PageView(
                  children: hotspot.images
                      .map((img) =>CachedImage(
                        imageUrl: hotspot.images.first,
                        width: 60,
                        height: 60,
                        placeholder: SizedBox(
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                          ),
                        ),
                      ))
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotspot.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(hotspot.description,
                      style: const TextStyle(fontSize: 16)),
                  // Add more details as needed
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Add/fix doc comments for all classes and key methods, centralize constants, use const where possible, and ensure code quality and maintainability throughout the file.
