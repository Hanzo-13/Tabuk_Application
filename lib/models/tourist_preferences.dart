// ===========================================
// lib/models/tourist_preferences_model.dart
// ===========================================
// Model for tourist Preferences and preferences.

/// Represents a tourist's Preferences and travel preferences.
class TouristPreferences {
  /// Unique user ID.
  final String uid;
  /// Username of the tourist.
  final String name;
  /// Profile image URL (matches Firestore field name).
  final String profileImageUrl;
  /// Event recommendation preference.
  final String eventRecommendation;
  /// Preference for lesser-known destinations.
  final String lesserKnown;
  /// Preferred travel timing.
  final String travelTiming;
  /// Preferred travel companion.
  final String companion;
  /// Preferred vibe (e.g., adventure, relaxation).
  final String vibe;
  /// List of preferred destination types.
  final List<String> destinationTypes;
  /// Date and time when the Preferences was created.
  final DateTime? createdAt;

  /// Creates a [TouristPreferences] instance.
  const TouristPreferences({
    required this.uid,
    required this.name,
    required this.profileImageUrl,
    required this.eventRecommendation,
    required this.lesserKnown,
    required this.travelTiming,
    required this.companion,
    required this.vibe,
    required this.destinationTypes,
    this.createdAt,
  });

  /// Creates a [TouristPreferences] from a map (e.g., from Firestore).
  factory TouristPreferences.fromMap(Map<String, dynamic> map, String id) {
    return TouristPreferences(
      uid: id,
      name: map['name'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      eventRecommendation: map['eventRecommendation'] ?? '',
      lesserKnown: map['lesserKnown'] ?? '',
      travelTiming: map['travelTiming'] ?? '',
      companion: map['companion'] ?? '',
      vibe: map['vibe'] ?? '',
      destinationTypes: List<String>.from(map['destinationTypes'] ?? []),
      createdAt: map['createdAt']?.toDate(),
    );
  }

  /// Converts the [TouristPreferences] to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'eventRecommendation': eventRecommendation,
      'lesserKnown': lesserKnown,
      'travelTiming': travelTiming,
      'companion': companion,
      'vibe': vibe,
      'destinationTypes': destinationTypes,
      'createdAt': createdAt,
    };
  }
}
