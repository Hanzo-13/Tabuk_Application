import 'dart:async';
import 'dart:math' as math;

import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:capstone_app/utils/colors.dart';
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
      onPolylinesChanged(polylines);
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

    // Get current position for origin (start point of direct line)
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

    // NEW STRATEGY: Use OpenRouteService for road-based routing
    // NavigationService will handle route calculation and polyline creation
    // No need to draw direct line - OpenRouteService provides proper road routes
    final success = await navigationService.startNavigation(
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
    
    // Hide loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    
    if (!success && context.mounted) {
      // Provide more helpful error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to calculate route. Please check your internet connection and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
    
    // The listeners set up in init() will handle updating the UI state.
    onStateUpdated();
  }

  /// Exit navigation.
  void exitNavigation() {
    navigationService.stopNavigation();
  }

  // ADD THIS NEW METHOD

  /// Update camera position for navigation with smooth animation
  // void updateCameraForNavigation(
  //   GoogleMapController controller,
  //   LatLng position,
  //   double bearing,
  // ) {
  //   final currentStep = navigationService.getCurrentStep();
  //   if (currentStep != null) {
  //     // Calculate bearing to next step
  //     final stepBearing = _calculateBearing(position, currentStep.endLocation);

  //     controller.animateCamera(
  //       CameraUpdate.newCameraPosition(
  //         CameraPosition(
  //           target: position,
  //           zoom: 18.5, // Higher zoom for navigation
  //           bearing: stepBearing,
  //           tilt: 60.0, // 3D perspective
  //         ),
  //       ),
  //     );
  //   }
  // }

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

    return 0.0;
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
