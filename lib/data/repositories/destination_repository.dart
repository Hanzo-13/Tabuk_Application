// ===========================================
// lib/data/repositories/destination_repository.dart
// Lightweight repository relying on Firestore offline persistence
// Now with cache-first support for offline access
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../services/offline_data_service.dart';
import '../../services/offline_sync_service.dart';
import '../../models/destination_model.dart';

class DestinationRepository {
  final FirebaseFirestore _db;

  DestinationRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('destination');

  /// Stream all active destinations (filters archived if present).
  Stream<List<Map<String, dynamic>>> getDestinationsStream() {
    return _collection.snapshots().map(
      (snap) =>
          snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .where(
                (m) => !(m['isArchived'] == true || m['status'] == 'Archived'),
              )
              .toList(),
    );
  }

  /// One-shot fetch (cache-first, falls back to Firestore).
  Future<List<Map<String, dynamic>>> getDestinationsOnce() async {
    try {
      // Try to get from cache first
      await OfflineDataService.initialize();
      final cachedHotspots = await OfflineDataService.loadHotspots();
      
      if (cachedHotspots.isNotEmpty) {
        // Filter active destinations and convert to map format
        final activeHotspots = cachedHotspots
            .where((h) => h.isArchived == null || h.isArchived != true)
            .map((h) {
              final json = h.toJson();
              json['id'] = h.hotspotId;
              json['hotspot_id'] = h.hotspotId;
              return json;
            })
            .toList();
        
        // Return cached data immediately, then sync in background
        _syncInBackground();
        return activeHotspots;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached destinations: $e');
    }

    // Fallback to Firestore
    try {
      final snap = await _collection.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching destinations from Firestore: $e');
      // If Firestore fails, try cache again as last resort
      try {
        await OfflineDataService.initialize();
        final cachedHotspots = await OfflineDataService.loadHotspots();
        return cachedHotspots
            .where((h) => h.isArchived == null || h.isArchived != true)
            .map((h) {
              final json = h.toJson();
              json['id'] = h.hotspotId;
              json['hotspot_id'] = h.hotspotId;
              return json;
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
        await OfflineSyncService.syncHotspots(downloadImages: false);
      } catch (_) {
        // Silent fail for background sync
      }
    });
  }
}

