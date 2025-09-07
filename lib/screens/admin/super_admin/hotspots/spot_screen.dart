// ignore_for_file: unnecessary_underscores, use_build_context_synchronously

import 'package:capstone_app/screens/admin/provincial_admin/hotspots/spot_registration_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/widgets/business_details_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SuperSpotsScreen extends StatefulWidget {
  const SuperSpotsScreen({super.key});

  @override
  State<SuperSpotsScreen> createState() => _SuperSpotsScreenState();
}

class _SuperSpotsScreenState extends State<SuperSpotsScreen> with TickerProviderStateMixin {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  String? adminRole;
  String? municipality;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _selectedProvince = 'All';
  String _viewMode = 'cards'; // 'cards' or 'table'
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // Enhanced categories for better organization
  final List<String> _categories = [
    'All',
    'Natural Attractions',
    'Recreational Facilities',
    'Cultural & Historical',
    'Agri-Tourism & Industrial',
    'Culinary & Shopping',
    'Events & Education',
  ];

  final List<String> _statusOptions = [
    'All',
    'Active',
    'Pending',
    'Inactive',
    'Suspended',
    'Under Review',
  ];

  final List<String> _provinces = [
    'All',
    'Agusan del Norte',
    'Agusan del Sur',
    'Dinagat Islands',
    'Surigao del Norte',
    'Surigao del Sur',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAdminInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          adminRole = data['role'];
          municipality = data['municipality'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot> _getDestinationStream() {
    final collection = FirebaseFirestore.instance.collection('destination');
    return collection.snapshots();
  }

  /// Enhanced filtering with province support
  List<QueryDocumentSnapshot> _filterDestinations(List<QueryDocumentSnapshot> destinations) {
    return destinations.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['business_name'] ?? '').toString().toLowerCase();
      final category = data['category'] ?? 'Other';
      final status = data['status'] ?? 'Pending';
      final description = (data['description'] ?? '').toString().toLowerCase();
      final location = (data['location'] ?? '').toString().toLowerCase();
      final province = (data['province'] ?? '').toString();

      // Search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          description.contains(_searchQuery.toLowerCase()) ||
          location.contains(_searchQuery.toLowerCase());

      // Category filter
      bool matchesCategory = _selectedCategory == 'All' || category == _selectedCategory;

      // Status filter
      bool matchesStatus = _selectedStatus == 'All' || status == _selectedStatus;

      // Province filter
      bool matchesProvince = _selectedProvince == 'All' || province == _selectedProvince;

      return matchesSearch && matchesCategory && matchesStatus && matchesProvince;
    }).toList();
  }

  /// Get statistics for dashboard
  Map<String, int> _getStatistics(List<QueryDocumentSnapshot> destinations) {
    final stats = <String, int>{
      'total': destinations.length,
      'active': 0,
      'pending': 0,
      'inactive': 0,
      'suspended': 0,
    };

    for (final doc in destinations) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      if (stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }
    }

    return stats;
  }

  /// Build statistics cards
  Widget _buildStatisticsCards(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard('Total Destinations', stats['total']!, Icons.place, Colors.blue),
                _buildStatCard('Active', stats['active']!, Icons.check_circle, Colors.green),
                _buildStatCard('Pending', stats['pending']!, Icons.access_time, Colors.orange),
                _buildStatCard('Inactive', stats['inactive']!, Icons.pause_circle, Colors.grey),
                _buildStatCard('Suspended', stats['suspended']!, Icons.block, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enhanced destination card with more admin features
  Widget _buildDestinationCard(Map<String, dynamic> data, String docId) {
    final images = data['images'] as List<dynamic>?;
    final name = data['business_name'] ?? 'Unnamed Destination';
    final category = data['category'] ?? 'Other';
    final status = data['status'] ?? 'Pending';
    final location = data['location'] ?? 'No location';
    final province = data['province'] ?? 'Unknown Province';
    final rating = data['rating'] ?? 0.0;
    final submittedBy = data['submitted_by'] ?? 'Unknown';
    final submittedDate = data['created_at'] != null 
        ? (data['created_at'] as Timestamp).toDate() 
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with admin controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$location, $province',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image section
            if (images != null && images.isNotEmpty)
              Container(
                height: 160,
                width: double.infinity,
                child: ClipRRect(
                  child: Image.network(
                    images[0],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and rating
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (rating > 0) ...[
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  if (data['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      data['description'],
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Submission info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'By: $submittedBy',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${submittedDate.day}/${submittedDate.month}/${submittedDate.year}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showBulkActions([docId]),
                          icon: const Icon(Icons.admin_panel_settings, size: 16),
                          label: const Text('Manage', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BusinessDetailsModal(
                                businessData: data,
                                role: 'Administrator',
                                currentUserId: uid,
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Details', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enhanced table view for better data management
  Widget _buildTableView(List<QueryDocumentSnapshot> destinations) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Submitted By', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: destinations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final submittedDate = data['created_at'] != null 
                ? (data['created_at'] as Timestamp).toDate() 
                : DateTime.now();
            
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      data['business_name'] ?? 'Unnamed',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                DataCell(Text(data['category'] ?? 'Other')),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      data['location'] ?? 'No location',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(data['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (data['status'] ?? 'Pending').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(data['submitted_by'] ?? 'Unknown')),
                DataCell(Text('${submittedDate.day}/${submittedDate.month}/${submittedDate.year}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => BusinessDetailsModal(
                              businessData: data,
                              role: 'Administrator',
                              currentUserId: uid,
                            ),
                          );
                        },
                        tooltip: 'View Details',
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onPressed: () => _showBulkActions([doc.id]),
                        tooltip: 'More Actions',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Enhanced bulk actions for super admin
  void _showBulkActions(List<String> docIds) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Admin Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Approve'),
                subtitle: const Text('Set status to Active'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkUpdateStatus(docIds, 'Active');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pause_circle, color: Colors.orange),
                title: const Text('Set Pending Review'),
                subtitle: const Text('Requires further review'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkUpdateStatus(docIds, 'Under Review');
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.grey),
                title: const Text('Deactivate'),
                subtitle: const Text('Temporarily hide from public'),
                onTap: () {
                  Navigator.pop(context);
                  _bulkUpdateStatus(docIds, 'Inactive');
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Suspend'),
                subtitle: const Text('Suspend for violations'),
                onTap: () {
                  Navigator.pop(context);
                  _showSuspensionDialog(docIds);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Permanently'),
                subtitle: const Text('This action cannot be undone'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBulkDelete(docIds);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show suspension reason dialog
  void _showSuspensionDialog(List<String> docIds) {
    String reason = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Suspend Destination(s)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for suspension:'),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => reason = value,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter suspension reason...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: reason.isNotEmpty ? () {
                Navigator.pop(context);
                _bulkUpdateStatus(docIds, 'Suspended', reason);
              } : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Suspend', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Bulk update status
  Future<void> _bulkUpdateStatus(List<String> docIds, String newStatus, [String? reason]) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final docId in docIds) {
        final docRef = FirebaseFirestore.instance.collection('destination').doc(docId);
        final updateData = {
          'status': newStatus,
          'last_updated': FieldValue.serverTimestamp(),
          'updated_by': uid,
        };
        
        if (reason != null) {
          updateData['suspension_reason'] = reason;
        }
        
        batch.update(docRef, updateData);
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${docIds.length} destination(s) updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update destinations'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Confirm bulk delete
  void _confirmBulkDelete(List<String> docIds) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Bulk Delete'),
          content: Text(
            'Are you sure you want to permanently delete ${docIds.length} destination(s)? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _bulkDelete(docIds);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Bulk delete destinations
  Future<void> _bulkDelete(List<String> docIds) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final docId in docIds) {
        final docRef = FirebaseFirestore.instance.collection('destination').doc(docId);
        batch.delete(docRef);
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${docIds.length} destination(s) deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete destinations'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.red;
      case 'under review':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Build advanced filter section
  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, style: const TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? 'All';
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'All';
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Province', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedProvince,
                      items: _provinces.map((province) {
                        return DropdownMenuItem(
                          value: province,
                          child: Text(province, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProvince = value ?? 'All';
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'User not logged in',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        title: const Text(
          'Destinations Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // View mode toggle
          IconButton(
            icon: Icon(_viewMode == 'cards' ? Icons.table_chart : Icons.grid_view),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'cards' ? 'table' : 'cards';
              });
            },
            tooltip: 'Toggle View Mode',
          ),
          // Export options
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export $value functionality coming soon!')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_view, size: 18),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getDestinationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No destinations available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Destinations will appear here once submitted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final allDestinations = snapshot.data!.docs;
          final filteredDestinations = _filterDestinations(allDestinations);
          final stats = _getStatistics(allDestinations);

          return Column(
            children: [
              // Statistics Dashboard
              _buildStatisticsCards(stats),

              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search destinations, locations, or categories...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryTeal),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Advanced Filters
              _buildAdvancedFilters(),

              // Active Filters Display
              if (_selectedCategory != 'All' || _selectedStatus != 'All' || _selectedProvince != 'All')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Filters: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      if (_selectedCategory != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_selectedCategory, style: const TextStyle(fontSize: 12)),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = 'All';
                              });
                            },
                            backgroundColor: AppColors.primaryTeal.withOpacity(0.1),
                            deleteIconColor: AppColors.primaryTeal,
                          ),
                        ),
                      if (_selectedStatus != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_selectedStatus, style: const TextStyle(fontSize: 12)),
                            onDeleted: () {
                              setState(() {
                                _selectedStatus = 'All';
                              });
                            },
                            backgroundColor: _getStatusColor(_selectedStatus).withOpacity(0.1),
                            deleteIconColor: _getStatusColor(_selectedStatus),
                          ),
                        ),
                      if (_selectedProvince != 'All')
                        Chip(
                          label: Text(_selectedProvince, style: const TextStyle(fontSize: 12)),
                          onDeleted: () {
                            setState(() {
                              _selectedProvince = 'All';
                            });
                          },
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          deleteIconColor: Colors.blue,
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = 'All';
                            _selectedStatus = 'All';
                            _selectedProvince = 'All';
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),

              // Results count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Showing ${filteredDestinations.length} of ${allDestinations.length} destinations',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (filteredDestinations.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () => _showBulkActions(
                          filteredDestinations.map((doc) => doc.id).toList(),
                        ),
                        icon: const Icon(Icons.admin_panel_settings, size: 16),
                        label: const Text('Bulk Actions'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content based on view mode
              Expanded(
                child: filteredDestinations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No destinations found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filters',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _viewMode == 'cards'
                        ? ListView.builder(
                            itemCount: filteredDestinations.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDestinations[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildDestinationCard(data, doc.id);
                            },
                          )
                        : _buildTableView(filteredDestinations),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminBusinessRegistrationScreen(
                adminRole: '',
                municipality: '',
              ),
            ),
          );
        },
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Destination'),
      ),
    );
  }
}