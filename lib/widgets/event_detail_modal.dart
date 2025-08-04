// ignore_for_file: use_build_context_synchronously

import 'package:capstone_app/screens/business/promotions/edit_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../utils/colors.dart';

class EventDetailModal extends StatelessWidget {
  final Event event;
  final String currentUserId;
  final String userRole; // 'Administrator', 'BusinessOwner', etc.
  final String? adminType; // e.g. 'Provincial Administrator'

  const EventDetailModal({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.userRole,
    this.adminType,
  });

  bool get isCreator => event.createdBy == currentUserId;

  bool get canEditOrManage => isCreator;

  bool get shouldShowCreatorInfo {
    // Admins can view creator info IF they are not the creator
    return userRole == 'Administrator' && !isCreator;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return Colors.orange;
      case 'upcoming':
        return Colors.green;
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event.thumbnailUrl != null && event.thumbnailUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  event.thumbnailUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 300,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              )
            else
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Icon(Icons.image, size: 64),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDate(event.startDate)} → ${_formatDate(event.endDate)}',
                      style: TextStyle(fontSize: 16, color: AppColors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.location}, ${event.municipality}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 24),

                    // ✅ Show creator info only for Admins who are NOT the creator
                    if (shouldShowCreatorInfo) _buildCreatorInfo(),

                    const SizedBox(height: 24),

                    // ✅ Show action buttons only if current user is the creator
                    if (canEditOrManage) _buildActionButtons(context, event),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Creator',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text('Role: ${event.role}', style: TextStyle(color: AppColors.primaryTeal, fontStyle: FontStyle.italic, fontSize: 15)),
        Text('Name: ${event.creatorName}'),
        Text('Email: ${event.creatorEmail}'),
        Text('Contact: ${event.creatorContact}'),
      ],
    );
  }

Widget _buildActionButtons(BuildContext context, Event event) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditEventScreen(event: event, eventId: '',),
            ),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('Edit Event'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).primaryColor,
        ),
      ),
      ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Confirm Removal"),
              content: const Text("Are you sure you want to remove this event permanently?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog first
                    try {
                      await FirebaseFirestore.instance
                          .collection('events')
                          .doc(event.eventId)
                          .delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Event removed successfully")),
                      );
                      Navigator.pop(context); // Close the modal bottom sheet
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to delete event: $e")),
                      );
                    }
                  },
                  child: const Text("Remove", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Remove Event'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red,
        ),
      ),
    ],
  );
}


  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
