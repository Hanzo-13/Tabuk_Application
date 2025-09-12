import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_app/models/event_model.dart';

class OfflineCacheService {
  static const String _eventsKey = 'cached_events_v1';
  static const String _destinationsKey = 'cached_destinations_v1';

  static Future<void> saveEvents(List<Event> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> data = events.map((e) {
        return {
          'title': e.title,
          'location': e.location,
          'municipality': e.municipality,
          'startDate': e.startDate.toIso8601String(),
          'endDate': e.endDate.toIso8601String(),
          'role': e.role,
          'thumbnailUrl': e.thumbnailUrl,
          'eventId': e.eventId,
          'description': e.description,
          'createdBy': e.createdBy,
          'createdAt': e.createdAt.toIso8601String(),
          'creatorName': e.creatorName,
          'creatorContact': e.creatorContact,
          'creatorEmail': e.creatorEmail,
        };
      }).toList();
      await prefs.setString(_eventsKey, jsonEncode(data));
    } catch (_) {}
  }

  static Future<List<Event>> loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_eventsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Event(
                eventId: m['eventId']?.toString() ?? '',
                title: m['title']?.toString() ?? '',
                description: m['description']?.toString() ?? '',
                startDate: DateTime.tryParse(m['startDate']?.toString() ?? '') ?? DateTime.now(),
                endDate: DateTime.tryParse(m['endDate']?.toString() ?? '') ?? DateTime.now(),
                location: m['location']?.toString() ?? '',
                municipality: m['municipality']?.toString() ?? '',
                createdBy: m['createdBy']?.toString() ?? '',
                thumbnailUrl: (m['thumbnailUrl']?.toString().isNotEmpty ?? false)
                    ? m['thumbnailUrl']?.toString()
                    : null,
                createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
                role: m['role']?.toString() ?? '',
                creatorName: m['creatorName']?.toString() ?? '',
                creatorContact: m['creatorContact']?.toString() ?? '',
                creatorEmail: m['creatorEmail']?.toString() ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.remove(_destinationsKey);
  }

  // -------- Destinations (Hotspots) --------
  static Future<void> saveDestinations(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_destinationsKey, jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadDestinations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_destinationsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}


