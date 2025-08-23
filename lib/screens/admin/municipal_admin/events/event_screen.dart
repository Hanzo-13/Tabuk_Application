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
      _EventCalendarMuniScreenState();
}

class _EventCalendarMuniScreenState extends State<EventCalendarMuniScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  bool _isLoading = true;
  Map<DateTime, List<Event>> _eventMarkers = {};
  String _userRole = 'Administrator';
  String _adminType = 'Municipal Administrator';


  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 3, vsync: this);
    // FIX 1: Call a single method to control the loading order
    _initializeData();
  }

  // FIX 2: New method to handle the async loading sequence correctly
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    // THEN, load all events
    await _loadEvents();
    
    // Finally, set loading to false to build the UI with all the data
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final events = await EventService.getAllEvents();
    _eventMarkers.clear(); // Clear old markers

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

    // Set the events list. No need for another setState if _initializeData handles it.
    _events = events;
  }

  List<Event> get _newEvents =>
      _events
          .where((e) => e.status == 'upcoming' || e.status == 'ongoing')
          .toList();

  List<Event> get _pastEvents =>
      _events.where((e) => e.status == 'ended').toList();

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

  void _showEventsBottomSheet() {
    if (_selectedDay == null) return;

    final selected = _selectedDay!;
    final eventsOnSelectedDay =
        _events.where((event) {
          final startDate = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
          final endDate = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
          final selectedDate = DateTime(selected.year, selected.month, selected.day);

          return (selectedDate.isAtSameMomentAs(startDate) || selectedDate.isAfter(startDate)) &&
                (selectedDate.isAtSameMomentAs(endDate) || selectedDate.isBefore(endDate));
        }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: false,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events on ${_formatDate(selected)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8, width: 350),
                if (eventsOnSelectedDay.isEmpty)
                  const Text('No events on this day.')
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: eventsOnSelectedDay.length,
                      itemBuilder: (context, index) {
                        final event = eventsOnSelectedDay[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              event.thumbnailUrl != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      event.thumbnailUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : const Icon(Icons.event, color: Colors.blue),
                          title: Text(event.title),
                          subtitle: Text(
                            '${event.location}, ${event.municipality}',
                          ),
                          trailing: Text(
                            event.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(event.status),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (_) => EventDetailModal(
                                    event: event,
                                    currentUserId:
                                        FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                    userRole: _userRole,
                                    adminType: _adminType,
                                    status: '',
                                  ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Municipal Event Calendar",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryTeal,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: 'Create Event',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventCreationScreen()),
              );
              if (result == true) {
                // Reload all data if an event was created
                _initializeData();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
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
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  eventLoader: (day) {
                    final key = DateTime.utc(day.year, day.month, day.day);
                    return _eventMarkers[key] ?? [];
                  },
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  onRangeSelected: _onRangeSelected,
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 3,
                    markerSize: 6,
                    cellMargin: EdgeInsets.symmetric(vertical: 10),
                    markerMargin: EdgeInsets.symmetric(horizontal: 1),
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
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Colors.grey,
                      size: 25,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 25,
                    ),
                  ),
                  rowHeight: 40,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if(events.isEmpty) return null;

                      final roles = events.map((e) => (e as Event).role).toSet();
                      List<Color> bars = [];

                      if (roles.contains('Provincial Administrator')) {
                        bars.add(Colors.blue.shade700);
                      }
                      if (roles.contains('Municipal Administrator')) {
                        bars.add(Colors.green);
                      }
                      if (roles.contains('business owner')) {
                        bars.add(Colors.yellow[700]!);
                      }

                      return bars.isEmpty
                          ? const SizedBox()
                          : Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:
                                  bars.map((color) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      height: 5,
                                      width: 5,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 8,
                                ),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildLegendItem(
                                      Colors.blue.shade700,
                                      'Provincial',
                                    ),
                                    _buildLegendItem(
                                      Colors.green,
                                      'Municipals',
                                    ),
                                    _buildLegendItem(
                                      Colors.yellow[700]!,
                                      'Businesses',
                                    ),
                                  ],
                                ),
                              ),
                              TabBar(
                                controller: _tabController,
                                indicatorColor: AppColors.primaryTeal,
                                indicatorWeight: 4,
                                labelColor: AppColors.black,
                                unselectedLabelColor: AppColors.grey,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.event_available,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 2),
                                        const Text('This Month'),
                                        if (_newEvents.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${_newEvents.length}',
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 8,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.archive_rounded,
                                          size: 10,
                                        ),
                                        const SizedBox(width: 2),
                                        const Text('Ended Events'),
                                        if (_pastEvents.isNotEmpty) ...[
                                          const SizedBox(width: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4.6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.textLight,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${_pastEvents.length}',
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
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
                              // FIX 3: Use the clearer method name here
                              // _buildMunicipalEventsList(),
                              _buildNewEventsList(),
                              _buildPastEventsList(),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteEvent(Event event) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Event"),
            content: Text("Are you sure you want to delete '${event.title}'?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await EventService.deleteEvent(event.eventId);
                  _initializeData(); // Refresh the list
                },
              ),
            ],
          ),
    );
  }

  Widget _buildNewEventsList() {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    if (_newEvents.isEmpty) {
      return const Center(
        child: Text(
          "No New Events, create now!",
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _newEvents.length,
      itemBuilder: (context, index) {
        final event = _newEvents[index];
        final bool isCreator = event.createdBy == currentUserId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading:
                event.thumbnailUrl != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        event.thumbnailUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                    : const Icon(Icons.event, color: Colors.blue),
            title: Text(event.title),
            subtitle: Text(
              '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}\n ${event.location}, ${event.municipality}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isCreator ? IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: "Delete Event",
              onPressed: () => _confirmDeleteEvent(event),
            ) : null,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder:
                    (_) => EventDetailModal(
                      event: event,
                      currentUserId: currentUserId,
                      userRole: _userRole,
                      adminType: _adminType,
                      status: '',
                    ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPastEventsList() {
    if (_pastEvents.isEmpty) {
      return const Center(
        child: Text("No Ended Events", style: TextStyle(color: Colors.black)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              "view only.",
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
          ..._pastEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildEventCard(event),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    String creatorLabel = '';
    Color labelColor = Colors.grey;

    switch (event.role) {
      case 'Provincial Administrator':
        creatorLabel = 'Provincial';
        labelColor = Colors.blue.shade700;
        break;
      case 'Municipal Administrator':
        creatorLabel = 'Municipal';
        labelColor = Colors.green;
        break;
      case 'business owner':
        creatorLabel = 'Business';
        labelColor = Colors.orange.shade700;
        break;
      default:
        creatorLabel = 'Unknown';
        labelColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading:
            event.thumbnailUrl != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    event.thumbnailUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
                : const Icon(Icons.event, color: Colors.blue),
        title: Text(
          event.title,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '${event.location}, ${event.municipality}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: labelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                creatorLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          event.status.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getStatusColor(event.status),
          ),
        ),
        onTap: () async {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (_) => EventDetailModal(
                  event: event,
                  currentUserId: _auth.currentUser?.uid ?? '',
                  userRole: _userRole,
                  adminType: _adminType,
                  status: '',
                ),
          );
        },
      ),
    );
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