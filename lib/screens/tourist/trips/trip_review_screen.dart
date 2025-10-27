// ===========================================
// lib/screens/tourist_module/trips/trip_review_screen.dart
// ===========================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/models/trip_model.dart';
import 'package:capstone_app/services/trip_service.dart';
import 'trip_info_creation_screen.dart';
import 'transportation_selection_screen.dart';
import 'destination_selection_screen.dart';

class TripReviewScreen extends StatefulWidget {
  final Trip trip;
  const TripReviewScreen({super.key, required this.trip});
  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  bool _checkingOverlap = true;
  bool _hasOverlap = false;
  List<Trip> _overlappingTrips = [];

  // Unified button style
  final ButtonStyle mainButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: AppColors.primaryOrange,
    side: const BorderSide(color: AppColors.primaryOrange),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  @override
  void initState() {
    super.initState();
    _checkDateOverlap();
  }

  Future<void> _checkDateOverlap() async {
    try {
      final trips = await TripService.getTrips(widget.trip.userId);
      final overlaps = trips.where((t) {
        if (t.tripPlanId == widget.trip.tripPlanId) return false;
        if (t.status.toLowerCase() == 'archived') return false;
        final aStart = widget.trip.startDate;
        final aEnd = widget.trip.endDate;
        final bStart = t.startDate;
        final bEnd = t.endDate;
        final isOverlap = aStart.isBefore(bEnd) && aEnd.isAfter(bStart) ||
            aStart.isAtSameMomentAs(bStart) || aEnd.isAtSameMomentAs(bEnd);
        return isOverlap;
      }).toList();
      if (mounted) {
        setState(() {
          _overlappingTrips = overlaps;
          _hasOverlap = overlaps.isNotEmpty;
          _checkingOverlap = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingOverlap = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final duration = trip.endDate.difference(trip.startDate).inDays + 1;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Review Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasOverlap) _buildOverlapWarning(),
            if (_checkingOverlap && !_hasOverlap) _buildOverlapChecking(),
            _buildSectionTitle('Overview'),
            const SizedBox(height: 8),
            _buildOverviewCard(duration),
            const SizedBox(height: 16),
            _buildSectionTitle('Spots'),
            const SizedBox(height: 8),
            _buildSpotsList(),
            const SizedBox(height: 16),
            _buildEditRow(context),
            const Spacer(),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildOverviewCard(int duration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.trip.title, 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textLight),
              const SizedBox(width: 6),
              Flexible(
                flex: 3,
                child: Text(
                  '${DateFormat('MMM dd').format(widget.trip.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.trip.endDate)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule, size: 16, color: AppColors.textLight),
              const SizedBox(width: 6),
              Flexible(
                flex: 1,
                child: Text(
                  '$duration day${duration != 1 ? 's' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_rounded, size: 16, color: AppColors.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.trip.transportation,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpotsList() {
    final trip = widget.trip;
    if (trip.spots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No spots selected.'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final spot in widget.trip.spots)
            Chip(
              label: Text(spot, overflow: TextOverflow.ellipsis),
              backgroundColor: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildEditRow(BuildContext context) {
  final trip = widget.trip;
  return Column(
    children: [
      // First row with two equal-width buttons
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48, // Fixed height for consistency
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TripBasicInfoScreen(
                        destination: trip.title,
                        initialTripName: trip.title,
                        initialStartDate: trip.startDate,
                        initialEndDate: trip.endDate,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('Edit Dates/Name', 
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: const BorderSide(color: AppColors.primaryTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48, // Fixed height for consistency
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransportationSelectionScreen(
                        destination: trip.title,
                        tripName: trip.title,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        initialTransportation: trip.transportation,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text('Edit Transport', 
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.homeTrendingColor,
                  side: const BorderSide(color: AppColors.homeTrendingColor),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // Second row with full-width button matching the row above
      SizedBox(
        height: 48, // Same fixed height
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DestinationSelectionScreen(
                  tripPlanId: trip.tripPlanId,
                  destination: trip.title,
                  tripName: trip.title,
                  startDate: trip.startDate,
                  endDate: trip.endDate,
                  transportation: trip.transportation,
                  initialSpots: trip.spots,
                ),
              ),
            );
          },
          icon: const Icon(Icons.list_alt_rounded, size: 18),
          label: const Text('Edit Itinerary', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryOrange,
            side: const BorderSide(color: AppColors.primaryOrange),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildOverlapWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dates overlap with another trip',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.errorRed),
                ),
                if (_overlappingTrips.isNotEmpty)
                  Text(
                    _overlappingTrips.map((t) => t.title).join(', '),
                    style: const TextStyle(color: AppColors.textDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlapChecking() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking date conflicts...'),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 48, // Fixed height for alignment
          child: OutlinedButton(
            onPressed: () async {
              await TripService.saveTrip(widget.trip);
              if (context.mounted) {
                Navigator.of(context).pop(widget.trip.toMap());
              }
            },
            style: mainButtonStyle,
            child: const Text('Save as Draft', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: SizedBox(
          height: 48, // Fixed height for alignment
          child: OutlinedButton(
            onPressed: () async {
              final confirmed = Trip(
                tripPlanId: widget.trip.tripPlanId,
                title: widget.trip.title,
                startDate: widget.trip.startDate,
                endDate: widget.trip.endDate,
                transportation: widget.trip.transportation,
                spots: widget.trip.spots,
                userId: widget.trip.userId,
                status: 'Planning',
              );
              await TripService.saveTrip(confirmed);
              if (context.mounted) {
                final map = confirmed.toMap();
                map['fromDestinationSelection'] = true;
                Navigator.of(context).pop(map);
              }
            },
            style: mainButtonStyle,
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    ],
  );
}
}