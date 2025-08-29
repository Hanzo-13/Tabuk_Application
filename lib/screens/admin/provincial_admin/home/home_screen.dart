import 'package:capstone_app/screens/admin/provincial_admin/map/map_screen.dart';
import 'package:capstone_app/screens/admin/provincial_admin/notification/notification_screen.dart';
import 'package:capstone_app/screens/admin/provincial_admin/users/users_screen.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProvHomeScreen extends StatefulWidget {
  const ProvHomeScreen({super.key});

  @override
  State<ProvHomeScreen> createState() => _ProvHomeScreenState();
}

class _ProvHomeScreenState extends State<ProvHomeScreen>
    with TickerProviderStateMixin {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  String? adminName;
  String? role;
  String? municipality;
  String? profileImage;
  bool _isLoading = true;

  // Counters
  int totalSpots = 0;
  int activeSpots = 0;
  int pendingSpots = 0;
  int totalEvents = 0;
  int upcomingEvents = 0;
  int totalUsers = 0;
  int activeTourists = 0;
  int businessOwners = 0;
  int pendingApprovals = 0;
  int admins = 0;

  // Recent activities
  List<Map<String, dynamic>> recentActivities = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadAdminData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        setState(() {
          adminName = userData['name'] ?? 'Administrator';
          role = userData['admin_type'] ?? userData['role'];
          municipality = userData['municipality'];
          profileImage = userData['profile_image'];
        });
        await Future.wait([_loadDetailedCounts(), _loadRecentActivities()]);
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    } finally {
      setState(() => _isLoading = false);
      _fadeController.forward();
      _slideController.forward();
    }
  }

  Future<void> _loadDetailedCounts() async {
    try {
      // Destinations
      final destinationsQuery = FirebaseFirestore.instance.collection(
        'destination',
      );
      final destinationsSnapshot = await destinationsQuery.get();

      totalSpots = destinationsSnapshot.docs.length;
      activeSpots =
          destinationsSnapshot.docs
              .where((doc) => (doc.data())['status'] == 'Open')
              .length;
      pendingSpots =
          destinationsSnapshot.docs
              .where((doc) => (doc.data())['status'] == 'Temporary Close' && (doc.data())['status'] == 'Permanently Close')
              .length;

      // Events
      final eventsQuery = FirebaseFirestore.instance.collection('events');
      final eventsSnapshot = await eventsQuery.get();
      final now = DateTime.now();

      totalEvents = eventsSnapshot.docs.length;
      upcomingEvents =
          eventsSnapshot.docs.where((doc) {
            final data = doc.data();
            if (data['start_date'] != null) {
              final startDate = (data['start_date'] as Timestamp).toDate();
              return startDate.isAfter(now);
            }
            return false;
          }).length;

      // Users
      final usersQuery = FirebaseFirestore.instance.collection('Users');
      final usersSnapshot = await usersQuery.get();

      totalUsers = usersSnapshot.docs.length;
      activeTourists =
          usersSnapshot.docs
              .where(
                (doc) =>
                    (doc.data())['role'] == 'Tourist' &&
                    (doc.data())['status'] == 'Active',
              )
              .length;
      businessOwners =
          usersSnapshot.docs
              .where((doc) => (doc.data())['role'] == 'BusinessOwner')
              .length;
      admins =
          usersSnapshot.docs
              .where((doc) => (doc.data())['role'] == 'Administrator' && (doc.data())['admin_type'] == 'Provincial Administrator' && (doc.data())['admin_type'] == 'Municipal Administrator')
              .length;

      // Pending approvals (spots + events with pending status)
      pendingApprovals =
          pendingSpots +
          eventsSnapshot.docs
              .where((doc) => (doc.data())['status'] == 'Pending')
              .length;

      setState(() {});
    } catch (e) {
      debugPrint('Error loading counts: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Recent destinations
      final recentSpots =
          await FirebaseFirestore.instance
              .collection('destination')
              .orderBy('created_at', descending: true)
              .limit(3)
              .get();

      for (var doc in recentSpots.docs) {
        final data = doc.data();
        activities.add({
          'type': 'destination',
          'title': 'New destination added',
          'subtitle': data['business_name'] ?? 'Unknown',
          'time':
              data['created_at'] != null
                  ? (data['created_at'] as Timestamp).toDate()
                  : DateTime.now(),
          'icon': Icons.place_outlined,
          'color': Colors.green,
        });
      }

      // Recent events
      final recentEvents =
          await FirebaseFirestore.instance
              .collection('events')
              .orderBy('created_at', descending: true)
              .limit(2)
              .get();

      for (var doc in recentEvents.docs) {
        final data = doc.data();
        activities.add({
          'type': 'event',
          'title': 'New event scheduled',
          'subtitle': data['title'] ?? 'Unknown Event',
          'time':
              data['created_at'] != null
                  ? (data['created_at'] as Timestamp).toDate()
                  : DateTime.now(),
          'icon': Icons.event_outlined,
          'color': Colors.orange,
        });
      }

      // Recent users
      final recentUsers =
          await FirebaseFirestore.instance
              .collection('Users')
              .orderBy('created_at', descending: true)
              .limit(2)
              .get();

      for (var doc in recentUsers.docs) {
        final data = doc.data();
        activities.add({
          'type': 'user',
          'title': 'New user registered',
          'subtitle':
              '${data['name'] ?? 'Unknown'} (${data['role'] ?? 'Unknown'})',
          'time':
              data['created_at'] != null
                  ? (data['created_at'] as Timestamp).toDate()
                  : DateTime.now(),
          'icon': Icons.person_add_outlined,
          'color': Colors.blue,
        });
      }

      // Sort activities by time
      activities.sort(
        (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
      );

      setState(() {
        recentActivities = activities.take(5).toList();
      });
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section
              _buildHeader(),

              // Stats Cards
              _buildStatsSection(),

              // Quick Actions
              _buildQuickActions(),

              // Recent Activities
              _buildRecentActivities(),

              // System Status
              // _buildSystemStatus(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryTeal.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Profile Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        profileImage != null
                            ? NetworkImage(profileImage!)
                            : null,
                    child:
                        profileImage == null
                            ? Icon(
                              Icons.admin_panel_settings,
                              size: 30,
                              color: AppColors.primaryTeal,
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Greeting and Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        adminName ?? 'Administrator',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role ?? 'Administrator',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Notification Bell
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProvNotificationScreen(notifications: const [], onNotificationTap: (Map<String, dynamic> notification) { },),
                      ),
                    );
                  },
                  icon: Stack(
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      if (pendingApprovals > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                pendingApprovals > 9
                                    ? '9+'
                                    : '$pendingApprovals',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Primary Stats
            Row(
              children: [
                Expanded(
                  child: _buildMainStatCard(
                    'Tourist Spots',
                    totalSpots,
                    '$activeSpots Active',
                    Icons.place,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMainStatCard(
                    'Events',
                    totalEvents,
                    '$upcomingEvents Upcoming',
                    Icons.event,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Secondary Stats
            Row(
              children: [
                Expanded(
                  child: _buildMainStatCard(
                    'Total Users',
                    totalUsers,
                    '$activeTourists Tourists', // Provide an empty subtitle or a suitable string
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMainStatCard(
                    'Pending',
                    pendingApprovals,
                    'Need Review',
                    Icons.pending_actions,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatCard(
    String title,
    int count,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'icon': Icons.map_outlined,
        'label': 'Map View',
        'color': Colors.teal,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProvMapScreen()),
          );
        },
      },
      {
        'icon': Icons.people_outline,
        'label': 'Users',
        'color': Colors.purple,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProvUsersScreen()),
          );
        },
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'color': Colors.indigo,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analytics coming soon!')),
          );
        },
      },
      {
        'icon': Icons.feedback_outlined,
        'label': 'Feedback',
        'color': Colors.amber,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback system coming soon!')),
          );
        },
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'color': Colors.grey,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings coming soon!')),
          );
        },
      },
      {
        'icon': Icons.help_outline,
        'label': 'Help',
        'color': Colors.green,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Help center coming soon!')),
          );
        },
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: action['onTap'] as VoidCallback,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (action['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: action['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity log coming soon!')),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: recentActivities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No recent activities',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentActivities.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final activity = recentActivities[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (activity['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: activity['color'] as Color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity['subtitle'] as String),
                            Text(
                              DateFormat('MMM dd, hh:mm a')
                                  .format(activity['time'] as DateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

//   Widget _buildSystemStatus() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'System Status',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               _buildStatusIndicator('Database', true),
//               const SizedBox(width: 20),
//               _buildStatusIndicator('Storage', true),
//               const SizedBox(width: 20),
//               _buildStatusIndicator('Authentication', true),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusIndicator(String service, bool isOnline) {
//     return Row(
//       children: [
//         Container(
//           width: 8,
//           height: 8,
//           decoration: BoxDecoration(
//             color: isOnline ? Colors.green : Colors.red,
//             shape: BoxShape.circle,
//           ),
//         ),
//         const SizedBox(width: 6),
//         Text(service, style: const TextStyle(fontSize: 14)),
//       ],
//     );
//   }
}
