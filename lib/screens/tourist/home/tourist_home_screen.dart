// ignore_for_file: unused_element, avoid_print, unused_local_variable, unnecessary_underscores
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  IconData _greetingIcon = Icons.wb_sunny;



  // Location service
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setGreeting();
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

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning! ☀️';
      _greetingIcon = Icons.wb_sunny;
    } else if (hour < 18) {
      _greeting = 'Good Afternoon! 🌤️';
      _greetingIcon = Icons.wb_cloudy;
    } else {
      _greeting = 'Good Evening! 🌙';
      _greetingIcon = Icons.nightlight_round;
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
                                  Icon(
                                    _greetingIcon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxTextWidth),
                                    child: Text(
                                      _greeting,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxTextWidth + 48),
                                child: const Text(
                                  'Discover amazing places around you',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
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
