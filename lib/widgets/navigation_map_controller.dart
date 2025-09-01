import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:geolocator/geolocator.dart';

class NavigationMapController extends StatefulWidget {
  final GoogleMapController mapController;
  final NavigationService navigationService;
  final Set<Polyline> polylines;
  final Function(Set<Polyline>) onPolylinesChanged;

  const NavigationMapController({
    super.key,
    required this.mapController,
    required this.navigationService,
    required this.polylines,
    required this.onPolylinesChanged,
  });

  @override
  State<NavigationMapController> createState() => _NavigationMapControllerState();
}

class _NavigationMapControllerState extends State<NavigationMapController> {
  bool _isNavigating = false;
  NavigationRoute? _currentRoute;
  StreamSubscription<bool>? _navigationStateSubscription;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _listenToNavigationUpdates();
  }

  void _listenToNavigationUpdates() {
    // Listen to navigation state changes
    _navigationStateSubscription = widget.navigationService.navigationStateStream.listen((isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = isNavigating;
        });
        
        if (isNavigating) {
          _currentRoute = widget.navigationService.currentRoute;
          _showRouteOnMap();
        } else {
          _clearRouteFromMap();
        }
      }
    });

    // Listen to location updates during navigation
    _locationSubscription = widget.navigationService.locationStream.listen((position) {
      if (mounted && _isNavigating) {
        _followUserPosition(position);
      }
    });
  }

  void _showRouteOnMap() async {
    if (_currentRoute == null) return;

    try {
      // Create simple route polyline
      final newPolylines = <Polyline>{};
      
      newPolylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _currentRoute!.overviewPolyline,
        color: Colors.blue,
        width: 6,
      ));

      widget.onPolylinesChanged(newPolylines);

      // Show entire route
      await _showEntireRoute();
    } catch (e) {
      debugPrint('Error showing route: $e');
    }
  }

  void _clearRouteFromMap() async {
    try {
      // Remove route polylines
      final newPolylines = <Polyline>{};
      
      // Keep only non-route polylines
      for (final polyline in widget.polylines) {
        if (!polyline.polylineId.value.startsWith('route')) {
          newPolylines.add(polyline);
        }
      }

      widget.onPolylinesChanged(newPolylines);

      // Reset camera
      await widget.mapController.animateCamera(
        CameraUpdate.zoomTo(14.0),
      );
    } catch (e) {
      debugPrint('Error clearing route: $e');
    }
  }

  Future<void> _showEntireRoute() async {
    if (_currentRoute == null || _currentRoute!.overviewPolyline.isEmpty) return;

    try {
      final bounds = _calculateBounds(_currentRoute!.overviewPolyline);
      await widget.mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      debugPrint('Error showing entire route: $e');
    }
  }

  void _followUserPosition(Position position) async {
    if (!_isNavigating) return;

    try {
      final currentLatLng = LatLng(position.latitude, position.longitude);
      
      await widget.mapController.animateCamera(
        CameraUpdate.newLatLng(currentLatLng),
      );
    } catch (e) {
      debugPrint('Error following user: $e');
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(0, 0),
        northeast: LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Add padding
    const padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  @override
  void dispose() {
    _navigationStateSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
