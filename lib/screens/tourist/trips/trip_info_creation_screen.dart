// ===========================================
// lib/screens/tourist_module/trips/trip_basic_info_screen.dart
// ===========================================
// Screen for entering basic trip information.



import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:capstone_app/utils/colors.dart';

import 'transportation_selection_screen.dart';

/// Screen for entering basic trip information.
class TripBasicInfoScreen extends StatefulWidget {
  final String destination;
  final String? initialTripName;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const TripBasicInfoScreen({super.key, required this.destination, this.initialTripName, this.initialStartDate, this.initialEndDate});

  @override
  State<TripBasicInfoScreen> createState() => _TripBasicInfoScreenState();
}

class _TripBasicInfoScreenState extends State<TripBasicInfoScreen> {
  // Layout and label constants
  static const int _totalSteps = 3;
  static const int _currentStep = 1;
  static const double _fieldSpacing = 24.0;
  static const double _buttonSpacing = 32.0;
  static const double _progressIndicatorHeight = 6.0;
  static const double _progressIndicatorMargin = 4.0;
  static const double _nextButtonHeight = 50.0;
  static const double _bottomSpacing = 20.0;
  static const String _tripDetailsLabel = 'Trip Details';
  static const String _tripNameLabel = 'Trip Name';
  static const String _tripNameHint = 'Enter trip name';
  static const String _tripDatesLabel = 'Trip Dates';
  static const String _startDateLabel = 'Start Date';
  static const String _endDateLabel = 'End Date';
  static const String _nextButtonLabel = 'Next';
  static const String _tripNameEmptyError = 'Please enter a trip name';
  static const String _tripDatesEmptyError = 'Please select both start and end dates';
  static const String _quickPresetsLabel = 'Quick presets';

  // Controllers
  final TextEditingController _tripNameController = TextEditingController();

  // Trip date state
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultValues();
  }

  /// Initializes default values for trip name and dates
  void _initializeDefaultValues() {
    _startDate = widget.initialStartDate ?? DateTime.now().add(const Duration(days: 1));
    _endDate = widget.initialEndDate ?? DateTime.now().add(const Duration(days: 3));
    _tripNameController.text = widget.initialTripName ?? '${widget.destination} ${DateTime.now().year}';
    _tripNameController.addListener(_recomputeValidity);
    _recomputeValidity();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  void _recomputeValidity() {
    final valid = _tripNameController.text.isNotEmpty && _startDate != null && _endDate != null;
    if (valid != _isValid) {
      setState(() {
        _isValid = valid;
      });
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
            Expanded(child: _buildBasicInfoContent()),
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
                      'Trip Details',
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
            'Step 1 of 3',
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

  /// Builds the main content area for entering trip info
  Widget _buildBasicInfoContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_rounded,
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
                          _tripDetailsLabel,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter your trip information',
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
            ),
            const SizedBox(height: 24),
            _buildTripNameField(),
            const SizedBox(height: _fieldSpacing),
            _buildTripDatesSection(),
            const SizedBox(height: 16),
            _buildQuickPresets(),
            const SizedBox(height: _buttonSpacing),
            _buildNextButton(),
            const SizedBox(height: _bottomSpacing),
          ],
        ),
      ),
    );
  }

  /// Builds the trip name input field
  Widget _buildTripNameField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.title_rounded,
                color: AppColors.primaryTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _tripNameLabel,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryOrange.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _tripNameController,
              decoration: InputDecoration(
                hintText: _tripNameHint,
                hintStyle: TextStyle(color: AppColors.textLight),
                prefixIcon: Icon(
                  Icons.edit_rounded,
                  color: AppColors.primaryOrange,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the trip dates section with start and end date pickers
  Widget _buildTripDatesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primaryTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _tripDatesLabel,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDateField(isStartDate: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateField(isStartDate: false)),
            ],
          ),
          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryTeal.withOpacity(0.1),
                    AppColors.primaryOrange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryTeal.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primaryTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_calculateTripDuration()} day${_calculateTripDuration() != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Quick date presets for convenience
  Widget _buildQuickPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          _quickPresetsLabel,
          style: TextStyle(color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip('Weekend', days: 2),
            _buildPresetChip('3 days', days: 3),
            _buildPresetChip('5 days', days: 5),
            _buildPresetChip('1 week', days: 7),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, {required int days}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withOpacity(0.1),
            AppColors.primaryOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryTeal.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final now = DateTime.now();
            setState(() {
              _startDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
              _endDate = _startDate!.add(Duration(days: days - 1));
            });
            _recomputeValidity();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a date field (start or end)
  Widget _buildDateField({required bool isStartDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStartDate ? _startDateLabel : _endDateLabel,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        _buildDateSelector(isStartDate),
      ],
    );
  }

  /// Builds the date selector widget
  Widget _buildDateSelector(bool isStartDate) {
    final date = isStartDate ? _startDate : _endDate;
    final formattedDate =
        date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Select date';
    return GestureDetector(
      onTap: () => _selectDate(isStartDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isStartDate ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
                size: 18,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStartDate ? 'Start' : 'End',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.primaryOrange,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the next button to continue to transportation selection
  Widget _buildNextButton() {
    return Container(
      width: double.infinity,
      height: _nextButtonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isValid
              ? [
                  AppColors.primaryOrange,
                  AppColors.primaryOrange.withOpacity(0.8),
                ]
              : [
                  Colors.grey.shade300,
                  Colors.grey.shade300,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isValid
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
          onTap: _isValid ? _continueToTransportation : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _nextButtonLabel,
                  style: TextStyle(
                    color: _isValid ? Colors.white : Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _isValid ? Colors.white : Colors.grey.shade600,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a date picker and updates the selected date
  Future<void> _selectDate(bool isStartDate) async {
    final initialDate =
        isStartDate
            ? _startDate ?? DateTime.now()
            : _endDate ??
                (_startDate ?? DateTime.now()).add(const Duration(days: 1));
    final firstDate =
        isStartDate ? DateTime.now() : _startDate ?? DateTime.now();
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryOrange),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
      _recomputeValidity();
    }
  }

  /// Calculates the trip duration in days
  int _calculateTripDuration() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  /// Validates input and continues to transportation selection
  void _continueToTransportation() {
    if (!_validateInputs()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportationSelectionScreen(
          destination: widget.destination,
          tripName: _tripNameController.text,
          startDate: _startDate!,
          endDate: _endDate!,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
         if (mounted) {
      Navigator.pop(context, result);
    } // Pass result up to TripsScreen
      }
    });
  }

  /// Validates trip name and dates
  bool _validateInputs() {
    if (_tripNameController.text.isEmpty) {
      _showValidationError(_tripNameEmptyError);
      return false;
    }
    if (_startDate == null || _endDate == null) {
      _showValidationError(_tripDatesEmptyError);
      return false;
    }
    return true;
  }

  /// Shows a SnackBar with the given error message
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
