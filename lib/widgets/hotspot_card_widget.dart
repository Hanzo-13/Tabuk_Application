import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/destination_model.dart';
import '../services/favorites_service.dart';
import '../utils/constants.dart';
import 'business_details_modal.dart';
import 'cached_image.dart';

class HotspotCardWidget extends StatefulWidget {
  final Hotspot hotspot;
  final Color accentColor;
  final String categoryKey;
  final String userRole;
  final VoidCallback? onTap;
  final bool showFavoriteButton;

  const HotspotCardWidget({
    super.key,
    required this.hotspot,
    required this.accentColor,
    required this.categoryKey,
    required this.userRole,
    this.onTap,
    this.showFavoriteButton = true,
  });

  @override
  State<HotspotCardWidget> createState() => _HotspotCardWidgetState();
}

class _HotspotCardWidgetState extends State<HotspotCardWidget> {
  bool _isPressed = false;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final isFavorite = await FavoritesService.isFavorite(
        widget.hotspot.hotspotId,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFavorite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // For web/grid layouts, use full width; for mobile horizontal scroll, use fixed width
    final isWeb = MediaQuery.of(context).size.width > 768;
    final cardWidth = isWeb ? null : (screenWidth * 0.6).clamp(140.0, 220.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap ?? () => _showBusinessDetails(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        width: cardWidth,
        height: cardWidth != null ? null : 280, // Fixed height for grid layouts
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildImage(),
              _buildGradientOverlay(),
              _buildContent(),
              // Hide favorite button in guest mode; parent widgets set showFavoriteButton=false for guests
              if (widget.showFavoriteButton) _buildFavoriteButton(),
              _buildCategoryBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Positioned.fill(
      child:
          widget.hotspot.images.isNotEmpty
              ? CachedImage(
                imageUrl: widget.hotspot.images.first,
                fit: BoxFit.cover,
                placeholderBuilder: (context) => _buildPlaceholder(),
                errorBuilder:
                    (context, error, stackTrace) => _buildPlaceholder(),
              )
              : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.hotspot.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, color: widget.accentColor, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.hotspot.location,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.category, color: widget.accentColor, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.hotspot.category,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => _toggleFavorite(),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child:
              _isLoadingFavorite
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                    size: 20,
                  ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.accentColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getCategoryShortName(widget.hotspot.category),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getCategoryShortName(String category) {
    switch (category) {
      case AppConstants.naturalAttraction:
        return 'Nature';
      case AppConstants.culturalSite:
        return 'Culture';
      case AppConstants.adventureSpot:
        return 'Adventure';
      case AppConstants.restaurant:
        return 'Food';
      case AppConstants.accommodation:
        return 'Stay';
      case AppConstants.shopping:
        return 'Shop';
      case AppConstants.entertainment:
        return 'Fun';
      default:
        return category.length > 8
            ? '${category.substring(0, 8)}...'
            : category;
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        final success = await FavoritesService.removeFromFavorites(
          widget.hotspot.hotspotId,
        );
        if (success && mounted) {
          setState(() {
            _isFavorite = false;
          });
          _showSnackBar(
            '${widget.hotspot.name} removed from favorites',
            Icons.favorite_border,
            Colors.orange,
          );
        }
      } else {
        final success = await FavoritesService.addToFavorites(widget.hotspot);
        if (success && mounted) {
          setState(() {
            _isFavorite = true;
          });
          _showSnackBar(
            '${widget.hotspot.name} added to favorites',
            Icons.favorite,
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Icons.error, Colors.red);
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showBusinessDetails() {
    final businessData = _mapHotspotToBusinessData(widget.hotspot);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Synchronous call - no async/await in UI handler
    BusinessDetailsModal.show(
      context: context,
      businessData: businessData,
      role: widget.userRole,
      currentUserId: currentUserId,
      showInteractions: false,
    );
  }

  Map<String, dynamic> _mapHotspotToBusinessData(Hotspot h) {
    return {
      'hotspot_id': h.hotspotId,
      'business_name': h.name,
      'description': h.description,
      'category': h.category.isNotEmpty ? h.category : h.type,
      'type': h.type,
      'address': h.location,
      'municipality': h.municipality,
      'district': h.district,
      'images': h.images,
      'imageUrl': h.imageUrl,
      'transportation': h.transportation,
      'operating_hours': h.operatingHours,
      'entrance_fees': h.entranceFees,
      'business_contact': h.contactInfo,
      'contact_info': h.contactInfo,
      'restroom': h.restroom,
      'food_access': h.foodAccess,
      'safety_tips': h.safetyTips,
      'local_guide': h.localGuide,
      'suggested_items': h.suggestions,
      'latitude': h.latitude,
      'longitude': h.longitude,
    };
  }
}
