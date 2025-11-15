// ===========================================
// lib/screens/tourist/trips/trips_screen.dart
// ===========================================
// Enhanced interactive screen for displaying and managing user trips.

import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../models/trip_model.dart' as firestoretrip;
import '../../../services/auth_service.dart';
import '../../../services/trip_service.dart';
import 'constants/trip_constants.dart';
import 'utils/trip_helpers.dart';
import 'widgets/trip_card.dart';
import 'widgets/progress_statistics_view.dart';
import 'trip_info_creation_screen.dart';

/// Enhanced interactive screen for displaying and managing user trips.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  late Stream<QuerySnapshot> _tripStream;
  String? _userId;

  /// Gets the current user ID from AuthService.
  String getUserId() {
    return AuthService.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: TripConstants.tabCount, vsync: this);
    _tabController.addListener(_handleTabChange);
    _userId = getUserId();
    _tripStream =
        FirebaseFirestore.instance
            .collection(TripConstants.collectionName)
            .where('user_id', isEqualTo: _userId)
            .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  /// Adds a new trip to Firestore and shows a success message
  Future<void> _addNewTrip(firestoretrip.Trip trip) async {
    try {
      final now = DateTime.now();
      final newTrip = firestoretrip.Trip(
        tripPlanId:
            trip.tripPlanId.isNotEmpty ? trip.tripPlanId : const Uuid().v4(),
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: _userId ?? '',
        status: trip.status,
        createdAt: now,
        updatedAt: now,
        autoSaved: false,
      );
      await TripService.saveTrip(newTrip);
      _showSnackBar(
        TripConstants.tripAddedMsg.replaceFirst('{destination}', trip.title),
        AppColors.homeNearbyColor,
      );
    } catch (e) {
      _showSnackBar('Failed to add trip: $e', AppColors.errorRed);
    }
  }

  /// Archives a trip and shows a message
  /// Archives a trip and shows a message
  /// Replace the existing _archiveTrip method
  Future<void> _archiveTrip(firestoretrip.Trip trip) async {
    try {
      final now = DateTime.now();
      final archivedTrip = firestoretrip.Trip(
        tripPlanId: trip.tripPlanId,
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: trip.userId,
        status: TripConstants.archivedStatus,
        visitedSpots: trip.visitedSpots, // Preserve visited spots
        createdAt: trip.createdAt,
        updatedAt: now,
        completedAt: now,
        autoSaved: trip.autoSaved,
      );
      await TripService.saveTrip(archivedTrip);
      _showSnackBar(
        TripConstants.tripArchivedMsg.replaceFirst('{destination}', trip.title),
        AppColors.primaryTeal,
      );
    } catch (e) {
      _showSnackBar('Failed to archive trip: $e', AppColors.errorRed);
    }
  }

  /// Restores an archived trip and shows a message
  /// Replace the existing _restoreTrip method
  Future<void> _restoreTrip(firestoretrip.Trip trip) async {
    try {
      final restoredTrip = firestoretrip.Trip(
        tripPlanId: trip.tripPlanId,
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: trip.userId,
        status: TripConstants.planningStatus,
        visitedSpots: trip.visitedSpots, // Preserve visited spots
      );
      await TripService.saveTrip(restoredTrip);
      _showSnackBar(
        TripConstants.tripRestoredMsg.replaceFirst('{destination}', trip.title),
        AppColors.homeNearbyColor,
      );
    } catch (e) {
      _showSnackBar('Failed to restore trip: $e', AppColors.errorRed);
    }
  }

  /// Deletes a trip with confirmation dialog
  Future<void> _deleteTrip(String tripPlanId, String tripTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: AppColors.errorRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Trip',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "$tripTitle"? This action cannot be undone.',
              style: TextStyle(color: AppColors.textLight),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textLight,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await TripService.deleteTrip(tripPlanId);
        _showSnackBar(TripConstants.tripDeletedMsg, AppColors.errorRed);
      } catch (e) {
        _showSnackBar('Failed to delete trip: $e', AppColors.errorRed);
      }
    }
  }

  /// Shows a SnackBar with the given message and color
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.homeNearbyColor
                  ? Icons.check_circle_rounded
                  : color == AppColors.errorRed
                  ? Icons.error_rounded
                  : Icons.info_rounded,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(TripConstants.snackBarMargin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TripConstants.snackBarBorderRadius),
        ),
        duration: const Duration(seconds: TripConstants.snackBarDurationSec),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _tripStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryTeal,
                      ),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading your adventures...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: AppColors.textLight),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final trips =
            snapshot.data?.docs
                .map((doc) {
                  final data = doc.data();
                  if (data is Map<String, dynamic>) {
                    return firestoretrip.Trip.fromMap(data);
                  }
                  return null;
                })
                .whereType<firestoretrip.Trip>()
                .toList() ??
            [];

        final myTrips =
            trips.where((t) => t.status != TripConstants.archivedStatus).toList();
        final archivedTrips =
            trips.where((t) => t.status == TripConstants.archivedStatus).toList();

        return DefaultTabController(
          length: TripConstants.tabCount,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.luggage_rounded,
                      size: 24,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    TripConstants.myTripsLabel,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              flexibleSpace: Container(
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
              ),
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
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
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.white,
                    indicatorWeight: 3,
                    labelColor: AppColors.white,
                    unselectedLabelColor: AppColors.white.withOpacity(0.7),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.explore_rounded, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                TripConstants.activeTabLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            if (myTrips.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${myTrips.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.archive_rounded, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                TripConstants.archivedTabLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            if (archivedTrips.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${archivedTrips.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.analytics_rounded, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                TripConstants.progressTabLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList(myTrips, false),
                  _buildTripList(archivedTrips, true),
                  ProgressStatisticsView(allTrips: trips),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const TripBasicInfoScreen(
                          destination: "New Destination",
                        ),
                  ),
                );
                if (result != null && result is Map<String, dynamic>) {
                  final trip = firestoretrip.Trip.fromMap(result);
                  if (result['fromDestinationSelection'] == true) {
                    await TripService.saveTrip(trip);
                    _showSnackBar(
                      TripConstants.tripAddedMsg.replaceFirst('{destination}', trip.title),
                      AppColors.homeNearbyColor,
                    );
                  } else {
                    _addNewTrip(trip);
                  }
                  if (_tabController.index != 0) {
                    _tabController.animateTo(0);
                  }
                }
              },
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'New Plan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              elevation: 4,
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTrip(firestoretrip.Trip trip) async {
    final TextEditingController nameController = TextEditingController(
      text: trip.title,
    );
    final TextEditingController spotSearchController = TextEditingController();
    DateTime startDate = trip.startDate;
    DateTime endDate = trip.endDate;
    String transportation = trip.transportation;
    List<String> spots = List<String>.from(trip.spots);
    final formKey = GlobalKey<FormState>();
    
    // For search functionality
    List<Map<String, dynamic>> allDestinations = [];
    List<Map<String, dynamic>> filteredDestinations = [];
    bool isSearching = false;
    bool isLoadingDestinations = false;

    // Load destinations from Firestore
    Future<void> loadDestinations() async {
      isLoadingDestinations = true;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('tourist_destinations')
            .get();
        
        allDestinations = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'location': data['location'] ?? '',
            'category': data['category'] ?? '',
          };
        }).toList();
      } catch (e) {
        print('Error loading destinations: $e');
      }
      isLoadingDestinations = false;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter destinations based on search
            void filterDestinations(String query) {
              if (query.isEmpty) {
                filteredDestinations = [];
                isSearching = false;
              } else {
                isSearching = true;
                filteredDestinations = allDestinations
                    .where((dest) {
                      final name = dest['name'].toString().toLowerCase();
                      final location = dest['location'].toString().toLowerCase();
                      final searchLower = query.toLowerCase();
                      // Exclude already added spots
                      final isAlreadyAdded = spots.contains(dest['name']);
                      return !isAlreadyAdded &&
                            (name.contains(searchLower) || location.contains(searchLower));
                    })
                    .toList();
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryTeal,
                            AppColors.primaryTeal.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: AppColors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Edit Trip Details',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Destination Section
                              _buildSectionLabel('Destination', Icons.location_on_rounded),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  hintText: 'Where are you going?',
                                  hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.5)),
                                  prefixIcon: Icon(
                                    Icons.place_rounded,
                                    color: AppColors.primaryTeal,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.primaryTeal,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.errorRed,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Please enter a destination'
                                        : null,
                              ),

                              const SizedBox(height: 24),

                              // Dates Section
                              _buildSectionLabel('Travel Dates', Icons.calendar_today_rounded),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateField(
                                      context: context,
                                      label: 'Start Date',
                                      date: startDate,
                                      icon: Icons.flight_takeoff_rounded,
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: startDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: ColorScheme.light(
                                                  primary: AppColors.primaryTeal,
                                                  onPrimary: AppColors.white,
                                                  onSurface: AppColors.textDark,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            startDate = picked;
                                            if (endDate.isBefore(startDate)) {
                                              endDate = startDate.add(
                                                const Duration(days: 1),
                                              );
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDateField(
                                      context: context,
                                      label: 'End Date',
                                      date: endDate,
                                      icon: Icons.flight_land_rounded,
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: endDate,
                                          firstDate: startDate,
                                          lastDate: DateTime(2100),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: ColorScheme.light(
                                                  primary: AppColors.primaryTeal,
                                                  onPrimary: AppColors.white,
                                                  onSurface: AppColors.textDark,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            endDate = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Trip Duration Indicator
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: AppColors.primaryTeal,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Duration: ${getTripDuration(startDate, endDate)} day${getTripDuration(startDate, endDate) != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: AppColors.primaryTeal,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Transportation Section
                              _buildSectionLabel('Transportation', Icons.directions_rounded),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: transportation.isNotEmpty ? transportation : null,
                                decoration: InputDecoration(
                                  hintText: 'Select transportation',
                                  hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: AppColors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppColors.primaryTeal,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items: TripConstants.transportationOptions
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Row(
                                          children: [
                                            Icon(
                                              getTransportationIcon(t),
                                              color: AppColors.primaryTeal,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              t,
                                              style: TextStyle(
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      transportation = val;
                                    });
                                  }
                                },
                              ),

                              const SizedBox(height: 24),

                              // Places Section with Search
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionLabel('Places to Visit', Icons.place_rounded),
                                  if (spots.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.homeForYouColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${spots.length} place${spots.length != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: AppColors.homeForYouColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Search Input with Autocomplete
                              Column(
                                children: [
                                  TextFormField(
                                    controller: spotSearchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search destinations from database...',
                                      hintStyle: TextStyle(
                                        color: AppColors.textLight.withOpacity(0.5),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: AppColors.primaryTeal,
                                        size: 20,
                                      ),
                                      suffixIcon: isLoadingDestinations
                                          ? Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    AppColors.primaryTeal,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : spotSearchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear_rounded),
                                                  onPressed: () {
                                                    setState(() {
                                                      spotSearchController.clear();
                                                      filteredDestinations = [];
                                                      isSearching = false;
                                                    });
                                                  },
                                                )
                                              : null,
                                      filled: true,
                                      fillColor: AppColors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppColors.primaryTeal,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    onTap: () async {
                                      if (allDestinations.isEmpty && !isLoadingDestinations) {
                                        setState(() {
                                          isLoadingDestinations = true;
                                        });
                                        await loadDestinations();
                                        setState(() {
                                          isLoadingDestinations = false;
                                        });
                                      }
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        filterDestinations(value);
                                      });
                                    },
                                  ),
                                  
                                  // Search Results Dropdown
                                  if (isSearching && filteredDestinations.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.all(4),
                                        itemCount: filteredDestinations.length,
                                        itemBuilder: (context, index) {
                                          final dest = filteredDestinations[index];
                                          return ListTile(
                                            dense: true,
                                            leading: Icon(
                                              Icons.place_rounded,
                                              color: AppColors.primaryTeal,
                                              size: 20,
                                            ),
                                            title: Text(
                                              dest['name'],
                                              style: TextStyle(
                                                color: AppColors.textDark,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Text(
                                              dest['location'],
                                              style: TextStyle(
                                                color: AppColors.textLight,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryTeal.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                dest['category'],
                                                style: TextStyle(
                                                  color: AppColors.primaryTeal,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              setState(() {
                                                spots.add(dest['name']);
                                                spotSearchController.clear();
                                                filteredDestinations = [];
                                                isSearching = false;
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  
                                  // No results message
                                  if (isSearching && 
                                      filteredDestinations.isEmpty && 
                                      spotSearchController.text.isNotEmpty &&
                                      !isLoadingDestinations)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search_off_rounded,
                                            color: Colors.orange.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'No destinations found matching "${spotSearchController.text}"',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Places List (Reorderable)
                              if (spots.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_off_rounded,
                                        size: 40,
                                        color: AppColors.textLight.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No places added yet',
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Search and select destinations above',
                                        style: TextStyle(
                                          color: AppColors.textLight.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ReorderableListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: spots.length,
                                    onReorder: (oldIndex, newIndex) {
                                      setState(() {
                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }
                                        final item = spots.removeAt(oldIndex);
                                        spots.insert(newIndex, item);
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Container(
                                        key: ValueKey(spots[index] + index.toString()),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.drag_indicator_rounded,
                                                color: AppColors.textLight,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryTeal.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    color: AppColors.primaryTeal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          title: Text(
                                            spots[index],
                                            style: TextStyle(
                                              color: AppColors.textDark,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: AppColors.errorRed,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                spots.removeAt(index);
                                              });
                                            },
                                            tooltip: 'Remove',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              
                              if (spots.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Drag and drop to reorder places',
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  try {
                                    // Preserve visited spots when editing
                                    final validVisitedSpots = trip.visitedSpots
                                        .where((index) => index < spots.length)
                                        .toList();

                                    final updatedTrip = firestoretrip.Trip(
                                      tripPlanId: trip.tripPlanId,
                                      title: nameController.text.trim(),
                                      startDate: startDate,
                                      endDate: endDate,
                                      transportation: transportation,
                                      spots: spots,
                                      userId: _userId ?? '',
                                      status: trip.status,
                                      visitedSpots: validVisitedSpots,
                                    );
                                    await TripService.saveTrip(updatedTrip);

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    if (mounted) {
                                      _showSnackBar(
                                        'Trip updated successfully!',
                                        AppColors.homeNearbyColor,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update trip'),
                                          backgroundColor: AppColors.errorRed,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method for section labels
  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primaryTeal,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // Helper method for date fields
  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy').format(date),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Update the _buildTripList method to use the new card builder:
  Widget _buildTripList(List<firestoretrip.Trip> trips, bool isArchived) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isArchived ? Icons.archive_outlined : Icons.explore_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArchived ? 'No completed trips' : 'No active trips',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArchived
                  ? 'Your completed trips will appear here.'
                  : 'Start planning your next adventure!',
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.8),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          isArchived: isArchived,
          onEdit: () => _editTrip(trip),
          onArchive: () => _archiveTrip(trip),
          onRestore: () => _restoreTrip(trip),
          onDelete: () => _deleteTrip(trip.tripPlanId, trip.title),
        );
      },
    );
  }
}
