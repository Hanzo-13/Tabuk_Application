import 'package:flutter/material.dart';
import '../models/destination_model.dart';
import '../services/favorites_service.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import 'cached_image.dart';

class HotspotDetailsDialog extends StatefulWidget {
  final Hotspot hotspot;
  final VoidCallback? onClose;

  const HotspotDetailsDialog({
    super.key,
    required this.hotspot,
    this.onClose,
  });

  @override
  State<HotspotDetailsDialog> createState() => _HotspotDetailsDialogState();
}

class _HotspotDetailsDialogState extends State<HotspotDetailsDialog> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final isFavorite = await FavoritesService.isFavorite(widget.hotspot.hotspotId);
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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImage(),
                  _buildContent(),
                ],
              ),
            ),
            _buildCloseButton(),
            _buildFavoriteButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: widget.hotspot.images.isNotEmpty
            ? CachedImage(
                imageUrl: widget.hotspot.images.first,
                fit: BoxFit.cover,
                placeholderBuilder: (context) => _buildImagePlaceholder(),
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDescription(),
          const SizedBox(height: 16),
          _buildQuickInfo(),
          const SizedBox(height: 20),
          _buildDetailedInfo(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hotspot.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.hotspot.location,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getCategoryColor(widget.hotspot.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.hotspot.category,
            style: TextStyle(
              color: _getCategoryColor(widget.hotspot.category),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.hotspot.description,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
        height: 1.5,
      ),
    );
  }

  Widget _buildQuickInfo() {
    return Row(
      children: [
        _buildQuickInfoItem(
          Icons.access_time,
          'Hours',
          'Open',
          Colors.green,
        ),
        const SizedBox(width: 16),
        _buildQuickInfoItem(
          Icons.attach_money,
          'Fee',
          widget.hotspot.isFree ? 'Free' : 'Paid',
          widget.hotspot.isFree ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildQuickInfoItem(
          Icons.location_on,
          'District',
          widget.hotspot.district,
          AppColors.primaryTeal,
        ),
      ],
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoSection('Transportation', widget.hotspot.transportation),
        _buildInfoSection('Operating Hours', [widget.hotspot.operatingHours.toString()]),
        if (widget.hotspot.safetyTips?.isNotEmpty ?? false)
          _buildInfoSection('Safety Tips', widget.hotspot.safetyTips!),
        if (widget.hotspot.localGuide?.isNotEmpty ?? false)
          _buildInfoSection('Local Guide', [widget.hotspot.localGuide!]),
        if (widget.hotspot.suggestions?.isNotEmpty ?? false)
          _buildInfoSection('Suggested to Bring', widget.hotspot.suggestions!),
        _buildAmenitiesSection(),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amenities:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAmenityItem(
                Icons.wc,
                'Restroom',
                widget.hotspot.restroom,
              ),
              const SizedBox(width: 16),
              _buildAmenityItem(
                Icons.restaurant,
                'Food Access',
                widget.hotspot.foodAccess,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityItem(IconData icon, String label, bool available) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: available ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: available ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: available ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          onPressed: () {
            Navigator.pop(context);
            widget.onClose?.call();
          },
          tooltip: 'Close',
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: _isLoadingFavorite
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                  size: 24,
                ),
          onPressed: _toggleFavorite,
          tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case AppConstants.naturalAttraction:
        return Colors.green;
      case AppConstants.culturalSite:
        return Colors.purple;
      case AppConstants.adventureSpot:
        return Colors.orange;
      case AppConstants.restaurant:
        return Colors.red;
      case AppConstants.accommodation:
        return Colors.blue;
      case AppConstants.shopping:
        return Colors.pink;
      case AppConstants.entertainment:
        return Colors.indigo;
      default:
        return AppColors.primaryOrange;
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        final success = await FavoritesService.removeFromFavorites(widget.hotspot.hotspotId);
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
        _showSnackBar(
          'Error: $e',
          Icons.error,
          Colors.red,
        );
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
}
