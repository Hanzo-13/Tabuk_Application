// ===========================================
// lib/models/place.dart
// ===========================================
// Model class for a place to visit during a trip.

import 'package:flutter/material.dart';

/// Represents a place visit with a name, date, time, and commute method.
class PlaceVisit {
  /// Name of the place visited.
  final String place;
  /// Date of the visit.
  final DateTime date;
  /// Time of the visit (optional).
  final TimeOfDay? visitTime;
  /// Commute method to reach this place (optional).
  final String? commuteMethod;

  /// Creates a [PlaceVisit] instance.
  const PlaceVisit({
    required this.place,
    required this.date,
    this.visitTime,
    this.commuteMethod = 'Walk',
  });

  /// Creates a copy of this PlaceVisit with optional parameters replaced
  PlaceVisit copyWith({
    String? place,
    DateTime? date,
    TimeOfDay? visitTime,
    String? commuteMethod,
  }) {
    return PlaceVisit(
      place: place ?? this.place,
      date: date ?? this.date,
      visitTime: visitTime ?? this.visitTime,
      commuteMethod: commuteMethod ?? this.commuteMethod,
    );
  }

  /// Converts PlaceVisit to a Map for storage
  Map<String, dynamic> toMap() {
    return {
      'place': place,
      'date': date.toIso8601String(),
      'visitTime': visitTime != null ? '${visitTime!.hour}:${visitTime!.minute}' : null,
      'commuteMethod': commuteMethod,
    };
  }

  /// Creates a PlaceVisit from a Map
  factory PlaceVisit.fromMap(Map<String, dynamic> map) {
    TimeOfDay? timeOfDay;
    if (map['visitTime'] != null) {
      final parts = (map['visitTime'] as String).split(':');
      timeOfDay = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    return PlaceVisit(
      place: map['place'] as String,
      date: DateTime.parse(map['date'] as String),
      visitTime: timeOfDay,
      commuteMethod: map['commuteMethod'] as String? ?? 'Walk',
    );
  }
}
