import 'package:capstone_app/utils/colors.dart';
import 'package:flutter/material.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<AdminNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> eventNotifications = [
    "New event proposal: 'Festival of Lights' in Municipality A",
    "Event 'Beach Cleanup' is scheduled for Aug 5",
  ];

  final List<String> reviewNotifications = [
    "New review on 'Riverwalk Café': ★★★★☆",
  ];

  final List<String> businessNotifications = [
    "New business submitted: 'Mountain View Resort'",
    "Business 'Island Tours' updated their profile",
  ];

  final List<String> importantNotifications = [
    "⚠️ Escalated issue: User reported inappropriate content",
    "⚠️ System alert: Verification pending for 3 new businesses",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Widget _buildNotificationList(List<String> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No notifications here.',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            title: Text(items[index]),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Optional: handle tap
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Notifications'),
        titleTextStyle: const TextStyle(
          fontSize: 25,
          color: AppColors.white,
        ),
        backgroundColor: AppColors.primaryTeal,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelStyle: const TextStyle(color: AppColors.white),
          tabs: const [
            Tab(icon: Icon(Icons.event, color: AppColors.white), text: 'Events'),
            Tab(icon: Icon(Icons.reviews, color: AppColors.white), text: 'Reviews'),
            Tab(icon: Icon(Icons.business_center, color: AppColors.white), text: 'Business'),
            Tab(icon: Icon(Icons.priority_high, color: AppColors.white), text: 'Important'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList(eventNotifications),
          _buildNotificationList(reviewNotifications),
          _buildNotificationList(businessNotifications),
          _buildNotificationList(importantNotifications),
        ],
      ),
    );
  }
}
