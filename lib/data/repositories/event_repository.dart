// ===========================================
// lib/data/repositories/event_repository.dart
// Lightweight repository relying on Firestore offline persistence
// Now with cache-first support for offline access
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../services/offline_data_service.dart';
import '../../services/offline_sync_service.dart';

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

  /// One-shot fetch of active events (cache-first, falls back to Firestore).
  Future<List<Map<String, dynamic>>> getActiveEventsOnce() async {
    try {
      // Try to get from cache first
      await OfflineDataService.initialize();
      final cachedEvents = await OfflineDataService.loadEvents();
      
      if (cachedEvents.isNotEmpty) {
        // Filter active events from cache
        final activeCached = cachedEvents
            .where((e) => e.status == 'active')
            .map((e) => {
                  'id': e.eventId,
                  ...e.toMap(),
                })
            .toList();
        
        // Return cached data immediately, then sync in background
        _syncInBackground();
        return activeCached;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached events: $e');
    }

    // Fallback to Firestore
    try {
      final snap = await _collection.where('status', isEqualTo: 'active').get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching events from Firestore: $e');
      // If Firestore fails, try cache again as last resort
      try {
        await OfflineDataService.initialize();
        final cachedEvents = await OfflineDataService.loadEvents();
        return cachedEvents
            .where((e) => e.status == 'active')
            .map((e) => {
                  'id': e.eventId,
                  ...e.toMap(),
                })
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// One-shot fetch of all events (cache-first, falls back to Firestore).
  Future<List<Map<String, dynamic>>> getAllEventsOnce() async {
    try {
      // Try to get from cache first
      await OfflineDataService.initialize();
      final cachedEvents = await OfflineDataService.loadEvents();
      
      if (cachedEvents.isNotEmpty) {
        // Return cached data immediately, then sync in background
        _syncInBackground();
        return cachedEvents
            .map((e) => {
                  'id': e.eventId,
                  ...e.toMap(),
                })
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached events: $e');
    }

    // Fallback to Firestore
    try {
      final snap = await _collection.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching events from Firestore: $e');
      // If Firestore fails, try cache again as last resort
      try {
        await OfflineDataService.initialize();
        final cachedEvents = await OfflineDataService.loadEvents();
        return cachedEvents
            .map((e) => {
                  'id': e.eventId,
                  ...e.toMap(),
                })
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Background sync (non-blocking)
  void _syncInBackground() {
    // Sync in background without blocking UI
    Future.microtask(() async {
      try {
        await OfflineSyncService.syncEvents(downloadImages: false);
      } catch (_) {
        // Silent fail for background sync
      }
    });
  }
}
