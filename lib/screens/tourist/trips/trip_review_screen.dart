// ===========================================
// lib/screens/tourist_module/trips/trip_review_screen.dart
// ===========================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/models/trip_model.dart';
import 'package:capstone_app/services/trip_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TripReviewScreen extends StatefulWidget {
  final Trip trip;
  const TripReviewScreen({super.key, required this.trip});
  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  late Trip _currentTrip;
  bool _checkingOverlap = true;
  bool _hasOverlap = false;
  List<Trip> _overlappingTrips = [];
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _checkDateOverlap();
  }

  Future<void> _checkDateOverlap() async {
    try {
      final trips = await TripService.getTrips(_currentTrip.userId);
      final overlaps = trips.where((t) {
        if (t.tripPlanId == _currentTrip.tripPlanId) return false;
        if (t.status.toLowerCase() == 'archived') return false;
        final aStart = _currentTrip.startDate;
        final aEnd = _currentTrip.endDate;
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

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _currentTrip.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.primaryTeal),
            const SizedBox(width: 8),
            const Text('Edit Trip Name'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Trip Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.location_on, color: AppColors.primaryTeal),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _currentTrip = Trip(
                    tripPlanId: _currentTrip.tripPlanId,
                    title: controller.text.trim(),
                    startDate: _currentTrip.startDate,
                    endDate: _currentTrip.endDate,
                    transportation: _currentTrip.transportation,
                    spots: _currentTrip.spots,
                    userId: _currentTrip.userId,
                    status: _currentTrip.status,
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDatesDialog() {
    DateTime startDate = _currentTrip.startDate;
    DateTime endDate = _currentTrip.endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Text('Edit Dates'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.flight_takeoff, color: AppColors.primaryOrange),
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(startDate)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startDate = picked;
                      if (endDate.isBefore(startDate)) {
                        endDate = startDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.flight_land, color: AppColors.primaryOrange),
                title: const Text('End Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(endDate)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate,
                    firstDate: startDate,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentTrip = Trip(
                    tripPlanId: _currentTrip.tripPlanId,
                    title: _currentTrip.title,
                    startDate: startDate,
                    endDate: endDate,
                    transportation: _currentTrip.transportation,
                    spots: _currentTrip.spots,
                    userId: _currentTrip.userId,
                    status: _currentTrip.status,
                  );
                });
                _checkDateOverlap();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransportationDialog() {
    String selectedTransport = _currentTrip.transportation;
    final transportOptions = ['Car', 'Motorcycle', 'Walk', 'Plane', 'Bus', 'Boat', 'Train'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.directions_rounded, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              const Text('Select Transportation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: transportOptions.map((transport) {
              final isSelected = selectedTransport == transport;
              return RadioListTile<String>(
                value: transport,
                groupValue: selectedTransport,
                title: Row(
                  children: [
                    Icon(
                      _getTransportationIcon(transport),
                      color: isSelected ? AppColors.primaryTeal : AppColors.textLight,
                    ),
                    const SizedBox(width: 12),
                    Text(transport),
                  ],
                ),
                activeColor: AppColors.primaryTeal,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedTransport = value;
                    });
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentTrip = Trip(
                    tripPlanId: _currentTrip.tripPlanId,
                    title: _currentTrip.title,
                    startDate: _currentTrip.startDate,
                    endDate: _currentTrip.endDate,
                    transportation: selectedTransport,
                    spots: _currentTrip.spots,
                    userId: _currentTrip.userId,
                    status: _currentTrip.status,
                  );
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDestinationDialog() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> allDestinations = [];
    List<Map<String, dynamic>> filteredDestinations = [];
    bool isLoading = true;

    // Load destinations
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
      isLoading = false;
    } catch (e) {
      isLoading = false;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void filterDestinations(String query) {
            setDialogState(() {
              if (query.isEmpty) {
                filteredDestinations = [];
              } else {
                filteredDestinations = allDestinations
                    .where((dest) {
                      final name = dest['name'].toString().toLowerCase();
                      final location = dest['location'].toString().toLowerCase();
                      final searchLower = query.toLowerCase();
                      final isAlreadyAdded = _currentTrip.spots.contains(dest['name']);
                      return !isAlreadyAdded && 
                             (name.contains(searchLower) || location.contains(searchLower));
                    })
                    .toList();
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_location_alt, color: AppColors.primaryTeal),
                const SizedBox(width: 8),
                const Text('Add Destination'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Search destinations',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.search, color: AppColors.primaryTeal),
                      suffixIcon: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: filterDestinations,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (filteredDestinations.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredDestinations.length,
                        itemBuilder: (context, index) {
                          final dest = filteredDestinations[index];
                          return ListTile(
                            leading: Icon(Icons.place, color: AppColors.primaryTeal),
                            title: Text(dest['name']),
                            subtitle: Text(dest['location']),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dest['category'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                final spots = List<String>.from(_currentTrip.spots);
                                spots.add(dest['name']);
                                _currentTrip = Trip(
                                  tripPlanId: _currentTrip.tripPlanId,
                                  title: _currentTrip.title,
                                  startDate: _currentTrip.startDate,
                                  endDate: _currentTrip.endDate,
                                  transportation: _currentTrip.transportation,
                                  spots: spots,
                                  userId: _currentTrip.userId,
                                  status: _currentTrip.status,
                                );
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeDestination(int index) {
    setState(() {
      final spots = List<String>.from(_currentTrip.spots);
      spots.removeAt(index);
      _currentTrip = Trip(
        tripPlanId: _currentTrip.tripPlanId,
        title: _currentTrip.title,
        startDate: _currentTrip.startDate,
        endDate: _currentTrip.endDate,
        transportation: _currentTrip.transportation,
        spots: spots,
        userId: _currentTrip.userId,
        status: _currentTrip.status,
      );
    });
  }

  IconData _getTransportationIcon(String transportation) {
    switch (transportation.toLowerCase()) {
      case 'motorcycle': return Icons.two_wheeler;
      case 'walk': return Icons.directions_walk;
      case 'car': return Icons.directions_car;
      case 'plane': return Icons.flight;
      case 'bus': return Icons.directions_bus;
      case 'boat': return Icons.directions_boat;
      case 'train': return Icons.train;
      default: return Icons.explore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _currentTrip.endDate.difference(_currentTrip.startDate).inDays + 1;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Review Your Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overlap Warning
                if (_hasOverlap) _buildOverlapWarning(),
                if (_checkingOverlap && !_hasOverlap) _buildOverlapChecking(),

                // Trip Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      // Trip Name
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on, color: AppColors.primaryTeal),
                        ),
                        title: const Text('Trip Name', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        subtitle: Text(
                          _currentTrip.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _showEditNameDialog,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const Divider(height: 1),
                      
                      // Dates
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                        ),
                        title: const Text('Travel Dates', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        subtitle: Text(
                          '${DateFormat('MMM dd').format(_currentTrip.startDate)} - ${DateFormat('MMM dd, yyyy').format(_currentTrip.endDate)} ($duration day${duration != 1 ? 's' : ''})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _showEditDatesDialog,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const Divider(height: 1),
                      
                      // Transportation
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.homeTrendingColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getTransportationIcon(_currentTrip.transportation),
                            color: AppColors.homeTrendingColor,
                          ),
                        ),
                        title: const Text('Transportation', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        subtitle: Text(
                          _currentTrip.transportation,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _showEditTransportationDialog,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Itinerary Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map_rounded, color: AppColors.primaryTeal, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Itinerary',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_currentTrip.spots.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isReordering = !_isReordering;
                          });
                        },
                        icon: Icon(_isReordering ? Icons.check : Icons.swap_vert),
                        label: Text(_isReordering ? 'Done' : 'Reorder'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryTeal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Destinations List
                if (_currentTrip.spots.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.explore_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No destinations yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text('Add your first destination below', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: _currentTrip.spots.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final spots = List<String>.from(_currentTrip.spots);
                          final item = spots.removeAt(oldIndex);
                          spots.insert(newIndex, item);
                          _currentTrip = Trip(
                            tripPlanId: _currentTrip.tripPlanId,
                            title: _currentTrip.title,
                            startDate: _currentTrip.startDate,
                            endDate: _currentTrip.endDate,
                            transportation: _currentTrip.transportation,
                            spots: spots,
                            userId: _currentTrip.userId,
                            status: _currentTrip.status,
                          );
                        });
                      },
                      itemBuilder: (context, index) {
                        return Container(
                          key: ValueKey(_currentTrip.spots[index] + index.toString()),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isReordering)
                                  Icon(Icons.drag_indicator, color: AppColors.textLight)
                                else
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTeal.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppColors.primaryTeal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              _currentTrip.spots[index],
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: _isReordering
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.close, color: AppColors.errorRed, size: 20),
                                    onPressed: () => _removeDestination(index),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // Add Destination Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddDestinationDialog,
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Add Destination'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      side: BorderSide(color: AppColors.primaryTeal, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await TripService.saveTrip(_currentTrip);
                          if (context.mounted) {
                            Navigator.of(context).pop(_currentTrip.toMap());
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save as Draft', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirmed = Trip(
                            tripPlanId: _currentTrip.tripPlanId,
                            title: _currentTrip.title,
                            startDate: _currentTrip.startDate,
                            endDate: _currentTrip.endDate,
                            transportation: _currentTrip.transportation,
                            spots: _currentTrip.spots,
                            userId: _currentTrip.userId,
                            status: 'Planning',
                          );
                          await TripService.saveTrip(confirmed);
                          if (context.mounted) {
                            final map = confirmed.toMap();
                            map['fromDestinationSelection'] = true;
                            Navigator.of(context).pop(map);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text('Confirm Trip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
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
}