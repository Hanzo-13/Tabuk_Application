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

  /// Status of the trip (e.g., Planning, Archived, Completed).
  final String status;

  /// User ID of the trip owner.
  final String userId;

  /// List of indices of visited spots.
  final List<int> visitedSpots;

  /// Timestamp when trip was created.
  DateTime? createdAt;

  /// Timestamp when trip was last updated.
  DateTime? updatedAt;

  /// Timestamp when trip was completed/archived.
  DateTime? completedAt;

  /// Whether the itinerary was automatically saved.
  bool autoSaved;

  /// Progress percentage (0.0 to 1.0).
  double get progress {
    if (spots.isEmpty) return 0.0;
    return visitedSpots.length / spots.length;
  }

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
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.autoSaved = false,
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
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'auto_saved': autoSaved,
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
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at'])
        : null,
    updatedAt: map['updated_at'] != null
        ? DateTime.parse(map['updated_at'])
        : null,
    completedAt: map['completed_at'] != null
        ? DateTime.parse(map['completed_at'])
        : null,
    autoSaved: map['auto_saved'] ?? false,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? autoSaved,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      autoSaved: autoSaved ?? this.autoSaved,
    );
  }

  // Add id getter for compatibility
  String get id => tripPlanId;
}
