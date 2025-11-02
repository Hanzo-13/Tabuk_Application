import 'package:capstone_app/services/trip_service.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_model.dart' as firestoretrip;
import '../../../utils/colors.dart';

class TripDetailsScreen extends StatefulWidget {
  final firestoretrip.Trip trip;

  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  // Track visited spots (persisted to Firestore)
  late Set<int> visitedSpots;

  @override
  void initState() {
    super.initState();
    // Initialize from trip's visited spots list
    visitedSpots = widget.trip.visitedSpots.toSet();
  }

  void _toggleVisited(int index) async {
    final wasChecked = visitedSpots.contains(index);
    final spotName = widget.trip.spots[index];
    
    setState(() {
      if (visitedSpots.contains(index)) {
        visitedSpots.remove(index);
      } else {
        visitedSpots.add(index);
      }
    });

    // Determine new status based on completion
    final isComplete = visitedSpots.length == widget.trip.spots.length;
    final wasComplete = widget.trip.status == 'Archived';
    
    String newStatus = widget.trip.status;
    
    // Auto-archive when 100% complete
    if (isComplete && !wasComplete) {
      newStatus = 'Archived';
    }
    // Auto-restore when unchecking from a completed trip
    else if (!isComplete && wasComplete) {
      newStatus = 'Planning';
    }

    // Save to Firestore
    try {
      final updatedTrip = firestoretrip.Trip(
        tripPlanId: widget.trip.tripPlanId,
        title: widget.trip.title,
        startDate: widget.trip.startDate,
        endDate: widget.trip.endDate,
        transportation: widget.trip.transportation,
        spots: widget.trip.spots,
        userId: widget.trip.userId,
        status: newStatus,
        visitedSpots: visitedSpots.toList(),
      );
      await TripService.saveTrip(updatedTrip);

      // If marking as visited (not unchecking), save to ArrivalService/DestinationHistory
      if (!wasChecked) {
        await _saveVisitToDestinationHistory(spotName);
      }

      if (mounted) {
        // Show celebration when completing
        if (isComplete && !wasComplete) {
          _showCompletionDialog();
        }
        // Show restoration message when unchecking from completed
        else if (!isComplete && wasComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.restore_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Trip restored to active plans',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryTeal,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (wasChecked) {
          visitedSpots.add(index);
        } else {
          visitedSpots.remove(index);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  /// Fetch destination details from Firestore and save visit to DestinationHistory
  Future<void> _saveVisitToDestinationHistory(String destinationName) async {
    try {
      // Search for destination in Firestore by name
      final destinationSnapshot = await FirebaseFirestore.instance
          .collection('destination')
          .where('business_name', isEqualTo: destinationName)
          .limit(1)
          .get();

      Map<String, dynamic>? destinationData;

      if (destinationSnapshot.docs.isNotEmpty) {
        // Found by business_name
        final doc = destinationSnapshot.docs.first;
        destinationData = Map<String, dynamic>.from(doc.data());
        destinationData['hotspot_id'] = doc.id;
      } else {
        // Try searching by name field
        final nameSnapshot = await FirebaseFirestore.instance
            .collection('destination')
            .where('name', isEqualTo: destinationName)
            .limit(1)
            .get();

        if (nameSnapshot.docs.isNotEmpty) {
          final doc = nameSnapshot.docs.first;
          destinationData = Map<String, dynamic>.from(doc.data());
          destinationData['hotspot_id'] = doc.id;
        } else {
          // Try case-insensitive partial match
          final allDestinations = await FirebaseFirestore.instance
              .collection('destination')
              .get();

          for (var doc in allDestinations.docs) {
            final data = doc.data();
            final businessName = data['business_name']?.toString().toLowerCase() ?? '';
            final name = data['name']?.toString().toLowerCase() ?? '';
            final searchName = destinationName.toLowerCase();

            if (businessName == searchName || 
                name == searchName ||
                businessName.contains(searchName) ||
                name.contains(searchName)) {
              destinationData = Map<String, dynamic>.from(data);
              destinationData['hotspot_id'] = doc.id;
              break;
            }
          }
        }
      }

      // Only save if we found valid destination data
      // Don't save with unknown/null values
      if (destinationData != null && 
          (destinationData['hotspot_id'] != null || destinationData['id'] != null)) {
        
        // Extract hotspot ID
        final hotspotId = destinationData['hotspot_id']?.toString() ?? 
                          destinationData['id']?.toString();
        
        // Get coordinates (required fields)
        final lat = (destinationData['latitude'] as num?)?.toDouble();
        final lng = (destinationData['longitude'] as num?)?.toDouble();
        
        // Only save if we have valid coordinates
        if (hotspotId != null && lat != null && lng != null) {
          await ArrivalService.saveArrival(
            hotspotId: hotspotId,
            latitude: lat,
            longitude: lng,
            businessName: destinationData['business_name'] ?? 
                          destinationData['name'] ?? 
                          destinationData['destinationName'] ??
                          destinationName,
            destinationName: destinationData['destinationName'] ??
                             destinationData['business_name'] ?? 
                             destinationData['name'] ?? 
                             destinationName,
            destinationCategory: destinationData['destinationCategory'] ??
                                 destinationData['category']?.toString(),
            destinationType: destinationData['destinationType'] ??
                             destinationData['type']?.toString(),
            destinationDistrict: destinationData['destinationDistrict'] ??
                                destinationData['district']?.toString(),
            destinationMunicipality: destinationData['destinationMunicipality'] ??
                                     destinationData['municipality']?.toString(),
            destinationImages: destinationData['destinationImages'] != null
                ? (destinationData['destinationImages'] as List).map((e) => e.toString()).toList()
                : destinationData['images'] != null
                    ? (destinationData['images'] as List).map((e) => e.toString()).toList()
                    : destinationData['imageUrl'] != null
                        ? [destinationData['imageUrl'].toString()]
                        : null,
            destinationDescription: destinationData['destinationDescription'] ??
                                   destinationData['description']?.toString(),
          );
        } else {
          print('Cannot save visit: Missing coordinates for destination: $destinationName');
        }
      } else {
        print('Cannot save visit: Destination not found in database: $destinationName');
        // Don't save with unknown data - it's better to skip than create bad records
      }
    } catch (e) {
      // Log error but don't block the UI update
      print('Error saving visit to destination history: $e');
      // Don't try to save with minimal data - better to skip than create bad records
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.homeNearbyColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 64,
                color: AppColors.homeNearbyColor,
              ),
            ),
            const SizedBox(height: 24),
            
            // Success message
            Text(
              '🎉 Trip Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Congratulations! You\'ve visited all ${widget.trip.spots.length} spots on your itinerary.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            
            // Status update info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryTeal.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your trip has been moved to "Trip Completed"',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to trips list
            },
            child: Text(
              'View Completed Trips',
              style: TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.homeNearbyColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showSpotDetails(String spotName, int spotIndex) {
    // TODO: Show your floating widget with spot details here
    // For now, showing a simple bottom sheet as placeholder
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  child: Text('${spotIndex + 1}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    spotName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Spot details would appear here...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Location info\n• Opening hours\n• Estimated time\n• Notes',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  double get _progressPercentage {
    if (widget.trip.spots.isEmpty) return 0;
    return visitedSpots.length / widget.trip.spots.length;
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;
    final spotsPerDay = widget.trip.spots.isEmpty ? 0 : (widget.trip.spots.length / duration).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.title),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        actions: [
          // Progress indicator in app bar
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${visitedSpots.length}/${widget.trip.spots.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Header Card with Dates and Transportation
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Dates',
                      '${DateFormat('MMM dd, yyyy').format(widget.trip.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.trip.endDate)} ($duration day${duration > 1 ? 's' : ''})',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      _getTransportationIcon(widget.trip.transportation),
                      'Transportation',
                      widget.trip.transportation,
                    ),
                    const Divider(height: 24),
                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trip Progress',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${(_progressPercentage * 100).toInt()}%',
                              style: TextStyle(
                                color: AppColors.primaryTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressPercentage,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Itinerary Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Itinerary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (widget.trip.spots.isNotEmpty && visitedSpots.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        visitedSpots.clear();
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (widget.trip.spots.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.explore_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No spots planned yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start adding tourist spots to your itinerary',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Timeline of spots grouped by day
              ...List.generate(duration, (dayIndex) {
                final dayNumber = dayIndex + 1;
                final startIndex = dayIndex * spotsPerDay;
                final endIndex = ((dayIndex + 1) * spotsPerDay).clamp(0, widget.trip.spots.length);
                
                if (startIndex >= widget.trip.spots.length) return const SizedBox.shrink();
                
                final daySpots = widget.trip.spots.sublist(startIndex, endIndex);
                final dayDate = widget.trip.startDate.add(Duration(days: dayIndex));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header
                    Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12, top: dayIndex > 0 ? 16 : 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Day $dayNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd').format(dayDate),
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Spots Timeline
                    ...List.generate(daySpots.length, (localIndex) {
                      final globalIndex = startIndex + localIndex;
                      final spot = daySpots[localIndex];
                      final isVisited = visitedSpots.contains(globalIndex);
                      final isFirst = localIndex == 0 && dayIndex == 0;
                      final isLast = globalIndex == widget.trip.spots.length - 1;

                      return _buildTimelineSpot(
                        spot: spot,
                        spotNumber: globalIndex + 1,
                        isVisited: isVisited,
                        isFirst: isFirst,
                        isLast: isLast,
                        onToggleVisited: () => _toggleVisited(globalIndex),
                        onTap: () => _showSpotDetails(spot, globalIndex),
                      );
                    }),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSpot({
    required String spot,
    required int spotNumber,
    required bool isVisited,
    required bool isFirst,
    required bool isLast,
    required VoidCallback onToggleVisited,
    required VoidCallback onTap,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column (checkbox + line)
          SizedBox(
            width: 50,
            child: Column(
              children: [
                // Top line
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: isVisited ? AppColors.primaryTeal : Colors.grey[300],
                    ),
                  ),
                
                // Checkbox
                GestureDetector(
                  onTap: onToggleVisited,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isVisited ? AppColors.primaryTeal : Colors.white,
                      border: Border.all(
                        color: isVisited ? AppColors.primaryTeal : Colors.grey[400]!,
                        width: 2.5,
                      ),
                    ),
                    child: isVisited
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                
                // Bottom line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          
          // Spot Card
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Card(
                margin: const EdgeInsets.only(left: 8, right: 0, bottom: 12),
                elevation: isVisited ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isVisited
                      ? BorderSide(color: AppColors.primaryTeal.withOpacity(0.3), width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Spot number badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isVisited
                              ? AppColors.primaryTeal.withOpacity(0.1)
                              : AppColors.primaryOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$spotNumber',
                            style: TextStyle(
                              color: isVisited ? AppColors.primaryTeal : AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Spot name
                      Expanded(
                        child: Text(
                          spot,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isVisited ? AppColors.textLight : AppColors.textDark,
                            decoration: isVisited ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      
                      // Arrow icon
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textLight, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getTransportationIcon(String transportation) {
    switch (transportation.toLowerCase()) {
      case 'motorcycle': return Icons.two_wheeler;
      case 'walk': return Icons.directions_walk;
      case 'car': return Icons.directions_car;
      default: return Icons.explore;
    }
  }
}