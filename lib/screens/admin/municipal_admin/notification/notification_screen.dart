import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/models/notification_model.dart';
import 'package:capstone_app/widgets/notification_card.dart';
import 'package:badges/badges.dart' as badges;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ["Events", "Reviews", "New Users", "Businesses", "General"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  Stream<List<NotificationItem>> _getNotifications(String type) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where("role", isEqualTo: "admin")
        .where("type", isEqualTo: type.toLowerCase().replaceAll(" ", ""))
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationItem.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<int> _getUnreadCount(String type) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where("role", isEqualTo: "admin")
        .where("type", isEqualTo: type.toLowerCase().replaceAll(" ", ""))
        .where("read", isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Administrator Notifications"),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs.map((tab) {
              return StreamBuilder<int>(
                stream: _getUnreadCount(tab),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return badges.Badge(
                    showBadge: count > 0,
                    badgeContent: Text(count.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                    child: Text(tab),
                  );
                },
              );
            }).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            return StreamBuilder<List<NotificationItem>>(
              stream: _getNotifications(tab),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data!;
                if (notifications.isEmpty) {
                  return const Center(child: Text("No notifications found"));
                }
                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return NotificationCard(item: notifications[index]);
                  },
                );
              },
            );
          }).toList(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 3, // Notifications tab active
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Map"),
            BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notifications"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}
