// ===========================================
// lib/data/repositories/event_repository.dart
// Lightweight repository relying on Firestore offline persistence
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';

class EventRepository {
  final FirebaseFirestore _db;

  EventRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('events');

  /// Stream active events (from cache/remote).
  Stream<List<Map<String, dynamic>>> getActiveEventsStream() {
    return _collection
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  /// One-shot fetch of active events (cache/remote).
  Future<List<Map<String, dynamic>>> getActiveEventsOnce() async {
    final snap = await _collection.where('status', isEqualTo: 'active').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// One-shot fetch of all events (cache/remote).
  Future<List<Map<String, dynamic>>> getAllEventsOnce() async {
    final snap = await _collection.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
