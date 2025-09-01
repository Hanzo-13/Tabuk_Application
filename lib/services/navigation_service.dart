// ignore_for_file: constant_identifier_names, depend_on_referenced_packages, prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:capstone_app/api/api.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:flutter/material.dart'; // Added for Colors
import 'package:async/async.dart';

class NavigationStep {
  final String instruction;
  final String? maneuver;
  final double distance;
  final double duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polyline;

  NavigationStep({
    required this.instruction,
    this.maneuver,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.polyline,
  });
}

class NavigationRoute {
  final List<NavigationStep> steps;
  final double totalDistance;
  final double totalDuration;
  final List<LatLng> overviewPolyline;
  final LatLng origin;
  final LatLng destination;
  final String travelMode;

  NavigationRoute({
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
    required this.overviewPolyline,
    required this.origin,
    required this.destination,
    required this.travelMode,
  });
}

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final _stepController = StreamController<NavigationStep>.broadcast();
  final _navigationStateController = StreamController<bool>.broadcast();
  final _locationController = StreamController<Position>.broadcast();
  final _arrivalController = StreamController<String>.broadcast();
  
  // Stream group for better memory management
  final StreamGroup _streamGroup = StreamGroup();

  Stream<NavigationStep> get stepStream => _stepController.stream;
  Stream<bool> get navigationStateStream => _navigationStateController.stream;
  Stream<Position> get locationStream => _locationController.stream;
  Stream<String> get arrivalStream => _arrivalController.stream;
  Stream<Set<Polyline>> get polylineStream => _polylineController.stream;

  NavigationRoute? _currentRoute;
  int _currentStepIndex = 0;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isNavigating = false; 
  String? _destinationName;
  String _currentTransportationMode = MODE_WALKING;
  bool _isMapRotated = true;
  
  // Destination information for arrival tracking
  String? _destinationId;
  String? _destinationCategory;
  String? _destinationType;
  String? _destinationDistrict;
  String? _destinationMunicipality;
  List<String>? _destinationImages;
  String? _destinationDescription;
  
  final StreamController<Set<Polyline>> _polylineController = StreamController<Set<Polyline>>.broadcast();

  NavigationRoute? get currentRoute => _currentRoute;
  bool get isNavigating => _isNavigating;

  void changeTransportationMode(String mode) {
    _currentTransportationMode = mode;
    // Recalculate route with new mode if currently navigating
    if (_isNavigating && _currentRoute != null) {
      _recalculateRouteWithNewMode();
    }
  }

  /// Transportation mode constants
  static const String MODE_WALKING = 'walking';
  static const String MODE_DRIVING = 'driving';
  static const String MODE_BICYCLING = 'bicycling';
  static const String MODE_MOTORCYCLE = 'motorcycle';
  static const String MODE_TRANSIT = 'transit';

  /// Get all available transportation modes
  List<String> getAvailableTransportationModes() {
    return [
      MODE_WALKING,
      MODE_BICYCLING,
      MODE_DRIVING,
      MODE_MOTORCYCLE,
      MODE_TRANSIT,
    ];
  }

  /// Get transportation mode multiplier for time calculations
  /// These multipliers are based on average speeds:
  /// Walking: 5 km/h, Bicycling: 15 km/h, Driving: 40 km/h, Motorcycle: 50 km/h
  double _getTransportationModeMultiplier(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 1.0; // Base walking speed (5 km/h)
      case MODE_BICYCLING:
        return 0.33; // Bicycling is ~3x faster than walking (15 km/h)
      case MODE_DRIVING:
        return 0.125; // Driving is ~8x faster than walking (40 km/h)
      case MODE_MOTORCYCLE:
        return 0.1; // Motorcycle is ~10x faster than walking (50 km/h)
      case MODE_TRANSIT:
        return 0.25; // Transit is ~4x faster than walking (20 km/h average)
      default:
        return 1.0;
    }
  }

  /// Get transportation mode name for display
  String getTransportationModeDisplayName(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 'Walking';
      case MODE_DRIVING:
        return 'Driving';
      case MODE_BICYCLING:
        return 'Bicycling';
      case MODE_MOTORCYCLE:
        return 'Motorcycle';
      case MODE_TRANSIT:
        return 'Transit';
      default:
        return 'Walking';
    }
  }

  /// Get transportation mode icon for display
  String getTransportationModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return '🚶';
      case MODE_BICYCLING:
        return '🚴';
      case MODE_DRIVING:
        return '🚗';
      case MODE_MOTORCYCLE:
        return '🏍️';
      case MODE_TRANSIT:
        return '🚌';
      default:
        return '🚶';
    }
  }

  /// Get transportation mode color for UI
  Color getTransportationModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return Colors.green;
      case MODE_BICYCLING:
        return Colors.blue;
      case MODE_DRIVING:
        return Colors.orange;
      case MODE_MOTORCYCLE:
        return Colors.red;
      case MODE_TRANSIT:
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  /// Adjust duration based on transportation mode
  double _adjustDurationForTransportationMode(double baseDuration, String mode) {
    final multiplier = _getTransportationModeMultiplier(mode);
    return baseDuration * multiplier;
  }

  /// Convert transportation mode to API-compatible mode
  String _convertToApiMode(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_MOTORCYCLE:
        return MODE_DRIVING; // Google Maps API doesn't have motorcycle mode, use driving
      case MODE_TRANSIT:
        return MODE_DRIVING; // Google Maps API transit mode is complex, use driving for now
      case MODE_WALKING:
      case MODE_DRIVING:
      case MODE_BICYCLING:
        return mode.toLowerCase();
      default:
        return MODE_WALKING;
    }
  }

  void toggleMapRotation(bool isRotated) {
    _isMapRotated = isRotated;
    // Notify map controller about rotation change
    _navigationStateController.add(_isNavigating);
  }

  bool get isMapRotated => _isMapRotated;
  String get currentTransportationMode => _currentTransportationMode;
  
  /// Get current transportation mode display name
  String get currentTransportationModeDisplayName => getTransportationModeDisplayName(_currentTransportationMode);

  Future<void> _recalculateRouteWithNewMode() async {
    if (_currentRoute == null) return;
    
    try {
      final newRoute = await getDirections(
        LatLng(_currentRoute!.destination.latitude, _currentRoute!.destination.longitude),
        mode: _currentTransportationMode,
      );
      
      if (newRoute != null) {
        _currentRoute = newRoute;
        _currentStepIndex = 0;
        _stepController.add(_currentRoute!.steps[_currentStepIndex]);
      }
    } catch (e) {
      if (kDebugMode) print('Error recalculating route: $e');
    }
  }

  /// Get turn-by-turn directions to a destination
  Future<NavigationRoute?> getDirections(
    LatLng destination, {
    String mode = MODE_WALKING, // Default to walking like in the image
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final origin = LatLng(position.latitude, position.longitude);
      
      // Convert transportation mode to API-compatible mode
      final apiMode = _convertToApiMode(mode);
      
      final url = ApiEnvironment.getDirectionsUrl(
        '${origin.latitude},${origin.longitude}',
        '${destination.latitude},${destination.longitude}',
        mode: apiMode,
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final body = json.decode(response.body);
      if (body['status'] != 'OK' || body['routes'] == null || body['routes'].isEmpty) return null;

      final routes = body['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      
      final route = routes[0] as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>? ?? [];
      final overviewPolyline = route['overview_polyline']?['points']?.toString() ?? '';

      final decoder = PolylinePoints();
      final overviewCoords = decoder.decodePolyline(overviewPolyline.toString());

      final steps = <NavigationStep>[];
      double totalDistance = 0;
      double totalDuration = 0;

              for (final leg in legs) {
          final legSteps = leg['steps'] as List<dynamic>? ?? [];
          
          for (final step in legSteps) {
          final stepData = step as Map<String, dynamic>;
          final instruction = stepData['html_instructions'] ?? '';
          final maneuver = stepData['maneuver']?.toString() ?? '';
          final distance = (stepData['distance']?['value'] ?? 0).toDouble();
          final duration = (stepData['duration']?['value'] ?? 0).toDouble();
          
                      final startLocation = LatLng(
              (stepData['start_location']?['lat'] ?? 0).toDouble(),
              (stepData['start_location']?['lng'] ?? 0).toDouble(),
            );
            final endLocation = LatLng(
              (stepData['end_location']?['lat'] ?? 0).toDouble(),
              (stepData['end_location']?['lng'] ?? 0).toDouble(),
            );

                      // Decode step polyline if available
            List<LatLng> stepPolyline = [];
            if (stepData['polyline']?['points'] != null) {
              final stepPoints = decoder.decodePolyline(stepData['polyline']['points'].toString());
              stepPolyline = stepPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
            } else {
              stepPolyline = [startLocation, endLocation];
            }

          steps.add(NavigationStep(
            instruction: _cleanHtmlInstructions(instruction),
            maneuver: maneuver,
            distance: distance,
            duration: duration,
            startLocation: startLocation,
            endLocation: endLocation,
            polyline: stepPolyline,
          ));

          totalDistance += distance;
          totalDuration += duration;
        }
      }

      // Adjust duration based on transportation mode
      final adjustedDuration = _adjustDurationForTransportationMode(totalDuration, mode);
      
      final navigationRoute = NavigationRoute(
        steps: steps,
        totalDistance: totalDistance,
        totalDuration: adjustedDuration,
        overviewPolyline: overviewCoords.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        origin: origin,
        destination: destination,
        travelMode: mode,
      );

      return navigationRoute;
    } catch (e) {
      if (kDebugMode) print('Error getting directions: $e');
      return null;
    }
  }

  /// Start navigation to a destination
  Future<bool> startNavigation(
    LatLng destination, {
    String? destinationId,
    String? destinationName,
    String? destinationCategory,
    String? destinationType,
    String? destinationDistrict,
    String? destinationMunicipality,
    List<String>? destinationImages,
    String? destinationDescription,
    String mode = MODE_WALKING, // Default to walking
  }) async {
    try {
      if (kDebugMode) print('Starting navigation to: ${destination.latitude}, ${destination.longitude}');
      
      // Check location permissions first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) print('Location permission denied for navigation');
        return false;
      }
      
      final route = await getDirections(destination, mode: mode);
      if (route == null) {
        if (kDebugMode) print('Failed to get directions');
        return false;
      }

      if (kDebugMode) print('Got route with ${route.steps.length} steps');

      _currentRoute = route;
      _currentStepIndex = 0;
      
      // Store destination information for arrival tracking
      _destinationId = destinationId;
      _destinationName = destinationName;
      _destinationCategory = destinationCategory;
      _destinationType = destinationType;
      _destinationDistrict = destinationDistrict;
      _destinationMunicipality = destinationMunicipality;
      _destinationImages = destinationImages;
      _destinationDescription = destinationDescription;
      
      // Start location tracking
      await _startLocationTracking();
      
      // Create navigation polylines
      _createNavigationPolylines();
      
      // Notify navigation started
      _navigationStateController.add(true);
      _stepController.add(route.steps[0]);
      
      if (kDebugMode) print('Navigation started successfully');
      return true;
    } catch (e) {
      if (kDebugMode) print('Error starting navigation: $e');
      return false;
    }
  }

  /// Create polylines for navigation display
  void _createNavigationPolylines() {
    if (_currentRoute == null) return;

    final polylines = <Polyline>{};
    
    // Main route polyline
    polylines.add(Polyline(
      polylineId: const PolylineId('navigation_route'),
      points: _currentRoute!.overviewPolyline,
      color: Colors.blue,
      width: 8,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
      jointType: JointType.round,
    ));

    // Step-by-step polylines for better visualization
    for (int i = 0; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      polylines.add(Polyline(
        polylineId: PolylineId('step_$i'),
        points: step.polyline,
        color: i == 0 ? Colors.green : Colors.blue.withOpacity(0.6),
        width: i == 0 ? 10 : 6,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }

    _polylineController.add(polylines);
  }

  /// Stop navigation
  void stopNavigation() {
    _currentRoute = null;
    _currentStepIndex = 0;
    _positionStream?.cancel();
    
    // Clear destination information
    _destinationId = null;
    _destinationName = null;
    _destinationCategory = null;
    _destinationType = null;
    _destinationDistrict = null;
    _destinationMunicipality = null;
    _destinationImages = null;
    _destinationDescription = null;
    
    // Clear polylines
    _polylineController.add({});
    
    _navigationStateController.add(false);
  }

  /// Get current navigation step
  NavigationStep? getCurrentStep() {
    if (_currentRoute == null || _currentStepIndex >= _currentRoute!.steps.length) {
      return null;
    }
    return _currentRoute!.steps[_currentStepIndex];
  }

  /// Get next navigation step
  NavigationStep? getNextStep() {
    if (_currentRoute == null || _currentStepIndex + 1 >= _currentRoute!.steps.length) {
      return null;
    }
    return _currentRoute!.steps[_currentStepIndex + 1];
  }

  /// Get remaining distance and time
  Map<String, dynamic> getRemainingInfo() {
    if (_currentRoute == null) return {};

    double remainingDistance = 0;
    double remainingDuration = 0;

    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      remainingDistance += _currentRoute!.steps[i].distance;
      remainingDuration += _currentRoute!.steps[i].duration;
    }

    return {
      'distance': remainingDistance,
      'duration': remainingDuration,
      'totalSteps': _currentRoute!.steps.length,
      'currentStep': _currentStepIndex + 1,
    };
  }

  /// Start location tracking for navigation
  Future<void> _startLocationTracking() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _locationController.add(position);
          
          // Check if we need to advance to next step
          _checkStepProgress();
        },
        onError: (error) {
          if (kDebugMode) print('Location tracking error: $error');
          // Fallback to single position request
          _getCurrentPositionFallback();
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error starting location tracking: $e');
      // Fallback to single position request
      _getCurrentPositionFallback();
    }
  }

  /// Fallback method for getting current position
  Future<void> _getCurrentPositionFallback() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = position;
      _locationController.add(position);
    } catch (e) {
      if (kDebugMode) print('Fallback position request failed: $e');
    }
  }

  /// Check if we need to advance to the next navigation step
  void _checkStepProgress() {
    if (_currentRoute == null || _currentPosition == null) return;

    final currentStep = getCurrentStep();
    if (currentStep == null) return;

    final currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final distanceToStepEnd = _calculateDistance(currentLatLng, currentStep.endLocation);

    // If we're within 20 meters of the step end, advance to next step
    if (distanceToStepEnd < 20 && _currentStepIndex < _currentRoute!.steps.length - 1) {
      _currentStepIndex++;
      _stepController.add(_currentRoute!.steps[_currentStepIndex]);
      
      // Update polylines to highlight current step
      _updateStepPolylines();
      
      // Check if we've reached the destination
      if (_currentStepIndex == _currentRoute!.steps.length - 1) {
        final distanceToDestination = _calculateDistance(currentLatLng, _currentRoute!.destination);
        if (distanceToDestination < 50) {
          // We've arrived!
          _onArrival();
        }
      }
    }
  }

  /// Update polylines to highlight current step
  void _updateStepPolylines() {
    if (_currentRoute == null) return;

    final polylines = <Polyline>{};
    
    // Main route polyline
    polylines.add(Polyline(
      polylineId: const PolylineId('navigation_route'),
      points: _currentRoute!.overviewPolyline,
      color: Colors.blue,
      width: 8,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
      jointType: JointType.round,
    ));

          // Step-by-step polylines with current step highlighted
      for (int i = 0; i < _currentRoute!.steps.length; i++) {
        final step = _currentRoute!.steps[i];
        final isCurrentStep = i == _currentStepIndex;
        final isCompletedStep = i < _currentStepIndex;
        
        Color stepColor;
        int stepWidth;
        
        if (isCurrentStep) {
          stepColor = Colors.green;
          stepWidth = 12;
        } else if (isCompletedStep) {
          stepColor = Colors.green.withOpacity(0.3);
          stepWidth = 4;
        } else {
          stepColor = Colors.blue.withOpacity(0.6);
          stepWidth = 6;
        }
        
        polylines.add(Polyline(
          polylineId: PolylineId('step_$i'),
          points: step.polyline,
          color: stepColor,
          width: stepWidth,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
        ));
      }

    _polylineController.add(polylines);
  }

  /// Handle arrival at destination
  void _onArrival() async {
    // Notify arrival
    if (kDebugMode) print('Arrived at destination!');
    
    // Save arrival to visited destinations
    if (_destinationId != null && _currentPosition != null) {
      try {
        await ArrivalService.saveArrival(
          hotspotId: _destinationId!,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          destinationName: _destinationName,
          destinationCategory: _destinationCategory,
          destinationType: _destinationType,
          destinationDistrict: _destinationDistrict,
          destinationMunicipality: _destinationMunicipality,
          destinationImages: _destinationImages,
          destinationDescription: _destinationDescription,
        );
        
        if (kDebugMode) print('Arrival saved successfully for: $_destinationName');
        // Notify arrival saved
        if (_destinationName != null) {
          _arrivalController.add(_destinationName!);
        }
      } catch (e) {
        if (kDebugMode) print('Error saving arrival: $e');
      }
    }
    
    // Stop navigation after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      stopNavigation();
    });
  }

  /// Calculate distance between two points
  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degToRad(b.latitude - a.latitude);
    final double dLon = _degToRad(b.longitude - a.longitude);
    final double lat1 = _degToRad(a.latitude);
    final double lat2 = _degToRad(b.latitude);
    final double h = (1 - math.cos(dLat)) / 2 + 
                     math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Clean HTML instructions from Google Directions API
  String _cleanHtmlInstructions(String htmlInstructions) {
    // Remove HTML tags
    String clean = htmlInstructions.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities
    clean = clean.replaceAll('&nbsp;', ' ');
    clean = clean.replaceAll('&amp;', '&');
    clean = clean.replaceAll('&lt;', '<');
    clean = clean.replaceAll('&gt;', '>');
    clean = clean.replaceAll('&quot;', '"');
    return clean.trim();
  }

  /// Force re-center the map
  void forceRecenter() {
    // Notify map controller to re-center
    _locationController.add(_currentPosition!);
  }

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
    _streamGroup.close();
    _stepController.close();
    _locationController.close();
    _navigationStateController.close();
    _arrivalController.close();
    _polylineController.close();
  }
}
