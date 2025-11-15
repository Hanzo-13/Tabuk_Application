// ===========================================
// lib/services/trip_statistics_service.dart
// ===========================================
// Service for collecting and analyzing trip statistics for developers/creators

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/trip_model.dart';

/// Service for collecting trip statistics and analytics
class TripStatisticsService {
  static const String _statisticsCollection = 'trip_statistics';
  static const String _aggregatedStatsDoc = 'aggregated_statistics';

  /// Save trip statistics when a trip is completed/archived
  static Future<void> saveTripStatistics(Trip trip) async {
    try {
      if (trip.status.toLowerCase() != 'archived' && 
          trip.status.toLowerCase() != 'completed') {
        return; // Only save stats for completed trips
      }

      final duration = trip.endDate.difference(trip.startDate).inDays + 1;
      final progress = trip.spots.isEmpty 
          ? 0.0 
          : trip.visitedSpots.length / trip.spots.length;

      final statsData = {
        'trip_id': trip.tripPlanId,
        'user_id': trip.userId,
        'title': trip.title,
        'start_date': trip.startDate.toIso8601String(),
        'end_date': trip.endDate.toIso8601String(),
        'duration_days': duration,
        'total_spots': trip.spots.length,
        'visited_spots': trip.visitedSpots.length,
        'progress_percentage': (progress * 100).round(),
        'transportation': trip.transportation,
        'destinations': trip.spots,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Save individual trip statistics
      await FirebaseFirestore.instance
          .collection(_statisticsCollection)
          .doc(trip.tripPlanId)
          .set(statsData);

      // Update aggregated statistics
      await _updateAggregatedStatistics(statsData);

      if (kDebugMode) {
        debugPrint('Trip statistics saved for: ${trip.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving trip statistics: $e');
      }
    }
  }

  /// Update aggregated statistics in Firestore
  static Future<void> _updateAggregatedStatistics(
      Map<String, dynamic> statsData) async {
    try {
      final statsRef = FirebaseFirestore.instance
          .collection(_statisticsCollection)
          .doc(_aggregatedStatsDoc);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(statsRef);

        if (!snapshot.exists) {
          // Initialize aggregated stats
          transaction.set(statsRef, {
            'total_trips': 1,
            'total_duration_days': statsData['duration_days'],
            'average_duration_days': statsData['duration_days'].toDouble(),
            'total_spots_visited': statsData['visited_spots'],
            'total_spots_planned': statsData['total_spots'],
            'transportation_usage': {
              statsData['transportation']: 1,
            },
            'popular_destinations': {},
            'average_progress': statsData['progress_percentage'].toDouble(),
            'last_updated': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data()!;
          final totalTrips = (data['total_trips'] ?? 0) + 1;
          final totalDuration = (data['total_duration_days'] ?? 0) +
              statsData['duration_days'];
          final avgDuration = totalDuration / totalTrips;
          final totalSpotsVisited =
              (data['total_spots_visited'] ?? 0) + statsData['visited_spots'];
          final totalSpotsPlanned =
              (data['total_spots_planned'] ?? 0) + statsData['total_spots'];
          final currentProgress = data['average_progress'] ?? 0.0;
          final newProgress = ((currentProgress * (totalTrips - 1)) +
                  statsData['progress_percentage']) /
              totalTrips;

          // Update transportation usage
          final transportUsage =
              Map<String, int>.from(data['transportation_usage'] ?? {});
          final transport = statsData['transportation'] as String;
          transportUsage[transport] = (transportUsage[transport] ?? 0) + 1;

          // Update popular destinations
          final popularDests =
              Map<String, int>.from(data['popular_destinations'] ?? {});
          final destinations = List<String>.from(statsData['destinations'] ?? []);
          for (final dest in destinations) {
            popularDests[dest] = (popularDests[dest] ?? 0) + 1;
          }

          transaction.update(statsRef, {
            'total_trips': totalTrips,
            'total_duration_days': totalDuration,
            'average_duration_days': avgDuration,
            'total_spots_visited': totalSpotsVisited,
            'total_spots_planned': totalSpotsPlanned,
            'transportation_usage': transportUsage,
            'popular_destinations': popularDests,
            'average_progress': newProgress,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating aggregated statistics: $e');
      }
    }
  }

  /// Get aggregated statistics (for developers/creators)
  static Future<Map<String, dynamic>?> getAggregatedStatistics() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_statisticsCollection)
          .doc(_aggregatedStatsDoc)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting aggregated statistics: $e');
      }
      return null;
    }
  }

  /// Get most popular destinations
  static Future<List<MapEntry<String, int>>> getPopularDestinations(
      {int limit = 10}) async {
    try {
      final stats = await getAggregatedStatistics();
      if (stats == null) return [];

      final popularDests =
          Map<String, int>.from(stats['popular_destinations'] ?? {});
      final sorted = popularDests.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting popular destinations: $e');
      }
      return [];
    }
  }

  /// Get transportation usage statistics
  static Future<Map<String, int>> getTransportationUsage() async {
    try {
      final stats = await getAggregatedStatistics();
      if (stats == null) return {};

      return Map<String, int>.from(stats['transportation_usage'] ?? {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting transportation usage: $e');
      }
      return {};
    }
  }
}

