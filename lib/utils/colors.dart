// ===========================================
// lib/utils/colors.dart
// ===========================================
// Centralized color palette for the Tabuk app.

import 'package:flutter/material.dart';

class AppColors {
  static const Color gradientStart = Color(0xFFFFF3CF);
  static const Color gradientEnd = Colors.white;

  //
  static const Color loadingImage = Color.fromARGB(255, 29, 83, 175);
  // Original colors for compatibility
  // static const Color
  static const Color primaryOrange = Color(0xFFFF8C42);
  static const Color primaryTeal = Color(0xFF2E8B8B);
  static const Color submitbutton = Color.fromARGB(255, 60, 217, 217);
  static const Color backgroundColor = Color(0xFFF5F5DC);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF666666);
  static const Color grey = Color.fromARGB(255, 89, 88, 88);
  static const Color white = Color(0xFFFFFFFF);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color cardBackground = white;
  static const Color imagePlaceholder = Color(0xFFE0E0E0);
  static const Color buttonBorder = Color(0xFF666666);
  static const Color buttonText = Colors.black;
  static const Color black = Colors.black;
  static const Color green = Colors.green;
  static const Color darkBlue = Color.fromARGB(255, 2, 115, 160);
  static const Color darkTeal = Color.fromARGB(255, 19, 110, 106);
  static const Color lightTeal = Color.fromARGB(255, 20, 197, 188);
  static const Color superAdmin = Color.fromARGB(255, 47, 10, 229);
  static final Color provincialAdmin = Color.fromARGB(255, 25, 118, 210);
  static const Color municipalAdmin = Color.fromARGB(255, 76, 175, 80);
  static const Color businessOwner = Color.fromARGB(255, 233, 142, 7);
  static const Color tourist = Color(0xFF2E8B8B);

  // Add missing color and property getters for compatibility
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color inputBorder = Color(0xFFBDBDBD);
  static const Color homeForYouColor = Color(0xFF42A5F5);
  static const Color homeTrendingColor = Color(0xFFFFA726);
  static const Color homeNearbyColor = Color(0xFF66BB6A);
  static const Color homeSeasonalColor = Color(0xFFAB47BC);
  static const Color homeDiscoverColor = Color.fromARGB(
    255,
    34,
    97,
    205,
  ); // Reusing homeForYouColor for discover
  static const Color profileSignOutButtonColor = Color(0xFFD32F2F);

  // Add role-specific colors for calendar event dots
  static const Color eventBusiness = Color(0xFFFFC107); // Amber
  static const Color eventMunicipal = Color(0xFF4CAF50); // Green
  static const Color eventProvincial = Color(0xFF2196F3); // Blue

  // Gradient background
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
    stops: [0.0, 1.0],
  );

  static const LinearGradient tealbackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBlue, darkTeal, lightTeal],
    stops: [0.0, 0.5, 1.0],
  );
}
