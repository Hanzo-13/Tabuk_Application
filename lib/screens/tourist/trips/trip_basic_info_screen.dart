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

  const TripBasicInfoScreen({super.key, required this.destination});

  @override
  State<TripBasicInfoScreen> createState() => _TripBasicInfoScreenState();
}

class _TripBasicInfoScreenState extends State<TripBasicInfoScreen> {
  // Layout and label constants
  static const int _totalSteps = 3;
  static const int _currentStep = 1;
  static const double _sectionSpacing = 16.0;
  static const double _fieldSpacing = 24.0;
  static const double _buttonSpacing = 32.0;
  static const double _progressIndicatorHeight = 6.0;
  static const double _progressIndicatorMargin = 4.0;
  static const double _dateFieldWidth = 160.0;
  static const double _dateFieldSpacing = 16.0;
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

  // Controllers
  final TextEditingController _tripNameController = TextEditingController();

  // Trip date state
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializeDefaultValues();
  }

  /// Initializes default values for trip name and dates
  void _initializeDefaultValues() {
    _startDate = DateTime.now().add(const Duration(days: 1));
    _endDate = DateTime.now().add(const Duration(days: 3));
    _tripNameController.text = '${widget.destination} ${DateTime.now().year}';
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(child: _buildBasicInfoContent()),
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

  /// Builds the main content area for entering trip info
  Widget _buildBasicInfoContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _tripDetailsLabel,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: _sectionSpacing),
            _buildTripNameField(),
            const SizedBox(height: _fieldSpacing),
            _buildTripDatesSection(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          _tripNameLabel,
          style: TextStyle(color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tripNameController,
          decoration: InputDecoration(
            hintText: _tripNameHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryOrange),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primaryOrange,
                width: 2,
              ),
            ),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  /// Builds the trip dates section with start and end date pickers
  Widget _buildTripDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(_tripDatesLabel, style: TextStyle(color: AppColors.textLight)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(width: _dateFieldWidth, child: _buildDateField(isStartDate: true)),
              const SizedBox(width: _dateFieldSpacing),
              SizedBox(width: _dateFieldWidth, child: _buildDateField(isStartDate: false)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_startDate != null && _endDate != null)
          Text(
            '${_calculateTripDuration()} days',
            style: const TextStyle(
              color: AppColors.primaryTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryOrange),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                formattedDate,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the next button to continue to transportation selection
  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: _nextButtonHeight,
      child: ElevatedButton(
        onPressed: _continueToTransportation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        child: const Text(
          _nextButtonLabel,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
