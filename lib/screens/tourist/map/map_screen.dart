// ignore_for_file: prefer_final_fields, avoid_print, unused_field, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:capstone_app/api/api.dart';
import 'package:capstone_app/data/repositories/destination_repository.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/models/destination_model.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:capstone_app/services/offline_cache_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
import 'package:capstone_app/widgets/common_search_bar.dart';
import 'package:capstone_app/widgets/custom_map_marker.dart';
import 'package:capstone_app/widgets/navigation_map_controller.dart';
import 'package:capstone_app/widgets/navigation_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  Map<String, Map<String, dynamic>> _destinationData = {};
  LatLng? _currentLatLng;
  Position? _lastAcceptedPosition;
  // Removed compass-related variables

  Set<Marker> _markers = {};
  Set<Marker> _allMarkers = {}; // ✅ Store all markers here
  bool _isLoading = false;
  final Set<Polyline> _polylines = {};
  bool _isLoadingDirections = false;
  final Set<Circle> _circles = {};

  // Smoothing config
  final List<Position> _recentPositions = [];
  DateTime? _lastOverlayUpdate;
  static const int _smoothingWindow = 5;
  static const double _maxJumpMeters = 100; // ignore >100m jump within 3s
  static const Duration _jumpWindow = Duration(seconds: 3);
  static const Duration _throttleInterval = Duration(milliseconds: 900); // ~1/s
  static const double _recenterThresholdMeters = 20; // recenter if drift >20m

  // Navigation service
  final NavigationService _navigationService = NavigationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final DestinationRepository _destinationRepository = DestinationRepository();
  bool _isNavigating = false;

  // Web/location UX
  bool _showLocationBanner = false;
  String _locationBannerText = 'Enable location to center the map on you.';

  String _searchQuery = '';
  String _role = 'Tourist';
  String _selectedCategory = 'All Categories';
  String _selectedMunicipality = 'All Municipalities';
  String _selectedType = 'All Types';

  // Category-based marker icons
  final Map<String, BitmapDescriptor> _categoryMarkerIcons = {};
  bool _categoryIconsInitialized = false;
  static const double _categoryMarkerSize = 80.0;
  static const Map<String, IconData> _categoryIcons = {
    'Natural Attraction': Icons.park,
    'Cultural Site': Icons.museum,
    'Adventure Spot': Icons.forest,
    'Restaurant': Icons.restaurant,
    'Accommodation': Icons.hotel,
    'Shopping': Icons.shopping_cart,
    'Entertainment': Icons.theater_comedy,
  };
  static const Map<String, Color> _categoryColors = {
    'Natural Attraction': Colors.green,
    'Cultural Site': Colors.purple,
    'Adventure Spot': Colors.orange,
    'Restaurant': Colors.red,
    'Accommodation': Colors.blueGrey,
    'Shopping': Colors.blue,
    'Entertainment': Colors.pink,
  };

  // Offline guest overlay state
  bool _isOfflineMode = false;
  List<Map<String, dynamic>> _cachedDestinations = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    _startLocationStream(); // Start streaming location
    _ensureLocationPermissionAndCenter();

    // Listen to navigation state changes
    _navigationService.navigationStateStream.listen((isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = isNavigating;
        });
      }
    });

    // Listen to navigation polylines
    _navigationService.polylineStream.listen((polylines) {
      if (mounted) {
        setState(() {
          _polylines.clear();
          _polylines.addAll(polylines);
        });
      }
    });
  }

  /// Fetch all data once in initState - no async calls in UI handlers
  Future<void> _fetchAllData() async {
    await Future.wait([
      _initializeCategoryMarkerIcons(),
      _fetchUserRole(),
      _fetchDestinationPins(),
    ]);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _navigationService.dispose();
    super.dispose();
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters before update
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _handleIncomingPosition(position);

      // Proximity check for arrivals
      _checkProximityAndSaveArrival(position);
    });
  }

  void _handleIncomingPosition(Position position) {
    final now = DateTime.now();
    if (_lastOverlayUpdate != null && now.difference(_lastOverlayUpdate!) < _throttleInterval) {
      return; // throttle updates
    }

    // Keep a small window of the most recent fixes
    _recentPositions.add(position);
    while (_recentPositions.length > _smoothingWindow) {
      _recentPositions.removeAt(0);
    }

    // Pick the most accurate fix in the window
    Position best = _recentPositions.reduce(
      (a, b) => (a.accuracy <= b.accuracy) ? a : b,
    );

    // Anti-jump: if last accepted exists and time < 3s and jump >100m, ignore
    if (_lastAcceptedPosition != null) {
      final ts = _lastAcceptedPosition!.timestamp;
      final tsMs = ts.millisecondsSinceEpoch;
      final dt = now.difference(DateTime.fromMillisecondsSinceEpoch(tsMs));
      final lastLatLng = LatLng(_lastAcceptedPosition!.latitude, _lastAcceptedPosition!.longitude);
      final bestLatLng = LatLng(best.latitude, best.longitude);
      final jump = _haversineDistanceMeters(lastLatLng, bestLatLng);
      if (dt < _jumpWindow && jump > _maxJumpMeters) {
        return; // discard spike
      }
    }

    _lastAcceptedPosition = best;
    _currentLatLng = LatLng(best.latitude, best.longitude);
    _lastOverlayUpdate = now;

    _updateUserLocationOverlay(best);

    // Auto-recenter only when moved significantly to avoid jitter
    if (_mapController != null) {
      final camTarget = _currentLatLng!;
      if (_lastCenter == null || _haversineDistanceMeters(_lastCenter!, camTarget) > _recenterThresholdMeters) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(camTarget));
        _lastCenter = camTarget;
      }
    }
    if (mounted) setState(() {});
  }

  LatLng? _lastCenter;

  Future<void> _ensureLocationPermissionAndCenter() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _showLocationBanner = true;
            _locationBannerText = 'Location services are off. Turn them on, then tap Enable.';
          });
        }
        return; // Can't proceed if location services are disabled
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _showLocationBanner = true;
            _locationBannerText = 'Location permission denied. Tap Enable and allow in the browser.';
          });
        }
        return; // User denied permissions
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      _updateUserLocationOverlay(pos);
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng!, 14),
        );
      }
      if (mounted) {
        setState(() {
          _showLocationBanner = false;
        });
      }
    } catch (_) {
      // Ignore errors; map will remain at default center
    }
  }

  void _updateUserLocationOverlay(Position pos) {
    final me = LatLng(pos.latitude, pos.longitude);
    // Draw only a small blue dot circle (no pin/marker)
    const double dotRadius = 18; // meters, purely visual
    _circles.removeWhere((c) => c.circleId.value == 'me_accuracy');
    _circles.add(
      Circle(
        circleId: const CircleId('me_accuracy'),
        center: me,
        radius: dotRadius,
        strokeColor: Colors.transparent,
        fillColor: Colors.blue.withOpacity(0.7),
        strokeWidth: 0,
        zIndex: 9998,
      ),
    );
    // Rebuild markers from _allMarkers, but hide any destination marker overlapping the blue dot
    _markers = _allMarkers.where((m) {
      final d = _haversineDistanceMeters(me, m.position);
      return d > 30; // hide markers within ~30m of user to avoid overlap
    }).toSet();
    if (mounted) setState(() {});
  }

  void _checkProximityAndSaveArrival(Position userPosition) async {
    // Only check if markers are loaded
    if (_allMarkers.isEmpty) return;

    // Check location permissions first
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // Skip proximity checking if no permission
    }

    final userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    for (final marker in _allMarkers) {
      final markerLatLng = marker.position;
      final double distance = _haversineDistanceMeters(
        userLatLng,
        markerLatLng,
      );
      if (distance <= 50) {
        // Get hotspotId from markerId
        final hotspotId = marker.markerId.value;
        // Check if already arrived today
        final hasArrived = await ArrivalService.hasArrivedToday(hotspotId);
        if (!hasArrived) {
          // Get enhanced destination data
          final destinationInfo = _destinationData[hotspotId];
          await ArrivalService.saveArrival(
            hotspotId: hotspotId,
            latitude: markerLatLng.latitude,
            longitude: markerLatLng.longitude,
            destinationName: destinationInfo?['destinationName'],
            destinationCategory: destinationInfo?['destinationCategory'],
            destinationType: destinationInfo?['destinationType'],
            destinationDistrict: destinationInfo?['destinationDistrict'],
            destinationMunicipality:
                destinationInfo?['destinationMunicipality'],
            destinationImages:
                destinationInfo?['destinationImages']?.cast<String>(),
            destinationDescription: destinationInfo?['destinationDescription'],
          );
        }
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    _filterMarkers();
  }

  void _onSearchCleared() {
    setState(() {
      _searchQuery = '';
    });
    _filterMarkers();
  }

  void _filterMarkers() {
    if (_searchQuery.isEmpty &&
        _selectedCategory == 'All Categories' &&
        _selectedMunicipality == 'All Municipalities' &&
        _selectedType == 'All Types') {
      setState(() => _markers = _allMarkers);
      return;
    }

    final filtered =
        _allMarkers.where((marker) {
          final name = marker.infoWindow.title?.toLowerCase() ?? '';
          final matchesSearch =
              _searchQuery.isEmpty || name.contains(_searchQuery);

          // Simple filtering based on marker title only
          return matchesSearch;
        }).toSet();

    setState(() {
      _markers = filtered;
    });
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(user.uid)
                .get();
        if (mounted) {
          setState(() {
            _role = userDoc.data()?['role'] ?? 'Guest';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _role = 'Guest';
        });
      }
    }
  }

  Future<void> _fetchDestinationPins() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final markers = <Marker>{};
      List<Map<String, dynamic>> rawDocs = [];
      // bool usedOffline = false; // available if you want to display a banner
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('destination')
            .get()
            .timeout(const Duration(seconds: 3));
        // Preserve document ids so hotspotId is reliable downstream
        rawDocs =
            snapshot.docs.map((d) {
              final m = Map<String, dynamic>.from(d.data());
              if ((m['hotspot_id'] == null ||
                      m['hotspot_id'].toString().isEmpty) &&
                  (m['id'] == null || m['id'].toString().isEmpty)) {
                m['hotspot_id'] = d.id;
              }
              return m;
            }).toList();
        // Cache for offline use
        await OfflineCacheService.saveDestinations(rawDocs);
        _isOfflineMode = false;
        _cachedDestinations = rawDocs;
      } catch (_) {
        // Offline fallback
        rawDocs = await OfflineCacheService.loadDestinations();
        // usedOffline = true;
        _isOfflineMode = rawDocs.isNotEmpty;
        _cachedDestinations = rawDocs;
      }

      for (final data in rawDocs) {
        final id =
            data['hotspot_id']?.toString() ?? data['id']?.toString() ?? '';
        final hotspot = Hotspot.fromMap(data, id);
        final double? lat = hotspot.latitude;
        final double? lng = hotspot.longitude;
        final String name =
            hotspot.name.isNotEmpty ? hotspot.name : 'Tourist Spot';

        if (lat != null && lng != null) {
          final position = LatLng(lat, lng);

          // Prefer category-based icon; fallback to text marker
          final categoryRaw =
              hotspot.category.isNotEmpty ? hotspot.category : hotspot.type;
          final normalizedCategory = _normalizeCategory(categoryRaw);
          final categoryIcon = _getCategoryMarkerIcon(normalizedCategory);
          final customIcon =
              categoryIcon ??
              await CustomMapMarker.createTextMarker(
                label: name,
                color: Colors.orange,
              );

          final marker = Marker(
            markerId: MarkerId(
              hotspot.hotspotId.isNotEmpty ? hotspot.hotspotId : id,
            ),
            position: position,
            icon: customIcon,
            infoWindow: InfoWindow(title: name),
            onTap: () {
              final dataWithId =
                  Map<String, dynamic>.from(data)
                    ..putIfAbsent(
                      'hotspot_id',
                      () =>
                          hotspot.hotspotId.isNotEmpty ? hotspot.hotspotId : id,
                    )
                    ..putIfAbsent('destinationName', () => name)
                    ..putIfAbsent('destinationCategory', () => hotspot.category)
                    ..putIfAbsent('destinationType', () => hotspot.type)
                    ..putIfAbsent('destinationDistrict', () => hotspot.district)
                    ..putIfAbsent(
                      'destinationMunicipality',
                      () => hotspot.municipality,
                    );
              BusinessDetailsModal.show(
                context: context,
                businessData: dataWithId,
                role: _role,
                currentUserId: FirebaseAuth.instance.currentUser?.uid,
                onNavigate: (lat, lng) {
                  _showNavigationPreview(LatLng(lat, lng), dataWithId);
                },
              );
            },
          );

          markers.add(marker);
        }
      }

      setState(() {
        _allMarkers = markers;
        _markers = markers;
      });
      if (rawDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cached destinations available offline.'),
          ),
        );
      }
    } catch (e) {
      print('Error fetching destinations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToMyLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition();
    final myLocation = LatLng(position.latitude, position.longitude);

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: myLocation, zoom: 14.5),
      ),
    );
  }

  Future<void> _getDirectionsTo(LatLng destination) async {
    try {
      setState(() {
        _isLoadingDirections = true;
      });

      // Check connectivity first
      final connectivityInfo = await _connectivityService.checkConnection();
      if (connectivityInfo.status != ConnectionStatus.connected) {
        if (mounted) {
          _showOfflineDirectionsDialog();
        }
        return;
      }

      // Ensure location services and permission are enabled before starting nav
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission required for navigation'),
            ),
          );
        }
        return;
      }

      // Start navigation using the navigation service
      final success = await _navigationService.startNavigation(destination);

      if (success) {
        // Clear existing polylines when starting navigation
        setState(() {
          _polylines.clear();
        });
      } else {
        // Fallback to old method if navigation service fails
        await _getDirectionsToLegacy(destination);
      }
    } catch (e) {
      debugPrint('Error starting navigation: $e');
      // Fallback to old method
      await _getDirectionsToLegacy(destination);
    } finally {
      if (mounted) {
        setState(() => _isLoadingDirections = false);
      }
    }
  }

  Future<void> _getDirectionsToWithDestinationInfo(
    LatLng destination,
    Map<String, dynamic> destinationData,
  ) async {
    try {
      setState(() {
        _isLoadingDirections = true;
      });

      // Start navigation using the navigation service with destination information
      final success = await _navigationService.startNavigation(
        destination,
        destinationId:
            destinationData['hotspot_id'] ?? destinationData['hotspotId'],
        destinationName:
            destinationData['destinationName'] ??
            destinationData['businessName'] ??
            destinationData['name'],
        destinationCategory:
            destinationData['destinationCategory'] ??
            destinationData['category'],
        destinationType:
            destinationData['destinationType'] ?? destinationData['type'],
        destinationDistrict:
            destinationData['destinationDistrict'] ??
            destinationData['district'],
        destinationMunicipality:
            destinationData['destinationMunicipality'] ??
            destinationData['municipality'],
        destinationImages:
            destinationData['destinationImages']?.cast<String>() ??
            destinationData['images']?.cast<String>(),
        destinationDescription:
            destinationData['destinationDescription'] ??
            destinationData['description'],
      );

      if (success) {
        // Clear existing polylines when starting navigation
        setState(() {
          _polylines.clear();
        });
      } else {
        // Fallback to old method if navigation service fails
        await _getDirectionsToLegacy(destination);
      }
    } catch (e) {
      debugPrint('Error starting navigation: $e');
      // Fallback to old method
      await _getDirectionsToLegacy(destination);
    } finally {
      if (mounted) {
        setState(() => _isLoadingDirections = false);
      }
    }
  }

  // Legacy directions method (fallback)
  Future<void> _getDirectionsToLegacy(LatLng destination) async {
    try {
      // Check location permissions first
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied ||
            requestedPermission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission required for directions'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      final origin = LatLng(position.latitude, position.longitude);

      setState(() {
        _isLoadingDirections = true;
        _polylines.clear();
      });

      // Try to resolve place IDs for better routing accuracy
      final originPlaceId = await _fetchPlaceIdForLatLng(origin);
      final destPlaceId = await _fetchPlaceIdForLatLng(destination);

      final originParam =
          originPlaceId != null
              ? 'place_id:$originPlaceId'
              : '${origin.latitude},${origin.longitude}';
      final destParam =
          destPlaceId != null
              ? 'place_id:$destPlaceId'
              : '${destination.latitude},${destination.longitude}';

      final url = ApiEnvironment.getDirectionsUrl(originParam, destParam);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to get directions: HTTP ${response.statusCode}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingDirections = false);
        return;
      }

      final body = json.decode(response.body);
      if (body['status'] != 'OK' ||
          body['routes'] == null ||
          body['routes'].isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No route found: ${body['status'] ?? 'Unknown error'}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoadingDirections = false);
        return;
      }

      // Prefer detailed leg/step polylines when available for accuracy
      List<LatLng> coords = [];
      final routes = body['routes'] as List<dynamic>;
      if (routes.isNotEmpty) {
        final route = routes[0] as Map<String, dynamic>;
        final legs = (route['legs'] as List<dynamic>?) ?? [];
        final decoder = PolylinePoints();
        if (legs.isNotEmpty) {
          for (final leg in legs) {
            final steps = (leg['steps'] as List<dynamic>?) ?? [];
            if (steps.isNotEmpty) {
              for (final step in steps) {
                final polyline =
                    (step as Map<String, dynamic>)['polyline']?['points'];
                if (polyline != null && polyline.toString().isNotEmpty) {
                  final decoded = decoder.decodePolyline(polyline.toString());
                  coords.addAll(
                    decoded.map((p) => LatLng(p.latitude, p.longitude)),
                  );
                }
              }
            }
          }
        }
        // Fallback to overview polyline if step-level not present
        if (coords.isEmpty && route['overview_polyline']?['points'] != null) {
          final points = route['overview_polyline']['points'];
          final decoded = decoder.decodePolyline(points.toString());
          coords = decoded
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(growable: false);
        }
      }

      // If Google stops at nearest road, extend last leg to exact destination for visual accuracy
      if (coords.isNotEmpty) {
        final last = coords.last;
        final distanceToDest = _haversineDistanceMeters(last, destination);
        if (distanceToDest > 1.0 && distanceToDest < 300.0) {
          coords = List<LatLng>.from(coords)..add(destination);
        }
      }

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: coords,
            color: Colors.blue,
            width: 6,
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      });

      // Fit camera
      if (coords.isNotEmpty) {
        double minLat = coords.first.latitude;
        double maxLat = coords.first.latitude;
        double minLng = coords.first.longitude;
        double maxLng = coords.first.longitude;
        for (final c in coords) {
          minLat = math.min(minLat, c.latitude);
          maxLat = math.max(maxLat, c.latitude);
          minLng = math.min(minLng, c.longitude);
          maxLng = math.max(maxLng, c.longitude);
        }
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            80,
          ),
        );
      }
    } catch (_) {
      // no-op UI messaging kept minimal here
    } finally {
      if (mounted) {
        setState(() => _isLoadingDirections = false);
      }
    }
  }

  // Exit navigation
  void _exitNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      _polylines.clear();
    });
  }

  // Re-center map on user location
  void _recenterMap() {
    if (_currentLatLng != null) {
      if (_isNavigating) {
        // During navigation, re-center with bearing calculation
        final currentStep = _navigationService.getCurrentStep();
        if (currentStep != null) {
          final bearing = _calculateBearing(
            _currentLatLng!,
            currentStep.endLocation,
          );
          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentLatLng!,
                zoom: 18.0,
                bearing: bearing,
                tilt: 45.0,
              ),
            ),
          );
        }
      } else {
        // Normal re-center
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLatLng!, zoom: 18.0, tilt: 45.0),
          ),
        );
      }
    }
  }

  // Calculate bearing between two points
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

  // Update polylines when navigation changes
  void _onPolylinesChanged(Set<Polyline> newPolylines) {
    setState(() {
      _polylines.clear();
      _polylines.addAll(newPolylines);
    });
  }

  // Show navigation preview and start navigation
  void _showNavigationPreview(
    LatLng destination, [
    Map<String, dynamic>? destinationData,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Start Navigation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Get turn-by-turn directions to this destination',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Start Navigation Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (destinationData != null) {
                      _getDirectionsToWithDestinationInfo(
                        destination,
                        destinationData,
                      );
                    } else {
                      _getDirectionsTo(destination);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Navigation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Simple Haversine distance utility
  double _haversineDistanceMeters(LatLng a, LatLng b) {
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

  Future<String?> _fetchPlaceIdForLatLng(LatLng latLng) async {
    try {
      final url = ApiEnvironment.getGeocodeUrlForLatLng(
        '${latLng.latitude},${latLng.longitude}',
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final placeId = (results.first as Map<String, dynamic>)['place_id'];
      return placeId is String ? placeId : null;
    } catch (_) {
      return null;
    }
  }

  // Category marker helpers
  Future<void> _initializeCategoryMarkerIcons() async {
    try {
      for (final entry in _categoryIcons.entries) {
        final String key = entry.key;
        final IconData icon = entry.value;
        final Color color = _categoryColors[key] ?? Colors.blue;
        final bitmap = await _createCategoryMarker(icon, color);
        _categoryMarkerIcons[key] = bitmap;
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _categoryIconsInitialized = true);
    }
  }

  Future<BitmapDescriptor> _createCategoryMarker(
    IconData iconData,
    Color color,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = _categoryMarkerSize / 2;

    // Shadow
    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius - 4, shadowPaint);

    // Main circle
    final Paint mainPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 4, mainPaint);

    // Border
    final Paint borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

    // Icon glyph
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: _categoryMarkerSize * 0.4,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    final Offset iconOffset = Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      _categoryMarkerSize.toInt(),
      _categoryMarkerSize.toInt(),
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  String _normalizeCategory(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.contains('adventure')) return 'Adventure Spot';
    if (value.contains('cultur')) return 'Cultural Site';
    if (value.contains('natural')) return 'Natural Attraction';
    if (value.contains('museum')) return 'Cultural Site';
    if (value.contains('eco')) return 'Natural Attraction';
    if (value.contains('park')) return 'Natural Attraction';
    if (value.contains('restaurant') || value.contains('food')) {
      return 'Restaurant';
    }
    if (value.contains('accommodation') || value.contains('hotel')) {
      return 'Accommodation';
    }
    if (value.contains('shopping')) return 'Shopping';
    if (value.contains('entertain')) return 'Entertainment';
    return value;
  }

  BitmapDescriptor? _getCategoryMarkerIcon(String category) {
    if (category.isEmpty) return null;
    final key = category.trim();
    if (_categoryMarkerIcons.containsKey(key)) return _categoryMarkerIcons[key];
    // Try fuzzy
    for (final entry in _categoryMarkerIcons.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _controller.complete(controller);
    // On web, google_maps_flutter_web can throw MapStyleException for some
    // styles. Guard and ignore failures so the map still renders.
    try {
      _mapController?.setMapStyle(AppConstants.kMapStyle);
    } catch (_) {
      // Fallback: no custom style
    }
  }

  void _showOfflineDirectionsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Offline Mode'),
            content: const Text(
              'Turn-by-turn directions require an internet connection. Please check your connection and try again.',
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

  void _showOfflineDirectionsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Offline Mode'),
            content: const Text(
              'Turn-by-turn directions require an internet connection. Please check your connection and try again.',
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMove: (position) {
              _navigationService.updateBearing(position.bearing);
            },
            initialCameraPosition: CameraPosition(
              target: AppConstants.bukidnonCenter,
              zoom: AppConstants.kInitialZoom,
            ),
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            cameraTargetBounds: CameraTargetBounds(AppConstants.bukidnonBounds),
            padding: EdgeInsets.only(bottom: 80 + bottomPadding),
          ),

          // Navigation Map Controller (invisible widget that controls map behavior)
          if (_mapController != null)
            NavigationMapController(
              mapController: _mapController!,
              navigationService: _navigationService,
              polylines: _polylines,
              onPolylinesChanged: _onPolylinesChanged,
            ),

          // Search Bar at the Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UniversalSearchBar(
              onChanged: _onSearchChanged,
              onClear: _onSearchCleared,
              onFilterTap: _showFilterSheet,
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Enable location banner (web/desktop UX)
          if (_showLocationBanner)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: AppColors.primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationBannerText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _ensureLocationPermissionAndCenter,
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating "my location" button
          Positioned(
            right: 16,
            bottom: 24,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _ensureLocationPermissionAndCenter,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.my_location, color: Colors.blue, size: 24),
                ),
              ),
            ),
          ),

          // Offline guest overlay: banner + cached list
          if (_isOfflineMode)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.offline_bolt,
                      color: Colors.yellow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Offline mode: showing cached places only',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isOfflineMode)
            Positioned(
              bottom: 16 + bottomPadding,
              left: 16,
              right: 16,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    _cachedDestinations.isEmpty
                        ? const Center(
                          child: Text('No cached places available'),
                        )
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: _cachedDestinations.length,
                          itemBuilder: (context, index) {
                            final data = _cachedDestinations[index];
                            final name =
                                (data['business_name'] ??
                                        data['name'] ??
                                        'Place')
                                    .toString();
                            final images =
                                (data['images'] is List)
                                    ? data['images'] as List
                                    : [];
                            final imageUrl =
                                images.isNotEmpty
                                    ? images.first.toString()
                                    : (data['imageUrl']?.toString());
                            return Container(
                              width: 220,
                              margin: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  BusinessDetailsModal.show(
                                    context: context,
                                    businessData: data,
                                    role: 'guest',
                                    currentUserId: null,
                                    showInteractions: false,
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child:
                                            imageUrl != null
                                                ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                                : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 30,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),

          // Navigation Overlay (disabled for guests & offline)
          if (_role.toLowerCase() != 'guest' && !_isOfflineMode)
            NavigationOverlay(
              navigationService: _navigationService,
              onExitNavigation: _exitNavigation,
            ),

          // Removed blue arrow compass indicator

          // My Location Button
          Positioned(
            bottom: 16 + bottomPadding,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_location',
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Re-center button (bottom left)
          if (_isNavigating)
            Positioned(
              bottom: 100 + bottomPadding,
              left: 16,
              child: GestureDetector(
                onTap: _recenterMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 24, // Increased from 16 to 24
                      ),
                      const SizedBox(width: 6), // Slightly wider spacing
                      const Text(
                        'Re-center',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16, // Increased from 12 to 16
                          fontWeight: FontWeight.w600, // Slightly bolder
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    // Simple filter options
    final Set<String> categories = {'All Categories'};
    final Set<String> municipalities = {'All Municipalities'};
    final Set<String> types = {'All Types'};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Filter Destinations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),

              // Category Filter
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  underline: Container(),
                  items:
                      categories
                          .toList()
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Row(
                                children: [
                                  if (category == 'All Categories')
                                    const Icon(
                                      Icons.category,
                                      color: Colors.grey,
                                      size: 20,
                                    )
                                  else if (_categoryIcons[category] != null)
                                    Icon(
                                      _categoryIcons[category],
                                      color: AppColors.primaryTeal,
                                      size: 20,
                                    )
                                  else
                                    const Icon(
                                      Icons.label,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(category),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _filterMarkers();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Municipality Filter
              Text(
                'Municipality',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedMunicipality,
                  isExpanded: true,
                  underline: Container(),
                  items:
                      municipalities
                          .toList()
                          .map(
                            (municipality) => DropdownMenuItem(
                              value: municipality,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_city,
                                    color: AppColors.primaryTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(municipality),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMunicipality = value!;
                    });
                    _filterMarkers();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Type Filter
              Text(
                'Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  underline: Container(),
                  items:
                      types
                          .toList()
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.type_specimen,
                                    color: AppColors.primaryTeal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(type),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                    _filterMarkers();
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Clear Filters Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All Categories';
                      _selectedMunicipality = 'All Municipalities';
                      _selectedType = 'All Types';
                    });
                    _filterMarkers();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Clear All Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
