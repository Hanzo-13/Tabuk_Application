// ===========================================
// lib/models/favorite_model.dart
// ===========================================
// Model for user favorites/hotspots.

import 'destination_model.dart';

/// Represents a user's favorite hotspot.
class Favorite {
  /// Unique identifier for the favorite entry.
  final String favoriteId;

  /// User ID who added this favorite.
  final String userId;

  /// Hotspot ID that was favorited.
  final String hotspotId;

  /// Date when the hotspot was added to favorites.
  final DateTime addedAt;

  /// The hotspot data (for easy access without additional queries).
  final Hotspot? hotspot;

  /// Creates a [Favorite] instance.
  const Favorite({
    required this.favoriteId,
    required this.userId,
    required this.hotspotId,
    required this.addedAt,
    this.hotspot,
  });

  /// Factory constructor for creating [Favorite] from Firestore Map.
  factory Favorite.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime resolveAddedAt(dynamic raw, dynamic rawIso) {
      try {
        // Firestore Timestamp
        if (raw != null) {
          final value = raw;
          // Supports both cloud_firestore Timestamp and DateTime
          if (value is DateTime) return value;
          final tsTypeName = value.runtimeType.toString();
          if (tsTypeName == 'Timestamp' && value.toDate != null) {
            // ignore: invalid_runtime_check_with_toString
            return value.toDate();
          }
          // Try parsing if string slipped in
          if (value is String) {
            final parsed = DateTime.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
        // Fallback ISO string we store alongside
        if (rawIso is String) {
          final parsed = DateTime.tryParse(rawIso);
          if (parsed != null) return parsed;
        }
      } catch (_) {}
      return DateTime.now();
    }

    final addedAt = resolveAddedAt(map['added_at'], map['added_at_iso']);

    return Favorite(
      favoriteId: documentId,
      userId: map['user_id']?.toString() ?? '',
      hotspotId: map['hotspot_id']?.toString() ?? '',
      addedAt: addedAt,
      hotspot: map['hotspot'] != null
          ? Hotspot.fromMap(
              Map<String, dynamic>.from(map['hotspot']),
              map['hotspot_id']?.toString() ?? '',
            )
          : null,
    );
  }

  /// Converts the [Favorite] to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'hotspot_id': hotspotId,
      'added_at': addedAt.toIso8601String(),
      'hotspot': hotspot?.toJson(),
    };
  }

  /// Creates a copy of this Favorite with updated fields.
  Favorite copyWith({
    String? favoriteId,
    String? userId,
    String? hotspotId,
    DateTime? addedAt,
    Hotspot? hotspot,
  }) {
    return Favorite(
      favoriteId: favoriteId ?? this.favoriteId,
      userId: userId ?? this.userId,
      hotspotId: hotspotId ?? this.hotspotId,
      addedAt: addedAt ?? this.addedAt,
      hotspot: hotspot ?? this.hotspot,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Favorite && other.favoriteId == favoriteId;
  }

  @override
  int get hashCode => favoriteId.hashCode;

  @override
  String toString() {
    return 'Favorite{favoriteId: $favoriteId, userId: $userId, hotspotId: $hotspotId, addedAt: $addedAt}';
  }
}
