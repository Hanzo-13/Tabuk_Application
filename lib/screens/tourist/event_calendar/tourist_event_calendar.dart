// ignore_for_file: unnecessary_const, unnecessary_cast, prefer_final_fields, unnecessary_string_interpolations

import 'package:capstone_app/data/repositories/event_repository.dart';
import 'package:capstone_app/models/event_model.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/event_detail_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class TouristEventCalendarScreen extends StatefulWidget {
  const TouristEventCalendarScreen({super.key});

  @override
  State<TouristEventCalendarScreen> createState() =>
      _TouristEventCalendarScreenState();
}

class _TouristEventCalendarScreenState extends State<TouristEventCalendarScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _events = [];
  bool _isLoading = true;
  Map<DateTime, List<Event>> _eventMarkers = {};
  final EventRepository _eventRepository = EventRepository();

  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final raw = await _eventRepository.getAllEventsOnce();
    final events = raw.map((m) => Event.fromMap(m, m['id'] ?? '')).toList();

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
      _isLoading = false;
    });
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
          return selected.isAfter(
                event.startDate.subtract(const Duration(days: 1)),
              ) &&
              selected.isBefore(event.endDate.add(const Duration(days: 1)));
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
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                                  userRole: 'Tourist',
                                  status: '',
                                ),
                          );
                        },
                      );
                    },
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
    final size = MediaQuery.of(context).size;
    final bool isSmallDevice = size.width < 360;
    final double rowHeightVar = isSmallDevice ? 36 : 44;
    final double markerSizeVar = isSmallDevice ? 5 : 7;
    final double headerFontSize = isSmallDevice ? 16 : 18;
    final double dayFontSize =
        isSmallDevice
            ? AppConstants.calendarDayFontSize - 1
            : AppConstants.calendarDayFontSize;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Event Calendar",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryTeal,

        /// Commented since Tourist Cannot Create Events
        // elevation: 1,
        // iconTheme: const IconThemeData(color: Colors.white),
        // centerTitle: false,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.add_outlined),
        //     tooltip: 'Create Event/ Promotion',
        //     onPressed: () async {
        //       await Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (_) => const EventCreationScreen()),
        //       );
        //       _loadEvents();
        //     },
        //   ),
        // ],
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
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                  calendarStyle: CalendarStyle(
                    markersMaxCount: 3,
                    markerSize: markerSizeVar,
                    cellMargin: EdgeInsets.symmetric(
                      vertical: isSmallDevice ? 6 : 10,
                    ),
                    markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                    todayDecoration: const BoxDecoration(
                      color: AppColors.homeTrendingColor,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      color: AppColors.primaryOrange,
                    ),
                    outsideTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      color: AppColors.textLight,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: Colors.black,
                      fontSize: headerFontSize,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: Colors.grey,
                      size: 24,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                  rowHeight: rowHeightVar,
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final roles = events.map((e) => e.role).toSet().toList();
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  bars.map((color) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 1,
                                      ),
                                      height: isSmallDevice ? 2.0 : 2.5,
                                      width: isSmallDevice ? 22 : 30,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
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
                                indicatorWeight: 3,
                                labelColor: AppColors.black,
                                unselectedLabelColor: AppColors.black
                                    .withOpacity(0.5),
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.event, size: 18),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Events',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (_newEvents.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${_newEvents.length}',
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.archive_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Ended Events',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (_pastEvents.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.textLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${_pastEvents.length}',
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
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
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

  Widget _buildNewEventsList() {
    if (_newEvents.isEmpty) {
      return const Center(
        child: Text("No new events", style: TextStyle(color: Colors.black)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _newEvents.length,
      itemBuilder: (context, index) => _buildEventCard(_newEvents[index]),
    );
  }

  Widget _buildPastEventsList() {
    if (_pastEvents.isEmpty) {
      return const Center(
        child: Text("No past events", style: TextStyle(color: Colors.black)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pastEvents.length,
      itemBuilder: (context, index) => _buildEventCard(_pastEvents[index]),
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
                '$creatorLabel',
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
                  currentUserId: '',
                  userRole: 'Tourist',
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
