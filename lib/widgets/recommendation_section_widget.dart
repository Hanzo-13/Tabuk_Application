import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/destination_model.dart';
import '../utils/colors.dart';
import '../utils/responsive.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    final isDesktop = Responsive.isDesktop(screenWidth);
    final horizontalPadding = (isWeb || isDesktop) ? 40.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all((isWeb || isDesktop) ? 14 : 12),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: widget.accentColor,
              size: (isWeb || isDesktop) ? 28 : 24,
            ),
          ),
          SizedBox(width: (isWeb || isDesktop) ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: (isWeb || isDesktop) ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: (isWeb || isDesktop) ? 16 : 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (widget.showViewAll && widget.onViewAll != null)
            TextButton(
              onPressed: widget.onViewAll,
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: (isWeb || isDesktop) ? 16 : 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHotspotsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    final isDesktop = Responsive.isDesktop(screenWidth);
    final isTablet = Responsive.isTablet(screenWidth);

    // Use grid layout for web/desktop, horizontal scroll for mobile
    if (isWeb || isDesktop) {
      // Desktop: 4-5 columns
      final crossAxisCount = isDesktop ? 5 : 4;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (isWeb || isDesktop) ? 40.0 : 16.0,
        ),
        itemCount: widget.hotspots.length,
        itemBuilder: (context, index) => HotspotCardWidget(
          hotspot: widget.hotspots[index],
          accentColor: widget.accentColor,
          categoryKey: widget.categoryKey,
          userRole: widget.userRole,
        ),
      );
    } else if (isTablet) {
      // Tablet: 3 columns
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (isWeb || isDesktop) ? 40.0 : 16.0,
        ),
        itemCount: widget.hotspots.length,
        itemBuilder: (context, index) => HotspotCardWidget(
          hotspot: widget.hotspots[index],
          accentColor: widget.accentColor,
          categoryKey: widget.categoryKey,
          userRole: widget.userRole,
        ),
      );
    } else {
      // Mobile: horizontal scroll
      final screenHeight = MediaQuery.of(context).size.height;
      final listHeight = (screenHeight * 0.28).clamp(180.0, 260.0);

      return SizedBox(
        height: listHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
          horizontal: (isWeb || isDesktop) ? 40.0 : 16.0,
        ),
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
