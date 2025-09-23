import 'package:flutter/material.dart';

import '../models/destination_model.dart';
import '../utils/colors.dart';
import 'hotspot_card_widget.dart';

class RecommendationSectionWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String categoryKey;
  final Color accentColor;
  final IconData icon;
  final List<Hotspot> hotspots;
  final String userRole;
  final int animationDelay;
  final VoidCallback? onViewAll;
  final bool showViewAll;

  const RecommendationSectionWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.categoryKey,
    required this.accentColor,
    required this.icon,
    required this.hotspots,
    required this.userRole,
    this.animationDelay = 0,
    this.onViewAll,
    this.showViewAll = true,
  });

  @override
  State<RecommendationSectionWidget> createState() =>
      _RecommendationSectionWidgetState();
}

class _RecommendationSectionWidgetState
    extends State<RecommendationSectionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Start animation with delay
    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hotspots.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, child) => FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildHotspotsList(),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: widget.accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (widget.showViewAll && widget.onViewAll != null)
            TextButton(
              onPressed: widget.onViewAll,
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildHotspotsList() {
    final screenHeight = MediaQuery.of(context).size.height;
    final listHeight = (screenHeight * 0.28).clamp(180.0, 260.0);

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.hotspots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder:
            (context, index) => HotspotCardWidget(
              hotspot: widget.hotspots[index],
              accentColor: widget.accentColor,
              categoryKey: widget.categoryKey,
              userRole: widget.userRole,
            ),
      ),
    );
  }
}

/// Configuration class for recommendation sections
class RecommendationSectionConfig {
  final String title;
  final String subtitle;
  final String categoryKey;
  final Color accentColor;
  final IconData icon;
  final bool showViewAll;

  const RecommendationSectionConfig({
    required this.title,
    required this.subtitle,
    required this.categoryKey,
    required this.accentColor,
    required this.icon,
    this.showViewAll = true,
  });
}

/// Predefined section configurations
class RecommendationSections {
  static const forYou = RecommendationSectionConfig(
    title: 'Just For You',
    subtitle: 'Personalized recommendations',
    categoryKey: 'forYou',
    accentColor: AppColors.homeForYouColor,
    icon: Icons.person_outline,
  );

  static const discover = RecommendationSectionConfig(
    title: 'Discover Hidden Gems',
    subtitle: 'Lesser-known amazing places',
    categoryKey: 'discover',
    accentColor: AppColors.homeSeasonalColor,
    icon: Icons.visibility_off,
  );

  static const nearby = RecommendationSectionConfig(
    title: 'Nearby Hotspots',
    subtitle: 'Close to your location',
    categoryKey: 'nearby',
    accentColor: AppColors.homeNearbyColor,
    icon: Icons.location_on,
  );

  static const popular = RecommendationSectionConfig(
    title: 'Popular Destinations',
    subtitle: 'Most visited places in Bukidnon',
    categoryKey: 'popular',
    accentColor: AppColors.homeTrendingColor,
    icon: Icons.trending_up,
  );

  static List<RecommendationSectionConfig> get allSections => [
    forYou,
    popular,
    nearby,
    discover,
  ];
}
