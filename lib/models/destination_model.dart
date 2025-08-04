// ===========================================
// lib/models/destination_model.dart
// ===========================================
// import 'package:hive/hive.dart';

// @HiveType(typeId: 1)
// class Hotspot extends HiveObject{
  // @HiveField(0)
class Hotspot {
  final String hotspotId;
  final String name;
  final String description;
  final String category;
  final String type;
  final String location;
  final String district;
  final String municipality;
  final List<String> images;
  final List<String> transportation;
  final Map<String, double>? entranceFees;
  final Map<String, dynamic> operatingHours;
  final String contactInfo;
  final bool restroom;
  final bool foodAccess;
  final DateTime createdAt;
  final List<String>? safetyTips;
  final String? localGuide;
  final List<String>? suggestions;
  final double? latitude;
  final double? longitude;

  Hotspot({
    required this.hotspotId,
    required this.name,
    required this.description,
    required this.category,
    required this.type,
    required this.location,
    required this.district,
    required this.municipality,
    required this.images,
    required this.transportation,
    required this.operatingHours,
    this.entranceFees,
    required this.contactInfo,
    required this.restroom,
    required this.foodAccess,
    required this.createdAt,
    this.safetyTips,
    this.localGuide,
    this.suggestions,
    this.latitude,
    this.longitude,
  });

  factory Hotspot.fromMap(Map<String, dynamic> map, String id) {
    return Hotspot(
      hotspotId: id,
      name: map['business_name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      type: map['type'] ?? '',
      location: map['address'] ?? '',
      district: map['district'] ?? '',
      municipality: map['municipality'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      transportation: List<String>.from(map['transportation'] ?? []),
      operatingHours: Map<String, dynamic>.from(map['operating_hours'] ?? {}),
      entranceFees: map['entrance_fees'] != null
          ? Map<String, double>.from(
              (map['entrance_fees'] as Map<String, dynamic>).map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              ),
            )
          : null,
      contactInfo: map['business_contact'] ?? '',
      restroom: map['restroom'] ?? false,
      foodAccess: map['food_access'] ?? false,
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : (map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      safetyTips: map['safety_tips'] != null ? List<String>.from(map['safety_tips']) : null,
      localGuide: map['local_guide'],
      suggestions: map['suggestions'] != null ? List<String>.from(map['suggestions']) : null,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'business_name': name,
      'description': description,
      'category': category,
      'type': type,
      'address': location,
      'district': district,
      'municipality': municipality,
      'images': images,
      'transportation': transportation,
      'operating_hours': operatingHours,
      'entrance_fees': entranceFees,
      'business_contact': contactInfo,
      'restroom': restroom,
      'food_access': foodAccess,
      'created_at': createdAt.toIso8601String(),
    };
    if (safetyTips != null) data['safety_tips'] = safetyTips;
    if (localGuide != null) data['local_guide'] = localGuide;
    if (suggestions != null) data['suggestions'] = suggestions;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    return data;
  }

  Hotspot copyWith({
    String? hotspotId,
    String? name,
    String? description,
    String? category,
    String? location,
    String? district,
    String? municipality,
    List<String>? images,
    List<String>? transportation,
    Map<String, dynamic>? operatingHours,
    Map<String, double>? entranceFees,
    String? contactInfo,
    bool? restroom,
    bool? foodAccess,
    List<String>? safetyTips,
    String? localGuide,
    List<String>? suggestions,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) {
    return Hotspot(
      hotspotId: hotspotId ?? this.hotspotId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type,
      location: location ?? this.location,
      district: district ?? this.district,
      municipality: municipality ?? this.municipality,
      images: images ?? this.images,
      transportation: transportation ?? this.transportation,
      operatingHours: operatingHours ?? this.operatingHours,
      entranceFees: entranceFees ?? this.entranceFees,
      contactInfo: contactInfo ?? this.contactInfo,
      restroom: restroom ?? this.restroom,
      foodAccess: foodAccess ?? this.foodAccess,
      safetyTips: safetyTips ?? this.safetyTips,
      localGuide: localGuide ?? this.localGuide,
      suggestions: suggestions ?? this.suggestions,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() {
    return 'Hotspot(hotspotId: $hotspotId, name: $name, location: $location, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other is Hotspot && other.hotspotId == hotspotId);
  }

  @override
  int get hashCode => hotspotId.hashCode;

  bool get isFree =>
      entranceFees == null || entranceFees!.values.every((fee) => fee == 0);

  bool get hasAmenities => restroom || foodAccess;

  String get formattedFeeSummary {
    if (isFree) return 'Free';
    if (entranceFees == null || entranceFees!.isEmpty) return 'No fee info';
    final parts = entranceFees!.entries
        .map((e) => '${e.key}: ₱${e.value.toStringAsFixed(2)}')
        .join(', ');
    return parts;
  }
}
