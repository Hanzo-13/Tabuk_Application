// ===========================================
// lib/screens/admin/admin_main_screen.dart
// ===========================================

// ignore_for_file: non_constant_identifier_names, avoid_types_as_parameter_names

import 'package:capstone_app/screens/admin/admin_approval_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/events/event_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/home/home_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/hotspots/spot_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/profile/profile_screen.dart';
import 'package:capstone_app/screens/admin/municipal_admin/users/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/colors.dart';

// Screens
import 'provincial_admin/home/home_screen.dart';
import 'provincial_admin/hotspots/spot_screen.dart';
import 'provincial_admin/events/event_screen.dart';
import 'provincial_admin/profile/profile_screen.dart';
import 'provincial_admin/users/users_screen.dart';

class MainAdminScreen extends StatefulWidget {
  final bool isProvincial;
  const MainAdminScreen({super.key, this.isProvincial = false});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  int _selectedIndex = 0;
  String? _adminType; // "municipal" or "provincial"

  @override
  void initState() {
    super.initState();
    _loadAdminType();
  }

  Future<void> _loadAdminType() async {
    final prefs = await SharedPreferences.getInstance();
    final user = AuthService.currentUser;
    if (user == null) return;

    // Always fetch fresh from Firestore (don’t rely only on cache)
    final doc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    final type = doc.data()?['admin_type'];
    if (type != null) {
      final normalized = type.toString().toLowerCase().trim();
      await prefs.setString('admin_type', normalized);

      if (!mounted) return;
      setState(() => _adminType = normalized);

      print("DEBUG: loaded admin_type = '$normalized'");
    } else {
      print("DEBUG: admin_type field missing for user ${user.uid}");
    }
  }

  /// Centralized role-based navigation config
  List<_NavItem> get _navItems {
    if (_adminType == "provincial administrator") {
      return [
        _NavItem("Home", Icons.home_filled, const ProvHomeScreen()),
        _NavItem("Destinations", Icons.pin_drop, const SpotsScreen()),
        _NavItem("Events", Icons.event, const EventCalendarProvScreen()),
        _NavItem("Users", Icons.group, const ProvUsersScreen()),
        _NavItem("Profile", Icons.person, const AdminProfileScreen()),
      ];
    } else if (_adminType == "municipal administrator") {
      return [
        _NavItem("Home", Icons.home_filled, const MunicipalHomeScreen()),
        _NavItem("Destinations", Icons.pin_drop, const MuniSpotsScreen()),
        _NavItem("Events", Icons.event, const EventCalendarMuniScreen()),
        _NavItem("Users", Icons.group, const MuniUsersScreen()),
        _NavItem("Profile", Icons.person, const MuniProfileScreen()),
      ];
    } else {
      // fallback (just in case)
      return [
        _NavItem("There's a Problem", Icons.error, const PendingAdminApprovalScreen()),
      ];
    }
  }


  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: AppColors.primaryOrange,
      unselectedItemColor: AppColors.textLight,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: _navItems
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_adminType == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: _navItems[_selectedIndex].screen,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}

/// Helper class
class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  _NavItem(this.label, this.icon, this.screen);
}
