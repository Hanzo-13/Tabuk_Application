// ===========================================
// lib/screens/business_module/business_main_screen.dart
// ===========================================

import 'package:capstone_app/screens/business/business_home/business_home_screen.dart';
import 'package:capstone_app/screens/business/events/business_events_screen.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/screens/business/profile/businessowner_profile_screen.dart';
import 'package:capstone_app/screens/business/businesses/businesses_screen.dart';

class MainBusinessOwnerScreen extends StatefulWidget {
  const MainBusinessOwnerScreen({super.key});

  @override
  State<MainBusinessOwnerScreen> createState() => _MainBusinessOwnerScreenState();
}

class _MainBusinessOwnerScreenState extends State<MainBusinessOwnerScreen> {
  int _selectedIndex = 0;

  // List of screens for each bottom nav item
  final List<Widget> _screens = [
    const BusinessOwnerHomeScreen(),
    const BusinessesScreen(), // Actual Businesses screen
    const EventCalendarBusinessOwnerScreen(),
    const BusinessProfileScreen(), // Actual Profile screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'Business',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.discount_outlined),
          label: 'Promotions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: AppColors.primaryOrange,
      unselectedItemColor: AppColors.textLight,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      showSelectedLabels: true,
    );
  }
}