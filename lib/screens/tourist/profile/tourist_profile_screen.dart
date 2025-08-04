import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/screens/tourist/profile/edit_tourist_profile.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/screens/login_screen.dart';

class TouristProfileScreen extends StatefulWidget {
  const TouristProfileScreen({super.key});

  @override
  State<TouristProfileScreen> createState() => _TouristProfileScreenState();
}

class _TouristProfileScreenState extends State<TouristProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = 'Guest User';
  String email = '';
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

    final doc = await _firestore.collection('Users').doc(currentUser.uid).get();
    if (!doc.exists || !(doc.data()?['form_completed'] ?? false)) {
      setState(() {
        isGuest = true;
        isLoading = false;
      });
      return;
    }

    final data = doc.data()!;
    setState(() {
      name = data['name'] ?? 'Tourist';
      email = data['email'] ?? '';
      isGuest = false;
      isLoading = false;
    });
  }

  Widget buildActionTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDark),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  Widget buildAvatar(String label) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 60, color: Colors.white),
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
        Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(isGuest ? "Tourist (Guest Mode)\n\n Create Account now!" : email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("Tourist Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryTeal,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.notifications),
          ),
        ],
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: buildActionTile(Icons.person, "Edit Profile Information", onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditTouristProfileScreen()),
                        );
                      }),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          buildActionTile(Icons.archive, "Completed Trips"),
                          buildActionTile(Icons.event, "Event Calendar"),
                          buildActionTile(Icons.favorite, "Favorites"),
                          buildActionTile(Icons.settings, "Preferences"),
                        ],
                      ),
                    ),
                  ],

                  // Support section – shown to all
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        if (!isGuest) ...[
                          buildActionTile(Icons.help_outline, "Help & Support"),
                          buildActionTile(Icons.mail_outline, "Contact Us"),
                          buildActionTile(Icons.shield_outlined, "Privacy Policy"),
                        ],
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            await AuthService.signOut();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
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
