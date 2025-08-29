// ignore_for_file: unnecessary_const, unnecessary_cast, prefer_final_fields, unnecessary_string_interpolations

import 'package:capstone_app/models/event_model.dart';
import 'package:capstone_app/screens/admin/provincial_admin/events/event_creation.dart';
import 'package:capstone_app/services/event_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/event_detail_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class EventCalendarMuniScreen extends StatefulWidget {
  const EventCalendarMuniScreen({super.key});

  @override
  State<EventCalendarMuniScreen> createState() =>
      _EventCalendarProvScreenState();
}

class _EventCalendarProvScreenState extends State<EventCalendarMuniScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  Map<DateTime, List<Event>> _eventMarkers = {};
  String _userRole = 'Administrator';
  String? _adminType = 'Municipal Administrator';

  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // Filter controls
  Set<String> _selectedCreatorTypes = {'Provincial Administrator', 'Municipal Administrator', 'business owner'};
  String _sortBy = 'date'; // 'date', 'title', 'creator'
  bool _showOnlyMyEvents = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 4, vsync: this); // Added Analytics tab
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await EventService.getAllEvents();
    
    _eventMarkers.clear();
    for (var event in events) {
      DateTime current = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );
      DateTime end = DateTime(
        event.endDate.year,
        event.endDate.month,
        event.endDate.day,
      );

      while (!current.isAfter(end)) {
        _eventMarkers.putIfAbsent(current, () => []).add(event);
        current = current.add(const Duration(days: 1));
      }
    }

    setState(() {
      _events = events;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<Event> filtered = _events;

    // Filter by creator type
    filtered = filtered.where((event) => _selectedCreatorTypes.contains(event.role)).toList();

    // Filter by ownership (Provincial Admin can see all, but can filter to own)
    if (_showOnlyMyEvents) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      filtered = filtered.where((event) => event.createdBy == currentUserId).toList();
    }

    // Sort events
    switch (_sortBy) {
      case 'title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'creator':
        filtered.sort((a, b) => a.role.compareTo(b.role));
        break;
      case 'date':
      default:
        filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
    }

    setState(() {
      _filteredEvents = filtered;
    });
  }

  List<Event> get _newEvents =>
      _filteredEvents
          .where((e) => e.status == 'upcoming' || e.status == 'ongoing')
          .toList();

  List<Event> get _pastEvents =>
      _filteredEvents.where((e) => e.status == 'ended').toList();

  List<Event> get _myEvents {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _filteredEvents.where((e) => e.createdBy == currentUserId).toList();
  }

  Map<String, int> get _eventStatistics {
    final stats = <String, int>{};
    for (var event in _events) {
      stats[event.role] = (stats[event.role] ?? 0) + 1;
    }
    return stats;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter & Sort Options',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Creator Type Filter
                  const Text('Filter by Creator Type:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('Provincial Administrator', Colors.blue.shade700, setModalState),
                      _buildFilterChip('Municipal Administrator', Colors.green, setModalState),
                      _buildFilterChip('business owner', Colors.yellow[700]!, setModalState),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Show only my events toggle
                  SwitchListTile(
                    title: const Text('Show only my events'),
                    value: _showOnlyMyEvents,
                    activeColor: AppColors.primaryTeal,
                    onChanged: (value) {
                      setModalState(() {
                        _showOnlyMyEvents = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sort options
                  const Text('Sort by:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(value: 'title', child: Text('Title')),
                      DropdownMenuItem(value: 'creator', child: Text('Creator Type')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apply filters button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _applyFilters();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, Color color, StateSetter setModalState) {
    final isSelected = _selectedCreatorTypes.contains(label);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: color.withOpacity(0.3),
      onSelected: (selected) {
        setModalState(() {
          if (selected) {
            _selectedCreatorTypes.add(label);
          } else {
            _selectedCreatorTypes.remove(label);
          }
        });
      },
    );
  }

void _showEventsBottomSheet() {
  if (_selectedDay == null) return;

  final selected = _selectedDay!;
  final eventsOnSelectedDay = _events.where((event) {
    return selected.isAfter(event.startDate.subtract(const Duration(days: 1))) &&
          selected.isBefore(event.endDate.add(const Duration(days: 1)));
  }).toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 2, 115, 160),
              Color.fromARGB(255, 13, 75, 72),
              Color.fromARGB(255, 41, 180, 173),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 20,
              offset: Offset(0, -5),
              spreadRadius: 5,
            ),
          ],
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.95,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                
                // Header Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      // Title and Close Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Events Schedule',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(selected),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Event Count Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryTeal.withOpacity(0.8),
                                      AppColors.primaryTeal,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryTeal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${eventsOnSelectedDay.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Close Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Day of Week Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          DateFormat('EEEE').format(selected),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content Section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: eventsOnSelectedDay.isEmpty
                        ? _buildEmptyState(context)
                        : _buildEventsList(context, eventsOnSelectedDay, scrollController),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Widget _buildEmptyState(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Empty State Illustration
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryTeal.withOpacity(0.1),
                AppColors.primaryTeal.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(60),
          ),
          child: Icon(
            Icons.event_busy_outlined,
            size: 60,
            color: AppColors.primaryTeal.withOpacity(0.6),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Empty State Text
        const Text(
          'No Events Scheduled',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'This day is free from any scheduled events.\nWould you like to create one?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Create Event Button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryTeal, AppColors.primaryTeal.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventCreationScreen()),
              );
              _loadEvents();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              'Create New Event',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Secondary Action
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Back to Calendar',
            style: TextStyle(
              color: AppColors.primaryTeal,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEventsList(BuildContext context, List<Event> events, ScrollController scrollController) {
  return Column(
    children: [
      // Events List Header
      Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Daily Schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${events.length} event${events.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.primaryTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Events List
      Expanded(
        child: ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: events.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final event = events[index];
            final isMyEvent = event.createdBy == (FirebaseAuth.instance.currentUser?.uid ?? '');
            
            return _buildEnhancedEventCard(event, isMyEvent, context);
          },
        ),
      ),
      
      const SizedBox(height: 20),
    ],
  );
}

Widget _buildEnhancedEventCard(Event event, bool isMyEvent, BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isMyEvent ? AppColors.primaryTeal.withOpacity(0.3) : Colors.grey.shade200,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isMyEvent 
              ? AppColors.primaryTeal.withOpacity(0.1)
              : Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _showEventDetails(event);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event Thumbnail/Icon
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _getRoleColor(event.role).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: event.thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              event.thumbnailUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(event.role),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getRoleColor(event.role),
                                  _getRoleColor(event.role).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                  
                  // Ownership Indicator
                  if (isMyEvent)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.green, Colors.greenAccent],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Title
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${event.location}, ${event.municipality}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Badges Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Creator Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getRoleColor(event.role).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getRoleColor(event.role).withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _getRoleColor(event.role),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getRoleShortName(event.role),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getRoleColor(event.role),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(event.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(event.status).withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            event.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(event.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Action Button
              _buildActionButton(event, isMyEvent, context),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildActionButton(Event event, bool isMyEvent, BuildContext context) {
  if (isMyEvent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: () {
          Navigator.pop(context);
          _confirmDeleteEvent(event);
        },
        icon: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 20,
        ),
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        tooltip: 'Delete Event',
      ),
    );
  } else {
    return PopupMenuButton<String>(
      onSelected: (value) {
        Navigator.pop(context);
        if (value == 'override_delete') {
          _confirmAdminOverrideDelete(event);
        } else {
          _showEventDetails(event);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 12),
              Text('View Details'),
            ],
          ),
        ),
        if (_adminType == 'Provincial Administrator')
          const PopupMenuItem(
            value: 'override_delete',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Admin Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.more_vert,
          color: Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}

String _getRoleShortName(String role) {
  switch (role) {
    case 'Provincial Administrator':
      return 'Provincial';
    case 'Municipal Administrator':
      return 'Municipal';
    case 'business owner':
      return 'Business';
    default:
      return role;
  }
}

  void _showEventDetails(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailModal(
        event: event,
        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        userRole: _userRole,
        adminType: _adminType,
        status: event.status,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Provincial Administrator':
        return Colors.blue.shade700;
      case 'Municipal Administrator':
        return Colors.green;
      case 'business owner':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Municipal Event Calendar",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primaryTeal,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            tooltip: 'Filter & Sort',
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Event',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventCreationScreen()),
              );
              _loadEvents();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Calendar with better visual indicators
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TableCalendar<Event>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selected, focusedDay) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focusedDay;
                    });
                    _showEventsBottomSheet();
                  },
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    return _eventMarkers[key] ?? [];
                  },
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  onRangeSelected: _onRangeSelected,
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 3,
                    markerSize: 7,
                    cellMargin: EdgeInsets.symmetric(vertical: 12),
                    markerMargin: EdgeInsets.symmetric(horizontal: 1.5),
                    todayDecoration: BoxDecoration(
                      color: AppColors.homeTrendingColor,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(
                      fontSize: AppConstants.calendarDayFontSize,
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                    outsideTextStyle: TextStyle(
                      fontSize: AppConstants.calendarDayFontSize,
                      color: AppColors.textLight,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey, size: 28),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey, size: 28),
                  ),
                  rowHeight: 45,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final roles = events.map((e) => e.role).toSet().toList();
                      List<Widget> markers = [];

                      if (roles.contains('Provincial Administrator')) {
                        markers.add(_buildCalendarMarker(Colors.blue.shade700, 'P'));
                      }
                      if (roles.contains('Municipal Administrator')) {
                        markers.add(_buildCalendarMarker(Colors.green, 'M'));
                      }
                      if (roles.contains('business owner')) {
                        markers.add(_buildCalendarMarker(Colors.yellow[700]!, 'B'));
                      }

                      return markers.isEmpty
                          ? const SizedBox()
                          : Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: markers,
                              ),
                            );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 8),

              _isLoading
                  ? const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                  : Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd.withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Enhanced Legend
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 8),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Event Creator Types',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildEnhancedLegendItem(
                                          Colors.blue.shade700,
                                          'Provincial Admin',
                                          'P',
                                          _eventStatistics['Provincial Administrator'] ?? 0,
                                        ),
                                        _buildEnhancedLegendItem(
                                          Colors.green,
                                          'Municipal Admin',
                                          'M',
                                          _eventStatistics['Municipal Administrator'] ?? 0,
                                        ),
                                        _buildEnhancedLegendItem(
                                          Colors.yellow[700]!,
                                          'Business Owners',
                                          'B',
                                          _eventStatistics['business owner'] ?? 0,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Enhanced Tab Bar
                              TabBar(
                                controller: _tabController,
                                indicatorColor: AppColors.primaryTeal,
                                indicatorWeight: 4,
                                labelColor: AppColors.black,
                                unselectedLabelColor: AppColors.grey,
                                isScrollable: true,
                                tabs: [
                                  _buildTabWithBadge(
                                    Icons.person_outline,
                                    'My Events',
                                    _myEvents.length,
                                    Colors.green,
                                  ),
                                  _buildTabWithBadge(
                                    Icons.event_available,
                                    'Active Events',
                                    _newEvents.length,
                                    AppColors.primaryOrange,
                                  ),
                                  _buildTabWithBadge(
                                    Icons.archive_rounded,
                                    'Past Events',
                                    _pastEvents.length,
                                    AppColors.textLight,
                                  ),
                                  const Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.analytics_outlined, size: 16),
                                        SizedBox(width: 4),
                                        Text('Analytics'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMyEventsList(),
                              _buildActiveEventsList(),
                              _buildPastEventsList(),
                              _buildAnalyticsView(),
                            ],
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

  Widget _buildCalendarMarker(Color color, String letter) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedLegendItem(Color color, String label, String marker, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                marker,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithBadge(IconData icon, String label, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDeleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event"),
        content: Text("Are you sure you want to delete '${event.title}'?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
            onPressed: () async {
              Navigator.of(context).pop();
              await EventService.deleteEvent(event.eventId);
              _loadEvents();
            },
          ),
        ],
      ),
    );
  }

  void _confirmAdminOverrideDelete(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.red),
            const SizedBox(width: 8),
            const Text("Admin Override Delete"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("You are about to delete an event created by another user:"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Event: ${event.title}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Creator: ${event.role}"),
                  Text("Location: ${event.location}, ${event.municipality}"),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This action cannot be undone. As Municipal Administrator, you have the authority to modify events within your municipality.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Admin Delete"),
            onPressed: () async {
              Navigator.of(context).pop();
              await EventService.deleteEvent(event.eventId);
              _loadEvents();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Event '${event.title}' deleted by admin override"),
                  backgroundColor: Colors.red,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEventsList() {
    if (_newEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "No active events found",
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create new events or adjust your filters",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _newEvents.length,
      itemBuilder: (context, index) {
        final event = _newEvents[index];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isMyEvent = event.createdBy == currentUserId;
        final canAdminDelete = _adminType == 'Provincial Administrator' && !isMyEvent;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Stack(
              children: [
                event.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          event.thumbnailUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getRoleColor(event.role),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event, color: Colors.white, size: 30),
                      ),
                if (isMyEvent)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${event.location}, ${event.municipality}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(event.role).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.role,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getRoleColor(event.role),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(event.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                if (isMyEvent)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Event', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                if (canAdminDelete)
                  const PopupMenuItem(
                    value: 'admin_delete',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Admin Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _showEventDetails(event);
                    break;
                  case 'delete':
                    _confirmDeleteEvent(event);
                    break;
                  case 'admin_delete':
                    _confirmAdminOverrideDelete(event);
                    break;
                }
              },
            ),
            onTap: () => _showEventDetails(event),
          ),
        );
      },
    );
  }

  Widget _buildPastEventsList() {
    if (_pastEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 45, color: Colors.grey.shade400),
            const SizedBox(height: 5),
            const Text(
              "No past events found",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pastEvents.length,
      itemBuilder: (context, index) {
        final event = _pastEvents[index];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isMyEvent = event.createdBy == currentUserId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Stack(
              children: [
                event.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.grey.withOpacity(0.5),
                            BlendMode.color,
                          ),
                          child: Image.network(
                            event.thumbnailUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event, color: Colors.white, size: 30),
                      ),
                if (isMyEvent)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              event.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '${event.location}, ${event.municipality}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.role,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "ENDED",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Event', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'view') {
                  _showEventDetails(event);
                } else if (value == 'delete') {
                  _confirmDeleteEvent(event);
                }
              },
            ),
            onTap: () => _showEventDetails(event),
          ),
        );
      },
    );
  }

  Widget _buildMyEventsList() {
    if (_myEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "You haven't created any events yet",
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventCreationScreen()),
                );
                _loadEvents();
              },
              icon: const Icon(Icons.add),
              label: const Text("Create Your First Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myEvents.length,
      itemBuilder: (context, index) {
        final event = _myEvents[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.shade200, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Stack(
              children: [
                event.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          event.thumbnailUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event, color: Colors.white, size: 30),
                      ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${event.location}, ${event.municipality}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(event.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(event.status),
                    ),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeleteEvent(event),
            ),
            onTap: () => _showEventDetails(event),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsView() {
    final totalEvents = _events.length;
    final activeEvents = _events.where((e) => e.status != 'ended').length;
    final endedEvents = _events.where((e) => e.status == 'ended').length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Events',
                  totalEvents.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active Events',
                  activeEvents.toString(),
                  Icons.event_available,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ended Events',
                  endedEvents.toString(),
                  Icons.event_busy,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Creator Statistics
          const Text(
            'Events by Creator Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          ..._eventStatistics.entries.map((entry) {
            final percentage = totalEvents > 0 
                ? (entry.value / totalEvents * 100).toStringAsFixed(1)
                : '0.0';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getRoleColor(entry.key),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _getRoleMarker(entry.key),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: totalEvents > 0 ? entry.value / totalEvents : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(_getRoleColor(entry.key)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          
          const SizedBox(height: 24),
          
          // Municipal Admin Powers Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Municipal Administrator Powers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPowerItem('✓ View all events from all creator types'),
                _buildPowerItem('✓ Delete event within municipality admin override'),
                _buildPowerItem('✓ Filter and sort all events system-wide'),
                _buildPowerItem('✓ Access comprehensive analytics'),
                _buildPowerItem('✓ Manage Municipal-level event calendar'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPowerItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  String _getRoleMarker(String role) {
    switch (role) {
      case 'Provincial Administrator':
        return 'P';
      case 'Municipal Administrator':
        return 'M';
      case 'business owner':
        return 'B';
      default:
        return '?';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.green;
      case 'ongoing':
        return Colors.orange;
      case 'ended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}