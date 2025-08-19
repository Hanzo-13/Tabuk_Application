import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/models/review_model.dart';
import 'package:flutter/foundation.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a new review
  static Future<bool> addReview({
    required String businessId,
    required double rating,
    required String comment,
    String? businessName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get user data
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      final userData = userDoc.data();
      
      final review = Review(
        id: '', // Will be set by Firestore
        businessId: businessId,
        userId: user.uid,
        userName: userData?['name'] ?? 'Anonymous',
        userPhotoUrl: userData?['photo_url'],
        rating: rating,
        comment: comment,
        datePosted: DateTime.now(),
      );

      // Add review to business reviews subcollection
      final docRef = await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .add(review.toMap());

      // Mirror review to top-level collection for easier per-user queries
      final String userReviewId = '${user.uid}_$businessId';
      await _firestore.collection('review_modal').doc(userReviewId).set({
        ...review.toMap(),
        'business_id': businessId,
        'business_name': businessName ?? '',
        'review_id': docRef.id,
      });

      // Also mirror to a canonical top-level 'reviews' collection
      await _firestore.collection('reviews').doc(userReviewId).set({
        ...review.toMap(),
        'business_id': businessId,
        'business_name': businessName ?? '',
        'review_id': docRef.id,
      });

      // Update business average rating and review count
      await _updateBusinessRating(businessId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding review: $e');
      }
      return false;
    }
  }

  // Fetch reviews for a business
  static Future<List<Review>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .orderBy('date_posted', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching reviews: $e');
      }
      return [];
    }
  }

  // Check if user has already reviewed this business
  static Future<bool> hasUserReviewed(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user review: $e');
      }
      return false;
    }
  }

  // Get user's existing review for a business
  static Future<Review?> getUserReview(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .where('user_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Review.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user review: $e');
      }
      return null;
    }
  }

  // Update existing review
  static Future<bool> updateReview({
    required String businessId,
    required String reviewId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .doc(reviewId)
          .update({
        'rating': rating,
        'comment': comment,
        'date_posted': Timestamp.fromDate(DateTime.now()),
      });

      // Update business average rating
      await _updateBusinessRating(businessId);

      // Also update mirrored user review document if present
      final user = _auth.currentUser;
      if (user != null) {
        final String userReviewId = '${user.uid}_$businessId';
        await _firestore.collection('review_modal').doc(userReviewId).update({
          'rating': rating,
          'comment': comment,
          'date_posted': Timestamp.fromDate(DateTime.now()),
        }).catchError((_) {});

        // Update top-level 'reviews' as well
        await _firestore.collection('reviews').doc(userReviewId).update({
          'rating': rating,
          'comment': comment,
          'date_posted': Timestamp.fromDate(DateTime.now()),
        }).catchError((_) {});
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating review: $e');
      }
      return false;
    }
  }

  // Delete review
  static Future<bool> deleteReview({
    required String businessId,
    required String reviewId,
  }) async {
    try {
      await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      // Update business average rating
      await _updateBusinessRating(businessId);

      // Delete mirrored user review doc
      final user = _auth.currentUser;
      if (user != null) {
        final String userReviewId = '${user.uid}_$businessId';
        await _firestore.collection('review_modal').doc(userReviewId).delete().catchError((_) {});
        await _firestore.collection('reviews').doc(userReviewId).delete().catchError((_) {});
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting review: $e');
      }
      return false;
    }
  }

  // Update business average rating and review count
  static Future<void> _updateBusinessRating(String businessId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('destination')
          .doc(businessId)
          .collection('reviews')
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        // No reviews, reset to default values
        await _firestore.collection('destination').doc(businessId).update({
          'average_rating': 0.0,
          'review_count': 0,
        });
        return;
      }

      double totalRating = 0;
      for (final doc in reviewsSnapshot.docs) {
        totalRating += (doc.data()['rating'] ?? 0).toDouble();
      }

      final averageRating = totalRating / reviewsSnapshot.docs.length;
      final reviewCount = reviewsSnapshot.docs.length;

      await _firestore.collection('destination').doc(businessId).update({
        'average_rating': averageRating,
        'review_count': reviewCount,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating business rating: $e');
      }
    }
  }

  // Get business rating summary
  static Future<Map<String, dynamic>> getBusinessRatingSummary(String businessId) async {
    try {
      final doc = await _firestore.collection('destination').doc(businessId).get();
      final data = doc.data();
      
      return {
        'average_rating': (data?['average_rating'] ?? 0).toDouble(),
        'review_count': data?['review_count'] ?? 0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting business rating summary: $e');
      }
      return {
        'average_rating': 0.0,
        'review_count': 0,
      };
    }
  }
}
