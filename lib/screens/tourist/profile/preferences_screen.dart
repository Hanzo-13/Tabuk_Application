import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/utils/colors.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  Map<String, dynamic> preferences = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('tourist_preferences')
          .doc(user.uid)
          .get();
          
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          preferences = Map<String, dynamic>.from(data['preferences'] ?? {});
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildPreferenceSection(String title, List<String> values) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForPreference(title),
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatTitle(title),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            if (values.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values.map((value) {
                  return Chip(
                    label: Text(
                      value,
                      style: const TextStyle(fontSize: 13),
                    ),
                    backgroundColor: AppColors.primaryTeal.withOpacity(0.1),
                    labelStyle: TextStyle(color: AppColors.primaryTeal),
                    side: BorderSide(
                      color: AppColors.primaryTeal.withOpacity(0.3),
                    ),
                  );
                }).toList(),
              )
            else
              const Text(
                'No preferences set',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPreference(String title) {
    switch (title.toLowerCase()) {
      case 'travel_interests':
        return Icons.interests;
      case 'budget_range':
        return Icons.attach_money;
      case 'accommodation_preferences':
        return Icons.hotel;
      case 'activity_types':
        return Icons.local_activity;
      case 'food_preferences':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      default:
        return Icons.settings;
    }
  }

  String _formatTitle(String title) {
    return title
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Your Preferences',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit preferences screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit preferences functionality coming soon!'),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : preferences.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Preferences Set',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Complete your preferences to get personalized recommendations for your trips.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to preferences setup
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Set preferences functionality coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Set Preferences'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'These are your current travel preferences. They help us provide personalized recommendations for your trips.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...preferences.entries.map((entry) {
                      final key = entry.key;
                      final value = entry.value;
                      
                      List<String> values;
                      if (value is List) {
                        values = value.map((v) => v.toString()).toList();
                      } else {
                        values = [value.toString()];
                      }
                      
                      return buildPreferenceSection(key, values);
                    }),
                  ],
                ),
    );
  }
}