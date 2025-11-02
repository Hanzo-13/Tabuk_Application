import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:capstone_app/utils/colors.dart';
// Optional: API key can be provided via --dart-define=GOOGLE_MAPS_API_KEY=...
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Manages navigation features including directions, camera updates, and route display
class MapNavigationManager {
  final NavigationService navigationService;
  final ConnectivityService connectivityService;

  final Function(bool) onNavigationStateChanged;
  final Function(Set<Polyline>) onPolylinesChanged;
  final Function() onStateUpdated;

  StreamSubscription? _polylineSubscription;
  StreamSubscription? _navigationStateSubscription;

  // Track the active destination to validate/complement the route polyline
  LatLng? _activeDestination;
  // LatLng? _activeOrigin; // not used currently

  String? get currentDestinationName => navigationService.currentDestinationName;

  MapNavigationManager({
    required this.navigationService,
    required this.connectivityService,
    required this.onNavigationStateChanged,
    required this.onPolylinesChanged,
    required this.onStateUpdated,
  });

  /// Sets up listeners to the NavigationService.
  void init() {
    // Listen for changes in navigation state (start/stop)
    _navigationStateSubscription = navigationService.navigationStateStream.listen((isNavigating) {
      onNavigationStateChanged(isNavigating);
      onStateUpdated(); // Trigger a UI rebuild
    });

    // Listen for new polylines and pass them to the UI
    _polylineSubscription = navigationService.polylineStream.listen((polylines) {
      // 1) Smooth polylines for a natural look with point-thinning to ensure rendering
      final smoothed = _smoothPolylines(polylines);
      // 2) Ensure the route visually reaches the precise destination point
      final fixed = _ensurePolylineCompletesToDestination(smoothed);
      // Debug: counts to help diagnose rendering
      try {
        int totalPts = 0; for (final p in fixed) { totalPts += p.points.length; }
        // ignore: avoid_print
        print('Route polylines: ${fixed.length}, total points: $totalPts');
      } catch (_) {}
      onPolylinesChanged(fixed);
    });
  }

