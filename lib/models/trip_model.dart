// ===========================================
// lib/models/trip_model.dart
// ===========================================
// Model for trip planning, including serialization for Firestore.

/// Trip model for Firestore.
class Trip {
  /// Unique identifier for the trip plan.
  final String tripPlanId;
  /// Title of the trip.
  String title;
  /// Start date of the trip.
  DateTime startDate;
  /// End date of the trip.
  DateTime endDate;
  /// Transportation method for the trip.
  String transportation;
  /// List of spots/places included in the trip.
  List<String> spots;
  /// Status of the trip (e.g., Planning, Completed).
  final String status;
  /// User ID of the trip owner.
  final String userId;

  /// Creates a [Trip] instance.
  Trip({
    required this.tripPlanId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.transportation,
    required this.spots,
    required this.userId,
    this.status = 'Planning',
  });

  /// Converts [Trip] to a map for Firestore.
  Map<String, dynamic> toMap() => {
    'trip_plan_id': tripPlanId,
    'title': title,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'transportation': transportation,
    'spots': spots,
    'user_id': userId,
    'status': status,
  };

  /// Creates a [Trip] from a Firestore map.
  factory Trip.fromMap(Map<String, dynamic> map) => Trip(
    tripPlanId: map['trip_plan_id'] ?? '',
    title: map['title'] ?? '',
    startDate: DateTime.parse(map['start_date']),
    endDate: DateTime.parse(map['end_date']),
    transportation: map['transportation'] ?? '',
    spots: List<String>.from(map['spots'] ?? []),
    userId: map['user_id'] ?? '',
    status: map['status'] ?? 'Planning',
  );

  // Add id getter for compatibility
  String get id => tripPlanId;
}
