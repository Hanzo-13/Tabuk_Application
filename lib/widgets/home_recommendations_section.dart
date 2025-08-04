// // ignore_for_file: unused_element, avoid_print, unused_local_variable

// // import 'dart:typed_data';
// // import 'package:capstone_app/services/image_cache_service.dart';
// import 'package:capstone_app/services/recommender_system.dart';
// // import 'package:capstone_app/widgets/cached_image.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:capstone_app/models/destination_model.dart';
// import 'package:capstone_app/screens/tourist/hotspot_details_screen.dart';
// import 'package:capstone_app/utils/colors.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//   late AnimationController _headerAnimationController;
//   late Animation<double> _headerFadeAnimation;
//   late Animation<Offset> _headerSlideAnimation;

//   String _greeting = '';
//   IconData _greetingIcon = Icons.wb_sunny;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//     _setGreeting();
//   }

//   void _initializeAnimations() {
//     _headerAnimationController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );

//     _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeInOut),
//     );

//     _headerSlideAnimation = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
//       CurvedAnimation(parent: _headerAnimationController, curve: Curves.elasticOut),
//     );

//     _headerAnimationController.forward();
//   }

//   void _setGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) {
//       _greeting = 'Good Morning! ☀️';
//       _greetingIcon = Icons.wb_sunny;
//     } else if (hour < 18) {
//       _greeting = 'Good Afternoon! 🌤️';
//       _greetingIcon = Icons.wb_cloudy;
//     } else {
//       _greeting = 'Good Evening! 🌙';
//       _greetingIcon = Icons.nightlight_round;
//     }
//   }

//   @override
//   void dispose() {
//     _headerAnimationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.backgroundColor,
//       body: CustomScrollView(
//         slivers: [
//           // Header
//           SliverAppBar(
//             expandedHeight: 200,
//             pinned: true,
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             flexibleSpace: FlexibleSpaceBar(
//               background: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       AppColors.primaryOrange.withOpacity(0.8),
//                       AppColors.primaryTeal.withOpacity(0.6),
//                       AppColors.backgroundColor.withOpacity(0.4),
//                     ],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                 ),
//                 child: SafeArea(
//                   child: AnimatedBuilder(
//                     animation: _headerAnimationController,
//                     builder: (context, child) {
//                       return FadeTransition(
//                         opacity: _headerFadeAnimation,
//                         child: SlideTransition(
//                           position: _headerSlideAnimation,
//                           child: Padding(
//                             padding: const EdgeInsets.all(20),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(_greetingIcon, color: Colors.white, size: 28),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: Text(
//                                         _greeting,
//                                         style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 const Text(
//                                   'Discover amazing places here in Bukidnon!',
//                                   style: TextStyle(fontSize: 16, color: Colors.white70),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ),
//           ),

//           // Recommendation Section
//           SliverToBoxAdapter(
//             child: FutureBuilder<List<Hotspot>>(
//               future: SimpleRecommenderService.getRecommendedDestinations(limit: 10),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: Padding(
//                     padding: EdgeInsets.all(32),
//                     child: CircularProgressIndicator(),
//                   ));
//                 }

//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Padding(
//                       padding: const EdgeInsets.all(32),
//                       child: Text('Error: ${snapshot.error}'),
//                     ),
//                   );
//                 }

//                 final spots = snapshot.data ?? [];
//                 if (spots.isEmpty) {
//                   return const _EmptyState();
//                 }

//                 return _CarouselSection(
//                   title: 'Recommended For You',
//                   color: AppColors.homeForYouColor,
//                   icon: Icons.recommend,
//                   spots: spots,
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _CarouselSection extends StatelessWidget {
//   final String title;
//   final Color color;
//   final IconData icon;
//   final List<Hotspot> spots;

//   const _CarouselSection({
//     required this.title,
//     required this.color,
//     required this.icon,
//     required this.spots,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (spots.isNotEmpty)
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Row(
//               children: [
//                 Icon(icon, color: color),
//                 const SizedBox(width: 8),
//                 Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ],
//             ),
//           ),
//         SizedBox(
//           height: 220,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: spots.length,
//             itemBuilder: (_, index) {
//               final spot = spots[index];
//               return GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => HotspotDetailsScreen(hotspot: spot)),
//                   );
//                 },
//                 child: Container(
//                   margin: const EdgeInsets.symmetric(horizontal: 12),
//                   width: 160,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(16),
//                     image: DecorationImage(
//                       image: NetworkImage(spot.images.isNotEmpty ? spot.images.first : ''),
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                   child: Container(
//                     alignment: Alignment.bottomLeft,
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(16),
//                       gradient: LinearGradient(
//                         colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomCenter,
//                       ),
//                     ),
//                     child: Text(
//                       spot.name,
//                       style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _EmptyState extends StatelessWidget {
//   const _EmptyState();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       alignment: Alignment.center,
//       child: Column(
//         children: const [
//           Icon(Icons.explore_off, size: 80, color: Colors.grey),
//           SizedBox(height: 16),
//           Text('No recommendations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           SizedBox(height: 8),
//           Text('Try updating your preferences or start exploring.',
//               style: TextStyle(fontSize: 14, color: Colors.grey),
//               textAlign: TextAlign.center),
//         ],
//       ),
//     );
//   }
// }
