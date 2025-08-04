// ===========================================
// lib/services/session_service.dart
// ===========================================
// SessionService - Manages persistent user session info using SharedPreferences

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';

  static Map<String, dynamic>? _cachedSession;

  /// Initialize session data at app launch
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (isLoggedIn) {
        final uid = prefs.getString(_keyUserId);
        final email = prefs.getString(_keyUserEmail);
        final role = prefs.getString(_keyUserRole);

        if (uid != null && email != null && role != null) {
          _cachedSession = {
            'uid': uid,
            'email': email,
            'role': role,
          };
          debugPrint('Session initialized: $_cachedSession');
        }
      }
    } catch (e) {
      debugPrint('Error initializing session: $e');
    }
  }

  /// Store session data persistently and in-memory
  static Future<void> storeSession(
    String uid,
    String email,
    String role,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, uid);
      await prefs.setString(_keyUserEmail, email);
      await prefs.setString(_keyUserRole, role);

      _cachedSession = {
        'uid': uid,
        'email': email,
        'role': role,
      };

      debugPrint('Session stored: $uid, $email, $role');
    } catch (e) {
      debugPrint('Error storing session: $e');
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserRole);
      _cachedSession = null;
      debugPrint('Session cleared');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  /// Check if a session exists
  static Future<bool> hasValidSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('Error checking session: $e');
      return false;
    }
  }

  /// Get the cached session or load from SharedPreferences
  static Future<Map<String, dynamic>?> getSession() async {
    if (_cachedSession != null) return _cachedSession;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (!isLoggedIn) return null;

      final uid = prefs.getString(_keyUserId);
      final email = prefs.getString(_keyUserEmail);
      final role = prefs.getString(_keyUserRole);

      if (uid != null && email != null && role != null) {
        _cachedSession = {
          'uid': uid,
          'email': email,
          'role': role,
        };
        return _cachedSession;
      }

      return null;
    } catch (e) {
      debugPrint('Error retrieving session: $e');
      return null;
    }
  }

  /// Returns user ID if available
  static Future<String?> getUserId() async => (await getSession())?['uid'];

  /// Returns user email if available
  static Future<String?> getUserEmail() async => (await getSession())?['email'];

  /// Returns user role if available
  static Future<String?> getUserRole() async => (await getSession())?['role'];

  /// Returns true if user is logged in (alias)
  static Future<bool> isLoggedIn() async => await hasValidSession();
}
