import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String type; // events, reviews, users, businesses, general
  final String title;
  final String message;
  final DateTime timestamp;
  final String priority; // low, medium, high
  final bool read;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.priority,
    required this.read,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> data, String id) {
    return NotificationItem(
      id: id,
      type: data['type'] ?? 'general',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'low',
      read: data['read'] ?? false,
    );
  }
}
