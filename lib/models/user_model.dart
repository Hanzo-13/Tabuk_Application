// ===========================================
// lib/models/user_model.dart
// ===========================================
// Model for user data in the Users collection.

/// Represents a user in the system.
class User {
  /// Unique user ID (Firestore document ID).
  final String id;
  /// User's email address.
  final String email;
  /// User's display name.
  final String name;
  /// User's role in the system.
  final String role;
  /// Profile photo URL.
  final String profilePhoto;
  /// Username (if applicable).
  final String username;
  /// Contact information.
  final String contact;
  /// Country/nationality.
  final String country;
  /// Gender.
  final String gender;
  /// Date of birth.
  final String dob;
  /// Whether the user has completed their profile form.
  final bool formCompleted;
  /// Timestamp when the user was created.
  final DateTime createdAt;
  /// Timestamp when the user was last updated.
  final DateTime? updatedAt;

  /// Creates a [User] instance.
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.profilePhoto,
    required this.username,
    required this.contact,
    required this.country,
    required this.gender,
    required this.dob,
    required this.formCompleted,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a [User] from a Firestore document.
  factory User.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Handle profile photo with fallbacks
    String profilePhoto = '';
    if (data['profilePhoto'] != null && (data['profilePhoto'] as String).trim().isNotEmpty) {
      profilePhoto = data['profilePhoto'];
    } else if (data['profile_photo'] != null && (data['profile_photo'] as String).trim().isNotEmpty) {
      profilePhoto = data['profile_photo'];
    } else if (data['profileImageUrl'] != null && (data['profileImageUrl'] as String).trim().isNotEmpty) {
      profilePhoto = data['profileImageUrl'];
    }
    
    // Only use valid URLs
    if (profilePhoto.isNotEmpty && !profilePhoto.startsWith('http')) {
      profilePhoto = '';
    }

    // Handle timestamps
    DateTime createdAt;
    if (data['created_at'] != null) {
      if (data['created_at'] is DateTime) {
        createdAt = data['created_at'];
      } else if (data['created_at'] is String) {
        createdAt = DateTime.tryParse(data['created_at']) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    if (data['updated_at'] != null) {
      if (data['updated_at'] is DateTime) {
        updatedAt = data['updated_at'];
      } else if (data['updated_at'] is String) {
        updatedAt = DateTime.tryParse(data['updated_at']);
      }
    }

    return User(
      id: documentId,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      profilePhoto: profilePhoto,
      username: data['username']?.toString() ?? '',
      contact: data['contact']?.toString() ?? '',
      country: data['country']?.toString() ?? '',
      gender: data['gender']?.toString() ?? '',
      dob: data['dob']?.toString() ?? '',
      formCompleted: data['form_completed'] ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts the [User] to a map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'profilePhoto': profilePhoto,
      'username': username,
      'contact': contact,
      'country': country,
      'gender': gender,
      'dob': dob,
      'form_completed': formCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy of this User with updated fields.
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? profilePhoto,
    String? username,
    String? contact,
    String? country,
    String? gender,
    String? dob,
    bool? formCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      username: username ?? this.username,
      contact: contact ?? this.contact,
      country: country ?? this.country,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      formCompleted: formCompleted ?? this.formCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, role: $role, profilePhoto: $profilePhoto)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}