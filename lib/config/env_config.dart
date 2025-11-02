import 'package:flutter/foundation.dart';

class EnvConfig {
  // Load from environment variables or secure storage
  static String get googleMapsApiKey {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '', // Fail safely - require environment variable
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Use const with fallback key directly for development
      return const String.fromEnvironment(
        'ANDROID_GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE', // Android dev key - remove in production
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Use const with fallback key directly for development
      return const String.fromEnvironment(
        'IOS_GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8', // iOS dev key - remove in production
      );
    }
    return '';
  }
  
  static String get firebaseApiKey {
    return const String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: '',
    );
  }
  
  static String get firebaseProjectId {
    return const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
  }
  
  static String get imgbbApiKey {
    return const String.fromEnvironment(
      'IMGBB_API_KEY',
      defaultValue: '',
    );
  }
  
  static void validate() {
    assert(
      googleMapsApiKey.isNotEmpty,
      'Google Maps API Key must be provided via environment variable',
    );
  }
}