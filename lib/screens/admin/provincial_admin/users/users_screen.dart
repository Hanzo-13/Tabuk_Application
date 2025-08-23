import 'package:capstone_app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProvUsersScreen extends StatefulWidget {
  const ProvUsersScreen({super.key});

  @override
  State<ProvUsersScreen> createState() => _ProvUsersScreenState();
}

class _ProvUsersScreenState extends State<ProvUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Firestore Streams with search functionality
  Stream<QuerySnapshot> _touristsStream() {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'Tourist')
        .snapshots();
  }

  Stream<QuerySnapshot> _businessOwnersStream() {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'BusinessOwner')
        .snapshots();
  }

  Stream<QuerySnapshot> _municipalAdminsStream() {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'Administrator')
        .where('admin_type', isEqualTo: 'Municipal Administrator')
        .snapshots();
  }

  Stream<QuerySnapshot> _provincialAdminsStream() {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'Administrator')
        .where('admin_type', isEqualTo: 'Provincial Administrator')
        .snapshots();
  }

  /// Filter users based on search query
  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((doc) {
      final user = doc.data() as Map<String, dynamic>;
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final location = (user['location'] ?? '').toString().toLowerCase();
      
      return name.contains(_searchQuery.toLowerCase()) ||
             email.contains(_searchQuery.toLowerCase()) ||
             location.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  /// Get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get role icon
  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'Tourist':
        return Icons.explore;
      case 'BusinessOwner':
        return Icons.business;
      case 'Administrator':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  /// Enhanced User Card Widget
  Widget _buildUserCard(Map<String, dynamic> user, bool isCurrentUser, String docId) {
    final status = user['status'] ?? 'Unknown';
    final role = user['role'] ?? 'Unknown';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrentUser 
              ? BorderSide(color: AppColors.primaryTeal, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showUserDetails(user, isCurrentUser, docId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getRoleIcon(role),
                        color: AppColors.primaryTeal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTeal,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user['email'] ?? 'No Email',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        user['location'] ?? 'No Location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Enhanced User List Widget
  Widget _buildUserList(Stream<QuerySnapshot> stream) {
    return Column(
      children: [
        // Search Bar
        Container(
          margin: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by name, email, or location...',
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
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // User List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Error fetching users",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No users found",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final allUsers = snapshot.data!.docs;
              final filteredUsers = _filterUsers(allUsers);

              if (filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No users found for \"$_searchQuery\"",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final userDoc = filteredUsers[index];
                  final user = userDoc.data() as Map<String, dynamic>;
                  final isCurrentUser = userDoc.id == currentUserId;

                  return _buildUserCard(user, isCurrentUser, userDoc.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Enhanced User Details Dialog
  void _showUserDetails(Map<String, dynamic> user, bool isCurrentUser, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getRoleIcon(user['role']),
                        color: AppColors.primaryTeal,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] ?? 'User Details',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Current User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.email, "Email", user['email']),
                      _buildDetailRow(Icons.phone, "Contact", user['contact']),
                      _buildDetailRow(Icons.location_on, "Location", user['location']),
                      _buildDetailRow(Icons.person, "Role", user['role']),
                      _buildDetailRow(Icons.circle, "Status", user['status'],
                          statusColor: _getStatusColor(user['status'])),
                      _buildDetailRow(Icons.verified_user, "Admin Status", user['admin_status']),
                      if (user['admin_type'] != null)
                        _buildDetailRow(Icons.admin_panel_settings, "Admin Type", user['admin_type']),
                      if (user['department'] != null)
                        _buildDetailRow(Icons.business, "Department", user['department']),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Close"),
                      ),
                    ),
                    if (!isCurrentUser) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showUserActions(user, docId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Actions"),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Enhanced Detail Row Widget
  Widget _buildDetailRow(IconData icon, String label, dynamic value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (statusColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value?.toString() ?? "N/A",
                    style: TextStyle(
                      color: statusColor ?? Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// User Actions Dialog
  void _showUserActions(Map<String, dynamic> user, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Actions for ${user['name']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit User"),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement edit functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Edit functionality coming soon!")),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  user['status'] == 'Active' ? Icons.block : Icons.check_circle,
                  color: user['status'] == 'Active' ? Colors.red : Colors.green,
                ),
                title: Text(user['status'] == 'Active' ? "Suspend User" : "Activate User"),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement status toggle
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Status toggle coming soon!")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message, color: Colors.blue),
                title: const Text("Send Message"),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement messaging
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Messaging feature coming soon!")),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        title: const Text(
          "User Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryTeal,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              indicatorColor: AppColors.primaryTeal,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.explore, size: 20),
                  text: "Tourists",
                ),
                Tab(
                  icon: Icon(Icons.business, size: 20),
                  text: "Business Owners",
                ),
                Tab(
                  icon: Icon(Icons.location_city, size: 20),
                  text: "Municipal Admin",
                ),
                Tab(
                  icon: Icon(Icons.account_balance, size: 20),
                  text: "Provincial Admin",
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_touristsStream()),
          _buildUserList(_businessOwnersStream()),
          _buildUserList(_municipalAdminsStream()),
          _buildUserList(_provincialAdminsStream()),
        ],
      ),
    );
  }
}