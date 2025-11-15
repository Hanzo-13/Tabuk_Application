// ignore_for_file: prefer_final_fields, avoid_print, unused_field, use_build_context_synchronously

import 'dart:async';
import 'dart:io' show Platform;

import 'package:capstone_app/data/repositories/destination_repository.dart';
import 'package:capstone_app/screens/tourist/map/map_location_manager.dart';
import 'package:capstone_app/screens/tourist/map/map_marker_manager.dart';
import 'package:capstone_app/screens/tourist/map/map_navigation_manager.dart';
import 'package:capstone_app/screens/tourist/map/map_ui_components.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:capstone_app/services/offline_cache_service.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
import 'package:capstone_app/widgets/common_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Core Controllers
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _isCompassModeActive = false;
  bool _isCameraAnimationThrottled = false;

  // Managers
  late MapLocationManager _locationManager;
  late MapMarkerManager _markerManager;
  late MapNavigationManager _navigationManager;

  // In _MapScreenState
  BitmapDescriptor? _userLocationDotIcon;
  BitmapDescriptor? _userLocationChevronIcon;
  BitmapDescriptor? _userLocationHeadingIcon;

  // Services
  final NavigationService _navigationService = NavigationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final DestinationRepository _destinationRepository = DestinationRepository();

  // State
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  bool _isLoading = true;
  bool _isNavigating = false;
  bool _didFitRouteOnce = false;
  bool _isFollowingUser = true;
  String _role = 'Tourist';
  String _searchQuery = '';
  bool _isOfflineMode = false;
  List<Map<String, dynamic>> _cachedDestinations = [];
  DateTime? _lastCameraUpdate; // Throttle camera updates
  LatLng? _lastCameraUpdatePosition;
  double _lastCameraUpdateBearing = 0.0;
  bool _isAnimatingCamera = false;
  MapType _mapType = MapType.normal; // Track map type for navigation

  // Location State
  LatLng? _currentLatLng;
  Position? _lastPosition; // Store last position for marker updates
  double _currentBearing = 0.0;
  bool _showLocationBanner = false;
  String _locationBannerText = 'Enable location to use map features.';

  // In _MapScreenState
  String? _selectedFilterCategory;
  String? _selectedFilterSubCategory;

  

  final Map<String, List<String>> _categories = {
    'Natural Attractions': [
      'Waterfalls',
      'Mountains',
      'Caves',
      'Hot Springs',
      'Cold Springs',
      'Lakes',
      'Rivers',
      'Forests',
      'Natural Pools',
      'Nature Trails',
    ],
    'Recreational Facilities': [
      'Resorts',
      'Theme Parks',
      'Sports Complexes',
      'Adventure Parks',
      'Entertainment Venues',
      'Golf Courses',
    ],
    'Cultural & Historical': [
      'Churches',
      'Temples',
      'Museums',
      'Festivals',
      'Heritage Sites',
      'Archaeological Sites',
    ],
    'Agri-Tourism & Industrial': [
      'Farms',
      'Agro-Forestry',
      'Industrial Tours',
      'Ranches',
    ],
    'Culinary & Shopping': [
      'Local Restaurants',
      'Souvenir Shops',
      'Food Festivals',
      'Markets',
    ],
    'Events & Education': [
      'Workshops',
      'Educational Tours',
      'Conferences',
      'Local Events',
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUserLocationIconsSync();
    _initializeManagers();
    
    // Defer heavy operations to avoid blocking main thread
    // This prevents ANR warnings and frame skipping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAsync();
    });
    
    _listenToCompass();
  }

  /// Initialize heavy operations asynchronously after first frame
  /// This prevents blocking the main thread during widget build
  Future<void> _initializeAsync() async {
    if (!mounted) return;
    
    try {
      // Add small delay to let UI render first
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      
      // Initialize map asynchronously
      await _initMap();
    } catch (e) {
      if (kDebugMode) debugPrint('Error during async initialization: $e');
    }
  }

  void _initializeUserLocationIconsSync() {
    // Kick off async high-quality icons
    _initializeUserLocationIcons();
    // Immediate fallbacks to avoid nulls on first updates
    _userLocationDotIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _userLocationChevronIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _userLocationHeadingIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  // In _MapScreenState
  void _clearFilters() {
    setState(() {
      _selectedFilterCategory = null;
      _selectedFilterSubCategory = null;
    });
    _filterMarkers();
  }

  void _listenToCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final newHeading = event.heading;
      if (newHeading == null) return;

      // Always update for potential UI compass indicator
      setState(() {
        _currentBearing = newHeading;
      });

      // Update marker rotation when in compass mode
      if (_isCompassModeActive && _lastPosition != null) {
        _updateUserLocationMarker(_lastPosition!);
      }

      // Throttle camera animation to avoid spamming updates
      if (_isCompassModeActive &&
          !_isCameraAnimationThrottled &&
          _mapController != null &&
          _currentLatLng != null) {
        setState(() {
          _isCameraAnimationThrottled = true;
        });

        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLatLng!,
              zoom: 18.5,
              bearing: newHeading,
              tilt: 60.0,
            ),
          ),
        );

        Timer(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _isCameraAnimationThrottled = false;
            });
          }
        });
      }
    });
  }

  void _toggleCompassMode() {
    if (!mounted) return;
    setState(() {
      _isCompassModeActive = !_isCompassModeActive;
    });

    if (_currentLatLng != null) {
      _locationManager.requestLocationUpdate();
    }

    // If turning off compass mode, reset camera to north-up
    if (!_isCompassModeActive && _mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLatLng!,
            zoom: 17,
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
    }
  }

  void _initializeManagers() {
    _locationManager = MapLocationManager(
      onLocationUpdate: _handleLocationUpdate,
      onPermissionDenied: _handlePermissionDenied,
      isNavigatingProvider: () => _isNavigating,
    );

    // CRITICAL: Set NavigationService to use MapLocationManager's stream (single GPS listener)
    // This prevents duplicate GPS listeners competing for updates
    _navigationService.setLocationStream(_locationManager.locationStream);

    _markerManager = MapMarkerManager(onMarkerTap: _handleMarkerTap);

    _navigationManager = MapNavigationManager(
      navigationService: _navigationService,
      connectivityService: _connectivityService,
      onNavigationStateChanged: (isNavigating) {
        if (mounted) setState(() => _isNavigating = isNavigating);

        if (isNavigating) {
          _didFitRouteOnce = false;
          _isFollowingUser = true;
          // Set default map type to hybrid when navigation starts
          if (mounted) {
            setState(() {
              _mapType = MapType.hybrid;
            });
          }
          // Disable compass mode to let navigation control bearing
          if (_isCompassModeActive) {
            setState(() {
              _isCompassModeActive = false;
            });
          }

          // Force an initial follow shortly after start
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _ensureCameraFollowing();
          });

          // Periodic safeguard to ensure camera keeps following
          Timer.periodic(const Duration(seconds: 2), (timer) {
            if (!_isNavigating || !mounted) {
              timer.cancel();
              return;
            }
            _ensureCameraFollowing();
          });
        }
      },
      onPolylinesChanged: (polylines) {
        if (mounted) setState(() => _polylines = polylines);
        if (_isNavigating && !_didFitRouteOnce) {
          _fitPolylinesBounds();
        }
      },
      onStateUpdated: () {
        if (mounted) setState(() {});
      },
    );
    _navigationManager.init();
  }

  void _onMyLocationButtonPressed() {
    // Check if the user is currently navigating.
    // If compass mode is active, a single tap should turn it off.
    if (_isCompassModeActive) {
      _toggleCompassMode();
      return;
    }
    if (_isNavigating) {
      // If navigating, call the function that re-centers the map with bearing and tilt.
      _recenterMap();
    } else {
      // If just browsing, call the function that finds the user's location and zooms in.
      _goToMyLocation();
    }
  }

  Future<void> _initializeUserLocationIcons() async {
    _userLocationDotIcon = await MapMarkerManager.createLocationDotBitmap();
    _userLocationChevronIcon =
        await MapMarkerManager.createLocationChevronBitmap();
    _userLocationHeadingIcon =
        await MapMarkerManager.createLocationHeadingBitmap();
    if (mounted) setState(() {});
  }

  Future<void> _initMap() async {
    if (!mounted) return;
    
    try {
      // Show loading state
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // 1. Fetch data asynchronously (non-blocking)
      // Split into smaller chunks to avoid blocking
      await Future.wait([
        _markerManager.initializeCategoryMarkerIcons(),
        _initializeUserLocationIcons(),
      ], eagerError: false);
      
      if (!mounted) return;
      
      // Fetch user role and destinations in parallel but with timeout
      await Future.wait([
        _fetchUserRole().timeout(const Duration(seconds: 5), onTimeout: () {
          if (mounted) setState(() => _role = 'Guest');
        }),
        _fetchDestinationPins(),
      ], eagerError: false);
      
      if (!mounted) return;

      // 2. Handle location permissions and start tracking
      final hasPermission = await _locationManager.handleLocationPermission(
        context,
      );
      if (!mounted) return;
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _showLocationBanner = true;
            _locationBannerText =
                'Location permission is required to use the map features.';
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Start location tracking (non-blocking)
      _locationManager.startLocationTracking().catchError((e) {
        if (kDebugMode) debugPrint('Error starting location tracking: $e');
        if (mounted) {
          setState(() {
            _showLocationBanner = true;
            _locationBannerText = 'Unable to start location tracking.';
            _isLoading = false;
          });
        }
      });

      // Navigation listeners are initialized via MapNavigationManager
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Removed _fetchAllData - now handled in _initMap for better control

  void _handleLocationUpdate(Position position, LatLng latLng, double bearing) {
    if (!mounted) return;

    setState(() {
      _currentLatLng = latLng;
      _lastPosition = position; // Store position for compass mode updates
      _currentBearing = bearing;
      _showLocationBanner = false;
    });

    _updateUserLocationMarker(position);
    _updateUserLocationCircle(latLng, position.accuracy);
    _checkProximityAndSaveArrival(position);

    // Navigation camera following with movement/heading checks
    if (_isNavigating && _isFollowingUser && _mapController != null) {
      final currentStep = _navigationService.getCurrentStep();
      double targetBearing = position.heading.isFinite ? position.heading : 0;
      if (currentStep != null) {
        targetBearing = _locationManager.calculateBearing(
          latLng,
          currentStep.endLocation,
        );
      }

      bool shouldUpdateCamera = true;
      if (_lastCameraUpdatePosition != null) {
        final distanceMoved = _locationManager.calculateDistance(
          _lastCameraUpdatePosition!,
          latLng,
        );
        final headingChanged =
            (_lastCameraUpdateBearing - targetBearing).abs() > 5;
        shouldUpdateCamera = distanceMoved > 1 || headingChanged;
      }

      final now = DateTime.now();
      if (shouldUpdateCamera &&
          (_lastCameraUpdate == null ||
              now.difference(_lastCameraUpdate!) >
                  const Duration(milliseconds: 100))) {
        _lastCameraUpdate = now;
        _lastCameraUpdatePosition = latLng;
        _lastCameraUpdateBearing = targetBearing;

        setState(() {
          _isAnimatingCamera = true;
        });
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: latLng,
              zoom: 18.5,
              bearing: targetBearing,
              tilt: 60.0,
            ),
          ),
        );
      }
    }
  }

  void _ensureCameraFollowing() {
    if (!_isNavigating || !_isFollowingUser) return;
    if (_currentLatLng == null || _mapController == null) return;

    final currentStep = _navigationService.getCurrentStep();
    double targetBearing = _currentBearing;
    if (currentStep != null) {
      targetBearing = _locationManager.calculateBearing(
        _currentLatLng!,
        currentStep.endLocation,
      );
    }

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLatLng!,
          zoom: 18.5,
          bearing: targetBearing,
          tilt: 60.0,
        ),
      ),
    );
  }

  void _handlePermissionDenied() {
    if (mounted) {
      setState(() {
        _showLocationBanner = true;
        _locationBannerText =
            'Location permission is required to use the map features.';
      });
    }
  }

  // ADD THIS NEW FUNCTION to _MapScreenState
  void _updateUserLocationMarker(Position position) {
    if (!mounted) return;

    // Ensure icons are initialized - initialize synchronously if needed
    if (_userLocationDotIcon == null || _userLocationChevronIcon == null) {
      // Initialize icons asynchronously but update marker immediately with fallback
      _initializeUserLocationIcons().then((_) {
        if (mounted) {
          // Re-update marker with proper icons once initialized
          _updateUserLocationMarkerWithIcons(position);
        }
      });
      return; // Exit early if icons aren't ready yet
    }

    _updateUserLocationMarkerWithIcons(position);
  }

  void _updateUserLocationMarkerWithIcons(Position position) {
    if (!mounted) return;

    final latLng = LatLng(position.latitude, position.longitude);
    final bool isMoving = position.speed > 0.5;
    // Use heading marker when compass mode is active, otherwise chevron/dot
    BitmapDescriptor? icon;
    double rotation = 0;
    bool flat = false;

    if (_isCompassModeActive && _userLocationHeadingIcon != null) {
      icon = _userLocationHeadingIcon;
      rotation = _currentBearing;
      flat = true;
    } else if (isMoving && _userLocationChevronIcon != null) {
      icon = _userLocationChevronIcon;
      rotation = position.heading.isFinite ? position.heading : 0;
      flat = true;
    } else if (_userLocationDotIcon != null) {
      icon = _userLocationDotIcon;
      rotation = 0;
      flat = false;
    }

    if (icon == null) return;
    setState(() {
      _circles.clear();
      _markers.removeWhere((m) => m.markerId.value == 'user_location_marker');

      _markers.add(
        Marker(
          markerId: const MarkerId('user_location_marker'),
          position: latLng,
          icon: icon!,
          rotation: rotation,
          anchor: const Offset(0.5, 0.5),
          flat: flat,
          zIndex: 10,
        ),
      );
    });
  }
  // Draw and update the user's accuracy radius as a circle
  void _updateUserLocationCircle(LatLng latLng, double accuracyMeters) {
    if (!mounted) return;
    final safeAccuracy = accuracyMeters.isFinite && accuracyMeters > 0
        ? accuracyMeters
        : 30.0;
    setState(() {
      _circles.removeWhere((c) => c.circleId.value == 'user_accuracy_circle');
      _circles.add(
        Circle(
          circleId: const CircleId('user_accuracy_circle'),
          center: latLng,
          radius: safeAccuracy,
          fillColor: Colors.blueAccent.withOpacity(0.12),
          strokeColor: Colors.blueAccent.withOpacity(0.35),
          strokeWidth: 2,
          zIndex: 5,
        ),
      );
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
        setState(() => _role = 'Guest');
      }
    }
  }

  Future<void> _fetchDestinationPins() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      List<Map<String, dynamic>> rawDocs = [];

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('destination')
            .get()
            .timeout(const Duration(seconds: 3));

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

        await OfflineCacheService.saveDestinations(rawDocs);
        _isOfflineMode = false;
        _cachedDestinations = rawDocs;
      } catch (_) {
        rawDocs = await OfflineCacheService.loadDestinations();
        _isOfflineMode = rawDocs.isNotEmpty;
        _cachedDestinations = rawDocs;
      }

      final markers = await _markerManager.createMarkersFromDestinations(
        rawDocs,
      );

      if (mounted) {
        setState(() {
          _markers = markers;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching destinations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMarkerTap(Map<String, dynamic> data) {
    if (!mounted) return;
    BusinessDetailsModal.show(
      context: context,
      businessData: data,
      role: _role,
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
      onNavigate: (lat, lng) {
        if (!mounted) return;
        _navigationManager.showNavigationPreview(
          context,
          LatLng(lat, lng),
          data,
        );
      },
    );
  }

  // Cooldown to prevent immediate arrival notifications when map opens
  DateTime? _lastArrivalCheck;
  static const _arrivalCheckCooldown = Duration(
    seconds: 30,
  ); // Increased to 30 seconds to prevent early false positives

  void _checkProximityAndSaveArrival(Position userPosition) async {
    if (!mounted) return;

    // Let NavigationService handle arrivals during active navigation
    if (_isNavigating) return;

    // Get the current navigation destination from NavigationService
    final currentRoute = _navigationService.currentRoute;
    if (currentRoute == null) return;

    // Add cooldown to prevent immediate popup when navigation starts
    final now = DateTime.now();
    if (_lastArrivalCheck != null &&
        now.difference(_lastArrivalCheck!) < _arrivalCheckCooldown) {
      return;
    }

    // Check location permission - works on both iOS and Android
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Validate position accuracy - ensure we have a valid GPS fix
    // Require higher accuracy for arrival detection (better than 50m)
    if (userPosition.accuracy > 50) {
      // Position accuracy too poor (>50m), skip arrival check
      // This prevents false positives from inaccurate GPS readings
      return;
    }

    final userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final destination = currentRoute.destination;

    // Calculate distance to the actual navigation destination (not all markers)
    final distance = _locationManager.calculateDistance(
      userLatLng,
      destination,
    );

    // Arrival detection threshold: 30 meters (reduced for more accuracy)
    // This works consistently on both iOS and Android
    if (distance <= 30) {
      // Find the marker for this destination (skip user location marker)
      Marker? destinationMarker;
      for (final marker in _markers) {
        // Skip user location marker
        if (marker.markerId.value == 'user_location_marker') continue;

        final markerDistance = _locationManager.calculateDistance(
          marker.position,
          destination,
        );

        // Find the closest marker to the destination (within 100m)
        if (markerDistance < 100) {
          destinationMarker = marker;
          break; // Found our destination marker
        }
      }

      // If no valid destination marker found, skip
      if (destinationMarker == null ||
          destinationMarker.markerId.value == 'user_location_marker') {
        return;
      }

      final hotspotId = destinationMarker.markerId.value;

      try {
        // Check if already arrived today (checks both collections)
        final hasArrived = await ArrivalService.hasArrivedToday(hotspotId);
        if (!mounted) return;

        if (!hasArrived) {
          final destinationInfo = _markerManager.getDestinationData(hotspotId);

          // Only save arrival if we have valid destination data
          // Don't save if all we have is null/unknown values
          if (destinationInfo != null &&
              destinationInfo['destinationName'] != null &&
              destinationInfo['destinationName'] != 'Unknown Destination') {
            // Update cooldown to prevent duplicate saves
            _lastArrivalCheck = now;

            // Save arrival with complete destination data
            await NavigationService.saveArrival(
              hotspotId: hotspotId,
              latitude: destination.latitude,
              longitude: destination.longitude,
              businessName:
                  destinationInfo['destinationName'] ??
                  destinationInfo['business_name'] ??
                  destinationInfo['name'],
              destinationName:
                  destinationInfo['destinationName'] ??
                  destinationInfo['business_name'] ??
                  destinationInfo['name'],
              destinationCategory:
                  destinationInfo['destinationCategory'] ??
                  destinationInfo['category'],
              destinationType:
                  destinationInfo['destinationType'] ?? destinationInfo['type'],
              destinationDistrict:
                  destinationInfo['destinationDistrict'] ??
                  destinationInfo['district'],
              destinationMunicipality:
                  destinationInfo['destinationMunicipality'] ??
                  destinationInfo['municipality'],
              destinationImages:
                  destinationInfo['destinationImages']?.cast<String>() ??
                  destinationInfo['images']?.cast<String>(),
              destinationDescription:
                  destinationInfo['destinationDescription'] ??
                  destinationInfo['description'],
            );
            if (!mounted) return;

            // Optional: Show a brief notification that arrival was recorded
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Visited: ${destinationInfo['destinationName'] ?? destinationInfo['business_name'] ?? destinationInfo['name'] ?? 'Destination'}',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        // Log error but don't block location updates
        print('Error checking/saving arrival: $e');
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
    final allMarkers = _markerManager.getAllMarkers();

    // If no filters and no search, show everything.
    if (_searchQuery.isEmpty && _selectedFilterCategory == null) {
      setState(() => _markers = allMarkers);
      return;
    }

    final filtered =
        allMarkers.where((marker) {
          final markerData = _markerManager.getDestinationData(
            marker.markerId.value,
          );
          if (markerData == null) return false;

          // 1. Check search query
          final name = marker.infoWindow.title?.toLowerCase() ?? '';
          final matchesSearch =
              _searchQuery.isEmpty || name.contains(_searchQuery);

          // 2. Check category and sub-category filters
          bool matchesCategoryFilter = true; // Assume it matches by default

          if (_selectedFilterCategory != null) {
            // Get the list of allowed sub-categories for the selected main filter
            final allowedSubCategories =
                _categories[_selectedFilterCategory]
                    ?.map((e) => e.toLowerCase())
                    .toList() ??
                [];

            final markerCategory =
                (markerData['destinationCategory']?.toString() ?? '')
                    .toLowerCase()
                    .trim();
            final markerType =
                (markerData['destinationType']?.toString() ?? '')
                    .toLowerCase()
                    .trim();
            final selectedSubCategory =
                _selectedFilterSubCategory?.toLowerCase().trim();

            if (selectedSubCategory != null && selectedSubCategory.isNotEmpty) {
              // If a sub-category is also selected, check if marker type matches (with fuzzy matching)
              matchesCategoryFilter = _matchesSubCategory(
                markerType,
                selectedSubCategory,
              );
            } else {
              // If only a main category is selected, check if:
              // 1. Marker's main category matches the selected main category (fuzzy match)
              // 2. OR marker's type matches any sub-category in the selected main category

              final selectedMainCategory =
                  _selectedFilterCategory!.toLowerCase().trim();

              // Check if marker category matches main category (accounting for singular/plural, variations)
              final categoryMatches = _matchesMainCategory(
                markerCategory,
                selectedMainCategory,
              );

              // Check if marker type matches any sub-category
              final typeMatches = allowedSubCategories.any(
                (subCat) => _matchesSubCategory(markerType, subCat),
              );

              matchesCategoryFilter = categoryMatches || typeMatches;
            }
          }

          // A marker is shown if it matches both search and active filters
          return matchesSearch && matchesCategoryFilter;
        }).toSet();

    setState(() {
      _markers = filtered;
    });
  }

  /// Helper to match main categories (handles singular/plural, variations)
  bool _matchesMainCategory(String markerCategory, String selectedCategory) {
    if (markerCategory.isEmpty || selectedCategory.isEmpty) return false;

    // Normalize by removing common variations
    String normalize(String cat) {
      return cat
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final normalizedMarker = normalize(markerCategory);
    final normalizedSelected = normalize(selectedCategory);

    // Exact match
    if (normalizedMarker == normalizedSelected) return true;

    // Handle singular/plural variations (e.g., "Natural Attraction" vs "Natural Attractions")
    if (normalizedMarker == '${normalizedSelected}s' ||
        normalizedSelected == '${normalizedMarker}s') {
      return true;
    }

    // Check if one contains the other (for variations like "Natural Attraction" containing "Natural")
    final markerWords = normalizedMarker.split(' ');
    final selectedWords = normalizedSelected.split(' ');

    // If first word matches (e.g., "Natural" in both "Natural Attraction" and "Natural Attractions")
    if (markerWords.isNotEmpty &&
        selectedWords.isNotEmpty &&
        markerWords.first == selectedWords.first) {
      return true;
    }

    // Check for common category mappings
    final categoryMappings = {
      'natural attraction': ['natural attractions'],
      'natural attractions': ['natural attraction'],
      'cultural site': ['cultural & historical', 'cultural', 'historical'],
      'cultural & historical': ['cultural site', 'cultural'],
      'recreational facility': ['recreational facilities'],
      'recreational facilities': ['recreational facility'],
      'agri-tourism & industrial': ['agri-tourism', 'industrial'],
      'culinary & shopping': ['culinary', 'shopping'],
      'events & education': ['events', 'education'],
    };

    if (categoryMappings.containsKey(normalizedMarker)) {
      return categoryMappings[normalizedMarker]!.contains(normalizedSelected);
    }
    if (categoryMappings.containsKey(normalizedSelected)) {
      return categoryMappings[normalizedSelected]!.contains(normalizedMarker);
    }

    return false;
  }

  /// Helper to match sub-categories (handles variations, partial matches)
  bool _matchesSubCategory(String markerType, String selectedSubCategory) {
    if (markerType.isEmpty || selectedSubCategory.isEmpty) return false;

    // Normalize strings
    String normalize(String str) {
      return str.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    }

    final normalizedMarker = normalize(markerType);
    final normalizedSelected = normalize(selectedSubCategory);

    // Exact match
    if (normalizedMarker == normalizedSelected) return true;

    // Check if marker type contains the selected sub-category or vice versa
    if (normalizedMarker.contains(normalizedSelected) ||
        normalizedSelected.contains(normalizedMarker)) {
      return true;
    }

    // Handle common variations and abbreviations
    final variations = {
      'waterfall': ['waterfalls'],
      'waterfalls': ['waterfall'],
      'mountain': ['mountains', 'hill', 'hills'],
      'mountains': ['mountain', 'hill', 'hills'],
      'cave': ['caves'],
      'caves': ['cave'],
      'hot spring': ['hot springs', 'hotspring', 'hotsprings'],
      'hot springs': ['hot spring', 'hotspring', 'hotsprings'],
      'cold spring': ['cold springs', 'coldspring', 'coldsprings'],
      'cold springs': ['cold spring', 'coldspring', 'coldsprings'],
      'lake': ['lakes'],
      'lakes': ['lake'],
      'river': ['rivers'],
      'rivers': ['river'],
      'forest': ['forests', 'woodland', 'woods'],
      'forests': ['forest', 'woodland', 'woods'],
      'resort': ['resorts'],
      'resorts': ['resort'],
      'theme park': ['theme parks'],
      'theme parks': ['theme park'],
      'church': ['churches'],
      'churches': ['church'],
      'temple': ['temples'],
      'temples': ['temple'],
      'museum': ['museums'],
      'museums': ['museum'],
      'festival': ['festivals'],
      'festivals': ['festival'],
      'restaurant': ['restaurants', 'dining', 'eatery'],
      'restaurants': ['restaurant', 'dining', 'eatery'],
      'shop': ['shops', 'shopping', 'store', 'stores'],
      'shops': ['shop', 'shopping', 'store', 'stores'],
      'market': ['markets', 'bazaar'],
      'markets': ['market', 'bazaar'],
      'farm': ['farms', 'agricultural'],
      'farms': ['farm', 'agricultural'],
    };

    if (variations.containsKey(normalizedMarker)) {
      return variations[normalizedMarker]!.contains(normalizedSelected);
    }
    if (variations.containsKey(normalizedSelected)) {
      return variations[normalizedSelected]!.contains(normalizedMarker);
    }

    return false;
  }

  Future<void> _goToMyLocation() async {
    if (_currentLatLng != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLatLng!,
            zoom: 17,
            bearing: _isNavigating ? _currentBearing : 0,
            tilt: _isNavigating ? 45 : 0,
          ),
        ),
      );
    } else {
      await _locationManager.requestLocationUpdate();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _controller.complete(controller);

    // Defer heavy map operations to avoid blocking main thread
    // This prevents ANR warnings during map initialization
    Future.microtask(() async {
      if (!mounted || _mapController == null) return;
      
      try {
        // Map style: Skip on web as it may cause issues, or handle differently
        if (!kIsWeb) {
          // Add small delay to let map fully initialize
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted || _mapController == null) return;
          
          try {
            _mapController?.setMapStyle(AppConstants.kMapStyle);
          } catch (e) {
            if (kDebugMode) debugPrint('Map style error: $e');
            // Handle Google Play Services errors gracefully
            if (e.toString().contains('SecurityException') || 
                e.toString().contains('GoogleApiManager')) {
              if (kDebugMode) {
                debugPrint('Google Play Services error. Running on emulator without Play Services?');
              }
            }
          }

          // iOS specific: Enable compass
          if (Platform.isIOS) {
            try {
              controller.setMapStyle(AppConstants.kMapStyle);
            } catch (e) {
              if (kDebugMode) debugPrint('iOS map style error: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error in deferred map setup: $e');
      }
    });
  }

  void _exitNavigation() {
    _navigationManager.exitNavigation();
    setState(() {
      _polylines.clear();
      _isNavigating = false;
      _didFitRouteOnce = false;
      _isFollowingUser = true;
      _mapType = MapType.normal; // Reset map type to normal when exiting navigation
    });
  }

  void _recenterMap() {
    _navigationManager.recenterMap(
      _mapController,
      _currentLatLng,
      _currentBearing,
    );
  }

  Future<void> _fitPolylinesBounds() async {
    if (_mapController == null || _polylines.isEmpty) return;
    try {
      // Collect all points from route polylines
      final points = <LatLng>[];
      for (final p in _polylines) {
        if (p.points.isNotEmpty) {
          points.addAll(p.points);
        }
      }
      if (points.isEmpty) return;

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;
      for (final pt in points) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
      _didFitRouteOnce = true;
    } catch (_) {}
  }

  // Removed legacy direct-line route helper (road-based routing is used)

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes for proper location tracking on both platforms
    if (state == AppLifecycleState.resumed) {
      // App resumed: resume location tracking and check for arrivals
      _locationManager.resumeLocationTracking();
      // Request a location update to check proximity immediately after resume
      _locationManager.requestLocationUpdate();
    } else if (state == AppLifecycleState.paused) {
      // App paused: pause location tracking to save battery
      // Note: On iOS, location tracking may continue in background if "Always" permission is granted
      // On Android, background location requires additional permissions
      _locationManager.pauseLocationTracking();
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated: location tracking will be cleaned up in dispose()
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _locationManager.dispose();
    _navigationManager.dispose();
    _navigationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMoveStarted: () {
              // Only break following on user gestures, not programmatic animations
              if (_isNavigating && !_isAnimatingCamera) {
                _isFollowingUser = false;
              }
            },
            onCameraMove: (position) {
              _navigationService.updateBearing(position.bearing);
            },
            onCameraIdle: () {
              if (_isAnimatingCamera) {
                setState(() {
                  _isAnimatingCamera = false;
                });
              }
            },
            initialCameraPosition: CameraPosition(
              target: AppConstants.bukidnonCenter,
              zoom: AppConstants.kInitialZoom,
            ),
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true, // Enable compass for iOS
            zoomControlsEnabled: false,
            mapType: _isNavigating ? _mapType : MapType.normal,
            cameraTargetBounds: CameraTargetBounds(AppConstants.bukidnonBounds),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 250,

              bottom: 80 + bottomPadding,
            ),
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: false,
          ),

          // NavigationMapController removed; MapNavigationManager handles polylines and camera

          MapUIComponents.buildTopControls(
            context: context,
            isNavigating: _isNavigating,
            topPadding: MediaQuery.of(context).padding.top,
            // NOTE: You will need to pass the onChanged, onClear, and onFilterTap
            // callbacks from your screen into this component.
          ),

          // Debug following banner removed

          // Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UniversalSearchBar(
              onChanged: _onSearchChanged,
              onClear: _onSearchCleared,
              onFilterTap: () {
                MapUIComponents.showFilterSheet(
                  context: context,
                  categories: _categories,
                  onApply: (category, subCategory) {
                    // This code runs when the user taps "Apply" or "Clear"
                    setState(() {
                      _selectedFilterCategory = category;
                      _selectedFilterSubCategory = subCategory;
                    });
                    // Now, trigger your filter logic
                    _filterMarkers();
                  },
                );
              },
            ),
          ),

          // This will only build the bar if at least one filter is active.
          if (_selectedFilterCategory != null ||
              _selectedFilterSubCategory != null)
            MapUIComponents.buildActiveFiltersBar(
              category: _selectedFilterCategory,
              subCategory: _selectedFilterSubCategory,
              onClear: _clearFilters, // Pass the clear function to the button
            ),

          // Loading Indicator
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Location Permission Banner
          if (_showLocationBanner)
            MapUIComponents.buildLocationBanner(
              context,
              _locationBannerText,
              () async {
                final hasPermission = await _locationManager
                    .handleLocationPermission(context);
                if (hasPermission) {
                  await _locationManager.startLocationTracking();
                }
              },
            ),

          if (_isNavigating &&
              _navigationManager.currentDestinationName != null)
            MapUIComponents.buildDestinationBanner(
              destinationName: _navigationManager.currentDestinationName!,
              topPadding: MediaQuery.of(context).padding.top,
            ),

          // Offline Mode Banner
          if (_isOfflineMode) MapUIComponents.buildOfflineBanner(),

          // Offline Cached Destinations List
          if (_isOfflineMode && _cachedDestinations.isNotEmpty)
            MapUIComponents.buildOfflineDestinationsList(
              context,
              _cachedDestinations,
              bottomPadding,
              _role,
            ),

          // Navigation Overlay
          if (_role.toLowerCase() != 'guest' && !_isOfflineMode)
            NavigationOverlay(
              navigationService: _navigationService,
              onExitNavigation: _exitNavigation,
              onMapTypeChanged: (mapType) {
                setState(() {
                  _mapType = mapType;
                });
              },
              currentMapType: _mapType,
            ),

          Positioned(
            // A fixed position on the bottom right, which is standard for map apps.
            bottom: 24 + bottomPadding,
            right: 16,
            // We use the nice iOS-style button and pass our new smart function to it.
            child: GestureDetector(
              onDoubleTap: _toggleCompassMode, // Double-tap toggles compass mode
              child: MapUIComponents.buildMyLocationButton(
                _onMyLocationButtonPressed, // Single tap recenters
              ),
            ),
          ),
        ],
      ),
    );
  }
}
