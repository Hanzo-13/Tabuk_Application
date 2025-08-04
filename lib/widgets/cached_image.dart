// ===========================================
// lib/widgets/cached_image.dart
// ===========================================
// Reusable image widget with Hive-based caching and loading fallback

// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:capstone_app/services/image_cache_service.dart';
import 'dart:typed_data';

class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });
  
  get sColor => null;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ImageCacheService.getImage(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
            const SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            );
        }

        if (snapshot.data != null) {
          final image = Image.memory(
            snapshot.data!,
            fit: fit,
            width: width,
            height: height,
          );

          return borderRadius != null
              ? ClipRRect(borderRadius: borderRadius!, child: image)
              : image;
        }

        return errorWidget ??
            const Icon(
              Icons.image_not_supported,
              size: 60,
              color: Colors.grey,
            );
      },
    );
  }
}
