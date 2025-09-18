// ===========================================
// lib/screens/tourist_module/trips/destination_selection_screen.dart
// ===========================================
// Screen for selecting places to visit during a trip.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/models/place.dart';
import 'package:capstone_app/models/trip_model.dart';
import 'package:capstone_app/models/destination_model.dart';
import 'package:capstone_app/services/trip_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trip_review_screen.dart';

/// Screen for selecting places to visit during a trip.
class DestinationSelectionScreen extends StatefulWidget {
  final String tripPlanId;
  final String destination;
  final String tripName;
  final DateTime startDate;
  final DateTime endDate;
  final String transportation;
  final List<String>? initialSpots;

  const DestinationSelectionScreen({
    super.key,
    required this.tripPlanId,
    required this.destination,
    required this.tripName,
    required this.startDate,
    required this.endDate,
    required this.transportation,
    this.initialSpots,
  });

  @override
  State<DestinationSelectionScreen> createState() =>
      _DestinationSelectionScreenState();
}

class _DestinationSelectionScreenState extends State<DestinationSelectionScreen> {
  // Constants
  static const double _padding = 16.0;
  static const double _progressIndicatorHeight = 6.0;
  static const double _progressIndicatorMargin = 4.0;
  static const double _customPlaceIconSize = 20.0;
  static const double _customPlaceButtonPadding = 12.0;
  static const double _customPlaceBorderRadius = 8.0;
  static const double _itinerarySectionSpacing = 8.0;
  static const double _popularPlacesSectionSpacing = 8.0;
  static const String _addCustomPlaceLabel = 'Add Custom Place';
  static const String _addButtonLabel = 'Add';
  static const String _finishButtonLabel = 'Finish';
  static const String _yourItineraryLabel = 'Your Itinerary';
  static const String _selectPlacesLabel = 'Select places to visit';
  static const String _addPlacesDescription = 'Add places from suggestions or create your own';
  static const String _cancelButtonLabel = 'Cancel';
  static const String _saveButtonLabel = 'Save';
  static const String _placeNameEmptyError = 'Please enter a place name';
  static const String _placeAlreadyExistsError = 'This place is already in your itinerary';
  static const String _tripAddPlaceError = 'Please add at least one place to your itinerary';

  // State variables
  final List<PlaceVisit> _placesToVisit = [];
  final TextEditingController _placeController = TextEditingController();
  String? _currentlyEditingPlace;
  DateTime? _selectedPlaceDate;
  List<Hotspot> _hotspots = [];
  bool _loadingHotspots = true;

