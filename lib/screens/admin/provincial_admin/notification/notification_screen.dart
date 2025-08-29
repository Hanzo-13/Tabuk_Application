import 'package:capstone_app/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProvNotificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Function(Map<String, dynamic>) onNotificationTap;

  const ProvNotificationScreen({
    super.key,
    required this.notifications,
    required this.onNotificationTap,
  });

  @override
  State<ProvNotificationScreen> createState() => _ProvNotificationScreenState();
}

class _ProvNotificationScreenState extends State<ProvNotificationScreen> {
  // A helper map to define the icon and color for each notification type
  final Map<String, Map<String, dynamic>> _notificationStyles = {
    'users': {'icon': Icons.person_add_alt_1, 'color': Colors.blue},
    'businesses': {'icon': Icons.business_center, 'color': Colors.green},
    'reviews': {'icon': Icons.rate_review, 'color': Colors.orange},
    'events': {'icon': Icons.event, 'color': Colors.purple},
    'default': {'icon': Icons.notifications, 'color': Colors.grey},
  };

  // When a notification is tapped, navigate to the appropriate detail screen
  void _handleNotificationTap(NotificationItem notification) {
    // 1. Mark the notification as read in Firestore for better UX
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'read': true});

    // 2. Navigate based on the notification type
    // if (notification.relatedDocId == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('This notification has no associated action.')),
    //   );
    //   return;
    // }

    // switch (notification.type) {
    //   case 'users':
    //     print('Navigating to user details for ID: ${notification.relatedDocId}');
    //     // TODO: Replace with your actual user detail/approval screen
    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(
    //         builder: (context) => AdminUserApprovalScreen(userId: notification.relatedDocId!),
    //       ),
    //     );
    //     break;
    //   case 'businesses':
    //     print('Navigating to business details for ID: ${notification.relatedDocId}');
    //     // TODO: Replace with your actual business detail/approval screen
    //     // Navigator.push(context, MaterialPageRoute(builder: (context) => AdminBusinessApprovalScreen(businessId: notification.relatedDocId!)));
    //     break;
    //   // Add cases for 'reviews' and 'events' if they have detail pages
    //   default:
    //     print('No navigation defined for type: ${notification.type}');
    //     break;
    // }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Notifications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New Users'),
              Tab(text: 'Businesses'),
              Tab(text: 'Reviews'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNotificationList(type: 'users'),
            _buildNotificationList(type: 'businesses'),
            _buildNotificationList(type: 'reviews'),
            _buildNotificationList(type: 'events'),
          ],
        ),
      ),
    );
  }

  // A reusable widget to build a list for a specific notification type
  Widget _buildNotificationList({required String type}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading notifications.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No new notifications for $type', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final notifications = snapshot.data!.docs.map((doc) {
          return NotificationItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildNotificationItem(notifications[index]);
          },
        );
      },
    );
  }
  
  // This widget builds a single notification item, styled like your recent activity list
  Widget _buildNotificationItem(NotificationItem notification) {
    final style = _notificationStyles[notification.type] ?? _notificationStyles['default']!;
    final Color iconColor = style['color'];
    final IconData iconData = style['icon'];

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleNotificationTap(notification),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(notification.message),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, hh:mm a').format(notification.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: !notification.read
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}