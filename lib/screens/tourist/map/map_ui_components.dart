import 'dart:math' as math;

import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/services/navigation_service.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
// import 'package:capstone_app/widgets/common_search_bar.dart';
import 'package:flutter/material.dart';

/// Reusable UI components for the map screen
class MapUIComponents {
  /// Build location permission banner
  static Widget buildLocationBanner(
    BuildContext context,
    String message,
    VoidCallback onEnable,
  ) {
    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onEnable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Enable'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a bar that displays the currently active filters and a clear button.
  static Widget buildActiveFiltersBar({
    required String? category,
    required String? subCategory,
    required VoidCallback onClear,
  }) {
    // Helper to build a single filter "chip"
    Widget buildFilterChip(String label, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryTeal, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Positioned(
      top: 100, // Position it right below the search bar
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Show the selected category chip
            if (category != null) buildFilterChip(category, Icons.category),
            
            // Add a small spacer if both filters are active
            if (category != null && subCategory != null) const SizedBox(width: 8),
            
            // Show the selected sub-category chip
            if (subCategory != null) buildFilterChip(subCategory, Icons.merge_type),
            
            const Spacer(), // Pushes the clear button to the right
            
            // The "X" button to clear the filters
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the destination display banner, visible during navigation.
  static Widget buildDestinationBanner({
    required String destinationName,
    required double topPadding, // We'll use top padding for positioning
  }) {
    return Positioned(
      top: topPadding + 150, // Position below the search bar
      left: 16,
      child: IgnorePointer(
        child: Container(
          width: 250, // Set a fixed width instead of stretching full width
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Make row take minimum space
            children: [
              const Icon(Icons.flag, color: AppColors.primaryTeal, size: 22),
              const SizedBox(width: 12),
              const Text(
                'To:',
                style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destinationName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // In map_ui_components.dart, inside the MapUIComponents class

/// Builds a container for all top-aligned map controls.
  static Widget buildTopControls({
    required BuildContext context,
    required bool isNavigating,
    String? destinationName,
    required double topPadding,
    // Add any other data needed for top controls here
  }) {
    return Positioned(
      top: 15, // A safe padding from the status bar
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Conditionally show the Destination Banner
          if (isNavigating && destinationName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag, color: AppColors.primaryTeal, size: 22),
                  const SizedBox(width: 12),
                  const Text('To:', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destinationName,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build offline mode banner
  static Widget buildOfflineBanner() {
    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Offline mode: showing cached places only',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build offline destinations list
  static Widget buildOfflineDestinationsList(
    BuildContext context,
    List<Map<String, dynamic>> cachedDestinations,
    double bottomPadding,
    String role,
  ) {
    return Positioned(
      bottom: 16 + bottomPadding,
      left: 16,
      right: 16,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Cached Destinations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: cachedDestinations.length,
                itemBuilder: (context, index) {
                  final data = cachedDestinations[index];
                  final name = (data['business_name'] ?? data['name'] ?? 'Place').toString();
                  final images = (data['images'] is List) ? data['images'] as List : [];
                  final imageUrl = images.isNotEmpty ? images.first.toString() : data['imageUrl']?.toString();

                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    child: InkWell(
                      onTap: () {
                        BusinessDetailsModal.show(
                          context: context,
                          businessData: data,
                          role: role,
                          currentUserId: null,
                          showInteractions: false,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.image, size: 30, color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  /// Build my location button (iOS-styled)
  static Widget buildMyLocationButton(VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          child: const Icon(
            Icons.my_location,
            color: AppColors.primaryTeal,
            size: 30,
          ),
        ),
      ),
    );
  }

  /// Build compass indicator (iOS-style)
  static Widget buildCompass(double bearing) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Compass background
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryTeal.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          // North indicator
          Transform.rotate(
            angle: -bearing * (math.pi / 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward,
                  color: Colors.red[700],
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  'N',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show filter bottom sheet
  static void showFilterSheet({
    required BuildContext context,
    required Map<String, List<String>> categories,
    required Function(String? category, String? subCategory) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(
        categories: categories,
        onApply: onApply,
      ),
    );
  }
}

// In map_ui_components.dart, at the bottom of the file

class _FilterSheet extends StatefulWidget {
  final Map<String, List<String>> categories;
  final Function(String? category, String? subCategory) onApply;

  const _FilterSheet({
    required this.categories,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

// Navigation overlay (moved here to consolidate UI in one file)
class NavigationOverlay extends StatefulWidget {
  final NavigationService navigationService;
  final VoidCallback onExitNavigation;

  const NavigationOverlay({
    super.key,
    required this.navigationService,
    required this.onExitNavigation,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  bool _isNavigating = false;
  bool _showVehicleSelector = false;
  Map<String, dynamic> _remainingInfo = {};

  @override
  void initState() {
    super.initState();
    _listenToNavigationUpdates();
  }

  void _listenToNavigationUpdates() {
    widget.navigationService.navigationStateStream.listen((isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = isNavigating;
          if (isNavigating) {
            _remainingInfo = widget.navigationService.getRemainingInfo();
          }
        });
      }
    });

    widget.navigationService.stepStream.listen((_) {
      if (mounted) {
        setState(() {
          _remainingInfo = widget.navigationService.getRemainingInfo();
        });
      }
    });

    widget.navigationService.transportationModeStream.listen((_) {
      if (mounted && _isNavigating) {
        setState(() {
          _remainingInfo = widget.navigationService.getRemainingInfo();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNavigating) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (_showVehicleSelector) _buildVehicleSelector(),

        Positioned(
          top: 120,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_remainingInfo['duration'] ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${_formatDistance(_remainingInfo['distance'] ?? 0)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 120,
          right: 16,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton(
                  heroTag: "transportButton",
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _showVehicleSelector = !_showVehicleSelector;
                    });
                  },
                  child: Text(
                    widget.navigationService.getTransportationModeIcon(
                      widget.navigationService.currentTransportationMode,
                    ),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton(
                  heroTag: "exitButton",
                  backgroundColor: Colors.red[50],
                  onPressed: widget.onExitNavigation,
                  child: Icon(Icons.close, color: Colors.red[600]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  Widget _buildVehicleSelector() {
    return Positioned(
      top: 180,
      left: 16,
      right: 80,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Transportation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.navigationService
                  .getAvailableTransportationModes()
                  .map((mode) {
                final isSelected =
                    mode == widget.navigationService.currentTransportationMode;
                return GestureDetector(
                  onTap: () {
                    widget.navigationService.changeTransportationMode(mode);
                    setState(() {
                      _showVehicleSelector = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.navigationService
                              .getTransportationModeColor(mode)
                              .withOpacity(0.2)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? widget.navigationService
                                .getTransportationModeColor(mode)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.navigationService
                              .getTransportationModeIcon(mode),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.navigationService
                              .getTransportationModeDisplayName(mode),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? widget.navigationService
                                    .getTransportationModeColor(mode)
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  List<String> _availableSubCategories = [];

  @override
  Widget build(BuildContext context) {
    // Create a list of main categories for the dropdown, including an "All" option
    final mainCategories = ['All Categories', ...widget.categories.keys];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle and Title
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Filter Destinations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 24),

          // Main Category Dropdown
          _buildDropdown(
            title: 'Category',
            icon: Icons.category,
            value: _selectedMainCategory,
            items: mainCategories,
            onChanged: (newValue) {
              setState(() {
                _selectedMainCategory = newValue == 'All Categories' ? null : newValue;
                // When main category changes, update sub-categories and reset selection
                _selectedSubCategory = null;
                if (_selectedMainCategory != null) {
                  _availableSubCategories = ['All Sub-categories', ...widget.categories[_selectedMainCategory]!];
                } else {
                  _availableSubCategories = [];
                }
              });
            },
          ),
          const SizedBox(height: 20),

          // Sub-Category Dropdown (only visible if a main category is selected)
          if (_selectedMainCategory != null)
            _buildDropdown(
              title: 'Type',
              icon: Icons.merge_type,
              value: _selectedSubCategory,
              items: _availableSubCategories,
              onChanged: (newValue) {
                setState(() {
                  _selectedSubCategory = newValue == 'All Sub-categories' ? null : newValue;
                });
              },
            ),
          const SizedBox(height: 32),

          // Apply and Clear Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // Pass null values for "Clear"
                    widget.onApply(null, null);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear Filters', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Pass the selected values back to the map screen
                    widget.onApply(_selectedMainCategory, _selectedSubCategory);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Helper widget to build consistent dropdowns
  Widget _buildDropdown({
    required String title,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text('All ${title}s', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}