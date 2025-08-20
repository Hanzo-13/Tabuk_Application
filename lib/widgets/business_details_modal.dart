// ignore_for_file: non_constant_identifier_names, unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:capstone_app/screens/review_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessDetailsModal extends StatefulWidget {
  final Map<String, dynamic> businessData;
  final String role;
  final String? currentUserId;
  final Map<String, dynamic>? creatorData;

  const BusinessDetailsModal({
    super.key,
    required this.businessData,
    required this.role,
    this.currentUserId,
    this.creatorData,
  });

  static void show({
    required BuildContext context,
    required Map<String, dynamic> businessData,
    required String role,
    Map<String, dynamic>? creatorData,
    String? currentUserId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BusinessDetailsModal(
        businessData: businessData,
        role: role,
        currentUserId: currentUserId,
        creatorData: creatorData,
      ),
    );
  }

  @override
  State<BusinessDetailsModal> createState() => _BusinessDetailsModalState();
}

class _BusinessDetailsModalState extends State<BusinessDetailsModal> {
  Map<String, dynamic>? _creatorData;
  late Map<String, dynamic> businessData;
  late String? currentUserId;
  late String role;

  @override
  void initState() {
    super.initState();
    businessData = widget.businessData;
    currentUserId = widget.currentUserId;
    role = widget.role;
    _fetchCreatorData();
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
      final doc = await FirebaseFirestore.instance
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

  Widget _buildRoleBasedButtons(BuildContext context) {
    final String creatorId = businessData['owner_uid'] ?? '';
    final bool isCreator = creatorId == currentUserId;
    final String normalizedRole = role.toLowerCase();

    // ✅ Tourist
    if (normalizedRole == 'tourist') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Launch maps
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Navigate'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Add to favorites
            },
            icon: const Icon(Icons.favorite_border),
            label: const Text('Favorite'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Add to trip
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add to Trip'),
          ),
        ],
      );
    }

    if (normalizedRole == 'guest') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Register to get Navigations.',
          style: TextStyle(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // ✅ Business Owner who is the creator
    if (normalizedRole == 'business owner' && isCreator) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to Edit screen
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmArchive(context),
            icon: const Icon(Icons.archive, color: Colors.red),
            label: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    // ✅ Administrator who is the creator
    if (normalizedRole == 'administrator' && isCreator) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to Edit screen
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmArchive(context),
            icon: const Icon(Icons.archive, color: Colors.red),
            label: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    // ✅ Administrator who is NOT the creator
    if (normalizedRole == 'administrator' && !isCreator) {
      final String creatorRole = _creatorData?['role'] ?? 'Unknown';
      final String creatorName = _creatorData?['name'] ?? 'Unknown';
      final String creatorEmail = _creatorData?['email'] ?? 'Unknown';
      final String creatorContact = businessData['contact_info'] ?? 'Unknown';
      final String creatorMunicipality =
          businessData['municipality'] ?? 'Unknown';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Created By:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Role: $creatorRole', style: TextStyle(color: AppColors.primaryTeal, fontStyle: FontStyle.italic, fontSize: 15)),
          Text('Name: $creatorName'),
          Text('Email: $creatorEmail'),
          Text('Contact: $creatorContact'),
          Text('Municipality: $creatorMunicipality'),
          const SizedBox(height: 8),
        ],
      );
    }

    return const SizedBox();
  }

  // 👇 Keep all your existing widget helpers and build method here...
  // (I left out unchanged code to keep this short — but your current setup is already great)

  Future<void> _confirmArchive(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
  
  @override
  Widget build(BuildContext context) {
    role.toLowerCase();

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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  _statusChip(businessData['status'] ?? 'Close'),
                  const SizedBox(height: 8),
                  Text(
                    businessData['description'] ?? 'No description.',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${businessData['distance_from_highway']} from Main Highway',
                    style: const TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(height: 5),
                  _infoRow(
                    'Transportation Available',
                    businessData['transportation'],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Operating Hours:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._buildOperatingHoursList(
                    businessData['operating_hours'] ?? {},
                  ),
                  const Divider(height: 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Entrance Fees:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._buildEntranceFeeList(businessData['entrance_fees'] ?? {}),
                  _infoRow('Contact Info', businessData['contact_info']),
                  _infoRow('Local Guide', businessData['local_guide']),
                  _infoRow(
                    'Restroom',
                    businessData['restroom'] == true ? 'Available' : 'None',
                  ),
                  _infoRow('Food Access', businessData['food_access']),
                  _infoRow('Water Access', businessData['water_access']),
                  _infoRow(
                    'Suggested to Bring',
                    businessData['suggested_items'],
                  ),
                  const Divider(height: 24),
                  _buildReviewSummary(context),
                  const Divider(height: 24),
                  _buildRoleBasedButtons(context),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildOperatingHoursList(Map<String, dynamic> hours) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days.map((day) {
      final entry = hours[day];
      final open = entry?['open'] ?? '--';
      final close = entry?['close'] ?? '--';
      return Padding(
        padding: const EdgeInsets.only(left: 50, bottom: 4),
        child: Text(
          '$day:\n              -           open: $open    |      close: $close',
        ),
      );
    }).toList();
  }

  List<Widget> _buildEntranceFeeList(dynamic feesRaw) {
    if (feesRaw is! Map<String, dynamic> || feesRaw.isEmpty) {
      return [const Text('No fee information available.')];
    }

    return feesRaw.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '${entry.key}:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '₱${entry.value}',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildReviewSummary(BuildContext context) {
    final double averageRating =
        businessData['average_rating']?.toDouble() ?? 0.0;
    final int reviewCount = businessData['review_count'] ?? 0;

    String formattedCount =
        reviewCount >= 1000
            ? '${(reviewCount / 1000).toStringAsFixed(1)}K'
            : reviewCount.toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ReviewScreen(
                  businessId: businessData['hotspot_id'],
                  businessName: businessData['business_name'],
                ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
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
                  '$formattedCount',
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
      ),
    );
  }

  Widget _statusChip(String status) {
    return Row(
      children: [
        const Text(
          'Tourist spot Status: ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Chip(
          label: Text(status, style: const TextStyle(color: Colors.white)),
          backgroundColor:
              status.toLowerCase() == 'open' ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final images = businessData['images'] ?? [];

    if (images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.photo, size: 50)),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(images[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : 'Unknown',
            ),
          ),
        ],
      ),
    );
  }
}
