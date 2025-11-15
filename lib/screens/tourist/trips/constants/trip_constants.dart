// ===========================================
// lib/screens/tourist/trips/constants/trip_constants.dart
// ===========================================
// Constants used across trip-related screens

class TripConstants {
  // Collection and status constants
  static const String collectionName = 'trip_planning';
  static const String archivedStatus = 'Archived';
  static const String planningStatus = 'Planning';
  
  // UI Labels
  static const String myTripsLabel = 'My Adventures';
  static const String activeTabLabel = 'Trip Plans';
  static const String archivedTabLabel = 'Trip Completed';
  static const String progressTabLabel = 'Progress';
  
  // Messages
  static const String tripAddedMsg = 'Trip to {destination} added successfully!';
  static const String tripArchivedMsg = 'Trip to {destination} is complete';
  static const String tripRestoredMsg = 'Trip to {destination} is restored';
  static const String tripDeletedMsg = 'Trip deleted';
  
  // SnackBar constants
  static const double snackBarMargin = 16.0;
  static const double snackBarBorderRadius = 8.0;
  static const int snackBarDurationSec = 2;
  
  // Transportation options
  static const List<String> transportationOptions = [
    'Car',
    'Motorcycle',
    'Walk',
    'Plane',
    'Bus',
    'Boat',
    'Train',
  ];
  
  // Tab count
  static const int tabCount = 3;
}