  @override
  void initState() {
    super.initState();
    _fetchHotspots();
    _selectedPlaceDate = widget.startDate;
    if (widget.initialSpots != null && widget.initialSpots!.isNotEmpty) {
      // Preload itinerary without dates; default to startDate
      for (final s in widget.initialSpots!) {
        _placesToVisit.add(PlaceVisit(place: s, date: widget.startDate));
      }
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _fetchHotspots() async {
    setState(() => _loadingHotspots = true);
    final query = FirebaseFirestore.instance.collection('destination');
    final snapshot = await query.get();
    final all = snapshot.docs.map((doc) => Hotspot.fromMap(doc.data(), doc.id)).toList();
    final destinationLower = widget.destination.toLowerCase();
    final filtered = all.where((h) {
      final muni = (h.municipality).toString().toLowerCase();
      final district = (h.district).toString().toLowerCase();
      final location = (h.location).toString().toLowerCase();
      return muni.contains(destinationLower) ||
             district.contains(destinationLower) ||
             location.contains(destinationLower);
    }).toList();

    // Fallback: if no matches (e.g., generic or new destination label), show top popular items
    List<Hotspot> result = filtered;
    if (result.isEmpty) {
      // Try to sort by review_count or average_rating if available in source maps
      // Since we have Hotspot, fallback to createdAt desc if no metrics are present
      result = List<Hotspot>.from(all);
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      result = result.take(10).toList();
    }

    setState(() {
      _hotspots = result;
      _loadingHotspots = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(child: _buildContent()),
          _buildFinishButton(), // Moved outside of scrollable content
        ],
      ),
    );
  }

  /// Builds the progress indicator showing current step
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              height: _progressIndicatorHeight,
              margin: const EdgeInsets.symmetric(horizontal: _progressIndicatorMargin),
              decoration: BoxDecoration(
                color: index < 3 ? AppColors.primaryOrange : AppColors.textLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Builds the main content area - now properly scrollable
  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async => _fetchHotspots(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _selectPlacesLabel,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              _addPlacesDescription,
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            _buildAddCustomPlace(),
            const SizedBox(height: 16),
            if (_placesToVisit.isNotEmpty) _buildItinerary(),
            _buildPopularPlaces(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Builds the finish button as a separate widget
  Widget _buildFinishButton() {
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _finishPlanning,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text(_finishButtonLabel),
        ),
      ),
    );
  }

  /// Builds the custom place input section
  Widget _buildAddCustomPlace() {
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_location,
                color: AppColors.primaryOrange,
                size: _customPlaceIconSize,
              ),
              const SizedBox(width: 8),
              const Text(
                _addCustomPlaceLabel,
                style: TextStyle(
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    hintText: 'Enter place name',
                  ),
                  onSubmitted: (value) => _addCustomPlace(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomPlace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: _customPlaceButtonPadding,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_customPlaceBorderRadius),
                  ),
                ),
                child: const Text(_addButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the itinerary section
  Widget _buildItinerary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          _yourItineraryLabel,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: _itinerarySectionSpacing),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _placesToVisit.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final place = _placesToVisit[index];
              return ListTile(
                title: Text(place.place),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(place.date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primaryOrange),
                      onPressed: () => _editPlace(place),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePlace(index),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds the popular places section - now with constrained height
  Widget _buildPopularPlaces() {
    if (_loadingHotspots) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hotspots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: AppColors.textLight),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No suggestions found. Try adding your own places above or pull to refresh.',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Places in ${widget.destination}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: _popularPlacesSectionSpacing),
        SizedBox(
          height: 300, // Fixed height to prevent overflow
          child: ListView.builder(
            itemCount: _hotspots.length,
            itemBuilder: (context, index) {
              final hotspot = _hotspots[index];
              final alreadyAdded = _placesToVisit.any((p) => p.place == hotspot.name);
              return ListTile(
                title: Text(hotspot.name),
                subtitle: Text(hotspot.category),
                trailing: alreadyAdded
                    ? const Icon(Icons.check, color: AppColors.primaryOrange)
                    : IconButton(
                        icon: const Icon(Icons.add_location_alt, color: AppColors.primaryOrange),
                        onPressed: () => _addPlace(hotspot.name),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Adds a custom place from text input
  void _addCustomPlace() {
    final placeName = _placeController.text.trim();
    if (placeName.isEmpty) {
      _showError(_placeNameEmptyError, Colors.red);
      return;
    }
    if (_placesToVisit.any((p) => p.place.toLowerCase() == placeName.toLowerCase())) {
      _showError(_placeAlreadyExistsError, Colors.orange);
      return;
    }
    _placeController.clear();
    _addPlace(placeName);
  }

  /// Adds a place to the itinerary, showing a date picker dialog
  void _addPlace(String place) {
    _currentlyEditingPlace = place;
    _selectedPlaceDate = widget.startDate;
    _showDatePicker();
  }

  /// Edits an existing place in the itinerary
  void _editPlace(PlaceVisit placeVisit) {
    _currentlyEditingPlace = placeVisit.place;
    _selectedPlaceDate = placeVisit.date;
    _placesToVisit.removeWhere((p) => p.place == placeVisit.place);
    _showDatePicker();
  }

  /// Deletes a place from the itinerary by index
  void _deletePlace(int index) {
    setState(() {
      _placesToVisit.removeAt(index);
    });
    _autosaveDraft();
  }

   /// Shows the date picker dialog for selecting a date for a place
  void _showDatePicker() {
    final int duration = widget.endDate.difference(widget.startDate).inDays + 1;
    final List<DateTime> availableDates = List.generate(
      duration,
      (index) => widget.startDate.add(Duration(days: index)),
    );
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'Select Date for ${_currentlyEditingPlace ?? ''}',
            ),
            content: SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: availableDates.length,
                itemBuilder: (context, index) {
                  final date = availableDates[index];
                  final isSelected = _selectedPlaceDate == date;
                  return ListTile(
                    title: Text(DateFormat('MMM dd, yyyy').format(date)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primaryOrange)
                        : null,
                    onTap: () {
                      setDialogState(() {
                        _selectedPlaceDate = date;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(_cancelButtonLabel),
              ),
              ElevatedButton(
                onPressed: () {
                  _savePlaceWithDate();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text(_saveButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Saves the place with the selected date to the itinerary
  void _savePlaceWithDate() {
    if (_currentlyEditingPlace != null && _selectedPlaceDate != null) {
      setState(() {
        _placesToVisit.add(
          PlaceVisit(place: _currentlyEditingPlace!, date: _selectedPlaceDate!),
        );
        // Sort places by date
        _placesToVisit.sort((a, b) => a.date.compareTo(b.date));
      });
      _autosaveDraft();
    } else {
      _showError('Please select a place and date.', Colors.red);
    }
  }

  void _finishPlanning() async {
    if (_placesToVisit.isEmpty) {
      _showError(_tripAddPlaceError, AppColors.primaryOrange);
      return;
    }
    final userId = await _getUserId();
    if (!mounted) return;
    final trip = Trip(
      tripPlanId: widget.tripPlanId,
      title: widget.tripName,
      startDate: widget.startDate,
      endDate: widget.endDate,
      transportation: widget.transportation,
      spots: _placesToVisit.map((p) => p.place).toList(),
      userId: userId,
      status: 'Draft',
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripReviewScreen(trip: trip),
      ),
    );
    if (!mounted) return;
    if (result != null && result is Map<String, dynamic>) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _autosaveDraft() async {
    try {
      final userId = await _getUserId();
      final draft = Trip(
        tripPlanId: widget.tripPlanId,
        title: widget.tripName,
        startDate: widget.startDate,
        endDate: widget.endDate,
        transportation: widget.transportation,
        spots: _placesToVisit.map((p) => p.place).toList(),
        userId: userId,
        status: 'Draft',
      );
      await TripService.saveTrip(draft);
    } catch (_) {}
  }

  Future<String> _getUserId() async {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
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