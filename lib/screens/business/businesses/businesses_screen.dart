// ignore_for_file: unnecessary_underscores

import 'package:capstone_app/screens/business/businesses/business_registration_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
// import 'package:capstone_app/screens/business/businessowner_registration_form.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});

  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Businesses'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryTeal,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.add),
        //     tooltip: 'Add Business',
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (_) => const BusinessRegistrationForm()),
        //       );
        //     },
        //   ),
        // ],
      ),
      body: uid == null
          ? const Center(child: Text('User not logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('destination')
                  .where('owner_uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BusinessRegistrationForm()),
                        );
                      },
                      icon: const Icon(Icons.add_business),
                      label: const Text('Add Your First Business'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  );
                }

                final businesses = snapshot.data!.docs;
              
                return ListView.builder(
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final doc = businesses[index];
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
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BusinessRegistrationForm()),
                );
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add Business'),
            ),
    );
  }
}
