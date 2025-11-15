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
  final List<Position> _recentPositions = [];
  DateTime? _lastPositionAt;
  Timer? _watchdogTimer;
  Timer? _pollingTimer;

  // Stream controller to broadcast location updates to other components
  final StreamController<Position> _locationStreamController = 
      StreamController<Position>.broadcast();

  // Public stream for other components (like NavigationService) to subscribe to
  Stream<Position> get locationStream => _locationStreamController.stream;

  // Callbacks
  final Function(Position position, LatLng latLng, double bearing) onLocationUpdate;
  final VoidCallback onPermissionDenied;
  final bool Function()? isNavigatingProvider;

  // IMPROVED: Better smoothing configuration for natural walking
  static const int _smoothingWindow = 5; // Increased for smoother walking
  static const double _maxJumpMeters = 50; // More aggressive spike filtering for walking
  static const Duration _jumpWindow = Duration(seconds: 3);
  
  // New: Walking-specific filtering
// m/s (about 1 km/h)
  static const double _maxWalkingSpeed = 2.5; // m/s (about 9 km/h)
  static const double _minMovementDistance = 2.0; // meters - minimum distance to consider movement

  MapLocationManager({
    required this.onLocationUpdate,
    required this.onPermissionDenied,
    this.isNavigatingProvider,
  });

  /// Handle location permissions with iOS-specific considerations
  Future<bool> handleLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

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

  /// Start location tracking with platform-specific settings optimized for performance
  /// Uses balanced accuracy and distance filter to reduce main thread blocking
  Future<void> startLocationTracking() async {
    await _positionStream?.cancel();

    // OPTIMIZED: Balanced settings to prevent ANR and reduce battery drain
    // Using balanced accuracy and distance filter to reduce update frequency
    final LocationSettings locationSettings;
    
    final bool isNavigating = isNavigatingProvider?.call() ?? false;
    
    if (!kIsWeb && Platform.isIOS) {
      // iOS: Use medium accuracy when not navigating, bestForNavigation when navigating
      locationSettings = LocationSettings(
        accuracy: isNavigating 
            ? LocationAccuracy.bestForNavigation 
            : LocationAccuracy.medium,
        distanceFilter: isNavigating ? 0 : 10, // 10m filter when not navigating
      );
    } else {
      // Android: Medium accuracy to reduce main thread blocking
      // High accuracy only when actively navigating
      locationSettings = LocationSettings(
        accuracy: isNavigating 
            ? LocationAccuracy.high 
            : LocationAccuracy.medium,
        distanceFilter: isNavigating ? 0 : 10, // 10m filter when not navigating
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

      await requestLocationUpdate();
      _startWatchdog();

      // OPTIMIZED: Reduced polling frequency to prevent main thread blocking
      // Only poll when actively navigating, otherwise rely on stream updates
      _pollingTimer?.cancel();
      if (isNavigating) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: (!kIsWeb && Platform.isIOS)
                  ? LocationAccuracy.bestForNavigation
                  : LocationAccuracy.medium, // Use medium to reduce blocking
            );
            _handleIncomingPosition(position);
          } catch (e) {
            if (kDebugMode) debugPrint('Polling position failed: $e');
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error starting location tracking: $e');
      
      // Handle Google Play Services errors gracefully (for emulator)
      if (e.toString().contains('SecurityException') || 
          e.toString().contains('GoogleApiManager') ||
          e.toString().contains('DEVELOPER_ERROR')) {
        if (kDebugMode) {
          debugPrint('Google Play Services error detected. This may be due to emulator limitations.');
        }
        // Fallback to basic location settings
      }
      
      try {
        // OPTIMIZED: Use medium accuracy for fallback to reduce blocking
        final fallbackSettings = LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10, // Add distance filter to reduce updates
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

  /// Request a single location update
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
    
    final bool isNavigating = isNavigatingProvider?.call() ?? false;
    
    // IMPROVED: Better GPS spike detection for walking
    if (_lastAcceptedPosition != null) {
      final lastTime = _lastAcceptedPosition!.timestamp;
      final dt = now.difference(lastTime);
      final lastLatLng = LatLng(
        _lastAcceptedPosition!.latitude,
        _lastAcceptedPosition!.longitude,
      );
      final currentLatLng = LatLng(position.latitude, position.longitude);
      final jump = calculateDistance(lastLatLng, currentLatLng);
      
      // Filter obvious GPS spikes
      if (dt < _jumpWindow && jump > _maxJumpMeters && position.accuracy > 20) {
        if (kDebugMode) {
          debugPrint('Discarding GPS spike: ${jump.toInt()}m in ${dt.inSeconds}s with accuracy ${position.accuracy.toInt()}m');
        }
        return;
      }
      
      // NEW: Filter unrealistic walking speeds during navigation
      if (isNavigating && dt.inSeconds > 0) {
        final speed = jump / dt.inSeconds;
        if (speed > _maxWalkingSpeed && position.accuracy > 15) {
          if (kDebugMode) {
            debugPrint('Discarding unrealistic walking speed: ${speed.toStringAsFixed(2)} m/s');
          }
          return;
        }
      }
      
      // NEW: Ignore tiny movements that are likely GPS jitter
      if (jump < _minMovementDistance && position.accuracy > 10) {
        // Update accuracy but keep position stable for jitter
        final smoothed = Position(
          latitude: _lastAcceptedPosition!.latitude,
          longitude: _lastAcceptedPosition!.longitude,
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          altitude: position.altitude,
          heading: position.heading,
          speed: position.speed,
          speedAccuracy: position.speedAccuracy,
          altitudeAccuracy: position.altitudeAccuracy,
          headingAccuracy: position.headingAccuracy,
        );
        _lastAcceptedPosition = smoothed;
        _updateWithSmoothedPosition(smoothed);
        return;
      }
    }
    
    // IMPROVED: Better smoothing for walking
    _recentPositions.add(position);
    while (_recentPositions.length > _smoothingWindow) {
      _recentPositions.removeAt(0);
    }

    // Use weighted average of recent positions for smooth movement
    Position smoothed;
    if (_recentPositions.length >= 3 && isNavigating) {
      smoothed = _calculateSmoothedPosition(_recentPositions);
    } else {
      // Use best accuracy from recent positions
      final cutoffTime = now.subtract(const Duration(seconds: 2));
      final recentEnough = _recentPositions.where((p) => p.timestamp.isAfter(cutoffTime)).toList();
      smoothed = recentEnough.isNotEmpty
          ? recentEnough.reduce((a, b) => (a.accuracy <= b.accuracy) ? a : b)
          : position;
    }

    _lastAcceptedPosition = smoothed;
    _updateWithSmoothedPosition(smoothed);
  }

  /// NEW: Calculate smoothed position using weighted average
  Position _calculateSmoothedPosition(List<Position> positions) {
    if (positions.isEmpty) return positions.last;
    if (positions.length == 1) return positions.first;
    
    // Weight recent positions more heavily
    double totalWeight = 0;
    double weightedLat = 0;
    double weightedLng = 0;
    double bestAccuracy = double.infinity;
    
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      // More recent = higher weight, better accuracy = higher weight
      final recencyWeight = (i + 1) / positions.length; // 0.2, 0.4, 0.6, 0.8, 1.0 for 5 positions
      final accuracyWeight = 1.0 / (1.0 + pos.accuracy); // Better accuracy = higher weight
      final weight = recencyWeight * accuracyWeight;
      
      weightedLat += pos.latitude * weight;
      weightedLng += pos.longitude * weight;
      totalWeight += weight;
      
      if (pos.accuracy < bestAccuracy) {
        bestAccuracy = pos.accuracy;
      }
    }
    
    final avgLat = weightedLat / totalWeight;
    final avgLng = weightedLng / totalWeight;
    final latest = positions.last;
    
    return Position(
      latitude: avgLat,
      longitude: avgLng,
      timestamp: latest.timestamp,
      accuracy: bestAccuracy,
      altitude: latest.altitude,
      heading: latest.heading,
      speed: latest.speed,
      speedAccuracy: latest.speedAccuracy,
      altitudeAccuracy: latest.altitudeAccuracy,
      headingAccuracy: latest.headingAccuracy,
    );
  }

  void _updateWithSmoothedPosition(Position position) {
    // Calculate bearing if we have a previous position
    double bearing = 0.0;
    if (_lastCenter != null) {
      final newLatLng = LatLng(position.latitude, position.longitude);
      final distance = calculateDistance(_lastCenter!, newLatLng);
      
      // Only update bearing if we've moved enough
      if (distance > _minMovementDistance) {
        bearing = calculateBearing(_lastCenter!, newLatLng);
      } else if (_lastAcceptedPosition != null) {
        // Keep previous bearing for stability
        bearing = calculateBearing(
          LatLng(_lastAcceptedPosition!.latitude, _lastAcceptedPosition!.longitude),
          LatLng(position.latitude, position.longitude),
        );
      }
    }
    _lastCenter = LatLng(position.latitude, position.longitude);

    // Broadcast location update to all subscribers
    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(position);
    }

    // Call the update callback for UI updates
    onLocationUpdate(position, _lastCenter!, bearing);
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
    _pollingTimer?.cancel();
  }

  /// Resume location tracking
  void resumeLocationTracking() {
    _positionStream?.resume();
    
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: (!kIsWeb && Platform.isIOS)
              ? LocationAccuracy.bestForNavigation
              : LocationAccuracy.high,
        );
        _handleIncomingPosition(position);
      } catch (e) {
        if (kDebugMode) debugPrint('Polling position failed: $e');
      }
    });
  }

  /// Stop location tracking
  void dispose() {
    _positionStream?.cancel();
    _recentPositions.clear();
    _locationStreamController.close();
    _watchdogTimer?.cancel();
    _pollingTimer?.cancel();
  }

  Future<void> _restartLocationStream() async {
    try { await _positionStream?.cancel(); } catch (_) {}
    _pollingTimer?.cancel();
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