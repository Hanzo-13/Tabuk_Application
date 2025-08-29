import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class BusinessOwnerHomeScreen extends StatefulWidget {
  const BusinessOwnerHomeScreen({super.key});

  @override
  State<BusinessOwnerHomeScreen> createState() => _BusinessOwnerHomeScreenState();
}

class _BusinessOwnerHomeScreenState extends State<BusinessOwnerHomeScreen>
    with TickerProviderStateMixin {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  String ownerName = 'Business Owner';
  int businessCount = 0;
  int promotionCount = 0;
  double? averageRating;
  int totalViews = 0;
  int activePromotions = 0;
  List<Map<String, dynamic>> recentActivities = [];
  bool _loading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadOwnerData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerData() async {
    if (uid == null) return;

    try {
      // Load user data
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final userData = userDoc.data();
      if (userData != null) {
        ownerName = userData['name'] ?? 'Business Owner';
      }

      // Load destinations data
      final destinationSnap = await FirebaseFirestore.instance
          .collection('destination')
          .where('owner_uid', isEqualTo: uid)
          .get();

      // Load events data
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('created_by', isEqualTo: uid)
          .get();

      // Calculate metrics
      double totalRating = 0;
      int ratingCount = 0;
      int views = 0;
      int activePromos = 0;

      for (var doc in destinationSnap.docs) {
        final data = doc.data();
        if (data.containsKey('average_rating') && data['average_rating'] != null) {
          totalRating += data['average_rating'];
          ratingCount++;
        }
        if (data.containsKey('view_count')) {
          views += (data['view_count'] as int? ?? 0);
        }
      }

      // Count active promotions (events that haven't ended)
      final now = DateTime.now();
      for (var doc in eventsSnap.docs) {
        final data = doc.data();
        if (data.containsKey('end_date')) {
          final endDate = (data['end_date'] as Timestamp).toDate();
          if (endDate.isAfter(now)) {
            activePromos++;
          }
        }
      }

      // Generate mock recent activities (replace with real data)
      recentActivities = [
        {
          'title': 'New review received',
          'subtitle': '⭐ 4.5 stars from a customer',
          'time': '2 hours ago',
          'icon': Icons.star,
          'color': Colors.amber,
        },
        {
          'title': 'Promotion viewed',
          'subtitle': 'Summer Sale got 12 new views',
          'time': '5 hours ago',
          'icon': Icons.visibility,
          'color': Colors.blue,
        },
        {
          'title': 'Business listing updated',
          'subtitle': 'Beach Resort info updated',
          'time': '1 day ago',
          'icon': Icons.edit,
          'color': Colors.green,
        },
      ];

      setState(() {
        businessCount = destinationSnap.docs.length;
        promotionCount = eventsSnap.docs.length;
        averageRating = ratingCount > 0 ? totalRating / ratingCount : null;
        totalViews = views;
        activePromotions = activePromos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Loading your dashboard...', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadOwnerData,
        child: CustomScrollView(
          slivers: [
            // Enhanced App Bar with gradient
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkBlue,
                        AppColors.darkTeal,
                        AppColors.lightTeal,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  child: Text(
                                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'B',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_getGreeting()},',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        ownerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    // TODO: Navigate to notifications
                                  },
                                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Statistics Cards
                      _buildStatsGrid(),
                      const SizedBox(height: 32),

                      // Quick Actions with better layout
                      _buildQuickActionsSection(theme),
                      const SizedBox(height: 32),

                      // Recent Activity Section
                      _buildRecentActivitySection(theme),
                      const SizedBox(height: 32),

                      // Performance Insights (placeholder)
                      _buildInsightsSection(theme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildEnhancedStatCard(
          'Businesses',
          businessCount.toString(),
          Icons.business,
          Colors.blue,
          'Total locations',
        ),
        _buildEnhancedStatCard(
          'Active Promotions',
          activePromotions.toString(),
          Icons.campaign,
          Colors.green,
          'Currently running',
        ),
        _buildEnhancedStatCard(
          'Average Rating',
          averageRating?.toStringAsFixed(1) ?? 'N/A',
          Icons.star,
          Colors.amber,
          'Customer reviews',
        ),
        _buildEnhancedStatCard(
          'Total Views',
          _formatNumber(totalViews),
          Icons.visibility,
          Colors.purple,
          'This month',
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 16),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Add New Business',
              Icons.add_business,
              Colors.teal,
              () {
                // TODO: Navigate to business registration
              },
            ),
            _buildActionCard(
              'View Reviews',
              Icons.rate_review,
              Colors.deepPurple,
              () {
                // TODO: Navigate to reviews screen
              },
            ),
            _buildActionCard(
              'Create Promotion',
              Icons.campaign,
              Colors.orange,
              () {
                // TODO: Navigate to create promotion
              },
            ),
            _buildActionCard(
              'Analytics',
              Icons.analytics,
              Colors.indigo,
              () {
                // TODO: Navigate to analytics
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to full activity log
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentActivities.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final activity = recentActivities[index];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (activity['color'] as Color).withOpacity(0.1),
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
                subtitle: Text(activity['subtitle'] as String),
                trailing: Text(
                  activity['time'] as String,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInsightsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Insights',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Business Performance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your businesses are performing well this month with increased views and positive reviews.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to detailed analytics
                        },
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('View Analytics'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to optimization tips
                        },
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Get Tips'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}