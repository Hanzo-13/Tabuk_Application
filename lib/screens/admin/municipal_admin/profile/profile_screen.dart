import 'package:capstone_app/screens/admin/provincial_admin/notification/notification_screen.dart';
import 'package:capstone_app/screens/admin/provincial_admin/profile/profile_edit_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/colors.dart';
import '../../../login_screen.dart';

class MuniProfileScreen extends StatefulWidget {
  const MuniProfileScreen({super.key});

  @override
  State<MuniProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<MuniProfileScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  String role = 'Municipal Administrator';
  String province = '';
  String joinDate = '';
  bool isLoading = true;
  int pendingApprovals = 0;
  int totalBusinesses = 0;
  int activeEvents = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    loadAdminData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadAdminData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('Users').doc(currentUser.uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      
      // Load admin stats (you might want to fetch these from different collections)
      await _loadAdminStats();
      
      setState(() {
        name = data['name'] ?? 'Admin User';
        email = data['email'] ?? currentUser.email ?? '';
        province = data['province'] ?? 'Not Set';
        joinDate = data['created_at'] != null
          ? _formatDate((data['created_at'] as Timestamp).toDate())
          : 'Unknown';
        isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadAdminStats() async {
    // Mock data - replace with actual Firestore queries
    setState(() {
      pendingApprovals = 5;
      totalBusinesses = 127;
      activeEvents = 8;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {double? height}) {
    return Container(

      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primaryTeal).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primaryTeal, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          "Admin Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProvNotificationScreen(
                        notifications: const [],
                        onNotificationTap: (Map<String, dynamic> notification) {},
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_outlined, size: 26),
              ),
              if (pendingApprovals > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingApprovals > 99 ? '99+' : '$pendingApprovals',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeInAnimation,
              child: RefreshIndicator(
                onRefresh: loadAdminData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Header Section with Gradient
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryTeal, AppColors.primaryTeal.withOpacity(0.8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Profile Avatar
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const EditAdminProfileScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTeal,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              province,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // Stats Section
                        Container(
                        height: 120,
                        margin: const EdgeInsets.all(16),
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1, // Adjust this for child height/width ratio
                          children: [
                          _buildStatCard(
                            'Pending\nApprovals',
                            '$pendingApprovals',
                            Icons.pending_actions,
                            Colors.orange,
                            height: 100, // Set desired height for each card
                          ),
                          _buildStatCard(
                            'Total\nBusinesses',
                            '$totalBusinesses',
                            Icons.business,
                            Colors.blue,
                            height: 100,
                          ),
                          _buildStatCard(
                            'Active\nEvents',
                            '$activeEvents',
                            Icons.event,
                            Colors.green,
                            height: 100,
                          ),
                          ],
                        ),
                        ),

                      // Admin Actions Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionTile(
                              icon: Icons.business,
                              title: 'View Business Information',
                              subtitle: 'Manage registered businesses',
                              onTap: () {
                                // Navigate to business management
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.approval,
                              title: 'Approval Requests',
                              subtitle: '$pendingApprovals pending requests',
                              onTap: () {
                                // Navigate to approval requests
                              },
                              trailing: pendingApprovals > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$pendingApprovals',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right, color: Colors.grey),
                            ),
                            _buildActionTile(
                              icon: Icons.event,
                              title: 'Event Calendar',
                              subtitle: 'Manage provincial events',
                              onTap: () {
                                // Navigate to event calendar
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.analytics,
                              title: 'Analytics & Reports',
                              subtitle: 'View performance metrics',
                              onTap: () {
                                // Navigate to analytics
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Account Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionTile(
                              icon: Icons.person,
                              title: 'Edit Profile Information',
                              subtitle: 'Update your personal details',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditAdminProfileScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.security,
                              title: 'Security Settings',
                              subtitle: 'Change password & security',
                              onTap: () {
                                // Navigate to security settings
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Support Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionTile(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              subtitle: 'Get help with the app',
                              onTap: () {
                                // Navigate to help
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.mail_outline,
                              title: 'Contact Us',
                              subtitle: 'Reach out to our team',
                              onTap: () {
                                // Navigate to contact
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.shield_outlined,
                              title: 'Privacy Policy',
                              subtitle: 'Read our privacy terms',
                              onTap: () {
                                // Navigate to privacy policy
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.logout,
                              title: 'Log Out',
                              subtitle: 'Sign out of your account',
                              iconColor: Colors.red,
                              onTap: _showLogoutDialog,
                              trailing: const Icon(Icons.chevron_right, color: Colors.red),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              'Member since: $joinDate',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}