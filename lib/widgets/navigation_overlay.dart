import 'package:flutter/material.dart';
import 'package:capstone_app/services/navigation_service.dart';

class NavigationOverlay extends StatefulWidget {
  final NavigationService navigationService;
  final VoidCallback onExitNavigation;

  const NavigationOverlay({
    super.key,
    required this.navigationService,
    required this.onExitNavigation,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  bool _isNavigating = false;
  bool _showVehicleSelector = false;
  Map<String, dynamic> _remainingInfo = {};

  @override
  void initState() {
    super.initState();
    _listenToNavigationUpdates();
  }

  void _listenToNavigationUpdates() {
    // Listen to navigation state changes
    widget.navigationService.navigationStateStream.listen((isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = isNavigating;
          if (isNavigating) {
            _remainingInfo = widget.navigationService.getRemainingInfo();
          }
        });
      }
    });

    // Listen to step changes to update remaining info
    widget.navigationService.stepStream.listen((step) {
      if (mounted) {
        setState(() {
          _remainingInfo = widget.navigationService.getRemainingInfo();
        });
      }
    });

    // ADD THIS: Listen to transportation mode changes
    widget.navigationService.transportationModeStream.listen((mode) {
      if (mounted && _isNavigating) {
        setState(() {
          _remainingInfo = widget.navigationService.getRemainingInfo();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNavigating) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Vehicle selector overlay
        if (_showVehicleSelector) _buildVehicleSelector(),

        // Duration display at top
        Positioned(
          top: 120, // Moved down to avoid overlap with search bar
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_remainingInfo['duration'] ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${_formatDistance(_remainingInfo['distance'] ?? 0)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),

        // Control buttons on the right
        Positioned(
          top: 120, // Aligned with duration display
          right: 16,
          child: Column(
            children: [
              // Vehicle selection button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton(
                  heroTag: "transportButton",
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _showVehicleSelector = !_showVehicleSelector;
                    });
                  },
                  child: Text(
                    widget.navigationService.getTransportationModeIcon(
                      widget.navigationService.currentTransportationMode,
                    ),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),

              // Exit navigation button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton(
                  heroTag: "exitButton",
                  backgroundColor: Colors.red[50],
                  onPressed: widget.onExitNavigation,
                  child: Icon(Icons.close, color: Colors.red[600]),
                ),
              ),
            ],
          ),
        ),
        //Re-center button removed - using the one from base map
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  Widget _buildVehicleSelector() {
    return Positioned(
      top: 180, // Moved below the duration display
      left: 16,
      right: 80,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8), // Added margin for spacing
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), // Increased shadow opacity
              blurRadius: 12, // Increased blur for better elevation
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Transportation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  widget.navigationService
                      .getAvailableTransportationModes()
                      .map((mode) {
                        final isSelected =
                            mode ==
                            widget.navigationService.currentTransportationMode;
                        return GestureDetector(
                          onTap: () {
                            widget.navigationService.changeTransportationMode(
                              mode,
                            );
                            setState(() {
                              _showVehicleSelector = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? widget.navigationService
                                          .getTransportationModeColor(mode)
                                          .withOpacity(0.2)
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? widget.navigationService
                                            .getTransportationModeColor(mode)
                                        : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.navigationService
                                      .getTransportationModeIcon(mode),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.navigationService
                                      .getTransportationModeDisplayName(mode),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? widget.navigationService
                                                .getTransportationModeColor(
                                                  mode,
                                                )
                                            : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
