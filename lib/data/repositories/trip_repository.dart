// ===========================================
// lib/data/repositories/trip_repository.dart
// Lightweight repository relying on Firestore offline persistence
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';

class TripRepository {
  final FirebaseFirestore _db;

  TripRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tripsCollection(String userId) {
    return _db.collection('Users').doc(userId).collection('trips');
  }

  /// Stream trips for a user. Works offline via Firestore cache.
  Stream<List<Map<String, dynamic>>> getTripsStream(String userId) {
    return _tripsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  /// Load a single trip once (from cache/remote).
  Future<Map<String, dynamic>?> getTripOnce(
    String userId,
    String tripId,
  ) async {
    final doc = await _tripsCollection(userId).doc(tripId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Save a new trip document. Queued offline automatically by Firestore.
  Future<String> saveNewTrip(
    String userId,
    Map<String, dynamic> tripData,
  ) async {
    final now = DateTime.now();
    final withMeta = {
      'createdAt': tripData['createdAt'] ?? now,
      'updatedAt': now,
      ...tripData,
    };
    final ref = await _tripsCollection(userId).add(withMeta);
    return ref.id;
  }

  /// Update an existing trip. Queued offline automatically.
  Future<void> updateTrip(
    String userId,
    String tripId,
    Map<String, dynamic> updatedData,
  ) async {
    final withMeta = {'updatedAt': DateTime.now(), ...updatedData};
    await _tripsCollection(userId).doc(tripId).update(withMeta);
  }

  /// Delete a trip. Queued offline automatically.
  Future<void> deleteTrip(String userId, String tripId) async {
    await _tripsCollection(userId).doc(tripId).delete();
  }
}

