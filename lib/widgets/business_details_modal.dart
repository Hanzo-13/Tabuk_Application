// ignore_for_file: non_constant_identifier_names, unnecessary_string_interpolations, unnecessary_string_escapes, use_build_context_synchronously
import 'package:capstone_app/models/destination_model.dart';
import 'package:capstone_app/models/review_model.dart';
import 'package:capstone_app/screens/review_screen.dart';
import 'package:capstone_app/services/favorites_service.dart';
import 'package:capstone_app/services/review_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/widgets/cached_image.dart';
import 'package:capstone_app/widgets/network_image_with_timeout.dart';
import 'package:capstone_app/widgets/review_form_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessDetailsModal extends StatefulWidget {
  final Map<String, dynamic> businessData;
  final String role;
  final String? currentUserId;
  final Map<String, dynamic>? creatorData;
  final void Function(double lat, double lng)? onNavigate;
  final bool showInteractions;

  const BusinessDetailsModal({
    super.key,
    required this.businessData,
    required this.role,
    this.currentUserId,
    this.creatorData,
    this.onNavigate,
    this.showInteractions = true,
  });

  static void show({
    required BuildContext context,
    required Map<String, dynamic> businessData,
    required String role,
    Map<String, dynamic>? creatorData,
    String? currentUserId,
    void Function(double lat, double lng)? onNavigate,
    bool showInteractions = true,
  }) {
    // Normalize role with local preference (guest override)
    final String normalizedRole = role.toLowerCase();
    Future<void> open() async {
      String finalRole = normalizedRole;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedRole = prefs.getString('user_role');
        if (cachedRole != null && cachedRole.toLowerCase() == 'guest') {
          finalRole = 'guest';
        }
      } catch (_) {}

      showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BusinessDetailsModal(
            businessData: businessData,
            role: finalRole,
            currentUserId: currentUserId,
            creatorData: creatorData,
            onNavigate: onNavigate,
            showInteractions: finalRole == 'guest' ? false : showInteractions,
          ),
    );
    }

    // Fire and forget
    // ignore: discarded_futures
    open();
  }

  @override
  State<BusinessDetailsModal> createState() => _BusinessDetailsModalState();
}

class _BusinessDetailsModalState extends State<BusinessDetailsModal> {
  Map<String, dynamic>? _creatorData;
  late Map<String, dynamic> businessData;
  late String? currentUserId;
  late String role;
  final double _sectionSpacing = 16;
  final double _chipSpacing = 8;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentImageIndex = 0;
  Timer? _slideshowTimer;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _isLoadingNearby = false;

