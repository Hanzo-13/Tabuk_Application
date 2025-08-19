import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();

  /// Get current position
  Position? get currentPosition => _currentPosition;

  /// Stream of location updates
  Stream<Position> get locationStream => _locationController.stream;

  /// Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) print('Location permissions denied');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) print('Location permissions permanently denied');
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) print('Error checking location permissions: $e');
      return false;
    }
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _locationController.add(_currentPosition!);
      return _currentPosition;
    } catch (e) {
      if (kDebugMode) print('Error getting current position: $e');
      return null;
    }
  }

  /// Start listening to location updates
  Future<void> startLocationUpdates({
    Duration interval = const Duration(seconds: 30),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return;

      // Stop existing stream if any
      await stopLocationUpdates();

      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 100, // Update every 100 meters
          timeLimit: interval,
        ),
      ).listen(
        (Position position) {
          _currentPosition = position;
          _locationController.add(position);
        },
        onError: (error) {
          if (kDebugMode) print('Error in location stream: $error');
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error starting location updates: $e');
    }
  }

  /// Stop location updates
  Future<void> stopLocationUpdates() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calculate distance between two points
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate distance in kilometers
  static double calculateDistanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return calculateDistance(
      lat1: lat1,
      lng1: lng1,
      lat2: lat2,
      lng2: lng2,
    ) / 1000;
  }

  /// Check if location is enabled
  Future<bool> isLocationEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      if (kDebugMode) print('Error checking if location is enabled: $e');
      return false;
    }
  }

  /// Get last known position
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      if (kDebugMode) print('Error getting last known position: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    stopLocationUpdates();
    _locationController.close();
  }
}
