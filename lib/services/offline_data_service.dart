import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../models/destination_model.dart';
import '../models/trip_model.dart' as trip_model;

/// Enhanced offline data service using Hive for persistent local storage
/// Supports hotspots, events, trips, and their associated images
class OfflineDataService {
  static const String _hotspotsBoxName = 'offline_hotspots';
  static const String _eventsBoxName = 'offline_events';
  static const String _tripsBoxName = 'offline_trips';
  static const String _metadataBoxName = 'offline_metadata';
  
  static Box? _hotspotsBox;
  static Box? _eventsBox;
  static Box? _tripsBox;
  static Box? _metadataBox;
  
  static bool _initialized = false;

  /// Initialize all Hive boxes for offline storage
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _hotspotsBox = await Hive.openBox(_hotspotsBoxName);
      _eventsBox = await Hive.openBox(_eventsBoxName);
      _tripsBox = await Hive.openBox(_tripsBoxName);
      _metadataBox = await Hive.openBox(_metadataBoxName);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing offline data service: $e');
      rethrow;
    }
  }

  /// Check if boxes are initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('OfflineDataService not initialized. Call initialize() first.');
    }
  }

  // ==================== HOTSPOTS ====================

  /// Save hotspots to offline storage
  static Future<void> saveHotspots(List<Hotspot> hotspots) async {
    _ensureInitialized();
    try {
      final List<Map<String, dynamic>> data = hotspots.map((h) {
        final json = h.toJson();
        json['hotspot_id'] = h.hotspotId;
        json['id'] = h.hotspotId;
        return json;
      }).toList();
      
      await _hotspotsBox!.put('all_hotspots', data);
      await _updateMetadata('hotspots_last_sync', DateTime.now().toIso8601String());
      await _updateMetadata('hotspots_count', hotspots.length);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving hotspots offline: $e');
      rethrow;
    }
  }

  /// Load hotspots from offline storage
  static Future<List<Hotspot>> loadHotspots() async {
    _ensureInitialized();
    try {
      final data = _hotspotsBox!.get('all_hotspots');
      if (data == null) return [];
      
      final List<dynamic> list = data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Hotspot.fromMap(m, m['hotspot_id']?.toString() ?? m['id']?.toString() ?? ''))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading hotspots offline: $e');
      return [];
    }
  }

  /// Get a single hotspot by ID from offline storage
  static Future<Hotspot?> getHotspotById(String hotspotId) async {
    final hotspots = await loadHotspots();
    try {
      return hotspots.firstWhere((h) => h.hotspotId == hotspotId);
    } catch (_) {
      return null;
    }
  }

  // ==================== EVENTS ====================

  /// Save events to offline storage
  static Future<void> saveEvents(List<Event> events) async {
    _ensureInitialized();
    try {
      final List<Map<String, dynamic>> data = events.map((e) {
        final map = e.toMap();
        map['eventId'] = e.eventId;
        map['id'] = e.eventId;
        // Convert Timestamps to ISO strings for storage
        map['startDate'] = e.startDate.toIso8601String();
        map['endDate'] = e.endDate.toIso8601String();
        map['created_at'] = e.createdAt.toIso8601String();
        return map;
      }).toList();
      
      await _eventsBox!.put('all_events', data);
      await _updateMetadata('events_last_sync', DateTime.now().toIso8601String());
      await _updateMetadata('events_count', events.length);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving events offline: $e');
      rethrow;
    }
  }

  /// Load events from offline storage
  static Future<List<Event>> loadEvents() async {
    _ensureInitialized();
    try {
      final data = _eventsBox!.get('all_events');
      if (data == null) return [];
      
      final List<dynamic> list = data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) {
            // Convert ISO strings back to Timestamps for Event.fromMap
            final eventData = Map<String, dynamic>.from(m);
            eventData['startDate'] = Timestamp.fromDate(DateTime.parse(m['startDate']));
            eventData['endDate'] = Timestamp.fromDate(DateTime.parse(m['endDate']));
            eventData['created_at'] = Timestamp.fromDate(DateTime.parse(m['created_at']));
            return Event.fromMap(eventData, m['eventId']?.toString() ?? m['id']?.toString() ?? '');
          })
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading events offline: $e');
      return [];
    }
  }

  /// Get a single event by ID from offline storage
  static Future<Event?> getEventById(String eventId) async {
    final events = await loadEvents();
    try {
      return events.firstWhere((e) => e.eventId == eventId);
    } catch (_) {
      return null;
    }
  }

  // ==================== TRIPS ====================

  /// Save trips to offline storage for a specific user
  static Future<void> saveUserTrips(String userId, List<trip_model.Trip> trips) async {
    _ensureInitialized();
    try {
      final List<Map<String, dynamic>> data = trips.map((t) => t.toMap()).toList();
      await _tripsBox!.put('user_trips_$userId', data);
      await _updateMetadata('trips_last_sync_$userId', DateTime.now().toIso8601String());
      await _updateMetadata('trips_count_$userId', trips.length);
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving trips offline: $e');
      rethrow;
    }
  }

  /// Load trips from offline storage for a specific user
  static Future<List<trip_model.Trip>> loadUserTrips(String userId) async {
    _ensureInitialized();
    try {
      final data = _tripsBox!.get('user_trips_$userId');
      if (data == null) return [];
      
      final List<dynamic> list = data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => trip_model.Trip.fromMap(m))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading trips offline: $e');
      return [];
    }
  }

  // ==================== METADATA ====================

  /// Update metadata
  static Future<void> _updateMetadata(String key, dynamic value) async {
    _ensureInitialized();
    await _metadataBox!.put(key, value);
  }

  /// Get metadata
  static dynamic getMetadata(String key) {
    _ensureInitialized();
    return _metadataBox!.get(key);
  }

  /// Get last sync time for hotspots
  static DateTime? getHotspotsLastSync() {
    final syncTime = getMetadata('hotspots_last_sync');
    if (syncTime == null) return null;
    try {
      return DateTime.parse(syncTime);
    } catch (_) {
      return null;
    }
  }

  /// Get last sync time for events
  static DateTime? getEventsLastSync() {
    final syncTime = getMetadata('events_last_sync');
    if (syncTime == null) return null;
    try {
      return DateTime.parse(syncTime);
    } catch (_) {
      return null;
    }
  }

  /// Get last sync time for trips
  static DateTime? getTripsLastSync(String userId) {
    final syncTime = getMetadata('trips_last_sync_$userId');
    if (syncTime == null) return null;
    try {
      return DateTime.parse(syncTime);
    } catch (_) {
      return null;
    }
  }

  /// Check if data needs to be synced (older than maxAge)
  static bool needsSync(String dataType, {Duration maxAge = const Duration(hours: 24)}) {
    DateTime? lastSync;
    if (dataType == 'hotspots') {
      lastSync = getHotspotsLastSync();
    } else if (dataType == 'events') {
      lastSync = getEventsLastSync();
    }
    
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Clear all offline data
  static Future<void> clearAll() async {
    _ensureInitialized();
    try {
      await _hotspotsBox!.clear();
      await _eventsBox!.clear();
      await _tripsBox!.clear();
      await _metadataBox!.clear();
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing offline data: $e');
    }
  }

  /// Clear specific user's trips
  static Future<void> clearUserTrips(String userId) async {
    _ensureInitialized();
    try {
      await _tripsBox!.delete('user_trips_$userId');
      await _metadataBox!.delete('trips_last_sync_$userId');
      await _metadataBox!.delete('trips_count_$userId');
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing user trips: $e');
    }
  }

  /// Get storage size information (approximate)
  static Map<String, int> getStorageInfo() {
    _ensureInitialized();
    return {
      'hotspots': _hotspotsBox!.length,
      'events': _eventsBox!.length,
      'trips': _tripsBox!.length,
      'metadata': _metadataBox!.length,
    };
  }
}

