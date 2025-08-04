// ===========================================
// lib/screens/tourist_module/trips/transportation_selection_screen.dart
// ===========================================
// Screen for selecting transportation method for a trip.



import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

import 'destination_selection_screen.dart';

/// Enum representing transportation options.
enum TransportationType { car, plane, bus, boat, none }

/// Screen for selecting transportation method for a trip.
class TransportationSelectionScreen extends StatefulWidget {
  final String destination;
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;

  const TransportationSelectionScreen({
    super.key,
    required this.destination,
    required this.tripName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<TransportationSelectionScreen> createState() =>
      _TransportationSelectionScreenState();
}

class _TransportationSelectionScreenState
    extends State<TransportationSelectionScreen> {
  // Stepper and layout constants
  static const int _currentStep = 2;
  static const int _totalSteps = 3;
  static const double _progressIndicatorHeight = 6.0;
  static const double _progressIndicatorMargin = 4.0;
  static const double _optionPadding = 16.0;
  static const double _optionBorderRadius = 12.0;
  static const double _optionIconSize = 36.0;
  static const double _optionBoxShadowBlur = 8.0;
  static const double _optionBoxShadowOffsetY = 2.0;
  static const double _sectionSpacing = 24.0;
  static const double _buttonSpacing = 16.0;
  static const String _headerTitle = 'How will you travel?';
  static const String _headerSubtitle = 'Select your preferred transportation method';
  static const String _backButtonLabel = 'Back';
  static const String _nextButtonLabel = 'Next';
  static const String _selectTransportError = 'Please select a transportation method';

  // Current selected transportation
  TransportationType _selectedTransportation = TransportationType.none;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(child: _buildTransportationContent()),
        ],
      ),
    );
  }

  /// Builds the app bar with trip destination title
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Trip to ${widget.destination}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  /// Builds the progress indicator showing current step
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: Container(
              height: _progressIndicatorHeight,
              margin: const EdgeInsets.symmetric(horizontal: _progressIndicatorMargin),
              decoration: BoxDecoration(
                color: index < _currentStep
                    ? AppColors.primaryOrange
                    : AppColors.textLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Builds the main content area with transportation options
  Widget _buildTransportationContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: _sectionSpacing),
          _buildTransportationGrid(),
          const SizedBox(height: _sectionSpacing),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  /// Builds the header section with title and description
  Widget _buildHeaderSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headerTitle,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          _headerSubtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  /// Builds the grid of transportation options
  Widget _buildTransportationGrid() {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildTransportationOption(
            type: TransportationType.car,
            icon: Icons.directions_car,
            label: 'Car',
          ),
          _buildTransportationOption(
            type: TransportationType.plane,
            icon: Icons.flight,
            label: 'Plane',
          ),
          _buildTransportationOption(
            type: TransportationType.bus,
            icon: Icons.directions_bus,
            label: 'Bus',
          ),
          _buildTransportationOption(
            type: TransportationType.boat,
            icon: Icons.directions_boat,
            label: 'Boat',
          ),
        ],
      ),
    );
  }

  /// Builds a single transportation option card
  Widget _buildTransportationOption({
    required TransportationType type,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedTransportation == type;
    return GestureDetector(
      onTap: () => _selectTransportation(type),
      child: Container(
        padding: const EdgeInsets.all(_optionPadding),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryOrange
                : AppColors.textLight.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(_optionBorderRadius),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.15),
                blurRadius: _optionBoxShadowBlur,
                offset: const Offset(0, _optionBoxShadowOffsetY),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: _optionIconSize,
              color: isSelected ? AppColors.primaryOrange : AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the navigation buttons (back and next)
  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side: const BorderSide(color: AppColors.primaryOrange),
            ),
            child: const Text(_backButtonLabel),
          ),
        ),
        const SizedBox(width: _buttonSpacing),
        Expanded(
          child: ElevatedButton(
            onPressed: _continueToDestinations,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text(_nextButtonLabel),
          ),
        ),
      ],
    );
  }

  /// Updates the selected transportation type
  void _selectTransportation(TransportationType type) {
    setState(() {
      // Toggle selection if already selected
      if (_selectedTransportation == type) {
        _selectedTransportation = TransportationType.none;
      } else {
        _selectedTransportation = type;
      }
    });
  }

  /// Checks if any transportation option is selected
  bool _isTransportationSelected() {
    return _selectedTransportation != TransportationType.none;
  }

  /// Gets the string representation of the selected transportation
  String _getSelectedTransportationString() {
    switch (_selectedTransportation) {
      case TransportationType.car:
        return 'Car';
      case TransportationType.plane:
        return 'Plane';
      case TransportationType.bus:
        return 'Bus';
      case TransportationType.boat:
        return 'Boat';
      case TransportationType.none:
        return 'Not specified';
    }
  }

  /// Navigates to the destination selection screen
  void _continueToDestinations() async {
  if (!_isTransportationSelected()) {
    _showError(_selectTransportError, AppColors.primaryOrange);
    return;
  }
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DestinationSelectionScreen(
        destination: widget.destination,
        tripName: widget.tripName,
        startDate: widget.startDate,
        endDate: widget.endDate,
        transportation: _getSelectedTransportationString(),
      ),
    ),
  );
  if (!mounted) return; 
  if (result != null && result is Map<String, dynamic>) {
    Navigator.pop(context, result);
  }
}
  /// Shows a SnackBar with the given error message and color
  void _showError(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
