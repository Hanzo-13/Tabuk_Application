import 'package:cloud_firestore/cloud_firestore.dart';

/// Event model representing both public events and business promotions.
/// Use [eventType] if you want to differentiate visual/UI presentation.
/// You can optionally deprecate [eventType] and treat all as events.
class Event {
  final String eventId;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location; // Specific venue or address
  final String municipality; // City/Area for filtering
  final String createdBy; // Creator's UID
  // final String eventType; // Optional: "Event" or "Promotion"
  final String? thumbnailUrl; // Optional: Featured image
  final DateTime createdAt;
  final String role; // Creator role: business owner, municipal admin, etc.
  final String creatorName;
  final String creatorContact;
  final String creatorEmail;

  Event({
    required this.eventId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.municipality,
    required this.createdBy,
    // required this.eventType,
    this.thumbnailUrl,
    required this.createdAt,
    required this.role,
    required this.creatorName,
    required this.creatorContact,
    required this.creatorEmail,
  });

  /// Computed status based on current date
  String get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventStart = DateTime(startDate.year, startDate.month, startDate.day);
    final eventEnd = DateTime(endDate.year, endDate.month, endDate.day);

    if (eventEnd.isBefore(today)) {
      return 'ended';
    } else if (eventStart.isAfter(today)) {
      return 'upcoming';
    } else {
      return 'ongoing';
    }
  }

  /// Create Event from Firestore document
  factory Event.fromMap(Map<String, dynamic> map, String id) {
    return Event(
      eventId: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      location: map['location'] ?? '',
      municipality: map['municipality'] ?? '',
      createdBy: map['created_by'] ?? '',
      // eventType: map['event_type'] ?? 'Event',
      thumbnailUrl: map['thumbnailUrl'] != null && map['thumbnailUrl'].toString().isNotEmpty
    ? map['thumbnailUrl']
    : '',
      createdAt: (map['created_at'] as Timestamp).toDate(),
      role: map['role'] ?? 'admin',
      creatorName: map['name'] ?? '',
      creatorContact: map['contact'] ?? '',
      creatorEmail: map['email'] ?? '',
    );
  }

  /// Convert Event to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'location': location,
      'municipality': municipality,
      'created_by': createdBy,
      'thumbnailUrl': thumbnailUrl,
      'created_at': Timestamp.fromDate(createdAt),
      'role': role,
      'name': creatorName,
      'contact': creatorContact,
      'email': creatorEmail,
    };
  }

  static fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {}
}
