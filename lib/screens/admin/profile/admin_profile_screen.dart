import 'package:capstone_app/screens/admin/profile/edit_admin_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/colors.dart';
import '../../login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => isLoading = false);
        return;
      }

    final doc = await _firestore.collection('Users').doc(currentUser.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      name = data['name'] ?? '';
      email = data['email'] ?? '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("Admin User Page", style: TextStyle(color: Colors.white)),
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
                  const SizedBox(height: 20),
                  // Avatar Placeholder
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 60, color: Colors.white),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.edit, size: 16, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 24),

                  // First card: Profile editing
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: buildActionTile(Icons.person, "Edit Profile Information", onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditAdminProfileScreen()),
                      );
                    }),
                  ),
                  // Second card: Admin actions
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        buildActionTile(Icons.business, "View Business Information"),
                        buildActionTile(Icons.device_unknown, "View (UnKnown Button)"),
                        buildActionTile(Icons.event, "Event Calendar"),
                      ],
                    ),
                  ),

                  // Third card: support section
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        buildActionTile(Icons.help_outline, "Help & Support"),
                        buildActionTile(Icons.mail_outline, "Contact Us"),
                        buildActionTile(Icons.shield_outlined, "Privacy Policy"),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text("Log Out", style: TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold)),
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
