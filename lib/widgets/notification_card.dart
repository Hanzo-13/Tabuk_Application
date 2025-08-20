import 'package:flutter/material.dart';
import 'package:capstone_app/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationItem item;

  const NotificationCard({Key? key, required this.item}) : super(key: key);

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case "high":
        return Colors.red;
      case "medium":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          item.type == "events"
              ? Icons.event
              : item.type == "reviews"
                  ? Icons.star
                  : item.type == "users"
                      ? Icons.person_add
                      : item.type == "businesses"
                          ? Icons.business
                          : Icons.notifications,
          color: _getPriorityColor(item.priority),
          size: 30,
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.message),
            const SizedBox(height: 4),
            Text(
              "${item.timestamp}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(item.priority.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              backgroundColor: _getPriorityColor(item.priority),
            ),
            if (!item.read)
              const Icon(Icons.circle, color: Colors.orange, size: 12),
          ],
        ),
      ),
    );
  }
}
