// ===========================================
// lib/services/trip_service.dart
// ===========================================
// Handles CRUD operations for trip planning in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';
import '../utils/constants.dart';
import 'trip_statistics_service.dart';

/// Service for saving, retrieving, and deleting trips in Firestore.
class TripService {
  /// Saves a trip to Firestore.
  static Future<void> saveTrip(Trip trip, {bool autoSave = false}) async {
    try {
      final now = DateTime.now();
      final tripToSave = trip.copyWith(
        updatedAt: now,
        createdAt: trip.createdAt ?? now,
        completedAt: trip.status.toLowerCase() == 'archived' ||
                trip.status.toLowerCase() == 'completed'
            ? (trip.completedAt ?? now)
            : trip.completedAt,
        autoSaved: autoSave || trip.autoSaved,
      );

      final tripMap = tripToSave.toMap();
      // Add server timestamps if not present
      if (tripMap['created_at'] == null) {
        tripMap['created_at'] = FieldValue.serverTimestamp();
      }
      if (tripMap['updated_at'] == null) {
        tripMap['updated_at'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection(AppConstants.tripPlanningCollection)
          .doc(trip.tripPlanId)
          .set(tripMap, SetOptions(merge: true));

      // Save statistics if trip is archived/completed
      if (tripToSave.status.toLowerCase() == 'archived' ||
          tripToSave.status.toLowerCase() == 'completed') {
        await TripStatisticsService.saveTripStatistics(tripToSave);
      }
    } catch (e) {
      throw Exception('${AppConstants.errorSavingTrip}: $e');
    }
  }

  /// Retrieves all trips for a given user.
  static Future<List<Trip>> getTrips(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.tripPlanningCollection)
          .where('user_id', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => Trip.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('${AppConstants.errorLoadingTrips}: $e');
    }
  }

  /// Deletes a trip by its ID.
  static Future<void> deleteTrip(String tripPlanId) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.tripPlanningCollection)
          .doc(tripPlanId)
          .delete();
    } catch (e) {
      throw Exception('${AppConstants.errorDeletingTrip}: $e');
    }
  }
}
