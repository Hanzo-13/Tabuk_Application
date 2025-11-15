// ===========================================
// lib/screens/tourist_module/trips/transportation_selection_screen.dart
// ===========================================
// Screen for selecting transportation method for a trip.



import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

import 'destination_selection_screen.dart';

/// Enum representing transportation options.
enum TransportationType { motorcycle, walk, car, none }

/// Screen for selecting transportation method for a trip.
class TransportationSelectionScreen extends StatefulWidget {
  final String destination;
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final String? initialTransportation;

  const TransportationSelectionScreen({
    super.key,
    required this.destination,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    this.initialTransportation,
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
  static const String _headerSubtitle = 'Select an available transportation method';
  static const String _backButtonLabel = 'Back';
  static const String _nextButtonLabel = 'Next';
  static const String _selectTransportError = 'Please select a transportation method';
  static const String _selectedHint = 'Tap again to deselect';

  // Current selected transportation
  TransportationType _selectedTransportation = TransportationType.none;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransportation != null) {
      final t = widget.initialTransportation!.toLowerCase();
      if (t == 'motorcycle') _selectedTransportation = TransportationType.motorcycle;
      if (t == 'walk') _selectedTransportation = TransportationType.walk;
      if (t == 'car') _selectedTransportation = TransportationType.car;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildProgressIndicator(),
            Expanded(child: _buildTransportationContent()),
          ],
        ),
      ),
    );
  }

  /// Builds a custom gradient app bar
  Widget _buildCustomAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryTeal.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transportation',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Trip to ${widget.destination}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the progress indicator showing current step
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index < _currentStep;
              return Expanded(
                child: Container(
                  height: _progressIndicatorHeight,
                  margin: const EdgeInsets.symmetric(horizontal: _progressIndicatorMargin),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [
                              AppColors.primaryOrange,
                              AppColors.primaryOrange.withOpacity(0.8),
                            ],
                          )
                        : null,
                    color: isActive ? null : AppColors.textLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primaryOrange.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step 2 of 3',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal.withOpacity(0.1),
            AppColors.primaryOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryTeal.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_rounded,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headerTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _headerSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
            type: TransportationType.motorcycle,
            icon: Icons.two_wheeler,
            label: 'Motorcycle',
          ),
          _buildTransportationOption(
            type: TransportationType.walk,
            icon: Icons.directions_walk,
            label: 'Walk',
          ),
          _buildTransportationOption(
            type: TransportationType.car,
            icon: Icons.directions_car,
            label: 'Car',
          ),
        ],
      ),
    );
  }

  /// Fixed version - builds a single transportation option card
  Widget _buildTransportationOption({
    required TransportationType type,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedTransportation == type;
    return GestureDetector(
      onTap: () => _selectTransportation(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(_optionPadding),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryOrange.withOpacity(0.15),
                    AppColors.primaryOrange.withOpacity(0.05),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryOrange
                : AppColors.textLight.withOpacity(0.2),
            width: isSelected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(_optionBorderRadius),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.3),
                blurRadius: _optionBoxShadowBlur,
                offset: const Offset(0, _optionBoxShadowOffsetY),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryOrange,
                          AppColors.primaryOrange.withOpacity(0.8),
                        ],
                      )
                    : null,
                color: isSelected ? null : AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: _optionIconSize,
                color: isSelected ? Colors.white : AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _selectedHint,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the navigation buttons (back and next)
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryOrange,
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text(
                      _backButtonLabel,
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _buttonSpacing),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTransportationSelected()
                      ? [
                          AppColors.primaryOrange,
                          AppColors.primaryOrange.withOpacity(0.8),
                        ]
                      : [
                          Colors.grey.shade300,
                          Colors.grey.shade300,
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isTransportationSelected()
                    ? [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isTransportationSelected() ? _continueToDestinations : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nextButtonLabel,
                          style: TextStyle(
                            color: _isTransportationSelected()
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: _isTransportationSelected()
                              ? Colors.white
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
      case TransportationType.motorcycle:
        return 'Motorcycle';
      case TransportationType.walk:
        return 'Walk';
      case TransportationType.car:
        return 'Car';
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
  final String tripPlanId = DateTime.now().millisecondsSinceEpoch.toString();
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DestinationSelectionScreen(
        tripPlanId: tripPlanId,
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