  @override
  void initState() {
    super.initState();
    businessData = widget.businessData;
    currentUserId = widget.currentUserId;
    role = widget.role;
    _fetchCreatorData();
    _startSlideshow();
    _fetchNearbyPlaces();
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getImages() {
    final dynamic imagesDynamic = businessData['images'] ?? [];
    return imagesDynamic is List
        ? imagesDynamic
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
  }

  void _startSlideshow() {
    final images = _getImages();
    if (images.length <= 1) return;
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final imgs = _getImages();
      if (imgs.length <= 1) return;

      // Check if PageController is attached before animating
      if (_pageController.hasClients) {
        final nextIndex = (_currentImageIndex + 1) % imgs.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        setState(() => _currentImageIndex = nextIndex);
      }
    });
  }

  Future<void> _fetchCreatorData() async {
    if (widget.creatorData != null) {
      setState(() {
        _creatorData = widget.creatorData!;
      });
      return;
    }

    final ownerUid = businessData['owner_uid'];
    if (ownerUid != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(ownerUid)
              .get();
      if (doc.exists) {
        setState(() {
          _creatorData = doc.data();
        });
      }
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (mounted) {
      setState(() => _isLoadingNearby = true);
    }

    try {
      // Try different possible coordinate fields
      dynamic currentLat =
          businessData['latitude'] ?? businessData['location']?['lat'];
      dynamic currentLng =
          businessData['longitude'] ?? businessData['location']?['lng'];

      if (currentLat == null || currentLng == null) {
        if (kDebugMode) debugPrint('No coordinates found for current location');
        if (mounted) {
          setState(() => _isLoadingNearby = false);
        }
        return;
      }

      if (kDebugMode) debugPrint('Fetching nearby places from: $currentLat, $currentLng');
      if (kDebugMode) debugPrint('Business data keys: ${businessData.keys.toList()}');

      final snapshot =
          await FirebaseFirestore.instance.collection('destination').get();

      if (kDebugMode) debugPrint('Found ${snapshot.docs.length} total destinations');

      final places = <Map<String, dynamic>>[];
      final currentPosition = LatLng(
        (currentLat as num).toDouble(),
        (currentLng as num).toDouble(),
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();
        dynamic placeLat = data['latitude'] ?? data['location']?['lat'];
        dynamic placeLng = data['longitude'] ?? data['location']?['lng'];

        if (placeLat != null && placeLng != null) {
          final placePosition = LatLng(
            (placeLat as num).toDouble(),
            (placeLng as num).toDouble(),
          );

          final distance = _calculateDistance(currentPosition, placePosition);

          // Only include places within 10km and exclude the current place
          final currentHotspotId =
              businessData['hotspot_id'] ?? businessData['id']?.toString();
          if (distance <= 10.0 && doc.id != currentHotspotId) {
            if (kDebugMode) debugPrint('Adding nearby place: ${data['business_name'] ?? data['name']} at ${distance.toStringAsFixed(2)} km');
            places.add({...data, 'hotspot_id': doc.id, 'distance': distance});
          }
        }
      }

      if (kDebugMode) debugPrint('Found ${places.length} places within 10km');

      // Sort by distance and take top 5
      places.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (mounted) {
        setState(() {
          _nearbyPlaces = places.take(5).toList();
          _isLoadingNearby = false;
        });
      }

      if (kDebugMode) debugPrint('Final nearby places: ${_nearbyPlaces.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching nearby places: $e');
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLng = _degreesToRadians(point2.longitude - point1.longitude);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(point1.latitude)) *
            math.cos(_degreesToRadians(point2.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  Future<void> _confirmArchive(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Archive Business'),
            content: const Text(
              'Are you sure you want to archive this business?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Archive'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('destination')
          .doc(businessData['hotspot_id'])
          .update({'archived': true});

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business archived successfully')),
        );
      }
    }
  }

  Widget _buildRoleBasedButtons(BuildContext context) {
    final String creatorId = businessData['owner_uid'] ?? '';
    final bool isCreator = creatorId == currentUserId;
    final String adminType =
        _creatorData?['admin_type'] ?? businessData['admin_type'] ?? '';
    final String normalizedRole = role.toLowerCase();

    // Hide advanced actions for guests
    if (normalizedRole == 'guest') {
      return const SizedBox.shrink();
    }

    if (normalizedRole == 'tourist') {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final lat =
                        businessData['latitude'] ??
                        businessData['location']?['lat'];
                    final lng =
                        businessData['longitude'] ??
                        businessData['location']?['lng'];
                    if (lat != null && lng != null) {
                      Navigator.pop(context);
                      widget.onNavigate?.call(
                        (lat as num).toDouble(),
                        (lng as num).toDouble(),
                      );
                    } else {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder:
                              (ctx) => const AlertDialog(
                                title: Text('No Coordinates'),
                                content: Text(
                                  'Destination coordinates not found.',
                                ),
                              ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Ensure we always have a hotspot_id for favorites
                    final enriched = Map<String, dynamic>.from(businessData);
                    if ((enriched['hotspot_id'] == null ||
                            enriched['hotspot_id'].toString().isEmpty) &&
                        enriched['id'] != null) {
                      enriched['hotspot_id'] = enriched['id'].toString();
                    }
                    final hotspot = Hotspot.fromMap(
                      enriched,
                      enriched['hotspot_id']?.toString() ?? '',
                    );
                    final success = await FavoritesService.addToFavorites(
                      hotspot,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Added to Favorites!'
                                : 'Failed to add to Favorites',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Favorite'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _getReviewButtonText(),
            builder: (context, snapshot) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReviewForm(context),
                  icon: const Icon(Icons.rate_review),
                  label: Text(snapshot.data ?? 'Write a Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    if (normalizedRole == 'guest') {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Register to get Navigations and Reviews.',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // You can navigate to signup screen here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please register to write reviews'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Write a Review (Register First)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (normalizedRole == 'businessowner' && isCreator) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmArchive(context),
              icon: const Icon(Icons.archive, color: Colors.red),
              label: const Text('Archive', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      );
    }

    if (normalizedRole == 'administrator' && isCreator) {
      final String creatorRole = _creatorData?['role'] ?? 'Unknown';
      final String creatorName = _creatorData?['name'] ?? 'Unknown';
      final String creatorEmail = _creatorData?['email'] ?? 'Unknown';
      final String creatorContact = businessData['contact_info'] ?? 'Unknown';
      final String creatorMunicipality =
          businessData['municipality'] ?? 'Unknown';
      final String adminType =
          _creatorData?['admin_type'] ?? businessData['admin_type'] ?? '';

      // The Column is now the single widget being returned, containing everything inside.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Creator Details Section ---
          const Text(
            'Created By:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Role: $creatorRole',
            style: TextStyle(
              color: AppColors.primaryTeal,
              fontStyle: FontStyle.italic,
              fontSize: 15,
            ),
          ),
          if (creatorRole.toLowerCase() == 'administrator' &&
              adminType.isNotEmpty)
            Text(
              'Admin Type: $adminType',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
            ),
          Text('Name: $creatorName'),
          Text('Email: $creatorEmail'),
          Text('Contact: $creatorContact'),
          Text('Municipality: $creatorMunicipality'),
          const SizedBox(
            height: 16,
          ), // Added more space for better UI separation
          // --- Action Buttons Section (Moved Inside the Column) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Add your edit logic here
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8), // Added space between buttons
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmArchive(context),
                  icon: const Icon(Icons.archive, color: Colors.red, size: 18),
                  label: const Text(
                    'Archive',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ], // End of Column's children
      ); // End of return statement
    }

    if (normalizedRole == 'administrator' && !isCreator) {
      final String creatorRole = _creatorData?['role'] ?? 'Unknown';
      final String creatorName = _creatorData?['name'] ?? 'Unknown';
      final String creatorEmail = _creatorData?['email'] ?? 'Unknown';
      final String creatorContact = businessData['contact_info'] ?? 'Unknown';
      final String creatorMunicipality =
          businessData['municipality'] ?? 'Unknown';
      final String adminType =
          _creatorData?['admin_type'] ?? 'Municipal Administrator';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Created By:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Role: $creatorRole',
            style: TextStyle(
              color: AppColors.primaryTeal,
              fontStyle: FontStyle.italic,
              fontSize: 15,
            ),
          ),
          if (creatorRole.toLowerCase() == 'administrator' &&
              adminType.isNotEmpty)
            Text(
              'Admin Type: $adminType',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
            ),
          Text('Name: $creatorName'),
          Text('Email: $creatorEmail'),
          Text('Contact: $creatorContact'),
          Text('Municipality: $creatorMunicipality'),
          const SizedBox(height: 8),
        ],
      );
    }

    if (normalizedRole == 'administrator' &&
        adminType.toLowerCase() == 'provincial administrator') {
      final String creatorRole = _creatorData?['role'] ?? 'Unknown';
      final String creatorName = _creatorData?['name'] ?? 'Unknown';
      final String creatorEmail = _creatorData?['email'] ?? 'Unknown';
      final String creatorContact = businessData['contact_info'] ?? 'Unknown';
      final String creatorMunicipality =
          businessData['municipality'] ?? 'Unknown';
      final String adminType =
          _creatorData?['admin_type'] ??
          businessData['admin_type'] ??
          'Provincial Administrator';

      // The Column is now the single widget being returned, containing everything inside.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Creator Details Section ---
          const Text(
            'Created By:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Role: $creatorRole',
            style: TextStyle(
              color: AppColors.primaryTeal,
              fontStyle: FontStyle.italic,
              fontSize: 15,
            ),
          ),

          if (creatorRole.toLowerCase() == 'administrator' &&
              adminType.isNotEmpty)
            Text(
              'Admin Type: $adminType',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
            ),
          Text('Name: $creatorName'),
          Text('Email: $creatorEmail'),
          Text('Contact: $creatorContact'),
          Text('Municipality: $creatorMunicipality'),
          const SizedBox(
            height: 16,
          ), // Added more space for better UI separation
          // --- Action Buttons Section (Moved Inside the Column) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Add your edit logic here
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8), // Added space between buttons
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmArchive(context),
                  icon: const Icon(Icons.archive, color: Colors.red, size: 18),
                  label: const Text(
                    'Archive',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ], // End of Column's children
      ); // End of return statement
    }

    return const SizedBox();
  }

  Widget _buildReviewSummary(BuildContext context) {
    final double averageRating =
        businessData['average_rating']?.toDouble() ?? 0.0;
    final int reviewCount = businessData['review_count'] ?? 0;
    final String formattedCount =
        reviewCount >= 1000
            ? '${(reviewCount / 1000).toStringAsFixed(1)}K'
            : reviewCount.toString();

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ReviewScreen(
                  businessId:
                      businessData['hotspot_id'] ??
                      businessData['id']?.toString() ??
                      '',
                  businessName:
                      businessData['business_name'] ?? 'Unknown Business',
                ),
          ),
        );

        // Refresh business data when returning from review screen
        if (result == true) {
          _refreshBusinessData();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Text(
                      formattedCount,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Reviews'),
                  ],
                ),
              ],
            ),
            if (currentUserId != null && role.toLowerCase() == 'tourist')
              FutureBuilder<bool>(
                future: ReviewService.hasUserReviewed(
                  businessData['hotspot_id'] ??
                      businessData['id']?.toString() ??
                      '',
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'You have reviewed this place',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryTeal),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _iconInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _amenitiesChips() {
    final List<Widget> chips = [];
    bool restroom = businessData['restroom'] == true;
    String food = (businessData['food_access'] ?? '').toString();
    String water = (businessData['water_access'] ?? '').toString();
    String guide = (businessData['local_guide'] ?? '').toString();

    if (restroom) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.wc, size: 18),
          label: const Text('Restroom'),
        ),
      );
    }
    if (food.isNotEmpty) {
      chips.add(
        Chip(avatar: const Icon(Icons.restaurant, size: 18), label: Text(food)),
      );
    }
    if (water.isNotEmpty) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.water_drop, size: 18),
          label: Text(water),
        ),
      );
    }
    if (guide.isNotEmpty) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.badge, size: 18),
          label: Text('Guide: $guide'),
        ),
      );
    }
    return chips;
  }

  Widget _quickFacts() {
    final String distance =
        (businessData['distance_from_highway'] ?? '').toString();

    // Compute status dynamically from data and operating hours
    final String status = _computeStatus();

    final String category =
        (businessData['category'] ?? businessData['type'] ?? '').toString();
    final String municipality = (businessData['municipality'] ?? '').toString();
    final String contact = (businessData['contact_info'] ?? '').toString();

    final List<Widget> rows = [];
    if (category.isNotEmpty) {
      rows.add(
        _iconInfoRow(icon: Icons.category, label: 'Category', value: category),
      );
    }
    if (municipality.isNotEmpty) {
      rows.add(
        _iconInfoRow(
          icon: Icons.location_city,
          label: 'Municipality',
          value: municipality,
        ),
      );
    }
    if (distance.isNotEmpty) {
      rows.add(
        _iconInfoRow(
          icon: Icons.signpost,
          label: 'From Highway',
          value: distance,
        ),
      );
    }
    if (contact.isNotEmpty) {
      rows.add(
        GestureDetector(
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: contact));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Contact copied')));
            }
          },
          child: _iconInfoRow(
            icon: Icons.phone,
            label: 'Contact',
            value: contact,
          ),
        ),
      );
    }
    rows.add(_statusChip(status));

    return Column(children: rows);
  }

  String _computeStatus() {
    // Explicit status if provided
    final dynamic rawStatus = businessData['status'];
    if (rawStatus is String && rawStatus.trim().isNotEmpty) {
      return rawStatus;
    }

    // Archived → permanently close
    if (businessData['archived'] == true) {
      return 'permanently close';
    }

    final Map<String, dynamic> hours =
        Map<String, dynamic>.from(businessData['operating_hours'] ?? {});
    if (hours.isEmpty) return 'Unknown';

    final String key = _weekdayKey(DateTime.now().weekday);
    final dynamic today = hours[key];
    if (today == null) return 'Unknown';

    if (today is String) {
      final t = today.toLowerCase();
      if (t.contains('close')) return 'temporary close';
      return today;
    }

    if (today is Map) {
      final String openStr = (today['open'] ?? '').toString();
      final String closeStr = (today['close'] ?? '').toString();
      if (openStr.isEmpty || closeStr.isEmpty) return 'Unknown';

      final DateTime? openTime = _parseTimeToday(openStr);
      final DateTime? closeTime = _parseTimeToday(closeStr);
      if (openTime == null || closeTime == null) return 'Unknown';

      final now = DateTime.now();
      if (now.isAfter(openTime) && now.isBefore(closeTime)) return 'open';
      return 'temporary close';
    }

    return 'Unknown';
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  DateTime? _parseTimeToday(String input) {
    try {
      final now = DateTime.now();
      final String trimmed = input.trim();

      // 24-hour format HH:mm or H:mm
      final RegExp r24 = RegExp(r'^(\d{1,2}):(\d{2})$');
      final Match? m24 = r24.firstMatch(trimmed);
      if (m24 != null) {
        final int h = int.parse(m24.group(1)!);
        final int min = int.parse(m24.group(2)!);
        if (h >= 0 && h < 24 && min >= 0 && min < 60) {
          return DateTime(now.year, now.month, now.day, h, min);
        }
      }

      // 12-hour format hh:mm AM/PM
      final RegExp r12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$');
      final Match? m12 = r12.firstMatch(trimmed);
      if (m12 != null) {
        int h = int.parse(m12.group(1)!);
        final int min = int.parse(m12.group(2)!);
        final String mer = m12.group(3)!.toLowerCase();
        if (mer == 'am') {
          if (h == 12) h = 0; // 12:xx AM -> 00:xx
        } else {
          if (h != 12) h += 12; // 1-11 PM -> 13-23
        }
        if (h >= 0 && h < 24 && min >= 0 && min < 60) {
          return DateTime(now.year, now.month, now.day, h, min);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _getSuggestedItemsText() {
    final dynamic raw =
        businessData['suggested_items'] ?? businessData['suggestions'];
    if (raw == null) return '';
    if (raw is List) {
      final items =
          raw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
      return items.isNotEmpty ? items.join(', ') : '';
    }
    final text = raw.toString().trim();
    if (text == '[]') return '';
    return text;
  }

  Widget _statusChip(String status) {
    return Row(
      children: [
        const Text(
          'Spot Status: ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Chip(
          label: Text(status, style: const TextStyle(color: Colors.white)),
          backgroundColor:
              status.toLowerCase() == 'open'
                  ? Colors.green
                  : status.toLowerCase() == 'temporary close'
                  ? Colors.grey
                  : status.toLowerCase() == 'permanently close'
                  ? AppColors.errorRed
                  : Colors.grey,
        ),
      ],
    );
  }

  String _formatOperatingHours(dynamic value) {
    // If the value is a Map, format it
    if (value is Map) {
      final from = value['open'] ?? '';
      final to = value['close'] ?? '';
      // Return a string with markers for coloring in the widget
      return '$from | $to';
    }
    // If it's already a String or something else, return it as is
    return value.toString();
  }

  Widget _buildImageGallery() {
    final List<String> images = _getImages();

    if (images.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Icon(Icons.photo, size: 50)),
      );
    }

    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              // The return statement must be a complete, self-contained widget.
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(images[index], images),
                    child: Hero(
                      tag: 'image_$index',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: _currentImageIndex == index ? 1.0 : 0.7,
                        // Simplified: No need for the ternary check here
                        child: CachedImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholderBuilder:
                              (context) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey[600],
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ); // <-- FIX: The AnimatedContainer is now properly closed with a parenthesis.
            }, // <-- FIX: The brace now correctly closes the itemBuilder function body.
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final bool active = i == _currentImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 10 : 8,
                    height: active ? 10 : 8,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primaryTeal : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String currentImage, List<String> allImages) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageView(
              currentImage: currentImage,
              allImages: allImages,
              initialIndex: allImages.indexOf(currentImage),
            ),
      ),
    );
  }

  Widget _buildNearbyPlaces() {
    if (_isLoadingNearby) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbyPlaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.near_me, 'Nearby Places'),
        SizedBox(height: _chipSpacing),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _nearbyPlaces.length,
            itemBuilder: (context, index) {
              final place = _nearbyPlaces[index];
              final distance = place['distance'] as double;
              final name =
                  place['business_name'] ?? place['name'] ?? 'Destination Name';
              final images = place['images'] ?? [];
              final imageUrl =
                  images.isNotEmpty ? images.first.toString() : null;

              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // Show the nearby place details
                    BusinessDetailsModal.show(
                      context: context,
                      businessData: place,
                      role: role,
                      currentUserId: currentUserId,
                      onNavigate: widget.onNavigate,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child:
                              imageUrl != null
                                  ? NetworkImageWithTimeout(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image,
                                        size: 30,
                                      ),
                                    ),
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 30),
                                  ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${distance.toStringAsFixed(1)} km away',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    );
  }

  List<Widget> _buildOperatingHoursList(Map<String, dynamic> hours) {
    if (hours.isEmpty) {
      return const [Text('No operating hours provided.')];
    }
    final entries =
        hours.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  // --- THIS IS THE LINE THAT WAS FIXED ---
                  // BEFORE: child: Text(e.value.toString()),
                  // AFTER:
                  child: Text(_formatOperatingHours(e.value)),
                  // --- END OF FIX ---
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildEntranceFeeList(Map<String, dynamic> fees) {
    if (fees.isEmpty) {
      return const [Text('No entrance fee information.')];
    }
    final entries =
        fees.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '₱${(e.value is num ? (e.value as num).toStringAsFixed(2) : e.value.toString())}',
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  // Removed unused _infoRow in favor of icon-based rows

  Future<String> _getReviewButtonText() async {
    final businessId =
        businessData['hotspot_id'] ?? businessData['id']?.toString() ?? '';
    if (businessId.isEmpty) return 'Write a Review';

    final hasReviewed = await ReviewService.hasUserReviewed(businessId);
    return hasReviewed ? 'Edit Review' : 'Write a Review';
  }

  void _showReviewForm(BuildContext context) async {
    final businessId =
        businessData['hotspot_id'] ?? businessData['id']?.toString() ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify business. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user has already reviewed this business
    final hasReviewed = await ReviewService.hasUserReviewed(businessId);
    Review? existingReview;

    if (hasReviewed) {
      existingReview = await ReviewService.getUserReview(businessId);
    }

    if (mounted) {
      final result = await ReviewFormModal.show(
        context: context,
        businessId: businessId,
        businessName: businessData['business_name'] ?? 'Unknown Business',
        existingReview: existingReview,
        onReviewSubmitted: () {
          // Refresh the business data to show updated ratings
          _refreshBusinessData();
        },
      );

      // If review was submitted, refresh the data
      if (result == true) {
        _refreshBusinessData();
      }
    }
  }

  Future<void> _refreshBusinessData() async {
    try {
      final businessId =
          businessData['hotspot_id'] ?? businessData['id']?.toString() ?? '';
      if (businessId.isNotEmpty) {
        final ratingSummary = await ReviewService.getBusinessRatingSummary(
          businessId,
        );
        setState(() {
          businessData['average_rating'] = ratingSummary['average_rating'];
          businessData['review_count'] = ratingSummary['review_count'];
        });
        // Also refresh review button text by triggering FutureBuilder rebuild
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error refreshing business data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DraggableScrollableSheet(
          initialChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  _buildImageGallery(),
                  SizedBox(height: _sectionSpacing),
                  Text(
                    businessData['business_name'] ?? 'Unknown Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${businessData['address']}, ${businessData['municipality']}, Bukidnon',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: _chipSpacing),
                  _quickFacts(),
                  SizedBox(height: _sectionSpacing),
                  _sectionHeader(Icons.info_outline, 'Overview'),
                  SizedBox(height: _chipSpacing),
                  Text(
                    businessData['description'] ?? 'No description.',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  SizedBox(height: _sectionSpacing),
                  _sectionHeader(Icons.directions_bus, 'Getting There'),
                  SizedBox(height: _chipSpacing),
                  _iconInfoRow(
                    icon: Icons.directions,
                    label: 'Transportation Available',
                    value: (businessData['transportation'] ?? '').toString(),
                  ),
                  const Divider(height: 24),
                  _sectionHeader(Icons.schedule, 'Operating Hours'),
                  SizedBox(height: _chipSpacing),
                  ..._buildOperatingHoursList(
                    Map<String, dynamic>.from(
                      businessData['operating_hours'] ?? {},
                    ),
                  ),
                  const Divider(height: 24),
                  _sectionHeader(Icons.payments, 'Entrance Fees'),
                  SizedBox(height: _chipSpacing),
                  ..._buildEntranceFeeList(
                    Map<String, dynamic>.from(
                      businessData['entrance_fees'] ?? {},
                    ),
                  ),
                  const Divider(height: 24),
                  _sectionHeader(Icons.checklist_rtl, 'Amenities & Tips'),
                  SizedBox(height: _chipSpacing),
                  if (_amenitiesChips().isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _amenitiesChips(),
                    ),
                  if (_getSuggestedItemsText().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _iconInfoRow(
                        icon: Icons.backpack,
                        label: 'Suggested to Bring',
                        value: _getSuggestedItemsText(),
                      ),
                    ),
                  const Divider(height: 24),
                  _buildNearbyPlaces(),
                  if (widget.showInteractions) ...[
                    const Divider(height: 24),
                    _buildReviewSummary(context),
                    const Divider(height: 24),
                    _buildRoleBasedButtons(context),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class FullScreenImageView extends StatefulWidget {
  final String currentImage;
  final List<String> allImages;
  final int initialIndex;

  const FullScreenImageView({
    super.key,
    required this.currentImage,
    required this.allImages,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.allImages.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.allImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Hero(
                tag: 'image_$index',
                child: NetworkImageWithTimeout(
                  imageUrl: widget.allImages[index],
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.error, size: 100, color: Colors.red),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
