import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  static final _eventCollection = FirebaseFirestore.instance.collection('events');

  /// Add a new event to Firestore
  static Future<void> addEvent(Event event) async {
    await _eventCollection.add(event.toMap());
  }

  /// Update an existing event
  static Future<void> updateEvent(String eventId, Event updatedEvent) async {
    await _eventCollection.doc(eventId).update(updatedEvent.toMap());
  }

  /// Delete an event
  static Future<void> deleteEvent(String eventId) async {
    await _eventCollection.doc(eventId).delete();
  }

  /// Get all events
  static Future<List<Event>> getAllEvents() async {
    final snapshot = await _eventCollection.orderBy('startDate', descending: false).get();
    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get events created by a specific user (for Business Owner filtering)
  static Future<List<Event>> getEventsByUser(String uid) async {
    final snapshot = await _eventCollection
        .where('created_by', isEqualTo: uid)
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get events for a specific municipality
  static Future<List<Event>> getEventsByMunicipality(String municipality) async {
    final snapshot = await _eventCollection
        .where('municipality', isEqualTo: municipality)
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get upcoming events only
  static Future<List<Event>> getUpcomingEvents() async {
    final now = DateTime.now();
    final snapshot = await _eventCollection
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get events for a specific date
  static Future<List<Event>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _eventCollection
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => Event.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get single event by ID
  static Future<Event?> getEventById(String eventId) async {
    final doc = await _eventCollection.doc(eventId).get();
    if (doc.exists) {
      return Event.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}