  /// Start the navigation process.
  Future<void> startNavigation(
    BuildContext context, // Pass context for showing dialogs
    LatLng destination, {
    Map<String, dynamic>? destinationData,
  }) async {
    final connectivityInfo = await connectivityService.checkConnection();
    if (connectivityInfo.status != ConnectionStatus.connected) {
      if (context.mounted) _showOfflineDialog(context);
      return;
    }

    // Show a loading indicator on the screen while the route is being calculated.
    // Note: With direct line routing, this will be very fast, but kept for UX consistency
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Calculating route...')),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Get current position for origin
    LatLng? origin;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      origin = LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current position for navigation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get your current location. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Extract destination information from destinationData if provided
    String? destinationId;
    String? destinationName;
    String? destinationCategory;
    String? destinationType;
    String? destinationDistrict;
    String? destinationMunicipality;
    List<String>? destinationImages;
    String? destinationDescription;
    
    if (destinationData != null) {
      destinationId = destinationData['hotspot_id']?.toString() ?? 
                      destinationData['id']?.toString();
      destinationName = destinationData['destinationName']?.toString() ?? 
                       destinationData['business_name']?.toString() ?? 
                       destinationData['name']?.toString();
      destinationCategory = destinationData['destinationCategory']?.toString() ?? 
                            destinationData['category']?.toString();
      destinationType = destinationData['destinationType']?.toString() ?? 
                       destinationData['type']?.toString();
      destinationDistrict = destinationData['destinationDistrict']?.toString() ?? 
                           destinationData['district']?.toString();
      destinationMunicipality = destinationData['destinationMunicipality']?.toString() ?? 
                                destinationData['municipality']?.toString();
      
      // Handle images - could be a List or a single value
      if (destinationData['destinationImages'] != null) {
        if (destinationData['destinationImages'] is List) {
          destinationImages = (destinationData['destinationImages'] as List)
              .map((e) => e.toString()).toList();
        } else {
          destinationImages = [destinationData['destinationImages'].toString()];
        }
      } else if (destinationData['images'] != null) {
        if (destinationData['images'] is List) {
          destinationImages = (destinationData['images'] as List)
              .map((e) => e.toString()).toList();
        } else {
          destinationImages = [destinationData['images'].toString()];
        }
      }
      
      destinationDescription = destinationData['destinationDescription']?.toString() ?? 
                               destinationData['description']?.toString();
    }

    // Save active endpoints for validation and visual completion of the route
    // _activeOrigin = origin;
    _activeDestination = destination;

    // Use routing service (OpenRouteService/OSRM via NavigationService)
    bool success = await navigationService.startNavigation(
      destination,
      origin: origin,
      destinationId: destinationId,
      destinationName: destinationName,
      destinationCategory: destinationCategory,
      destinationType: destinationType,
      destinationDistrict: destinationDistrict,
      destinationMunicipality: destinationMunicipality,
      destinationImages: destinationImages,
      destinationDescription: destinationDescription,
      mode: navigationService.currentTransportationMode,
      destinationData: destinationData,
    );

    // Retry once if it failed (transient API issues)
    if (!success) {
      await Future.delayed(const Duration(milliseconds: 500));
      success = await navigationService.startNavigation(
        destination,
        origin: origin,
        destinationId: destinationId,
        destinationName: destinationName,
        destinationCategory: destinationCategory,
        destinationType: destinationType,
        destinationDistrict: destinationDistrict,
        destinationMunicipality: destinationMunicipality,
        destinationImages: destinationImages,
        destinationDescription: destinationDescription,
        mode: navigationService.currentTransportationMode,
        destinationData: destinationData,
      );
    }
    
    // Hide loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    
    if (!success) {
      // Try Google Directions as a highly accurate road-following fallback
      Set<Polyline>? googleRoute = await _tryGoogleDirections(
        origin,
        destination,
        mode: navigationService.currentTransportationMode,
      );
      if (googleRoute != null) {
        final smoothed = _smoothPolylines(googleRoute);
        final fixed = _ensurePolylineCompletesToDestination(smoothed);
        onPolylinesChanged(fixed);
        print('✅ Using Google Directions API');
      } else if (context.mounted) {
        // Final fallback: direct line
        print('⚠️ Google Directions failed, using direct line');
        final direct = _buildDirectPolyline(origin: origin, destination: destination);
        onPolylinesChanged({direct});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using fallback route. Internet may be unstable.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    
    // The listeners set up in init() will handle updating the UI state.
    onStateUpdated();
  }

  /// Exit navigation.
  void exitNavigation() {
    navigationService.stopNavigation();
  }

  

  /// Re-center map on user location during navigation.
  void recenterMap(GoogleMapController? controller, LatLng? currentLocation, double currentBearing) {
    if (controller == null || currentLocation == null) return;
    
    final currentStep = navigationService.getCurrentStep();
    double bearing = 0;
    if(currentStep != null) {
      bearing = _calculateBearing(currentLocation, currentStep.endLocation);
    }

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLocation,
          zoom: 18.5,
          bearing: bearing,
          tilt: 60.0,
        ),
      ),
    );
  }

  /// Show navigation preview modal.
  void showNavigationPreview(
    BuildContext context,
    LatLng destination,
    Map<String, dynamic>? destinationData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NavigationPreviewModal(
        onStartNavigation: () {
          Navigator.pop(ctx);
          startNavigation(context, destination, destinationData: destinationData);
        },
      ),
    );
  }

  void dispose() {
    _polylineSubscription?.cancel();
    _navigationStateSubscription?.cancel();
  }

  void _showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('No Internet Connection'),
              ],
            ),
            content: const Text(
              'Turn-by-turn navigation requires an internet connection. Please check your connection and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final dLon = (end.longitude - start.longitude) * (math.pi / 180);

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x) * (180 / math.pi);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  // If the service polyline ends short, append a final segment to the exact destination.
  Set<Polyline> _ensurePolylineCompletesToDestination(Set<Polyline> polylines) {
    if (polylines.isEmpty || _activeDestination == null) return polylines;

    // Merge all points from visible route polylines
    final allPoints = <LatLng>[];
    for (final p in polylines) {
      if (p.points.isNotEmpty) allPoints.addAll(p.points);
    }
    if (allPoints.isEmpty) return polylines;

    final last = allPoints.last;
    final dest = _activeDestination!;
    final double endGap = _haversineMeters(last, dest);

    // If the final point is more than 20m away, add a short connector polyline
    if (endGap > 20) {
      final base = polylines.first; // mimic main route style
      final connectorPoints = _interpolatePoints(last, dest, stepMeters: 12);
      final connector = Polyline(
        polylineId: const PolylineId('connector_to_destination'),
        points: connectorPoints,
        color: base.color,
        width: base.width,
        geodesic: true,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
      );
      final fixed = polylines.toSet();
      fixed.add(connector);
      return fixed;
    }

    return polylines;
  }

  Polyline _buildDirectPolyline({required LatLng? origin, required LatLng destination}) {
    final start = origin ?? destination; // degenerate safe
    final pts = _interpolatePoints(start, destination, stepMeters: 12);
    return Polyline(
      polylineId: const PolylineId('direct_fallback'),
      points: pts,
      color: Colors.green,
      width: 6,
      geodesic: true,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLon = (b.longitude - a.longitude) * (math.pi / 180);
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    return 2 * r * math.asin(math.sqrt(h));
  }

  // Create intermediate points between a and b every stepMeters to smooth the segment
  List<LatLng> _interpolatePoints(LatLng a, LatLng b, {double stepMeters = 10}) {
    final distance = _haversineMeters(a, b);
    if (distance <= stepMeters) return [a, b];
    final steps = (distance / stepMeters).ceil();
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lng = a.longitude + (b.longitude - a.longitude) * t;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  // ---- Natural route smoothing (Catmull-Rom) ----
  Set<Polyline> _smoothPolylines(Set<Polyline> polylines) {
    if (polylines.isEmpty) return polylines;
    final result = <Polyline>{};
    for (final p in polylines) {
      if (p.points.length < 3) {
        result.add(p);
        continue;
      }
      // If the route is very dense, decimate first to keep under platform limits
      final basePts = p.points.length > 1200 ? _decimateByDistance(p.points, 12) : p.points;
      final smoothed = _smoothRoutePoints(basePts);
      result.add(Polyline(
        polylineId: p.polylineId,
        points: smoothed,
        color: p.color,
        width: p.width,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        consumeTapEvents: p.consumeTapEvents,
        visible: p.visible,
        patterns: p.patterns,
        zIndex: p.zIndex,
      ));
    }
    return result;
  }

  List<LatLng> _smoothRoutePoints(List<LatLng> points) {
    if (points.length < 3) return points;
    final smoothedPoints = <LatLng>[];
    smoothedPoints.add(points.first);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;
      // Fewer segments for very long routes to avoid huge point counts
      final segments = points.length > 800 ? 3 : 6;
      for (int j = 1; j <= segments; j++) {
        final t = j / segments;
        smoothedPoints.add(_catmullRomInterpolate(p0, p1, p2, p3, t));
      }
    }
    return smoothedPoints;
  }

  LatLng _catmullRomInterpolate(LatLng p0, LatLng p1, LatLng p2, LatLng p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final lat = 0.5 *
        ((2 * p1.latitude) +
            (-p0.latitude + p2.latitude) * t +
            (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2 +
            (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3);
    final lng = 0.5 *
        ((2 * p1.longitude) +
            (-p0.longitude + p2.longitude) * t +
            (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2 +
            (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3);
    return LatLng(lat, lng);
  }

  // Reduce points by keeping one approximately every stepMeters along the path
  List<LatLng> _decimateByDistance(List<LatLng> points, double stepMeters) {
    if (points.length <= 2) return points;
    final out = <LatLng>[];
    LatLng lastKept = points.first;
    out.add(lastKept);
    double sinceLast = 0;
    for (int i = 1; i < points.length; i++) {
      final d = _haversineMeters(lastKept, points[i]);
      sinceLast += d;
      if (sinceLast >= stepMeters) {
        out.add(points[i]);
        lastKept = points[i];
        sinceLast = 0;
      }
    }
    if (out.last != points.last) out.add(points.last);
    return out;
  }

  // ---- Google Directions Fallback ----
  Future<Set<Polyline>?> _tryGoogleDirections(LatLng origin, LatLng dest, {required String mode}) async {
    try {
      // API key configured in AppConstants.googleDirectionsApiKey
      final key = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
      if (key.isEmpty) return null;

      final googleMode = _toGoogleMode(mode);
      final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&mode=$googleMode&alternatives=false&key=$key');

      final client = HttpClient();
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      client.close();

      // Very lightweight JSON parsing without adding dependencies
      // We only need the overview_polyline.points content
      final match = RegExp(r'"overview_polyline"\s*:\s*\{\s*"points"\s*:\s*"([^\"]+)"')
          .firstMatch(body);
      if (match == null) return null;
      final encoded = match.group(1)!;
      final points = _decodeGooglePolyline(encoded);
      if (points.length < 2) return null;

      final polyline = Polyline(
        polylineId: const PolylineId('google_directions'),
        points: points,
        color: AppColors.primaryTeal,
        width: 6,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      );
      return {polyline};
    } catch (_) {
      return null;
    }
  }

  String _toGoogleMode(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('walk')) return 'walking';
    if (m.contains('bike') || m.contains('bicycle')) return 'bicycling';
    if (m.contains('transit') || m.contains('bus') || m.contains('train')) return 'transit';
    return 'driving';
  }

  List<LatLng> _decodeGooglePolyline(String encoded) {
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    final List<LatLng> points = [];

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

/// Navigation Preview Modal Widget
class _NavigationPreviewModal extends StatelessWidget {
  final VoidCallback onStartNavigation;

  const _NavigationPreviewModal({required this.onStartNavigation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // Navigation icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation,
              size: 48,
              color: AppColors.primaryTeal,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Start Navigation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Get turn-by-turn directions to this destination',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),
          
          // Start button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Start Navigation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


  