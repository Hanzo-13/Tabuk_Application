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

  final List<int> visitedSpots;

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
    this.visitedSpots = const [],
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
    'visited_spots': visitedSpots,
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
    visitedSpots: List<int>.from(map['visited_spots'] ?? []),
  );

    // Copy with method for easy updates
  Trip copyWith({
    String? tripPlanId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? transportation,
    List<String>? spots,
    String? userId,
    String? status,
    List<int>? visitedSpots,
  }) {
    return Trip(
      tripPlanId: tripPlanId ?? this.tripPlanId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      transportation: transportation ?? this.transportation,
      spots: spots ?? this.spots,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      visitedSpots: visitedSpots ?? this.visitedSpots,
    );
  }

  // Add id getter for compatibility
  String get id => tripPlanId;
}
