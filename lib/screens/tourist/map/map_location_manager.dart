import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Manages location tracking, permissions, and position smoothing
/// SINGLE SOURCE OF TRUTH for location updates - all components should subscribe to locationStream
class MapLocationManager {
  StreamSubscription<Position>? _positionStream;
  Position? _lastAcceptedPosition;
  LatLng? _lastCenter;
  DateTime? _lastOverlayUpdate;
  final List<Position> _recentPositions = [];
  DateTime? _lastPositionAt;
  Timer? _watchdogTimer;

  // Stream controller to broadcast location updates to other components
  final StreamController<Position> _locationStreamController = 
      StreamController<Position>.broadcast();

  // Public stream for other components (like NavigationService) to subscribe to
  Stream<Position> get locationStream => _locationStreamController.stream;

  // Callbacks
  final Function(Position position, LatLng latLng, double bearing) onLocationUpdate;
  final VoidCallback onPermissionDenied;

  // Smoothing configuration
  static const int _smoothingWindow = 5;
  static const double _maxJumpMeters = 100;
  static const Duration _jumpWindow = Duration(seconds: 3);
  static const Duration _throttleInterval = Duration(milliseconds: 900);

  MapLocationManager({
    required this.onLocationUpdate,
    required this.onPermissionDenied,
  });

  /// Handle location permissions with iOS-specific considerations
  Future<bool> handleLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them in Settings.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    // Check current permission status
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        onPermissionDenied();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showPermissionDialog(context);
      }
      onPermissionDenied();
      return false;
    }

    // iOS-specific: Check for "When In Use" permission
    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      return true;
    }

    return true;
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to show your position on the map and provide navigation. '
          'Please enable location permissions in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Start location tracking with platform-specific settings
  Future<void> startLocationTracking() async {
    // Cancel any existing stream before starting a new one
    await _positionStream?.cancel();

    // Platform-specific location settings for optimal arrival detection
    final LocationSettings locationSettings;
    
    if (!kIsWeb && Platform.isIOS) {
      // iOS: bestForNavigation for accurate arrival detection, longer timeLimit
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        // Avoid timeLimit on stream to prevent auto-stop
      );
    } else {
      // Android: high accuracy is sufficient and more battery-efficient for arrival detection
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        // No timeLimit on stream; watchdog will handle stalls
      );
    }

    try {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handleIncomingPosition,
        onError: (error) async {
          if (kDebugMode) debugPrint('Location stream error: $error');
          await _restartLocationStream();
        },
        cancelOnError: false,
      );

      // Get initial position
      await requestLocationUpdate();
      _startWatchdog();
    } catch (e) {
      if (kDebugMode) debugPrint('Error starting location tracking: $e');
      // Fallback: try with basic settings
      try {
        final fallbackSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );
        _positionStream = Geolocator.getPositionStream(
          locationSettings: fallbackSettings,
        ).listen(
          _handleIncomingPosition,
          onError: (error) async {
            if (kDebugMode) debugPrint('Fallback location stream error: $error');
            await _restartLocationStream();
          },
        );
      } catch (e2) {
        if (kDebugMode) debugPrint('Fallback location tracking also failed: $e2');
      }
    }
  }

  /// Request a single location update with platform-appropriate accuracy
  Future<void> requestLocationUpdate() async {
    try {
      final accuracy = (!kIsWeb && Platform.isIOS)
          ? LocationAccuracy.bestForNavigation 
          : LocationAccuracy.high;
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: const Duration(seconds: 15),
      );
      _handleIncomingPosition(position);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting current position: $e');
      // Try with less strict accuracy as fallback
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        _handleIncomingPosition(position);
      } catch (e2) {
        if (kDebugMode) debugPrint('Fallback position request also failed: $e2');
      }
    }
  }

  void _handleIncomingPosition(Position position) {
    final now = DateTime.now();
    _lastPositionAt = now;
    
    // Throttle updates
    if (_lastOverlayUpdate != null &&
        now.difference(_lastOverlayUpdate!) < _throttleInterval) {
      return;
    }

    // Keep a window of recent positions for smoothing
    _recentPositions.add(position);
    while (_recentPositions.length > _smoothingWindow) {
      _recentPositions.removeAt(0);
    }

    // Pick the most accurate position
    Position best = _recentPositions.reduce(
      (a, b) => (a.accuracy <= b.accuracy) ? a : b,
    );

    // Anti-jump logic: ignore sudden large jumps
    if (_lastAcceptedPosition != null) {
      final lastTime = _lastAcceptedPosition!.timestamp;
      final dt = now.difference(lastTime);
      final lastLatLng = LatLng(
        _lastAcceptedPosition!.latitude,
        _lastAcceptedPosition!.longitude,
      );
      final bestLatLng = LatLng(best.latitude, best.longitude);
      final jump = calculateDistance(lastLatLng, bestLatLng);
      
      if (dt < _jumpWindow && jump > _maxJumpMeters) {
        return; // Discard spike
      }
    }

    _lastAcceptedPosition = best;
    _lastOverlayUpdate = now;

    // Calculate bearing if we have a previous position
    double bearing = 0.0;
    if (_lastCenter != null) {
      bearing = calculateBearing(
        _lastCenter!,
        LatLng(best.latitude, best.longitude),
      );
    }
    _lastCenter = LatLng(best.latitude, best.longitude);

    // Broadcast location update to all subscribers (NavigationService, etc.)
    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(best);
    }

    // Call the update callback for UI updates
    onLocationUpdate(best, _lastCenter!, bearing);
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degToRad(b.latitude - a.latitude);
    final double dLon = _degToRad(b.longitude - a.longitude);
    final double lat1 = _degToRad(a.latitude);
    final double lat2 = _degToRad(b.latitude);
    
    final double h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  /// Calculate bearing between two points
  double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final dLon = (end.longitude - start.longitude) * (math.pi / 180);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x) * (180 / math.pi);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Pause location tracking
  void pauseLocationTracking() {
    _positionStream?.pause();
  }

  /// Resume location tracking
  void resumeLocationTracking() {
    _positionStream?.resume();
  }

  /// Stop location tracking
  void dispose() {
    _positionStream?.cancel();
    _recentPositions.clear();
    _locationStreamController.close();
    _watchdogTimer?.cancel();
  }

  Future<void> _restartLocationStream() async {
    try { await _positionStream?.cancel(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    await startLocationTracking();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final last = _lastPositionAt;
      if (last == null) return;
      if (DateTime.now().difference(last) > const Duration(seconds: 20)) {
        if (kDebugMode) debugPrint('Watchdog: restarting stalled location stream');
        await _restartLocationStream();
      }
    });
  }
}


