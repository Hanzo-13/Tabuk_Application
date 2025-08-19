// ===========================================
// lib/screens/admin_module/main_admin_screen.dart
// ===========================================

import 'package:capstone_app/screens/admin/events/admin_events_screen.dart';
import 'package:capstone_app/screens/admin/notification/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_app/utils/colors.dart';
import 'admin_home/admin_home_screen.dart';
import 'hotspots/admin_spot_screen.dart';
import 'profile/admin_profile_screen.dart';

class MainAdminScreen extends StatefulWidget {
  final bool isProvincial;
  const MainAdminScreen({super.key, this.isProvincial = false});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  int _selectedIndex = 0;
  String? _adminType;

  @override
  void initState() {
    super.initState();
    _loadAdminType();
  }

  Future<void> _loadAdminType() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedType = prefs.getString('admin_type');

    setState(() => _adminType = cachedType);
    }

  void _onItemTapped(int index) {
    if (_adminType == 'municipal' && index > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature is only available for Provincial Admins'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  List<Widget> get _screens {
      return [
        const AdminHomeScreen(),
        const AdminBusinessesScreen(),
        const EventCalendarAdminScreen(),
        AdminNotificationScreen(),
        const AdminProfileScreen(),
      ];
  }

  Widget _buildBottomNavBar() {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textLight,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pin_drop), label: 'Destinations'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
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
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}
