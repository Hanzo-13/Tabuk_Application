// ignore_for_file: unnecessary_underscores

import 'package:capstone_app/screens/admin/hotspots/admin_spot_registration_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  String? adminRole;
  String? municipality;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminInfo();
  }

  Future<void> _fetchAdminInfo() async {
    final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        adminRole = data['role'];
        municipality = data['municipality'];
        _isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot> _getDestinationStream() {
    final collection = FirebaseFirestore.instance.collection('destination');
    if (adminRole == 'Municipal Administrator' && municipality != null) {
      return collection.where('municipality', isEqualTo: municipality).snapshots();
    }
    return collection.snapshots(); // Provincial Admin sees all
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in.')),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Registered Destinations'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.white,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _getDestinationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No destinations available.'),
            );
          }

          final destination = snapshot.data!.docs;

          return ListView.builder(
            itemCount: destination.length,
            itemBuilder: (context, index) {
              final doc = destination[index];
              final data = doc.data() as Map<String, dynamic>;

              final images = data['images'] as List<dynamic>?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BusinessDetailsModal(
                        businessData: data,
                        role: 'Administrator',
                        currentUserId: uid,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // ✅ Thumbnail Image or Fallback
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: images != null && images.isNotEmpty
                            ? Image.network(
                                images[0],
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                              )
                            : Container(
                                height: 90,
                                width: 90,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported, size: 40),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // ✅ Title & Subtitle
                      Expanded(
                        child: ListTile(
                          title: Text(data['business_name'] ?? 'Unnamed Destination'),
                          subtitle: Text(data['category'] ?? 'No category'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // ✅ Add New Tourist Spot Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminBusinessRegistrationScreen(adminRole: '', municipality: '',)),
          );
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Spot'),
      ),
    );
  }
}
