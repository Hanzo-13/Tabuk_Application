// ignore_for_file: constant_identifier_names, depend_on_referenced_packages, prefer_final_fields
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added for Colors
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

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

  StreamController<NavigationStep> _stepController =
      StreamController<NavigationStep>.broadcast();
  StreamController<bool> _navigationStateController =
      StreamController<bool>.broadcast();
  StreamController<Position> _locationController =
      StreamController<Position>.broadcast();
  StreamController<String> _arrivalController =
      StreamController<String>.broadcast();

  // Stream group for better memory management
  StreamGroup _streamGroup = StreamGroup();

  // Add this new stream controller in NavigationService
  StreamController<String> _transportationModeController =
      StreamController<String>.broadcast();

  Stream<String> get transportationModeStream =>
      _transportationModeController.stream;
  Stream<NavigationStep> get stepStream => _stepController.stream;
  Stream<bool> get navigationStateStream => _navigationStateController.stream;
  Stream<Position> get locationStream => _locationController.stream;
  Stream<String> get arrivalStream => _arrivalController.stream;
  Stream<Set<Polyline>> get polylineStream => _polylineController.stream;

  NavigationRoute? _currentRoute;
  int _currentStepIndex = 0;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Stream<Position>?
  _externalLocationStream; // Location stream from MapLocationManager
  bool _isNavigating = false;
  String? _destinationName;
  String _currentTransportationMode = MODE_WALKING;
  bool _isMapRotated = true;

  // Destination information for arrival tracking
  String? get currentDestinationName => _destinationName;
  String? _destinationId;
  String? _destinationCategory;
  String? _destinationType;
  String? _destinationDistrict;
  String? _destinationMunicipality;
  List<String>? _destinationImages;
  String? _destinationDescription;

  StreamController<Set<Polyline>> _polylineController =
      StreamController<Set<Polyline>>.broadcast();

  NavigationRoute? get currentRoute => _currentRoute;
  bool get isNavigating => _isNavigating;

  // Update changeTransportationMode method
  void changeTransportationMode(String mode) {
    _currentTransportationMode = mode;

    // Emit transportation mode change to notify UI immediately
    if (!_transportationModeController.isClosed) {
      _transportationModeController.add(mode);
    }

    // Recalculate route with new mode if currently navigating
    if (_isNavigating && _currentRoute != null) {
      _recalculateRouteWithNewMode();
    }
  }

  /// Safely recreate any closed stream controllers. Returns true if any were recreated.
  bool reinitializeStreams() {
    bool recreated = false;
    if (_stepController.isClosed) {
      _stepController = StreamController<NavigationStep>.broadcast();
      recreated = true;
    }
    if (_navigationStateController.isClosed) {
      _navigationStateController = StreamController<bool>.broadcast();
      recreated = true;
    }
    if (_locationController.isClosed) {
      _locationController = StreamController<Position>.broadcast();
      recreated = true;
    }
    if (_arrivalController.isClosed) {
      _arrivalController = StreamController<String>.broadcast();
      recreated = true;
    }
    if (_polylineController.isClosed) {
      _polylineController = StreamController<Set<Polyline>>.broadcast();
      recreated = true;
    }
    if (_transportationModeController.isClosed) {
      _transportationModeController = StreamController<String>.broadcast();
      recreated = true;
    }
    // Recreate stream group if needed
    if (recreated) {
      _streamGroup = StreamGroup();
    }
    return recreated;
  }

  /// Transportation mode constants
  static const String MODE_WALKING = 'walking';
  static const String MODE_DRIVING = 'driving';
  static const String MODE_MOTORCYCLE = 'motorcycle';

  /// Get all available transportation modes
  List<String> getAvailableTransportationModes() {
    return [MODE_WALKING, MODE_DRIVING, MODE_MOTORCYCLE];
  }

  /// Get Google Maps compatible average speeds (km/h)
  /// Based on Google Maps actual assumptions and real-world data
  double _getTransportationModeSpeed(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 5.0; // Slightly faster average walking speed
      case MODE_DRIVING:
        return 45.0; // Better average for mixed urban/suburban driving
      case MODE_MOTORCYCLE:
        return 50.0; // Realistic motorcycle speed considering traffic
      default:
        return 5.0; // Default to walking
    }
  }

  /// Calculate realistic travel time based on distance and transportation mode
  /// Returns time in seconds
  double _calculateTravelTime(double distanceInMeters, String mode) {
    final speedKmh = _getTransportationModeSpeed(mode);
    final distanceKm = distanceInMeters / 1000.0;
    final timeInHours = distanceKm / speedKmh;
    return timeInHours * 3600; // Convert to seconds
  }

  /// Get transportation mode name for display
  String getTransportationModeDisplayName(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 'Walking';
      case MODE_DRIVING:
        return 'Driving';
      case MODE_MOTORCYCLE:
        return 'Motorcycle';
      default:
        return 'Walking';
    }
  }

  /// Get transportation mode icon for display
  String getTransportationModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return '🚶';
      case MODE_DRIVING:
        return '🚗';
      case MODE_MOTORCYCLE:
        return '🏍️';
      default:
        return '🚶';
    }
  }

  /// Get transportation mode color for UI
  Color getTransportationModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return Colors.green;
      case MODE_DRIVING:
        return Colors.orange;
      case MODE_MOTORCYCLE:
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  /// Convert transportation mode to API-compatible mode
  /// PRESERVED: This function is kept for future reference if API is re-enabled
  // ignore: unused_element
  String _convertToApiMode(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_MOTORCYCLE:
        return MODE_DRIVING; // Google Maps API doesn't have motorcycle mode, use driving
      case MODE_WALKING:
      case MODE_DRIVING:
        return mode.toLowerCase();
      default:
        return MODE_WALKING;
    }
  }

  /// Get step-specific detection distance based on transportation mode
  double _getStepDetectionDistance(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 15.0; // 15 meters for walking
      case MODE_DRIVING:
        return 50.0; // 50 meters for driving
      case MODE_MOTORCYCLE:
        return 45.0; // 45 meters for motorcycle
      default:
        return 15.0;
    }
  }

  /// Get arrival detection distance based on transportation mode
  double _getArrivalDetectionDistance(String mode) {
    switch (mode.toLowerCase()) {
      case MODE_WALKING:
        return 20.0; // 20 meters for walking
      case MODE_DRIVING:
        return 100.0; // 100 meters for driving
      case MODE_MOTORCYCLE:
        return 80.0; // 80 meters for motorcycle
      default:
        return 20.0;
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
  String get currentTransportationModeDisplayName =>
      getTransportationModeDisplayName(_currentTransportationMode);

  Future<void> _recalculateRouteWithNewMode() async {
    if (_currentRoute == null) return;

    try {
      final newRoute = await getDirections(
        LatLng(
          _currentRoute!.destination.latitude,
          _currentRoute!.destination.longitude,
        ),
        mode: _currentTransportationMode,
      );

      if (newRoute != null) {
        _currentRoute = newRoute;
        _currentStepIndex = 0;
        _stepController.add(_currentRoute!.steps[_currentStepIndex]);
        _createNavigationPolylines(); // Update polylines with new route
      }
    } catch (e) {
      if (kDebugMode) print('Error recalculating route: $e');
    }
  }

  /// Get turn-by-turn directions to a destination
  /// Uses OpenRouteService (free routing API) for road-based routing
  Future<NavigationRoute?> getDirections(
    LatLng destination, {
    String mode = MODE_WALKING, // Default to walking
    LatLng? origin, // Allow origin to be passed in
  }) async {
    try {
      // Get current position with timeout (if origin not provided)
      LatLng finalOrigin;
      
      if (origin != null) {
        finalOrigin = origin;
      } else {
        Position position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Location request timed out',
                const Duration(seconds: 10),
              );
            },
          );
        } catch (e) {
          if (kDebugMode) print('Error getting current position for route: $e');
          // Fallback: try with medium accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 5));
        }
        finalOrigin = LatLng(position.latitude, position.longitude);
      }
      
      if (kDebugMode) {
        print(
          'Getting route from (${finalOrigin.latitude}, ${finalOrigin.longitude}) to (${destination.latitude}, ${destination.longitude}) using OSRM',
        );
      }

      /* ============================================
         OLD GOOGLE DIRECTIONS API CODE - COMMENTED OUT
         This code is preserved for future reference if needed
         ============================================ */
      /*
      // [All the old Google API call code would be here - preserved but commented]
      */

      // NEW IMPLEMENTATION: OpenRouteService Routing (Free, Road-Based)
      // OpenRouteService is a free, open-source routing service that follows actual roads
      final route = await _getRouteFromOpenRouteService(
        finalOrigin,
        destination,
        mode,
      );

      if (route == null) {
        if (kDebugMode) print('Failed to get route from OpenRouteService');
        return null;
      }

      return route;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error getting directions: $e');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Get route from OSRM (Open Source Routing Machine)
  /// This provides road-based routing - free, no API key required
  /// OSRM follows actual roads and provides proper navigation routes
  Future<NavigationRoute?> _getRouteFromOpenRouteService(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    try {
      // Convert our mode to OSRM profile
      // OSRM supports: driving, driving-car, driving-traffic, walking, cycling
      String osrmProfile;
      switch (mode.toLowerCase()) {
        case MODE_WALKING:
          osrmProfile = 'foot';
          break;
        case MODE_DRIVING:
        case MODE_MOTORCYCLE:
          osrmProfile = 'driving';
          break;
        default:
          osrmProfile = 'foot';
      }

      // Use public OSRM server (router.project-osrm.org for global routing)
      // Format: /route/v1/{profile}/{coordinates}?overview=full&geometries=geojson
      // Coordinates format: lon1,lat1;lon2,lat2
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$osrmProfile/'
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      ).replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
        'alternatives': 'false',
      });

      if (kDebugMode) {
        print('Requesting route from OSRM...');
      }

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) print('OSRM request timed out');
          throw TimeoutException('Route request timed out');
        },
      );

      if (kDebugMode) {
        print('OSRM response status: ${response.statusCode}');
        if (response.statusCode != 200) {
          print('OSRM error response: ${response.body}');
        }
      }

      if (response.statusCode != 200) {
        // Try to parse error message for better debugging
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>?;
          final errorMsg = errorJson?['error']?.toString() ?? 
                          errorJson?['message']?.toString() ??
                          'HTTP ${response.statusCode}';
          if (kDebugMode) {
            print('OSRM error: $errorMsg');
          }
        } catch (e) {
          // Error response is not JSON
        }
        return null;
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      
      // Check for OSRM error code
      final code = jsonResponse['code'] as String?;
      if (code != null && code != 'Ok') {
        if (kDebugMode) {
          print('OSRM returned error code: $code');
          print('Message: ${jsonResponse['message']}');
        }
        return null;
      }
      
      if (jsonResponse['routes'] == null || 
          (jsonResponse['routes'] as List).isEmpty) {
        if (kDebugMode) print('No routes found in OSRM response');
        return null;
      }

      final routeData = (jsonResponse['routes'] as List).first as Map<String, dynamic>;
      
      // OSRM returns geometry - can be GeoJSON object or encoded polyline string
      // With geometries=geojson, it should return GeoJSON format
      final polylinePoints = <LatLng>[];
      
      dynamic geometryData = routeData['geometry'];
      
      if (geometryData is Map<String, dynamic>) {
        // GeoJSON format: {"type": "LineString", "coordinates": [[lon, lat], ...]}
        final coordinates = geometryData['coordinates'] as List?;
        if (coordinates != null) {
          for (final coord in coordinates) {
            if (coord is List && coord.length >= 2) {
              // GeoJSON format: [longitude, latitude]
              polylinePoints.add(LatLng(
                (coord[1] as num).toDouble(),
                (coord[0] as num).toDouble(),
              ));
            }
          }
        }
      } else if (geometryData is List) {
        // Sometimes geometry is a direct array of coordinates
        for (final coord in geometryData) {
          if (coord is List && coord.length >= 2) {
            polylinePoints.add(LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ));
          }
        }
      } else if (geometryData is String) {
        // Encoded polyline string - would need decoder, but for now fallback
        if (kDebugMode) print('OSRM returned encoded polyline, falling back to route parsing');
      }

      if (polylinePoints.isEmpty) {
        if (kDebugMode) {
          print('Warning: No coordinates extracted from OSRM geometry. Geometry type: ${geometryData.runtimeType}');
        }
        // Don't return null yet - try to get points from steps
      }

      // Parse route steps from OSRM
      final legs = routeData['legs'] as List<dynamic>?;
      final steps = <NavigationStep>[];
      double totalDistance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
      // Calculate total duration based on mode-specific speeds, not OSRM's duration
      // This ensures accurate time calculations that change with transportation mode
      double totalDuration = totalDistance > 0 
          ? _calculateTravelTime(totalDistance, mode)
          : 0.0;

      // Parse steps from legs if available
      if (legs != null && legs.isNotEmpty) {
        for (final leg in legs) {
          final legData = leg as Map<String, dynamic>;
          final legSteps = legData['steps'] as List<dynamic>? ?? [];
          
          for (final stepData in legSteps) {
            final step = stepData as Map<String, dynamic>;
            final stepDistance = (step['distance'] as num?)?.toDouble() ?? 0.0;
            // Recalculate duration based on transportation mode instead of using OSRM's duration
            // This ensures the time updates correctly when switching between walking, bike, and car
            final stepDuration = stepDistance > 0
                ? _calculateTravelTime(stepDistance, mode)
                : 0.0;
            final stepGeometry = step['geometry'] as Map<String, dynamic>?;
            final maneuver = step['maneuver'] as Map<String, dynamic>?;
            
            // Extract instruction from maneuver
            String instruction = 'Continue';
            if (maneuver != null) {
              final maneuverType = maneuver['type'] as String? ?? '';
              final modifier = maneuver['modifier'] as String? ?? '';
              if (modifier.isNotEmpty && maneuverType.isNotEmpty) {
                instruction = '$modifier $maneuverType';
              } else if (maneuverType.isNotEmpty) {
                instruction = maneuverType;
              }
            }
            
            // Extract step polyline and accumulate into main polyline
            List<LatLng> stepPolyline = [];
            if (stepGeometry != null && stepGeometry['coordinates'] != null) {
              final stepCoords = stepGeometry['coordinates'] as List;
              for (final coord in stepCoords) {
                if (coord is List && coord.length >= 2) {
                  final point = LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  );
                  stepPolyline.add(point);
                  
                  // Add to main polyline if not duplicate
                  if (polylinePoints.isEmpty || 
                      !polylinePoints.any((p) => _calculateDistance(p, point) < 5)) {
                    polylinePoints.add(point);
                  }
                }
              }
            }
            
            // If no step polyline, use portion of main polyline
            if (stepPolyline.isEmpty && steps.length < polylinePoints.length) {
              final ratio = steps.length / (legSteps.length + 1);
              final startIdx = (ratio * polylinePoints.length).floor();
              final endIdx = (((steps.length + 1) / (legSteps.length + 1)) * polylinePoints.length).floor()
                  .clamp(startIdx + 1, polylinePoints.length);
              if (endIdx <= polylinePoints.length) {
                stepPolyline = polylinePoints.sublist(startIdx, endIdx);
              }
            }
            
            // Final fallback
            if (stepPolyline.isEmpty) {
              stepPolyline = steps.isEmpty 
                  ? [origin, polylinePoints.length > 1 ? polylinePoints[1] : destination]
                  : [steps.last.endLocation, destination];
            }

            steps.add(
              NavigationStep(
                instruction: instruction,
                maneuver: maneuver?['type']?.toString(),
                distance: stepDistance,
                duration: stepDuration,
                startLocation: stepPolyline.isNotEmpty ? stepPolyline.first : origin,
                endLocation: stepPolyline.isNotEmpty ? stepPolyline.last : destination,
                polyline: stepPolyline,
              ),
            );
          }
        }
        
        // Recalculate totalDuration as sum of all step durations to ensure accuracy
        // This ensures the total time reflects mode-specific calculations
        totalDuration = steps.fold(0.0, (sum, step) => sum + step.duration);
        // Also recalculate totalDistance from steps for consistency
        totalDistance = steps.fold(0.0, (sum, step) => sum + step.distance);
      }

      // Build polyline from step geometries if route-level geometry is missing
      if (polylinePoints.isEmpty && steps.isNotEmpty) {
        // Accumulate all step polyline points
        for (final step in steps) {
          for (final point in step.polyline) {
            // Avoid duplicates by checking proximity
            bool isDuplicate = false;
            for (final existingPoint in polylinePoints) {
              if (_calculateDistance(existingPoint, point) < 5) { // Within 5 meters
                isDuplicate = true;
                break;
              }
            }
            if (!isDuplicate) {
              polylinePoints.add(point);
            }
          }
        }
        
        if (kDebugMode && polylinePoints.isNotEmpty) {
          print('Built polyline from ${steps.length} step geometries: ${polylinePoints.length} points');
        }
      }
      
      if (polylinePoints.isEmpty) {
        if (kDebugMode) {
          print('Warning: No geometry points extracted from OSRM response');
        }
      }

      // If no steps were created, create a single step for the entire route
      if (steps.isEmpty) {
        double routeDistance;
        double routeDuration;
        List<LatLng> routePolyline;
        
        if (polylinePoints.isNotEmpty) {
          // Calculate actual route distance along the polyline
          routeDistance = 0.0;
          for (int i = 0; i < polylinePoints.length - 1; i++) {
            routeDistance += _calculateDistance(polylinePoints[i], polylinePoints[i + 1]);
          }
          routeDuration = _calculateTravelTime(routeDistance, mode);
          routePolyline = polylinePoints;
        } else {
          // Fallback: calculate straight-line distance
          routeDistance = _calculateDistance(origin, destination);
          routeDuration = _calculateTravelTime(routeDistance, mode);
          routePolyline = [origin, destination];
          if (kDebugMode) {
            print('Warning: Using straight-line fallback due to missing route geometry');
          }
        }
        
        steps.add(
          NavigationStep(
            instruction: 'Follow the route to destination',
            maneuver: null,
            distance: routeDistance,
            duration: routeDuration,
            startLocation: origin,
            endLocation: destination,
            polyline: routePolyline,
          ),
        );
        
        totalDistance = routeDistance;
        totalDuration = routeDuration;
        
        // Ensure polylinePoints is set for the route overview
        if (polylinePoints.isEmpty) {
          polylinePoints.addAll(routePolyline);
        }
      }

      // Final check: ensure we have at least origin and destination in polyline
      if (polylinePoints.isEmpty) {
        polylinePoints.addAll([origin, destination]);
      }

      if (kDebugMode) {
        print(
          'Got route from OSRM: ${polylinePoints.length} points, '
          '${steps.length} steps, distance=${totalDistance.toStringAsFixed(0)}m, '
          'duration=${(totalDuration / 60).toStringAsFixed(1)}min',
        );
      }

      // Create and return the navigation route
      final navigationRoute = NavigationRoute(
        steps: steps,
        totalDistance: totalDistance,
        totalDuration: totalDuration,
        overviewPolyline: polylinePoints,
        origin: origin,
        destination: destination,
        travelMode: mode,
      );

      return navigationRoute;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error getting route from OpenRouteService: $e');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Set the external location stream (from MapLocationManager)
  /// This should be called before starting navigation to avoid duplicate GPS listeners
  void setLocationStream(Stream<Position> locationStream) {
    _externalLocationStream = locationStream;
    if (kDebugMode) {
      print('NavigationService: External location stream set');
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
    String mode = MODE_WALKING, Map<String, dynamic>? destinationData, LatLng? origin, // Default to walking
  }) async {
    try {
      // If streams were previously closed via dispose, reinitialize them safely
      if (_navigationStateController.isClosed ||
          _stepController.isClosed ||
          _polylineController.isClosed ||
          _transportationModeController.isClosed ||
          _locationController.isClosed ||
          _arrivalController.isClosed) {
        final recreated = reinitializeStreams();
        if (kDebugMode && recreated) {
          print('NavigationService streams reinitialized');
        }
      }
      if (kDebugMode) {
        print(
          'Starting navigation to: ${destination.latitude}, ${destination.longitude}',
        );
      }

      // Check location permissions first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) print('Location permission denied for navigation');
        return false;
      }

      final route = await getDirections(destination, mode: mode, origin: origin);
      if (route == null) {
        if (kDebugMode) print('Failed to get directions');
        return false;
      }

      if (kDebugMode) print('Got route with ${route.steps.length} steps');

      _currentRoute = route;
      _currentStepIndex = 0;
      _isNavigating = true;

      // Store destination information for arrival tracking
      _destinationId = destinationId;
      _destinationName = destinationName;
      _destinationCategory = destinationCategory;
      _destinationType = destinationType;
      _destinationDistrict = destinationDistrict;
      _destinationMunicipality = destinationMunicipality;
      _destinationImages = destinationImages;
      _destinationDescription = destinationDescription;

      // Start location tracking (subscribes to external stream if available)
      await _startLocationTracking();

      // Create navigation polylines
      _createNavigationPolylines();

      // Notify navigation started
      if (!_navigationStateController.isClosed) {
        _navigationStateController.add(true);
      }
      if (!_stepController.isClosed) {
        _stepController.add(route.steps[0]);
      }

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

    // Main route polyline (use current transportation mode color consistently)
    polylines.add(
      Polyline(
        polylineId: const PolylineId('navigation_route'),
        points: _currentRoute!.overviewPolyline,
        color: getTransportationModeColor(_currentTransportationMode),
        width: 8,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    );

    // Step-by-step polylines for better visualization
    for (int i = 0; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      polylines.add(
        Polyline(
          polylineId: PolylineId('step_$i'),
          points: step.polyline,
          // Use the same color for all segments; emphasize current step by width only
          color: getTransportationModeColor(
            _currentTransportationMode,
          ).withOpacity(i == 0 ? 1.0 : 0.6),
          width: i == 0 ? 10 : 6,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    _polylineController.add(polylines);
  }

  /// Stop navigation
  void stopNavigation() {
    _currentRoute = null;
    _currentStepIndex = 0;
    _isNavigating = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Clear destination information
    _destinationId = null;
    _destinationName = null;
    _destinationCategory = null;
    _destinationType = null;
    _destinationDistrict = null;
    _destinationMunicipality = null;
    _destinationImages = null;
    _destinationDescription = null;

    // Clear polylines if controller is still open
    if (!_polylineController.isClosed) {
      _polylineController.add({});
    }
    if (!_navigationStateController.isClosed) {
      _navigationStateController.add(false);
    }
  }

  /// Get current navigation step
  NavigationStep? getCurrentStep() {
    if (_currentRoute == null ||
        _currentStepIndex >= _currentRoute!.steps.length) {
      return null;
    }
    return _currentRoute!.steps[_currentStepIndex];
  }

  /// Get next navigation step
  NavigationStep? getNextStep() {
    if (_currentRoute == null ||
        _currentStepIndex + 1 >= _currentRoute!.steps.length) {
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

  /// Start location tracking - subscribes to external location stream (MapLocationManager)
  /// This avoids duplicate GPS listeners. Falls back to own listener only if no external stream provided.
  Future<void> _startLocationTracking() async {
    try {
      // Cancel previous subscription if any
      await _positionStreamSubscription?.cancel();

      // Prefer external location stream from MapLocationManager (single source of truth)
      if (_externalLocationStream != null) {
        if (kDebugMode) {
          print(
            'NavigationService: Subscribing to external location stream (MapLocationManager)',
          );
        }

        _positionStreamSubscription = _externalLocationStream!.listen(
          (Position position) {
            _currentPosition = position;
            // Emit to location controller for any other listeners
            if (!_locationController.isClosed) {
              _locationController.add(position);
            }
            // Check if we need to advance to next step
            _checkStepProgress();
          },
          onError: (error) {
            if (kDebugMode) print('External location stream error: $error');
          },
        );
      } else {
        // Fallback: Create own listener only if no external stream provided
        // This should rarely happen if properly initialized
        if (kDebugMode) {
          print(
            'NavigationService: WARNING - No external location stream. Creating own listener (not recommended)',
          );
        }

        LocationSettings locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );

        _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (Position position) {
            _currentPosition = position;
            if (!_locationController.isClosed) {
              _locationController.add(position);
            }
            _checkStepProgress();
          },
          onError: (error) {
            if (kDebugMode) print('Location tracking error: $error');
            _getCurrentPositionFallback();
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error starting location tracking: $e');
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

    final currentLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    // Check for route deviation first
    _checkRouteDeviation(currentLatLng);

    final distanceToStepEnd = _calculateDistance(
      currentLatLng,
      currentStep.endLocation,
    );

    // Use transportation mode specific detection distance
    final detectionDistance = _getStepDetectionDistance(
      _currentTransportationMode,
    );

    // If we're within detection distance of the step end, advance to next step
    if (distanceToStepEnd < detectionDistance &&
        _currentStepIndex < _currentRoute!.steps.length - 1) {
      _currentStepIndex++;
      _stepController.add(_currentRoute!.steps[_currentStepIndex]);

      // Update polylines to highlight current step (removes completed ones)
      _updateStepPolylines();

      if (kDebugMode) {
        print(
          'Advanced to step ${_currentStepIndex + 1}/${_currentRoute!.steps.length}',
        );
      }

      // Check if we've reached the destination
      if (_currentStepIndex == _currentRoute!.steps.length - 1) {
        final distanceToDestination = _calculateDistance(
          currentLatLng,
          _currentRoute!.destination,
        );

        final arrivalDistance = _getArrivalDetectionDistance(
          _currentTransportationMode,
        );

        if (distanceToDestination < arrivalDistance) {
          // We've arrived!
          _onArrival();
        }
      }
    }
  }

  /// Check if user has deviated from the route and trigger re-routing
  void _checkRouteDeviation(LatLng currentPosition) {
    if (_currentRoute == null) return;

    // Find the minimum distance from current position to any point on the route
    double minDistanceToRoute = double.infinity;

    // Check distance to overview polyline
    for (int i = 0; i < _currentRoute!.overviewPolyline.length - 1; i++) {
      final p1 = _currentRoute!.overviewPolyline[i];
      final p2 = _currentRoute!.overviewPolyline[i + 1];
      final distance = _distanceToSegment(currentPosition, p1, p2);
      if (distance < minDistanceToRoute) {
        minDistanceToRoute = distance;
      }
    }

    // Also check distance to current step's polyline
    final currentStep = getCurrentStep();
    if (currentStep != null && currentStep.polyline.isNotEmpty) {
      for (int i = 0; i < currentStep.polyline.length - 1; i++) {
        final p1 = currentStep.polyline[i];
        final p2 = currentStep.polyline[i + 1];
        final distance = _distanceToSegment(currentPosition, p1, p2);
        if (distance < minDistanceToRoute) {
          minDistanceToRoute = distance;
        }
      }
    }

    // Threshold for deviation detection (varies by transportation mode)
    double deviationThreshold;
    switch (_currentTransportationMode.toLowerCase()) {
      case MODE_WALKING:
        deviationThreshold = 30.0; // 30 meters for walking
        break;
      case MODE_DRIVING:
        deviationThreshold = 100.0; // 100 meters for driving
        break;
      case MODE_MOTORCYCLE:
        deviationThreshold = 80.0; // 80 meters for motorcycle
        break;
      default:
        deviationThreshold = 30.0;
    }

    // If user has deviated significantly, trigger re-routing
    if (minDistanceToRoute > deviationThreshold && !_isRecalculatingRoute) {
      if (kDebugMode) {
        print(
          'Route deviation detected: ${minDistanceToRoute.toStringAsFixed(1)}m. Re-routing...',
        );
      }
      _recalculateRouteFromCurrentPosition();
    }
  }

  bool _isRecalculatingRoute = false;

  /// Recalculate route from current position to destination
  Future<void> _recalculateRouteFromCurrentPosition() async {
    if (_currentRoute == null || _isRecalculatingRoute) return;

    _isRecalculatingRoute = true;

    try {
      final newRoute = await getDirections(
        _currentRoute!.destination,
        mode: _currentTransportationMode,
      );

      if (newRoute != null) {
        _currentRoute = newRoute;
        _currentStepIndex = 0;

        // Update step controller with new current step
        if (!_stepController.isClosed) {
          _stepController.add(_currentRoute!.steps[_currentStepIndex]);
        }

        // Update polylines with new route
        _updateStepPolylines();

        if (kDebugMode) {
          print(
            'Route recalculated successfully with ${newRoute.steps.length} steps',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error recalculating route: $e');
    } finally {
      // Reset flag after a delay to avoid rapid re-routing
      Future.delayed(const Duration(seconds: 3), () {
        _isRecalculatingRoute = false;
      });
    }
  }

  /// Calculate distance from a point to a line segment
  double _distanceToSegment(LatLng point, LatLng segStart, LatLng segEnd) {
    final A = point.latitude - segStart.latitude;
    final B = point.longitude - segStart.longitude;
    final C = segEnd.latitude - segStart.latitude;
    final D = segEnd.longitude - segStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    var param = -1.0;
    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = segStart.latitude;
      yy = segStart.longitude;
    } else if (param > 1) {
      xx = segEnd.latitude;
      yy = segEnd.longitude;
    } else {
      xx = segStart.latitude + param * C;
      yy = segStart.longitude + param * D;
    }

    return _calculateDistance(point, LatLng(xx, yy));
  }

  /// Update polylines to highlight current step - removes completed polylines
  void _updateStepPolylines() {
    if (_currentRoute == null) return;

    final polylines = <Polyline>{};

    // Main route polyline (show remaining route only)
    // Calculate remaining route points from current step onwards
    List<LatLng> remainingRoute = [];

    // Add points from current and future steps only
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      if (i == _currentStepIndex) {
        // Start from current position if available, otherwise from current step start
        if (_currentPosition != null) {
          remainingRoute.add(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          );
        }
        remainingRoute.addAll(_currentRoute!.steps[i].polyline);
      } else {
        remainingRoute.addAll(_currentRoute!.steps[i].polyline);
      }
    }

    // Add destination if not already included
    if (remainingRoute.isEmpty ||
        remainingRoute.last.latitude != _currentRoute!.destination.latitude ||
        remainingRoute.last.longitude != _currentRoute!.destination.longitude) {
      remainingRoute.add(_currentRoute!.destination);
    }

    // Main route polyline (remaining route)
    if (remainingRoute.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: remainingRoute,
          color: getTransportationModeColor(_currentTransportationMode),
          width: 8,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    // Only show current step and upcoming steps (no completed steps)
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      final isCurrentStep = i == _currentStepIndex;

      Color stepColor;
      int stepWidth;

      if (isCurrentStep) {
        // Current step in green with bold width
        stepColor = Colors.green;
        stepWidth = 12;
      } else {
        // Upcoming steps in transportation mode color with reduced opacity
        stepColor = getTransportationModeColor(
          _currentTransportationMode,
        ).withOpacity(0.6);
        stepWidth = 6;
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('step_$i'),
          points: step.polyline,
          color: stepColor,
          width: stepWidth,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    _polylineController.add(polylines);
  }

  /// Handle arrival at destination
  void _onArrival() async {
    // Notify arrival
    if (kDebugMode) print('Arrived at destination!');

    // Save arrival to visited destinations
    // Only save if we have valid destination ID and position, and destination name is not null/unknown
    if (_destinationId != null && 
        _currentPosition != null &&
        _destinationName != null &&
        _destinationName!.isNotEmpty &&
        _destinationName! != 'Unknown Destination') {
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

        if (kDebugMode) {
          print('Arrival saved successfully for: $_destinationName');
        }

        // Notify arrival saved
        _arrivalController.add(_destinationName!);
      } catch (e) {
        if (kDebugMode) print('Error saving arrival: $e');
      }
    } else {
      if (kDebugMode) {
        print('Cannot save arrival: Missing required destination data. '
              'ID: $_destinationId, Name: $_destinationName');
      }
    }

    // Stop navigation after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      stopNavigation();
    });
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degToRad(b.latitude - a.latitude);
    final double dLon = _degToRad(b.longitude - a.longitude);
    final double lat1 = _degToRad(a.latitude);
    final double lat2 = _degToRad(b.latitude);

    final double h =
        (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;

    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Clean HTML instructions from Google Directions API
  /// PRESERVED: This function is kept for future reference if API is re-enabled
  // ignore: unused_element
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
    if (_currentPosition != null) {
      // Notify map controller to re-center
      _locationController.add(_currentPosition!);
    }
  }

  /// Get estimated time for a given distance and transportation mode
  /// Useful for UI displays and planning
  String getEstimatedTimeString(double distanceInMeters, String mode) {
    final timeInSeconds = _calculateTravelTime(distanceInMeters, mode);
    final hours = (timeInSeconds / 3600).floor();
    final minutes = ((timeInSeconds % 3600) / 60).round();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get speed for current transportation mode (for UI display)
  String getCurrentModeSpeedInfo() {
    final speed = _getTransportationModeSpeed(_currentTransportationMode);
    return '~${speed.toStringAsFixed(1)} km/h';
  }

  /// Dispose resources
  void dispose() {
    // Prefer stopping navigation and cancelling subscriptions
    stopNavigation();
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    // Close controllers only if really tearing down
    if (!_streamGroup.isClosed) _streamGroup.close();
    if (!_stepController.isClosed) _stepController.close();
    if (!_locationController.isClosed) _locationController.close();
    if (!_navigationStateController.isClosed) {
      _navigationStateController.close();
    }
    if (!_arrivalController.isClosed) _arrivalController.close();
    if (!_polylineController.isClosed) _polylineController.close();
    if (!_transportationModeController.isClosed) {
      _transportationModeController.close();
    }
  }

  void updateBearing(double bearing) {}
}
