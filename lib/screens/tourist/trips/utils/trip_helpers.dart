// ===========================================
// lib/screens/tourist/trips/utils/trip_helpers.dart
// ===========================================
// Helper functions for trip-related operations

import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';
import '../../../../models/trip_model.dart' as firestoretrip;

/// Gets transportation icon based on transportation type
IconData getTransportationIcon(String transportation) {
  switch (transportation.toLowerCase()) {
    case 'motorcycle':
      return Icons.two_wheeler;
    case 'walk':
      return Icons.directions_walk;
    case 'car':
      return Icons.directions_car;
    case 'plane':
      return Icons.flight;
    case 'bus':
      return Icons.directions_bus;
    case 'boat':
      return Icons.directions_boat;
    case 'train':
      return Icons.train;
    default:
      return Icons.explore;
  }
}

/// Gets status color based on trip status
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'planning':
      return AppColors.primaryOrange;
    case 'active':
      return AppColors.homeNearbyColor;
    case 'archived':
      return AppColors.textLight;
    case 'completed':
      return AppColors.primaryTeal;
    default:
      return AppColors.textLight;
  }
}

/// Gets urgency color based on days until trip
Color getUrgencyColor(int daysUntil) {
  if (daysUntil == 0) return AppColors.errorRed;
  if (daysUntil <= 3) return AppColors.primaryOrange;
  if (daysUntil <= 7) return AppColors.homeTrendingColor;
  return AppColors.homeForYouColor;
}

/// Calculates days until trip start
int getDaysUntilTrip(DateTime startDate) {
  final now = DateTime.now();
  final difference = startDate.difference(now).inDays;
  return difference;
}

/// Gets trip duration in days
int getTripDuration(DateTime startDate, DateTime endDate) {
  return endDate.difference(startDate).inDays + 1;
}

/// Calculates the progress percentage for a trip
double getTripProgress(firestoretrip.Trip trip) {
  if (trip.spots.isEmpty) return 0.0;
  return trip.visitedSpots.length / trip.spots.length;
}

/// Gets progress color based on completion percentage
Color getProgressColor(double progress) {
  if (progress == 1.0) return AppColors.homeNearbyColor;
  if (progress >= 0.7) return AppColors.primaryTeal;
  if (progress >= 0.4) return AppColors.homeTrendingColor;
  if (progress > 0) return AppColors.primaryOrange;
  return Colors.grey.shade300;
}

