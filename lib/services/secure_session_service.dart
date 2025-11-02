import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureSessionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Use KeyStore for additional security
      sharedPreferencesName: 'secure_session',
      preferencesKeyPrefix: 'session_',
    ),
    iOptions: IOSOptions(
      // iOS will use Keychain by default
      // accessibility is optional, can be set if needed
    ),
    // Linux and Windows options are optional
  );

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';

  /// Store session data securely
  static Future<void> storeSession(
    String uid,
    String email,
    String role,
  ) async {
    try {
      await Future.wait([
        _storage.write(key: _keyIsLoggedIn, value: 'true'),
        _storage.write(key: _keyUserId, value: uid),
        _storage.write(key: _keyUserEmail, value: email),
        _storage.write(key: _keyUserRole, value: role),
      ]);
      debugPrint('Session stored securely');
    } catch (e) {
      debugPrint('Error storing session: $e');
      rethrow;
    }
  }

  /// Clear all session data
  static Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
      debugPrint('Session cleared');
    } catch (e) {
      debugPrint('Error clearing session: $e');
      rethrow;
    }
  }

  /// Check if session exists
  static Future<bool> hasValidSession() async {
    try {
      final isLoggedIn = await _storage.read(key: _keyIsLoggedIn);
      return isLoggedIn == 'true';
    } catch (e) {
      debugPrint('Error checking session: $e');
      return false;
    }
  }

  /// Get session data
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final isLoggedIn = await _storage.read(key: _keyIsLoggedIn);
      if (isLoggedIn != 'true') return null;

      final uid = await _storage.read(key: _keyUserId);
      final email = await _storage.read(key: _keyUserEmail);
      final role = await _storage.read(key: _keyUserRole);

      if (uid != null && email != null && role != null) {
        return {
          'uid': uid,
          'email': email,
          'role': role,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving session: $e');
      return null;
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  /// Get user role
  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  /// Store session with expiry timestamp
  static Future<void> storeSessionWithExpiry(
    String uid,
    String email,
    String role,
  ) async {
    await storeSession(uid, email, role);
    await _storage.write(
      key: 'session_expiry',
      value: DateTime.now().add(Duration(hours: 24)).toIso8601String(),
    );
  }

  /// Check if session is still valid (not expired)
  static Future<bool> isSessionValid() async {
    final expiry = await _storage.read(key: 'session_expiry');
    if (expiry == null) return false;
    
    final expiryDate = DateTime.parse(expiry);
    return DateTime.now().isBefore(expiryDate);
  }
}