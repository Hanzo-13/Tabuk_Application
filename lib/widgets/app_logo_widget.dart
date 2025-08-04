// ===========================================
// lib/widgets/app_logo_widget.dart
// ===========================================
// Widget for displaying the app logo with fallback.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';

/// Widget that displays the app logo with a fallback if the image fails to load.
class AppLogoWidget extends StatelessWidget {
  final double size;
  final double borderRadius;

  /// Creates an [AppLogoWidget].
  ///
  /// [size] sets the width and height of the logo. [borderRadius] sets the corner radius.
  const AppLogoWidget({super.key, this.size = 150, this.borderRadius = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/TABUK-new-logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackLogo();
          },
        ),
      ),
    );
  }

  /// Builds a fallback logo widget if the asset image fails to load.
  Widget _buildFallbackLogo() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.landscape, size: size * 0.4, color: AppColors.primaryTeal),
          Positioned(
            bottom: size * 0.1,
            child: Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: size * 0.11,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
