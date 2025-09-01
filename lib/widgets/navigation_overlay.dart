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
  NavigationStep? _currentStep;
  Map<String, dynamic> _remainingInfo = {};
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _listenToNavigationUpdates();
  }

  void _listenToNavigationUpdates() {
    // Listen to current step updates
    widget.navigationService.stepStream.listen((step) {
      if (mounted) {
        setState(() {
          _currentStep = step;
          _remainingInfo = widget.navigationService.getRemainingInfo();
        });
      }
    });

    // Listen to navigation state changes
    widget.navigationService.navigationStateStream.listen((isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = isNavigating;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNavigating || _currentStep == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Top instruction card
        _buildInstructionCard(),
        
        const Spacer(),
        
        // Bottom trip info card
        _buildTripInfoCard(),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      margin: const EdgeInsets.only(top: 60, left: 16, right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current step info
          Row(
            children: [
              Icon(
                _getDirectionIcon(_currentStep!.instruction),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentStep!.instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Distance and step counter
          Row(
            children: [
              Text(
                _formatDistance(_currentStep!.distance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Step ${_remainingInfo['currentStep'] ?? 1} of ${_remainingInfo['totalSteps'] ?? 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Exit button
          GestureDetector(
            onTap: widget.onExitNavigation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.red[600],
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Trip information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(_remainingInfo['duration'] ?? 0),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDistance(_remainingInfo['distance'] ?? 0)} remaining',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Re-center button
          GestureDetector(
            onTap: () {
              widget.navigationService.forceRecenter();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.my_location,
                color: Colors.blue[600],
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDirectionIcon(String instruction) {
    final lowerInstruction = instruction.toLowerCase();
    
    if (lowerInstruction.contains('turn left') || lowerInstruction.contains('left')) {
      return Icons.turn_left;
    } else if (lowerInstruction.contains('turn right') || lowerInstruction.contains('right')) {
      return Icons.turn_right;
    } else if (lowerInstruction.contains('u-turn') || lowerInstruction.contains('u turn')) {
      return Icons.u_turn_left;
    } else if (lowerInstruction.contains('arrive') || lowerInstruction.contains('destination')) {
      return Icons.location_on;
    } else {
      return Icons.arrow_upward;
    }
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
}
