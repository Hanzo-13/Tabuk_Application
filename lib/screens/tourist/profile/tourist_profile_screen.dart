import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/screens/tourist/profile/edit_tourist_profile.dart';
import 'package:capstone_app/screens/tourist/profile/faq_screen.dart';
import 'package:capstone_app/screens/tourist/profile/preferences_screen.dart';
import 'package:capstone_app/screens/tourist/profile/favorites_screen.dart';
import 'package:capstone_app/screens/tourist/profile/visited_destinations_screen.dart';
import 'package:capstone_app/screens/tourist/profile/reviews_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/user_service.dart';
import 'package:capstone_app/screens/login_screen.dart';

class TouristProfileScreen extends StatefulWidget {
  const TouristProfileScreen({super.key});

  @override
  State<TouristProfileScreen> createState() => _TouristProfileScreenState();
}

class _TouristProfileScreenState extends State<TouristProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String name = 'Guest User';
  String email = '';
  String profilePhoto = '';
  bool isGuest = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        isGuest = true;
        isLoading = false;
      });
      return;
    }

    // Use UserService for better data handling
    final user = await UserService.getCurrentUser();
    if (user == null || !user.formCompleted) {
      setState(() {
        isGuest = true;
        isLoading = false;
      });
      return;
    }

    setState(() {
      name = user.name.isNotEmpty ? user.name : 'Tourist';
      email = user.email;
      profilePhoto = user.profilePhoto;
      isGuest = false;
      isLoading = false;
    });
  }

  Widget buildActionTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryTeal, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget buildAvatar(String label) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              backgroundImage: _getProfileImage(),
              child: _getProfileImage() == null
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            if (!isGuest)
              const Positioned(
                bottom: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.edit, size: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          isGuest ? "Tourist (Guest Mode)\n\nCreate Account now!" : email,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (profilePhoto.isNotEmpty) {
      return NetworkImage(profilePhoto);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          "Tourist Profile",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  buildAvatar(name),

                  // Authenticated Registered Tourist
                  if (!isGuest) ...[
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      child: buildActionTile(
                        Icons.person,
                        "Edit Profile Information",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditTouristProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      child: Column(
                        children: [
                          buildActionTile(
                            Icons.location_on,
                            "Visited Destinations",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VisitedDestinationsScreen(),
                                ),
                              );
                            },
                          ),
                          buildActionTile(
                            Icons.favorite,
                            "Favorites",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen(),
                                ),
                              );
                            },
                          ),
                          buildActionTile(
                            Icons.settings,
                            "Preferences",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PreferencesScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Review Statistics Section
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 1,
                      child: Column(
                        children: [
                          buildActionTile(
                            Icons.rate_review,
                            "My Reviews",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReviewsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Support section – shown to all
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1,
                    child: Column(
                      children: [
                        if (!isGuest) ...[
                          buildActionTile(
                            Icons.help_outline,
                            "FAQ",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FAQScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.red,
                          ),
                          title: const Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            await AuthService.signOut();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}