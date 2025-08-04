// // ignore_for_file: unintended_html_in_doc_comment

// import 'package:capstone_app/models/destination_model.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';

// class SimpleRecommenderService {
//   /// Loads the current user's tourist preferences from Firestore
//   static Future<Map<String, dynamic>?> _getUserPreferences() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return null;

//     final doc = await FirebaseFirestore.instance
//         .collection('tourist_preferences')
//         .doc(user.uid)
//         .get();

//     return doc.data();
//   }

//   /// Fetches all hotspots (destinations) from Firestore
//   static Future<List<Hotspot>> _getAllHotspots() async {
//     final snapshot = await FirebaseFirestore.instance.collection('destination').get();
//     return snapshot.docs.map((doc) => Hotspot.fromMap(doc.data(), doc.id)).toList();
//   }

//   /// Parses preference map into a safe lowercase Set<String> of types
//   static Set<String> _extractPreferredTypes(Map<String, dynamic> preferencesMap) {
//     final Set<String> preferredTypes = {};

//     for (final entry in preferencesMap.entries) {
//       final value = entry.value;

//       if (value is Iterable) {
//         for (var e in value) {
//           preferredTypes.add(e.toString().toLowerCase().trim());
//         }
//       } else if (value is String) {
//         preferredTypes.add(value.toLowerCase().trim());
//       } else {
//         if (kDebugMode) {
//           print('⚠️ Unexpected preference value type for key "${entry.key}": ${value.runtimeType}');
//         }
//       }
//     }

//     return preferredTypes;
//   }

//   /// Personalized recommendation section for Tourist HomeScreen
//   static Future<Map<String, List<Hotspot>>> getHomeRecommendations({int? limit}) async {
//     final prefs = await _getUserPreferences();
//     final allHotspots = await _getAllHotspots();

//     if (prefs == null || allHotspots.isEmpty) {
//       return {
//         'forYou': [],
//         'trending': allHotspots.take(limit ?? 6).toList(),
//         'discover': allHotspots.reversed.take(limit ?? 6).toList(),
//       };
//     }

//     final preferencesRaw = prefs['preferences'];
//     if (preferencesRaw == null || preferencesRaw is! Map<String, dynamic>) {
//       if (kDebugMode) print('⚠️ preferences is null or not a map: $preferencesRaw');
//       return {
//         'forYou': [],
//         'trending': allHotspots.take(limit ?? 6).toList(),
//         'discover': allHotspots.reversed.take(limit ?? 6).toList(),
//       };
//     }

//     final preferredTypes = _extractPreferredTypes(preferencesRaw);

//     final personalized = allHotspots.where((spot) {
//       return preferredTypes.contains(spot.type.toLowerCase().trim());
//     }).toList();

//     return {
//       'forYou': personalized.take(limit ?? 6).toList(),
//       'trending': allHotspots.take(limit ?? 6).toList(),
//       'discover': allHotspots.reversed.take(limit ?? 6).toList(),
//     };
//   }

//   /// Reusable method to fetch only personalized list (for other screens)
//   static Future<List<Hotspot>> getRecommendedDestinations({required int limit}) async {
//     final prefs = await _getUserPreferences();
//     if (prefs == null) return [];

//     final preferencesRaw = prefs['preferences'];
//     if (preferencesRaw == null || preferencesRaw is! Map<String, dynamic>) {
//       if (kDebugMode) print('⚠️ preferences is null or not a map: $preferencesRaw');
//       return [];
//     }

//     final preferredTypes = _extractPreferredTypes(preferencesRaw);

//     final allHotspots = await _getAllHotspots();

//     final matched = allHotspots.where((spot) {
//       return preferredTypes.contains(spot.type.toLowerCase().trim());
//     }).toList();

//     return matched.take(limit).toList();
//   }
// }
