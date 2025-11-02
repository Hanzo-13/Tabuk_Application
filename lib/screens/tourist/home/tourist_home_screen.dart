// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/repositories/event_repository.dart';
import '../../../models/destination_model.dart';
import '../../../services/content_recommender_service.dart';
import '../../../services/location_service.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../../../widgets/recommendation_section_widget.dart';
import '../view_all_screen.dart';

class TouristHomeScreen extends StatefulWidget {
  const TouristHomeScreen({super.key});

  @override
  State<TouristHomeScreen> createState() => _TouristHomeScreenState();
}

class _TouristHomeScreenState extends State<TouristHomeScreen>
    with TickerProviderStateMixin {
  Position? _userPosition;
  late AnimationController _animationController;
  late AnimationController _eventSliderController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _eventSliderAnimation;

  final _recommendations = <String, List<Hotspot>>{};
  List<Map<String, dynamic>> _events = [];
  final PageController _eventPageController = PageController();
  Timer? _eventTimer;
  int _currentEventIndex = 0;

  String _greeting = '';
  String _userName = '';
  bool _isUserLoggedIn = false;
  String _userRole = 'Tourist';

  final LocationService _locationService = LocationService();
  final EventRepository _eventRepository = EventRepository();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchAllData();
    _startEventSlider();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _eventSliderController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _eventSliderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _eventSliderController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_eventSliderController.status == AnimationStatus.dismissed ||
          _eventSliderController.status == AnimationStatus.reverse) {
        _eventSliderController.forward();
      }
    });
  }

  void _startEventSlider() {
    _eventTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_events.isNotEmpty && _eventPageController.hasClients) {
        _currentEventIndex = (_currentEventIndex + 1) % _events.length;
        _eventPageController.animateToPage(
          _currentEventIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Fetch all data once in initState - no async calls in UI handlers
  Future<void> _fetchAllData() async {
    await Future.wait([
      _checkUserLoginStatus(),
      _fetchLocationAndRecommendations(),
      _loadEvents(),
    ]);
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _eventRepository.getActiveEventsOnce();

      // Sort client-side to avoid Firestore composite index issues
      events.sort((a, b) {
        final ad = a['startDate'];
        final bd = b['startDate'];
        DateTime aa;
        DateTime bb;
        if (ad is Timestamp) {
          aa = ad.toDate();
        } else if (ad is String) {
          aa = DateTime.tryParse(ad) ?? DateTime.now();
        } else {
          aa = DateTime.now();
        }
        if (bd is Timestamp) {
          bb = bd.toDate();
        } else if (bd is String) {
          bb = DateTime.tryParse(bd) ?? DateTime.now();
        } else {
          bb = DateTime.now();
        }
        return aa.compareTo(bb);
      });

      if (mounted) {
        setState(() {
          _events = events.take(5).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading events: $e');
    }
  }

  Future<void> _checkUserLoginStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          if (mounted) {
            setState(() {
              _userName =
                  userData['username'] ??
                  userData['display_name'] ??
                  'Explorer';
              _isUserLoggedIn = true;
              _userRole = userData['role']?.toString() ?? 'Tourist';
            });
            _setGreeting();
          }
        } else {
          if (mounted) {
            setState(() {
              _isUserLoggedIn = false;
              _userName = '';
              _userRole = 'Tourist';
            });
            _setGreeting();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isUserLoggedIn = false;
            _userName = '';
            _userRole = 'Tourist';
          });
          _setGreeting();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking user status: $e');
      if (mounted) {
        setState(() {
          _isUserLoggedIn = false;
          _userName = '';
          _userRole = 'Tourist';
        });
        _setGreeting();
      }
    }
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    final random = math.Random();
    String newGreeting;

    if (_isUserLoggedIn && _userName.isNotEmpty) {
      if (hour >= 18) {
        final eveningGreetings = [
          'Good Evening, $_userName 🌙',
          'Evening, $_userName 🌆',
          'Hello $_userName 🌙',
          'Good Evening, $_userName 🌆',
          'Hi $_userName 🌙',
        ];
        newGreeting = eveningGreetings[random.nextInt(eveningGreetings.length)];
      } else if (hour < 12) {
        final morningGreetings = [
          'Good Morning, $_userName ☀️',
          'Rise and shine, $_userName 🌅',
          'Morning, $_userName 🌞',
          'Good Morning, $_userName 🚀',
          'Hello $_userName 🌅',
        ];
        newGreeting = morningGreetings[random.nextInt(morningGreetings.length)];
      } else {
        final afternoonGreetings = [
          'Good Afternoon, $_userName 🌤️',
          'Afternoon, $_userName 🌅',
          'Hello $_userName 🌤️',
          'Good Afternoon, $_userName 🚶‍♂️',
          'Hi $_userName 🌤️',
        ];
        newGreeting =
            afternoonGreetings[random.nextInt(afternoonGreetings.length)];
      }
    } else {
      if (hour >= 18) {
        final eveningGreetings = [
          'Good Evening 🌙',
          'Evening 🌆',
          'Hello 🌙',
          'Good Evening 🌆',
          'Hi 🌙',
        ];
        newGreeting = eveningGreetings[random.nextInt(eveningGreetings.length)];
      } else if (hour < 12) {
        final morningGreetings = [
          'Good Morning ☀️',
          'Rise and shine 🌅',
          'Morning 🌞',
          'Good Morning 🚀',
          'Hello 🌅',
        ];
        newGreeting = morningGreetings[random.nextInt(morningGreetings.length)];
      } else {
        final afternoonGreetings = [
          'Good Afternoon 🌤️',
          'Afternoon 🌅',
          'Hello 🌤️',
          'Good Afternoon 🚶‍♂️',
          'Hi 🌤️',
        ];
        newGreeting =
            afternoonGreetings[random.nextInt(afternoonGreetings.length)];
      }
    }

    if (!mounted) return;
    setState(() {
      _greeting = newGreeting;
    });
  }

  Future<void> _fetchLocationAndRecommendations() async {
    try {
      _userPosition = await _locationService.getCurrentPosition();
      await _loadRecommendations();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching location and recommendations: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final recommendations =
          await ContentRecommenderService.getAllRecommendations(
            userLat: _userPosition?.latitude,
            userLng: _userPosition?.longitude,
            forYouLimit: AppConstants.homeForYouLimit,
            popularLimit: AppConstants.homePopularLimit,
            nearbyLimit: AppConstants.homeNearbyLimit,
            discoverLimit: AppConstants.homeDiscoverLimit,
            forceRefresh: true,
          );

      if (!mounted) return;
      setState(() {
        _recommendations.clear();
        _recommendations.addAll(recommendations);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading recommendations: $e');
    }
  }

  void _navigateToViewAll(String categoryKey, String title, Color accentColor) {
    final hotspots = _recommendations[categoryKey] ?? [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ViewAllScreen(
              categoryKey: categoryKey,
              title: title,
              hotspots: hotspots,
              accentColor: accentColor,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _eventSliderController.dispose();
    _eventTimer?.cancel();
    _eventPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          _buildEventSlider(),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryOrange.withOpacity(0.8),
                AppColors.primaryTeal.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _animationController,
              builder:
                  (context, child) => FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 12.0,
                        ),
                        child: MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: const TextScaler.linear(1.0)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  _greeting,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Flexible(
                                child: Text(
                                  'Discover amazing places around you',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventSlider() {
    if (_events.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _eventSliderController,
        builder:
            (context, child) => FadeTransition(
              opacity: _eventSliderAnimation,
              child: Container(
                height: 160,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event,
                            color: AppColors.primaryOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Upcoming Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PageView.builder(
                        controller: _eventPageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentEventIndex = index;
                          });
                        },
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryOrange.withOpacity(0.8),
                                  AppColors.primaryTeal.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          event['title'] ?? 'Event',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          event['description'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatEventDate(
                                                event['startDate'],
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (event['imageUrl'] != null)
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            event['imageUrl'],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_events.length > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _events.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    _currentEventIndex == index
                                        ? AppColors.primaryTeal
                                        : Colors.grey[300],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  String _formatEventDate(dynamic date) {
    if (date == null) return '';

    try {
      DateTime eventDate;
      if (date is Timestamp) {
        eventDate = date.toDate();
      } else if (date is String) {
        eventDate = DateTime.parse(date);
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = eventDate.difference(now).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      if (difference < 7) return '$difference days';

      return '${eventDate.day}/${eventDate.month}/${eventDate.year}';
    } catch (e) {
      return '';
    }
  }

  SliverToBoxAdapter _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final sections = <Widget>[];
    final sectionConfigs = [
      RecommendationSections.forYou,
      RecommendationSections.discover,
      RecommendationSections.nearby,
      RecommendationSections.popular,
    ];

    for (int i = 0; i < sectionConfigs.length; i++) {
      final config = sectionConfigs[i];
      final hotspots = _recommendations[config.categoryKey] ?? [];

      if (hotspots.isNotEmpty) {
        sections.add(
          RecommendationSectionWidget(
            title: config.title,
            subtitle: config.subtitle,
            categoryKey: config.categoryKey,
            accentColor: config.accentColor,
            icon: config.icon,
            hotspots: hotspots,
            userRole: _userRole,
            animationDelay: (i + 1) * 200,
            onViewAll:
                () => _navigateToViewAll(
                  config.categoryKey,
                  config.title,
                  config.accentColor,
                ),
            showViewAll: config.showViewAll,
          ),
        );
      }
    }

    return SliverToBoxAdapter(child: Column(children: sections));
  }
}
