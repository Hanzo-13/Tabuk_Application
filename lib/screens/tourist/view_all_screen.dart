import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/destination_model.dart';
import '../../widgets/business_details_modal.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/common_search_bar.dart';

class ViewAllScreen extends StatefulWidget {
  final String title;
  final List<Hotspot> hotspots;
  final Color accentColor;
  final String categoryKey;

  const ViewAllScreen({
    super.key,
    required this.title,
    required this.hotspots,
    required this.accentColor,
    required this.categoryKey,
  });

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  List<Hotspot> _filteredHotspots = [];
  String _searchQuery = '';
  String _selectedSortBy = 'name';
  final String _selectedFilter = 'all';
  String _role = 'Guest';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _filteredHotspots = List.from(widget.hotspots);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _currentUserId = user.uid;
      final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _role = (data['role']?.toString().trim().isNotEmpty ?? false) ? data['role'].toString() : 'Tourist';
        });
      }
    } catch (_) {
      // keep defaults
    }
  }

  void _filterAndSortHotspots() {
    List<Hotspot> filtered = List.from(widget.hotspots);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((hotspot) {
        return hotspot.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            hotspot.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            hotspot.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply category filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((hotspot) {
        return hotspot.category == _selectedFilter;
      }).toList();
    }

    // Apply sorting
    switch (_selectedSortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    setState(() {
      _filteredHotspots = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _filteredHotspots.isEmpty
                ? _buildEmptyState()
                : _buildHotspotsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return UniversalSearchBar(
      onChanged: (value) {
        _searchQuery = value;
        _filterAndSortHotspots();
      },
      onClear: () {
        _searchQuery = '';
        _filterAndSortHotspots();
      },
      onFilterTap: _showFilterDialog,
    );
  }

  Widget _buildHotspotsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredHotspots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildHotspotCard(_filteredHotspots[index]),
    );
  }

  Widget _buildHotspotCard(Hotspot hotspot) {
    return GestureDetector(
      onTap: () => _showHotspotDetails(hotspot),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: hotspot.images.isNotEmpty
                  ? CachedImage(
                      imageUrl: hotspot.images.first,
                      width: 110,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: _buildPlaceholder(),
                      errorWidget: _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotspot.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, color: widget.accentColor, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotspot.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hotspot.municipality.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hotspot.municipality,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No destinations found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String tempSortBy = _selectedSortBy;
        return StatefulBuilder(
          builder: (context, modalSetState) {
            Widget buildTempChip(String value, String label) {
              final bool selected = tempSortBy == value;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  modalSetState(() => tempSortBy = value);
                },
                selectedColor: widget.accentColor,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                shape: StadiumBorder(
                  side: BorderSide(color: selected ? widget.accentColor : Colors.grey.shade300),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sort results',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildTempChip('name', 'Name (A-Z)'),
                        buildTempChip('newest', 'Newest'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedSortBy = tempSortBy;
                          });
                          _filterAndSortHotspots();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHotspotDetails(Hotspot hotspot) {
    final businessData = _mapHotspotToBusinessData(hotspot);
    BusinessDetailsModal.show(
      context: context,
      businessData: businessData,
      role: _role,
      currentUserId: _currentUserId,
      onNavigate: null,
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
