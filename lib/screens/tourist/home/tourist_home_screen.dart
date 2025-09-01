// ignore_for_file: unused_element, avoid_print, unused_local_variable, unnecessary_underscores
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/destination_model.dart';
import '../../../services/content_recommender_service.dart';
import '../../../services/location_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import '../../../widgets/recommendation_section_widget.dart';
import '../view_all_screen.dart';

class TouristHomeScreen extends StatefulWidget {
  const TouristHomeScreen({super.key});

  @override
  State<TouristHomeScreen> createState() => _TouristHomeScreenState();
}

class _TouristHomeScreenState extends State<TouristHomeScreen> with TickerProviderStateMixin {
  Position? _userPosition;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _recommendations = <String, List<Hotspot>>{};
  String _greeting = '';
  String _userName = '';
  bool _isUserLoggedIn = false;

  // Location service
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkUserLoginStatus();
    _fetchLocationAndRecommendations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _animationController.forward();
  }

  Future<void> _checkUserLoginStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['username'] ?? userData['display_name'] ?? 'Explorer';
            _isUserLoggedIn = true;
          });
          // Set personalized greeting after user data is loaded
          _setGreeting();
        } else {
          // User exists but no document, set generic greeting
          setState(() {
            _isUserLoggedIn = false;
            _userName = '';
          });
          _setGreeting();
        }
      } else {
        // No user logged in, set generic greeting
        setState(() {
          _isUserLoggedIn = false;
          _userName = '';
        });
        _setGreeting();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking user status: $e');
      // Set generic greeting on error
      setState(() {
        _isUserLoggedIn = false;
        _userName = '';
      });
      _setGreeting();
    }
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    final random = math.Random();
    
    if (_isUserLoggedIn && _userName.isNotEmpty) {
      // Personalized greetings for logged-in users
      if (hour >= 18) {
        final eveningGreetings = [
          'Good Evening, $_userName 🌙',
          'Evening, $_userName 🌆',
          'Hello $_userName 🌙',
          'Good Evening, $_userName 🌆',
          'Hi $_userName 🌙',
        ];
        _greeting = eveningGreetings[random.nextInt(eveningGreetings.length)];
      } else if (hour < 12) {
        final morningGreetings = [
          'Good Morning, $_userName ☀️',
          'Rise and shine, $_userName 🌅',
          'Morning, $_userName 🌞',
          'Good Morning, $_userName 🚀',
          'Hello $_userName 🌅',
        ];
        _greeting = morningGreetings[random.nextInt(morningGreetings.length)];
      } else {
        final afternoonGreetings = [
          'Good Afternoon, $_userName 🌤️',
          'Afternoon, $_userName 🌅',
          'Hello $_userName 🌤️',
          'Good Afternoon, $_userName?🚶‍♂️',
          'Hi $_userName 🌤️',
        ];
        _greeting = afternoonGreetings[random.nextInt(afternoonGreetings.length)];
      }
    } else {
      // Generic greetings for guests
      if (hour >= 18) {
        final eveningGreetings = [
          'Good Evening 🌙',
          'Evening 🌆',
          'Hello 🌙',
          'Good Evening 🌆',
          'Hi 🌙',
        ];
        _greeting = eveningGreetings[random.nextInt(eveningGreetings.length)];
      } else if (hour < 12) {
        final morningGreetings = [
          'Good Morning ☀️',
          'Rise and shine 🌅',
          'Morning 🌞',
          'Good Morning 🚀',
          'Hello 🌅',
        ];
        _greeting = morningGreetings[random.nextInt(morningGreetings.length)];
      } else {
        final afternoonGreetings = [
          'Good Afternoon 🌤️',
          'Afternoon 🌅',
          'Hello 🌤️',
          'Good Afternoon 🚶‍♂️',
          'Hi 🌤️',
        ];
        _greeting = afternoonGreetings[random.nextInt(afternoonGreetings.length)];
      }
    }
  }

  Future<void> _fetchLocationAndRecommendations() async {

    try {
      // Get user location
      _userPosition = await _locationService.getCurrentPosition();
      
      // Load all recommendations
      await _loadRecommendations();
      
    } catch (e) {
      if (kDebugMode) print('Error fetching location and recommendations: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      // Load recommendations for different sections
      final recommendations = await ContentRecommenderService.getAllRecommendations(
        userLat: _userPosition?.latitude,
        userLng: _userPosition?.longitude,
        forYouLimit: AppConstants.homeForYouLimit,
        popularLimit: AppConstants.homePopularLimit,
        nearbyLimit: AppConstants.homeNearbyLimit,
        discoverLimit: AppConstants.homeDiscoverLimit,
        forceRefresh: true,
      );
      
      setState(() {
        _recommendations.clear();
        _recommendations.addAll(recommendations);
      });
    } catch (e) {
      if (kDebugMode) print('Error loading recommendations: $e');
    }
  }

  void _navigateToViewAll(String categoryKey, String title, Color accentColor) {
    final hotspots = _recommendations[categoryKey] ?? [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewAllScreen(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
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
      actions: [],
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
              builder: (context, child) => FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: const TextScaler.linear(1.0),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxTextWidth = constraints.maxWidth - 60;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                 
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: maxTextWidth),
                                      child: Text(
                                        _greeting,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxTextWidth + 48),
                                child: Text(
                                  _isUserLoggedIn 
                                      ? 'Discover amazing places around you'
                                      : 'Discover amazing places around you',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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

  SliverToBoxAdapter _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Build sections based on available data
    final sections = <Widget>[];

    // Add recommendation sections
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
            animationDelay: (i + 1) * 200,
            onViewAll: () => _navigateToViewAll(
              config.categoryKey,
              config.title,
              config.accentColor,
            ),
            showViewAll: config.showViewAll,
          ),
        );
      }
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          ...sections,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
