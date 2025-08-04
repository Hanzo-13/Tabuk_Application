import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  String? adminName;
  String? role; // "Municipal Administrator" or "Provincial Administrator"
  String? municipality;
  bool _isLoading = true;

  int spotCount = 0;
  int eventCount = 0;
  int userCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    final userData = userDoc.data();
    if (userData != null) {
      setState(() {
        adminName = userData['name'] ?? 'Administrator';
        role = userData['role'];
        municipality = userData['municipality'];
      });
      await _loadCounts();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadCounts() async {
    final destinationRef = FirebaseFirestore.instance.collection('destination');
    final eventsRef = FirebaseFirestore.instance.collection('events');
    final usersRef = FirebaseFirestore.instance.collection('Users');

    final destinationsSnapshot = (role == 'Municipal Administrator' && municipality != null)
        ? await destinationRef.where('municipality', isEqualTo: municipality).get()
        : await destinationRef.get();

    final eventsSnapshot = (role == 'Municipal Administrator' && municipality != null)
        ? await eventsRef.where('municipality', isEqualTo: municipality).get()
        : await eventsRef.get();

    final usersSnapshot = await usersRef.get();

    setState(() {
      spotCount = destinationsSnapshot.docs.length;
      eventCount = eventsSnapshot.docs.length;
      userCount = usersSnapshot.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 Greeting
            Text(
              'Welcome back, $adminName!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              role ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // 📊 Dashboard Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Tourist Spots', spotCount, Colors.green),
                _buildStatCard('Events', eventCount, Colors.orange),
                _buildStatCard('Users', userCount, Colors.blue),
              ],
            ),
            const SizedBox(height: 32),

            // ⚡ Shortcuts
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildShortcutButton(
                  icon: Icons.map,
                  label: 'Map View',
                  color: Colors.teal,
                  onTap: () {
                    // TODO: Navigate to map view
                  },
                ),
                _buildShortcutButton(
                  icon: Icons.people,
                  label: 'User Management',
                  color: Colors.purple,
                  onTap: () {
                    // TODO: Navigate to user management screen
                  },
                ),
                _buildShortcutButton(
                  icon: Icons.feedback,
                  label: 'View Feedback',
                  color: Colors.red,
                  onTap: () {
                    // TODO: Navigate to reports/feedback screen
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: color),
              ),
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
