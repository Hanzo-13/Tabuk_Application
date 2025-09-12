import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String businessId;
  final String? businessName;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating;
  final String comment;
  final DateTime datePosted;
  final bool isVerified;

  Review({
    required this.id,
    required this.businessId,
    this.businessName,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    required this.comment,
    required this.datePosted,
    this.isVerified = false,
  });

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      businessId: map['business_id'] ?? '',
      businessName: map['business_name'],
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Anonymous',
      userPhotoUrl: map['user_photo_url'],
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      datePosted:
          (map['date_posted'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: map['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      if (businessName != null) 'business_name': businessName,
      'user_id': userId,
      'user_name': userName,
      'user_photo_url': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'date_posted': Timestamp.fromDate(datePosted),
      'is_verified': isVerified,
    };
  }

  Review copyWith({
    String? id,
    String? businessId,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    double? rating,
    String? comment,
    DateTime? datePosted,
    bool? isVerified,
  }) {
    return Review(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      datePosted: datePosted ?? this.datePosted,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
