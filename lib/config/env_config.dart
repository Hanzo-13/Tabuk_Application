import 'package:flutter/foundation.dart';

class EnvConfig {
  // Map Display API Key - Used for showing maps in the app
  static String get googleMapsApiKey {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '', // Require environment variable for web
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment(
        'ANDROID_GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyDEeIzEOXmrCFNYt7f2QHM43lcq8fZtTsE', // Android Maps SDK key
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment(
        'IOS_GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8', // iOS dev key
      );
    }
    return '';
  }

  // Directions API Key - Used for calculating routes and directions
  static String get googleDirectionsApiKey {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'GOOGLE_DIRECTIONS_API_KEY',
        defaultValue: '', // Require environment variable for web
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment(
        'GOOGLE_DIRECTIONS_API_KEY',
        defaultValue: 'AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE', // Directions API key
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment(
        'GOOGLE_DIRECTIONS_API_KEY',
        defaultValue: 'AIzaSyATZftO3SXnK0-sWqq3-5Ew5eHcUvGAhL8', // Directions API key
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
      'Google Maps API Key must be provided',
    );
    assert(
      googleDirectionsApiKey.isNotEmpty,
      'Google Directions API Key must be provided',
    );
  }
}