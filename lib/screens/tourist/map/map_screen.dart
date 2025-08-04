// ignore_for_file: prefer_final_fields, avoid_print, unused_field

import 'dart:async';
import 'package:capstone_app/widgets/common_search_bar.dart';
import 'package:capstone_app/widgets/custom_map_marker.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLatLng;
  double _heading = 0;
  StreamSubscription<CompassEvent>? _headingStream;
  double _smoothedHeading = 0;
  final smoothingFactor = 0.1; // smaller = smoother

  Set<Marker> _markers = {};
  Set<Marker> _allMarkers = {}; // ✅ Store all markers here
  bool _isLoading = false;

  String _searchQuery = '';
  String _role = 'Tourist';

  @override
  void initState() {
    super.initState();
    _fetchDestinationPins();
    _startLocationStream(); // Start streaming location
    _headingStream = FlutterCompass.events!.listen((CompassEvent event) {
      if (event.heading != null) {
        setState(() {
           _smoothedHeading = _smoothedHeading + smoothingFactor * (event.heading! - _smoothedHeading);
        });
      }
    });
  }

  @override
void dispose() {
  _positionStream?.cancel();
  _headingStream?.cancel();
  super.dispose();
}

  void _startLocationStream() {
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // meters before update
  );

  _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position position) {
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });

      // Optionally, animate camera toward the user if needed
      // _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
    },
  );
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
    if (_searchQuery.isEmpty) {
      setState(() => _markers = _allMarkers);
      return;
    }

    final filtered = _allMarkers.where((marker) {
      final name = marker.infoWindow.title?.toLowerCase() ?? '';
      return name.contains(_searchQuery);
    }).toSet();

    setState(() {
      _markers = filtered;
    });
  }

  Future<void> _fetchDestinationPins() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
        setState(() {
          _role = userDoc.data()?['role'] ?? 'Guest';
        });
      }

      final snapshot = await FirebaseFirestore.instance.collection('destination').get();
      final markers = <Marker>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'];
        final lng = data['longitude'];
        final name = data['business_name'] ?? 'Tourist Spot';

        if (lat != null && lng != null) {
          final position = LatLng((lat as num).toDouble(), (lng as num).toDouble());

          final customIcon = await CustomMapMarker.createTextMarker(
            label: name,
            color: Colors.orange,
          );

          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: position,
            icon: customIcon,
            infoWindow: InfoWindow(title: name), // 👈 for filtering by title
            onTap: () {
              BusinessDetailsModal.show(
                context: context,
                businessData: data,
                role: _role,
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
    } catch (e) {
      print('Error fetching destinations: $e');
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _controller.complete(controller);
    _mapController?.setMapStyle(AppConstants.kMapStyle);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // appBar: AppBar(title: const Text('Tourist Map')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: AppConstants.bukidnonCenter,
              zoom: AppConstants.kInitialZoom,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            cameraTargetBounds: CameraTargetBounds(AppConstants.bukidnonBounds),
            padding: EdgeInsets.only(bottom: 80 + bottomPadding),
          ),

          // ✅ Positioned Search Bar at the Top
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

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          Positioned(
            bottom: 16 + bottomPadding,
            right: 16,
            child: FloatingActionButton(
              heroTag: Positioned(
                bottom: 100 + bottomPadding,
                right: 16,
                child: Transform.rotate(
                  angle: (_heading * (math.pi / 180) * -1), // Convert degrees to radians
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                    ),
                    child: const Icon(Icons.navigation, size: 30, color: Colors.blue),
                  ),
                ),
              ),
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter Tourist Spots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Municipality Dropdown
              DropdownButtonFormField<String>(
                value: null, // set your selectedMunicipality variable here
                items: ['Malaybalay', 'Valencia', 'Manolo Fortich']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  // Save selected municipality
                },
                decoration: const InputDecoration(labelText: 'Municipality'),
              ),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: null, // selectedCategory
                items: ['Park', 'Museum', 'Eco-tourism']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  // Save selected category
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),

              // Type Dropdown
              DropdownButtonFormField<String>(
                value: null, // selectedType
                items: ['Natural', 'Cultural', 'Adventure']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  // Save selected type
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Call a method like _applyFilters()
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        );
      },
    );
  }

}
