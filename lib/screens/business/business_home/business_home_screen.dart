import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessOwnerHomeScreen extends StatefulWidget {
  const BusinessOwnerHomeScreen({super.key});

  @override
  State<BusinessOwnerHomeScreen> createState() => _BusinessOwnerHomeScreenState();
}

class _BusinessOwnerHomeScreenState extends State<BusinessOwnerHomeScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  String ownerName = 'Business Owner';
  int businessCount = 0;
  int promotionCount = 0;
  double? averageRating;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    final userData = userDoc.data();
    if (userData != null) {
      ownerName = userData['name'] ?? 'Business Owner';
    }

    final destinationSnap = await FirebaseFirestore.instance
        .collection('destination')
        .where('owner_uid', isEqualTo: uid)
        .get();

    final eventsSnap = await FirebaseFirestore.instance
        .collection('events')
        .where('created_by', isEqualTo: uid)
        .get();

    double totalRating = 0;
    int ratingCount = 0;

    for (var doc in destinationSnap.docs) {
      final data = doc.data();
      if (data.containsKey('average_rating') && data['average_rating'] != null) {
        totalRating += data['average_rating'];
        ratingCount++;
      }
    }

    setState(() {
      businessCount = destinationSnap.docs.length;
      promotionCount = eventsSnap.docs.length;
      averageRating = ratingCount > 0 ? totalRating / ratingCount : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Business Home Screen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Greeting
            Text(
              'Welcome, $ownerName!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Here’s how your business is doing today.'),
            const SizedBox(height: 24),

            // 📊 Dashboard Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Businesses', businessCount, Colors.green),
                _buildStatCard('Promotions', promotionCount, Colors.blue),
                _buildStatCard(
                  'Avg. Rating',
                  averageRating != null ? averageRating!.toStringAsFixed(1) : 'N/A',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ⚡ Quick Actions
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildShortcutButton(
                  icon: Icons.add_business,
                  label: 'Add New Spot',
                  color: Colors.teal,
                  onTap: () {
                    // TODO: Navigate to business registration
                  },
                ),
                _buildShortcutButton(
                  icon: Icons.reviews,
                  label: 'View Reviews',
                  color: Colors.deepPurple,
                  onTap: () {
                    // TODO: Navigate to reviews/ratings screen
                  },
                ),
                _buildShortcutButton(
                  icon: Icons.calendar_month,
                  label: 'My Promotions',
                  color: Colors.indigo,
                  onTap: () {
                    // TODO: Navigate to promotions calendar
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, dynamic value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
