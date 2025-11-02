// ===========================================
// lib/data/repositories/trip_repository.dart
// Lightweight repository relying on Firestore offline persistence
// Now with cache-first support for offline access
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/offline_data_service.dart';
import '../../services/offline_sync_service.dart';
import '../../models/trip_model.dart' as trip_model;

class TripRepository {
  final FirebaseFirestore _db;

  TripRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tripsCollection() {
    return _db.collection('trip_planning');
  }

  /// Stream trips for a user. Works offline via Firestore cache.
  Stream<List<Map<String, dynamic>>> getTripsStream(String userId) {
    return _tripsCollection()
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  /// Load trips for a user (cache-first, falls back to Firestore).
  Future<List<Map<String, dynamic>>> getTripsOnce(String userId) async {
    try {
      // Try to get from cache first
      await OfflineDataService.initialize();
      final cachedTrips = await OfflineDataService.loadUserTrips(userId);
      
      if (cachedTrips.isNotEmpty) {
        // Return cached data immediately, then sync in background
        _syncInBackground(userId);
        return cachedTrips.map((t) => t.toMap()).toList();
      }
    } catch (e) {
      print('Error loading cached trips: $e');
    }

    // Fallback to Firestore
    try {
      final snapshot = await _tripsCollection()
          .where('user_id', isEqualTo: userId)
          .get();
      return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      print('Error fetching trips from Firestore: $e');
      // If Firestore fails, try cache again as last resort
      try {
        await OfflineDataService.initialize();
        final cachedTrips = await OfflineDataService.loadUserTrips(userId);
        return cachedTrips.map((t) => t.toMap()).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Load a single trip once (from cache/remote).
  Future<Map<String, dynamic>?> getTripOnce(
    String userId,
    String tripId,
  ) async {
    try {
      // Try cache first
      await OfflineDataService.initialize();
      final cachedTrips = await OfflineDataService.loadUserTrips(userId);
      try {
        final trip = cachedTrips.firstWhere((t) => t.tripPlanId == tripId);
        return trip.toMap();
      } catch (_) {
        // Not in cache, continue to Firestore
      }
    } catch (e) {
      print('Error loading cached trip: $e');
    }

    // Fallback to Firestore
    try {
      final snapshot = await _tripsCollection()
          .where('user_id', isEqualTo: userId)
          .get();
      final tripDoc = snapshot.docs.firstWhere((doc) => doc.id == tripId);
      if (!tripDoc.exists) return null;
      return {'id': tripDoc.id, ...tripDoc.data()};
    } catch (e) {
      print('Error fetching trip from Firestore: $e');
      return null;
    }
  }

  /// Save a new trip document. Queued offline automatically by Firestore.
  Future<String> saveNewTrip(
    String userId,
    Map<String, dynamic> tripData,
  ) async {
    final now = DateTime.now();
    final withMeta = {
      'user_id': userId,
      'createdAt': tripData['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      ...tripData,
    };
    final ref = await _tripsCollection().add(withMeta);
    // Update cache
    _updateCacheAfterSave(userId);
    return ref.id;
  }

  /// Update an existing trip. Queued offline automatically.
  Future<void> updateTrip(
    String userId,
    String tripId,
    Map<String, dynamic> updatedData,
  ) async {
    final withMeta = {
      'updatedAt': DateTime.now().toIso8601String(),
      ...updatedData,
    };
    await _tripsCollection().doc(tripId).update(withMeta);
    // Update cache
    _updateCacheAfterSave(userId);
  }

  /// Delete a trip. Queued offline automatically.
  Future<void> deleteTrip(String userId, String tripId) async {
    await _tripsCollection().doc(tripId).delete();
    // Update cache
    _updateCacheAfterSave(userId);
  }

  /// Background sync (non-blocking)
  void _syncInBackground(String userId) {
    Future.microtask(() async {
      try {
        await OfflineSyncService.syncUserTrips(userId);
      } catch (_) {
        // Silent fail for background sync
      }
    });
  }

  /// Update cache after save/update/delete
  void _updateCacheAfterSave(String userId) {
    _syncInBackground(userId);
  }
}

