import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/event_model.dart';
import '../models/destination_model.dart';
import '../models/trip_model.dart' as trip_model;
import 'offline_data_service.dart';
import 'image_cache_service.dart';
import 'connectivity_service.dart';

/// Service for syncing data from Firestore to local storage for offline access
/// Includes progress tracking and image pre-downloading
class OfflineSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ConnectivityService _connectivityService = ConnectivityService();
  
  // Progress callbacks
  static Function(String, double, String)? onProgress;
  static Function(String, String)? onComplete;
  static Function(String, String)? onError;

  /// Sync all data for offline use (hotspots, events, trips)
  /// Returns a map with sync results
  static Future<Map<String, SyncResult>> syncAllData({
    String? userId,
    bool downloadImages = true,
    Function(String, double, String)? progressCallback,
  }) async {
    onProgress = progressCallback;
    final results = <String, SyncResult>{};
    
    try {
      // Check connectivity
      final connectivity = await _connectivityService.checkConnection();
      if (!connectivity.isConnected) {
        throw Exception('No internet connection. Cannot sync data.');
      }

      // Initialize offline storage
      await OfflineDataService.initialize();

      // Sync hotspots
      progressCallback?.call('hotspots', 0.0, 'Starting hotspots sync...');
      results['hotspots'] = await syncHotspots(downloadImages: downloadImages);

      // Sync events
      progressCallback?.call('events', 0.0, 'Starting events sync...');
      results['events'] = await syncEvents(downloadImages: downloadImages);

      // Sync trips (if userId provided)
      if (userId != null && userId.isNotEmpty) {
        progressCallback?.call('trips', 0.0, 'Starting trips sync...');
        results['trips'] = await syncUserTrips(userId);
      }

      onComplete?.call('all', 'All data synced successfully');
      return results;
    } catch (e) {
      onError?.call('all', e.toString());
      rethrow;
    }
  }

  /// Sync hotspots/destinations from Firestore
  static Future<SyncResult> syncHotspots({bool downloadImages = true}) async {
    try {
      onProgress?.call('hotspots', 0.1, 'Fetching hotspots from Firestore...');
      
      // Fetch all destinations from Firestore
      final snapshot = await _firestore.collection('destination').get();
      
      onProgress?.call('hotspots', 0.3, 'Processing ${snapshot.docs.length} hotspots...');
      
      // Convert to Hotspot models
      final hotspots = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              return Hotspot.fromMap(data, doc.id);
            } catch (e) {
            if (kDebugMode) debugPrint('Error parsing hotspot ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Hotspot>()
          .toList();

      onProgress?.call('hotspots', 0.5, 'Saving ${hotspots.length} hotspots locally...');
      
      // Save to offline storage
      await OfflineDataService.saveHotspots(hotspots);

      // Download images if requested
      if (downloadImages) {
        onProgress?.call('hotspots', 0.6, 'Downloading hotspot images...');
        await _downloadHotspotImages(hotspots);
      }

      onProgress?.call('hotspots', 1.0, 'Hotspots synced successfully');
      onComplete?.call('hotspots', '${hotspots.length} hotspots synced');
      
      return SyncResult(
        success: true,
        count: hotspots.length,
        message: '${hotspots.length} hotspots synced successfully',
      );
    } catch (e) {
      final errorMsg = 'Error syncing hotspots: $e';
      onError?.call('hotspots', errorMsg);
      return SyncResult(
        success: false,
        count: 0,
        message: errorMsg,
      );
    }
  }

  /// Sync events from Firestore
  static Future<SyncResult> syncEvents({bool downloadImages = true}) async {
    try {
      onProgress?.call('events', 0.1, 'Fetching events from Firestore...');
      
      // Fetch all events from Firestore
      final snapshot = await _firestore.collection('events').get();
      
      onProgress?.call('events', 0.3, 'Processing ${snapshot.docs.length} events...');
      
      // Convert to Event models
      final events = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return Event.fromMap(data, doc.id);
            } catch (e) {
            if (kDebugMode) debugPrint('Error parsing event ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Event>()
          .toList();

      onProgress?.call('events', 0.5, 'Saving ${events.length} events locally...');
      
      // Save to offline storage
      await OfflineDataService.saveEvents(events);

      // Download images if requested
      if (downloadImages) {
        onProgress?.call('events', 0.6, 'Downloading event images...');
        await _downloadEventImages(events);
      }

      onProgress?.call('events', 1.0, 'Events synced successfully');
      onComplete?.call('events', '${events.length} events synced');
      
      return SyncResult(
        success: true,
        count: events.length,
        message: '${events.length} events synced successfully',
      );
    } catch (e) {
      final errorMsg = 'Error syncing events: $e';
      onError?.call('events', errorMsg);
      return SyncResult(
        success: false,
        count: 0,
        message: errorMsg,
      );
    }
  }

  /// Sync trips for a specific user from Firestore
  static Future<SyncResult> syncUserTrips(String userId) async {
    try {
      onProgress?.call('trips', 0.1, 'Fetching trips from Firestore...');
      
      // Fetch user trips from Firestore
      final snapshot = await _firestore
          .collection('trip_planning')
          .where('user_id', isEqualTo: userId)
          .get();
      
      onProgress?.call('trips', 0.5, 'Processing ${snapshot.docs.length} trips...');
      
      // Convert to Trip models
      final trips = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              // Ensure trip_plan_id matches document ID
              final tripData = Map<String, dynamic>.from(data);
              tripData['trip_plan_id'] = tripData['trip_plan_id'] ?? doc.id;
              return trip_model.Trip.fromMap(tripData);
            } catch (e) {
            if (kDebugMode) debugPrint('Error parsing trip ${doc.id}: $e');
              return null;
            }
          })
          .whereType<trip_model.Trip>()
          .toList();

      onProgress?.call('trips', 0.8, 'Saving ${trips.length} trips locally...');
      
      // Save to offline storage
      await OfflineDataService.saveUserTrips(userId, trips);

      onProgress?.call('trips', 1.0, 'Trips synced successfully');
      onComplete?.call('trips', '${trips.length} trips synced');
      
      return SyncResult(
        success: true,
        count: trips.length,
        message: '${trips.length} trips synced successfully',
      );
    } catch (e) {
      final errorMsg = 'Error syncing trips: $e';
      onError?.call('trips', errorMsg);
      return SyncResult(
        success: false,
        count: 0,
        message: errorMsg,
      );
    }
  }

  /// Download images for hotspots
  static Future<void> _downloadHotspotImages(List<Hotspot> hotspots) async {
    final List<String> imageUrls = [];
    
    // Collect all image URLs
    for (var hotspot in hotspots) {
      if (hotspot.images.isNotEmpty) {
        imageUrls.addAll(hotspot.images);
      } else if (hotspot.imageUrl != null && hotspot.imageUrl!.isNotEmpty) {
        imageUrls.add(hotspot.imageUrl!);
      }
    }

    // Download images with progress tracking
    int downloaded = 0;
    for (var url in imageUrls) {
      try {
        await ImageCacheService.getImage(url);
        downloaded++;
        
        if (onProgress != null && imageUrls.isNotEmpty) {
          final progress = 0.6 + (downloaded / imageUrls.length) * 0.4;
          onProgress?.call('hotspots', progress, 'Downloaded $downloaded/${imageUrls.length} images...');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error downloading image $url: $e');
      }
    }
  }

  /// Download images for events
  static Future<void> _downloadEventImages(List<Event> events) async {
    final List<String> imageUrls = events
        .where((e) => e.thumbnailUrl != null && e.thumbnailUrl!.isNotEmpty)
        .map((e) => e.thumbnailUrl!)
        .toList();

    // Download images with progress tracking
    int downloaded = 0;
    for (var url in imageUrls) {
      try {
        await ImageCacheService.getImage(url);
        downloaded++;
        
        if (onProgress != null && imageUrls.isNotEmpty) {
          final progress = 0.6 + (downloaded / imageUrls.length) * 0.4;
          onProgress?.call('events', progress, 'Downloaded $downloaded/${imageUrls.length} images...');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error downloading image $url: $e');
      }
    }
  }

  /// Check if sync is needed based on last sync time
  static bool shouldSync({
    Duration maxAge = const Duration(hours: 24),
    String? userId,
  }) {
    bool needsSync = false;
    
    if (OfflineDataService.needsSync('hotspots', maxAge: maxAge)) {
      needsSync = true;
    }
    
    if (OfflineDataService.needsSync('events', maxAge: maxAge)) {
      needsSync = true;
    }
    
    if (userId != null) {
      final tripsLastSync = OfflineDataService.getTripsLastSync(userId);
      if (tripsLastSync == null || 
          DateTime.now().difference(tripsLastSync) > maxAge) {
        needsSync = true;
      }
    }
    
    return needsSync;
  }

  /// Get sync status information
  static Map<String, dynamic> getSyncStatus({String? userId}) {
    return {
      'hotspots_last_sync': OfflineDataService.getHotspotsLastSync()?.toIso8601String(),
      'events_last_sync': OfflineDataService.getEventsLastSync()?.toIso8601String(),
      'trips_last_sync': userId != null 
          ? OfflineDataService.getTripsLastSync(userId)?.toIso8601String()
          : null,
      'hotspots_count': OfflineDataService.getMetadata('hotspots_count'),
      'events_count': OfflineDataService.getMetadata('events_count'),
      'trips_count': userId != null 
          ? OfflineDataService.getMetadata('trips_count_$userId')
          : null,
    };
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int count;
  final String message;

  SyncResult({
    required this.success,
    required this.count,
    required this.message,
  });

  @override
  String toString() => message;
}

