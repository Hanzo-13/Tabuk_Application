// ===========================================
// File: lib/screens/tourist_module/main_tourist_screen.dart
// Main screen for Tourist users with bottom navigation
// ===========================================

// ignore_for_file: use_build_context_synchronously

import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_app/services/offline_cache_service.dart';
import 'package:capstone_app/screens/tourist/event_calendar/tourist_event_calendar.dart';
import 'home/tourist_home_screen.dart';
import 'map/map_screen.dart';
import 'profile/tourist_profile_screen.dart';
import 'trips/trips_screen.dart';
import 'package:capstone_app/screens/login_screen.dart';

/// Main screen for tourist users with bottom navigation.
class MainTouristScreen extends StatefulWidget {
  const MainTouristScreen({super.key});

  @override
  State<MainTouristScreen> createState() => _MainTouristScreenState();
}

class _MainTouristScreenState extends State<MainTouristScreen> {
  int _selectedIndex = 0;
  String? _userRole;

  bool get _isGuest => _userRole?.toLowerCase() == 'guest';

  @override
  void initState() {
    super.initState();
    _loadRoleFromCacheOrFetch();
  }

  /// Load role from shared preferences or fetch from Firestore
  Future<void> _loadRoleFromCacheOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRole = prefs.getString('user_role');

    if (cachedRole != null) {
      setState(() => _userRole = cachedRole);
    } else {
      final user = AuthService.currentUser;
      if (user == null) {
        // Offline or not logged in -> guest
        setState(() => _userRole = 'guest');
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      final role = doc.data()?['role'];
      if (role != null) {
        await prefs.setString('user_role', role);
        if (!mounted) return;
        setState(() => _userRole = role);
      } else {
        // If no role yet and dialog hasn't been shown, skip showing here
        // because centralized dialog is handled in login/signup flow
        debugPrint('Role missing and handled by AuthChecker or login flow');
        // Fallback to guest for offline capability
        setState(() => _userRole = 'guest');
      }
    }
  }

  /// Navigation tap handler
  void _onItemTapped(int index) {
    if (_isGuest && index > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature is only available for registered users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> logoutGuest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await OfflineCacheService.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Pages based on role
  List<Widget> get _screens {
    if (_isGuest) {
      return [
        const MapScreen(),
        const TouristEventCalendarScreen(),
        const TouristProfileScreen(),
      ];
    } else {
      return [
        const TouristHomeScreen(),
        const MapScreen(),
        const TripsScreen(),
        const TouristEventCalendarScreen(),
        const TouristProfileScreen(),
      ];
    }
  }

  /// Bottom nav bar builder
  Widget _buildBottomNavBar() {
    if (_isGuest) {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textLight,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      );
    } else {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textLight,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.luggage), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
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

/// ❌ This Role Selection Dialog was previously used here,
/// but is now handled in `log_in_screen.dart` instead.
/// Keeping it commented for reference only.
/// DO NOT UNCOMMENT unless this screen needs to re-trigger role selection manually.
/*
class _RoleSelectionDialog extends StatefulWidget {
  final Function(String) onRoleSelected;
  final List<String> roles;
  const _RoleSelectionDialog({required this.onRoleSelected, required this.roles});
  @override
  State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
  String _selectedRole = 'Tourist';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Your Role',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: widget.roles.map((role) => DropdownMenuItem(
          value: role,
          child: Text(role, style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
        )).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedRole = value);
        },
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            widget.onRoleSelected(_selectedRole);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
*/
