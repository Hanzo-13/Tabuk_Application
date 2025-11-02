// ===========================================
// lib/services/user_service.dart
// ===========================================
// Service for user-related operations including profile management.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:capstone_app/models/user_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Service for user-related operations.
class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  /// Gets the current user's data from Firestore.
  static Future<User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final doc = await _firestore.collection('Users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;

      return User.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Updates the current user's profile information.
  static Future<bool> updateUserProfile({
    String? name,
    String? username,
    String? contact,
    String? country,
    String? profilePhoto,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return false;

      final updateData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (username != null) updateData['username'] = username;
      if (contact != null) updateData['contact'] = contact;
      if (country != null) updateData['country'] = country;
      if (profilePhoto != null) updateData['profilePhoto'] = profilePhoto;

      await _firestore.collection('Users').doc(firebaseUser.uid).update(updateData);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  /// Updates the user's profile photo.
  static Future<bool> updateProfilePhoto(String photoUrl) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return false;

      await _firestore.collection('Users').doc(firebaseUser.uid).update({
        'profilePhoto': photoUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating profile photo: $e');
      return false;
    }
  }

  /// Creates a new user document in Firestore.
  static Future<bool> createUser({
    required String userId,
    required String email,
    required String role,
    String? name,
    String? profilePhoto,
  }) async {
    try {
      final userData = {
        'email': email,
        'role': role,
        'name': name ?? '',
        'profilePhoto': profilePhoto ?? '',
        'username': '',
        'contact': '',
        'country': '',
        'gender': '',
        'dob': '',
        'form_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('Users').doc(userId).set(userData);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating user: $e');
      return false;
    }
  }

  /// Gets a user by their ID.
  static Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('Users').doc(userId).get();
      if (!doc.exists) return null;

      return User.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Checks if a user exists in the Users collection.
  static Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore.collection('Users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  /// Ensures a user document exists in Firestore.
  /// If it doesn't exist, creates it with basic information.
  static Future<bool> ensureUserDocument({
    required String userId,
    required String email,
    required String role,
    String? name,
    String? profilePhoto,
  }) async {
    try {
      final exists = await userExists(userId);
      if (!exists) {
        return await createUser(
          userId: userId,
          email: email,
          role: role,
          name: name,
          profilePhoto: profilePhoto,
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error ensuring user document: $e');
      return false;
    }
  }

  /// Deletes a user document from Firestore.
  static Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection('Users').doc(userId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Stream of user data changes.
  static Stream<User?> userStream(String userId) {
    return _firestore
        .collection('Users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return User.fromFirestore(doc.data()!, doc.id);
    });
  }

  /// Stream of current user data changes.
  static Stream<User?> currentUserStream() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return Stream.value(null);
    
    return userStream(firebaseUser.uid);
  }
} 