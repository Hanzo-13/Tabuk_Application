// ===========================================
// lib/models/place.dart
// ===========================================
// Model class for a place to visit during a trip.

/// Represents a place visit with a name and date.
class PlaceVisit {
  /// Name of the place visited.
  final String place;
  /// Date of the visit.
  final DateTime date;

  /// Creates a [PlaceVisit] instance.
  const PlaceVisit({required this.place, required this.date});
}
