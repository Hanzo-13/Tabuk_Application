import 'package:capstone_app/screens/admin/admin_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/screens/tourist/main_tourist_screen.dart';
// import 'package:capstone_app/screens/admin/admin_registration_form.dart'; // ✅ this is correct
import 'package:capstone_app/screens/business/main_business_screen.dart';
// import 'package:capstone_app/screens/tourist/preferences/tourist_registration_flow.dart';

/// Navigation helper class to route users based on their role.
class NavigationHelper {
  /// Navigates to the appropriate main screen for the given user role.
  static void navigateBasedOnRole(BuildContext context, String role) {
    Widget targetScreen;
    switch (role.toLowerCase()) {
      case 'administrator':
      case 'admin':
        targetScreen = const MainAdminScreen();
        break;
      case 'business owner':
      case 'businessowner':
        targetScreen = const MainBusinessOwnerScreen();
        break;
      case 'tourist':
        targetScreen = const MainTouristScreen();
        break;
      case 'guest':
      default:
        targetScreen = const MainTouristScreen();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }
}
