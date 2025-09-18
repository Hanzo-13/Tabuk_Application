import 'dart:math';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/destination_model.dart';

import '../utils/constants.dart';

class ContentRecommenderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for recommendations to avoid repeated API calls
  static final Map<String, List<Hotspot>> _recommendationCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidity = Duration(minutes: 15);

  // Cache for hotspots to avoid fetching the entire collection multiple times
  static List<Hotspot>? _allHotspotsCache;
  static DateTime? _allHotspotsCacheTimestamp;
  static const Duration _hotspotsCacheValidity = Duration(minutes: 10);

  // Cache for favorites count per hotspot to identify popularity
  static Map<String, int>? _favoritesCountCache;
  static DateTime? _favoritesCountCacheTimestamp;
  static const Duration _favoritesCacheValidity = Duration(minutes: 10);

  /// Get personalized recommendations based on user preferences and favorites
  static Future<List<Hotspot>> getForYouRecommendations({
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'forYou';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _recommendationCache[cacheKey] ?? [];
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user preferences
      final preferences = await _getUserPreferences(user.uid);
      
      // Get user favorites to understand their interests
      final favorites = await _getUserFavorites(user.uid);
      
      // Get all hotspots
      final allHotspots = await _getAllHotspots();
      
      if (allHotspots.isEmpty) return [];

      // Score hotspots based on preferences and favorites
      final scoredHotspots = _scoreHotspotsForUser(
        allHotspots, 
        preferences, 
        favorites,
      );

      // Sort by score and take top results
      scoredHotspots.sort((a, b) => b.score.compareTo(a.score));
      
      final recommendations = scoredHotspots
          .take(limit)
          .map((scored) => scored.hotspot)
          .toList();

      _updateCache(cacheKey, recommendations);
      return recommendations;
    } catch (e) {
      if (kDebugMode) print('Error getting For You recommendations: $e');
      return [];
    }
  }

  /// Get popular destinations based on views, ratings, and social proof
  static Future<List<Hotspot>> getPopularRecommendations({
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'popular';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _recommendationCache[cacheKey] ?? [];
    }

    try {
      final allHotspots = await _getAllHotspots();
      
      if (allHotspots.isEmpty) return [];

      // Fetch favorites count map to reflect known/liked destinations
      final favoritesCountMap = await _getFavoritesCountMap(forceRefresh: forceRefresh);

      // Score hotspots based on popularity metrics
      final scoredHotspots = await _scoreHotspotsByPopularity(allHotspots, favoritesCountMap);
      
      // Sort by popularity score and take top results
      scoredHotspots.sort((a, b) => b.score.compareTo(a.score));
      
      final recommendations = scoredHotspots
          .take(limit)
          .map((scored) => scored.hotspot)
          .toList();

      _updateCache(cacheKey, recommendations);
      return recommendations;
    } catch (e) {
      if (kDebugMode) print('Error getting Popular recommendations: $e');
      return [];
    }
  }

  /// Get nearby destinations based on user's current location
  static Future<List<Hotspot>> getNearbyRecommendations({
    required double userLat,
    required double userLng,
    int limit = 6,
    double maxDistanceKm = 30.0,
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'nearby';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _recommendationCache[cacheKey] ?? [];
    }

    try {
      final allHotspots = await _getAllHotspots();
      
      if (allHotspots.isEmpty) return [];

      // Filter hotspots with valid coordinates
      final hotspotsWithCoords = allHotspots
          .where((hotspot) => 
              hotspot.latitude != null && 
              hotspot.longitude != null)
          .toList();

      // Calculate distances and filter by max distance
      final nearbyHotspots = <ScoredHotspot>[];
      
      for (final hotspot in hotspotsWithCoords) {
        final distance = Geolocator.distanceBetween(
          userLat, 
          userLng, 
          hotspot.latitude!, 
          hotspot.longitude!,
        ) / 1000; // Convert to kilometers

        if (distance <= maxDistanceKm) {
          // Score based on distance (closer = higher score)
          final distanceScore = 1.0 - (distance / maxDistanceKm);
          nearbyHotspots.add(ScoredHotspot(
            hotspot: hotspot,
            score: distanceScore,
          ));
        }
      }

      // Sort by distance score (higher means closer) and take top results
      nearbyHotspots.sort((a, b) => b.score.compareTo(a.score));
      
      final recommendations = nearbyHotspots
          .take(limit)
          .map((scored) => scored.hotspot)
          .toList();

      _updateCache(cacheKey, recommendations);
      return recommendations;
    } catch (e) {
      if (kDebugMode) print('Error getting Nearby recommendations: $e');
      return [];
    }
  }

  /// Get discover recommendations - hidden gems and lesser-known places
  static Future<List<Hotspot>> getDiscoverRecommendations({
    int limit = 6,
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'discover';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _recommendationCache[cacheKey] ?? [];
    }

    try {
      final allHotspots = await _getAllHotspots();
      
      if (allHotspots.isEmpty) return [];

      // Score hotspots based on discovery factors
      final scoredHotspots = await _scoreHotspotsForDiscovery(allHotspots);
      
      // Sort by discovery score and take top results
      scoredHotspots.sort((a, b) => b.score.compareTo(a.score));
      
      final recommendations = scoredHotspots
          .take(limit)
          .map((scored) => scored.hotspot)
          .toList();

      _updateCache(cacheKey, recommendations);
      return recommendations;
    } catch (e) {
      if (kDebugMode) print('Error getting Discover recommendations: $e');
      return [];
    }
  }

  /// Get all recommendations for the home screen
  static Future<Map<String, List<Hotspot>>> getAllRecommendations({
    double? userLat,
    double? userLng,
    int forYouLimit = 6,
    int popularLimit = 6,
    int nearbyLimit = 6,
    int discoverLimit = 6,
    bool forceRefresh = false,
  }) async {
    try {
      final futures = await Future.wait([
        getForYouRecommendations(limit: forYouLimit, forceRefresh: forceRefresh),
        getPopularRecommendations(limit: popularLimit, forceRefresh: forceRefresh),
        if (userLat != null && userLng != null)
          getNearbyRecommendations(
            userLat: userLat,
            userLng: userLng,
            limit: nearbyLimit,
            forceRefresh: forceRefresh,
          )
        else
          getPopularRecommendations(limit: nearbyLimit, forceRefresh: forceRefresh),
        getDiscoverRecommendations(limit: discoverLimit, forceRefresh: forceRefresh),
      ]);

      return {
        'forYou': futures[0],
        'popular': futures[1],
        'nearby': futures[2],
        'discover': futures[3],
      };
    } catch (e) {
      if (kDebugMode) print('Error getting all recommendations: $e');
      return {
        'forYou': [],
        'popular': [],
        'nearby': [],
        'discover': [],
      };
    }
  }

  // Helper methods

  static Future<Map<String, dynamic>?> _getUserPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('tourist_preferences')
          .doc(userId)
          .get();
      return doc.data();
    } catch (e) {
      if (kDebugMode) print('Error getting user preferences: $e');
      return null;
    }
  }

  static Future<List<String>> _getUserFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs
          .map((doc) => doc.data()['hotspotId'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error getting user favorites: $e');
      return [];
    }
  }

  static Future<List<Hotspot>> _getAllHotspots({bool forceRefresh = false}) async {
    try {
      final now = DateTime.now();
      final isCacheValid = _allHotspotsCache != null &&
          _allHotspotsCacheTimestamp != null &&
          now.difference(_allHotspotsCacheTimestamp!) < _hotspotsCacheValidity;

      if (!forceRefresh && isCacheValid) {
        return _allHotspotsCache!;
      }

      final snapshot = await _firestore.collection('destination').get();
      final hotspots = snapshot.docs
          .map((doc) => Hotspot.fromMap(doc.data(), doc.id))
          .toList();

      _allHotspotsCache = hotspots;
      _allHotspotsCacheTimestamp = now;
      return hotspots;
    } catch (e) {
      if (kDebugMode) print('Error getting all hotspots: $e');
      return _allHotspotsCache ?? [];
    }
  }

  /// Clears cached hotspots (does not affect recommendation caches)
  static void clearHotspotsCache() {
    _allHotspotsCache = null;
    _allHotspotsCacheTimestamp = null;
  }

  static List<ScoredHotspot> _scoreHotspotsForUser(
    List<Hotspot> hotspots,
    Map<String, dynamic>? preferences,
    List<String> favorites,
  ) {
    return hotspots.map((hotspot) {
      double score = 0.0;
      
      // Base score
      score += 1.0;
      
      // Favorite boost
      if (favorites.contains(hotspot.hotspotId)) {
        score += 5.0;
      }
      
      // Preference matching
      if (preferences != null) {
        final prefs = preferences['preferences'] as Map<String, dynamic>?;
        if (prefs != null) {
          for (final entry in prefs.entries) {
            final value = entry.value;
            if (value is List) {
              for (final pref in value) {
                if (hotspot.category.toLowerCase().contains(pref.toString().toLowerCase()) ||
                    hotspot.type.toLowerCase().contains(pref.toString().toLowerCase())) {
                  score += 3.0;
                }
              }
            } else if (value is String) {
              if (hotspot.category.toLowerCase().contains(value.toLowerCase()) ||
                  hotspot.type.toLowerCase().contains(value.toLowerCase())) {
                score += 3.0;
              }
            }
          }
        }
      }
      
      // Category diversity bonus
      if (hotspot.category == AppConstants.naturalAttraction) score += 1.5;
      if (hotspot.category == AppConstants.culturalSite) score += 1.2;
      if (hotspot.category == AppConstants.adventureSpot) score += 1.8;
      
      // Amenities bonus
      if (hotspot.restroom) score += 0.5;
      if (hotspot.foodAccess) score += 0.5;
      
      return ScoredHotspot(hotspot: hotspot, score: score);
    }).toList();
  }

  static Future<List<ScoredHotspot>> _scoreHotspotsByPopularity(
    List<Hotspot> hotspots,
    Map<String, int> favoritesCountMap,
  ) async {
    return hotspots.map((hotspot) {
      double score = 0.0;

      // Base score
      score += 1.0;

      // Strong signal: favorites count (known destinations)
      final favoritesCount = (favoritesCountMap[hotspot.hotspotId] ?? 0).toDouble();
      // Log scale to avoid dominating
      score += (1.8 * (favoritesCount > 0 ? math.log(1 + favoritesCount) : 0));

      // Category popularity (based on general tourist interest)
      switch (hotspot.category) {
        case AppConstants.naturalAttraction:
          score += 2.2;
          break;
        case AppConstants.culturalSite:
          score += 2.0;
          break;
        case AppConstants.adventureSpot:
          score += 2.1;
          break;
        case AppConstants.restaurant:
          score += 1.4;
          break;
        case AppConstants.accommodation:
          score += 1.0;
          break;
        default:
          score += 0.6;
      }

      // More media often correlates with known spots
      score += (hotspot.images.length >= 5) ? 0.7 : (hotspot.images.length >= 2 ? 0.4 : 0.1);

      // Location popularity: central areas get higher scores
      final muni = hotspot.municipality.toLowerCase();
      if (muni.contains('malaybalay')) score += 1.2;
      if (muni.contains('valencia')) score += 1.0;

      // Slight preference to older, established spots
      final ageDays = DateTime.now().difference(hotspot.createdAt).inDays;
      score += (ageDays >= 365) ? 0.6 : (ageDays >= 180 ? 0.3 : 0.0);

      // Random small factor for variety
      score += Random().nextDouble() * 0.3;

      return ScoredHotspot(hotspot: hotspot, score: score);
    }).toList();
  }

  static Future<List<ScoredHotspot>> _scoreHotspotsForDiscovery(
    List<Hotspot> hotspots,
  ) async {
    // Fetch favorites count to DE-emphasize known destinations
    final favoritesCountMap = await _getFavoritesCountMap();

    return hotspots.map((hotspot) {
      double score = 0.0;

      // Base score
      score += 1.0;

      // Hidden gems: categories that are often less mainstream
      switch (hotspot.category) {
        case AppConstants.culturalSite:
          score += 2.6;
          break;
        case AppConstants.adventureSpot:
          score += 2.2;
          break;
        case AppConstants.naturalAttraction:
          score += 1.8;
          break;
        default:
          score += 1.2;
      }

      // Remote locations get higher scores
      final muni = hotspot.municipality.toLowerCase();
      if (muni.contains('impasugong') ||
          muni.contains('cabanglasan') ||
          muni.contains('kitaotao') ||
          muni.contains('dangcagan') ||
          muni.contains('damulog') ||
          muni.contains('kalilangan')) {
        score += 2.0;
      }

      // Penalize highly popular spots so Discover stays lesser-known
      final favoritesCount = (favoritesCountMap[hotspot.hotspotId] ?? 0).toDouble();
      score -= (favoritesCount > 0 ? math.log(1 + favoritesCount) : 0) * 1.5;

      // Unique features bonus
      if (hotspot.safetyTips?.isNotEmpty ?? false) score += 0.8;
      if (hotspot.localGuide?.isNotEmpty ?? false) score += 1.0;
      if (hotspot.suggestions?.isNotEmpty ?? false) score += 0.6;

      // Random factor for variety
      score += Random().nextDouble() * 0.8;

      return ScoredHotspot(hotspot: hotspot, score: score);
    }).toList();
  }

  static bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheValidity;
  }

  static void _updateCache(String cacheKey, List<Hotspot> recommendations) {
    _recommendationCache[cacheKey] = recommendations;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clear all cached recommendations
  static void clearCache() {
    _recommendationCache.clear();
    _cacheTimestamps.clear();
  }

  /// Clear specific cache entry
  static void clearCacheEntry(String cacheKey) {
    _recommendationCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
  }

  // Favorites aggregation helpers
  static Future<Map<String, int>> _getFavoritesCountMap({bool forceRefresh = false}) async {
    try {
      final now = DateTime.now();
      final isValid = _favoritesCountCache != null &&
          _favoritesCountCacheTimestamp != null &&
          now.difference(_favoritesCountCacheTimestamp!) < _favoritesCacheValidity;

      if (!forceRefresh && isValid && _favoritesCountCache != null) {
        return _favoritesCountCache!;
      }

      final snapshot = await _firestore.collection('favorites').get();
      final map = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hotspotId = data['hotspotId']?.toString();
        if (hotspotId == null || hotspotId.isEmpty) continue;
        map[hotspotId] = (map[hotspotId] ?? 0) + 1;
      }

      _favoritesCountCache = map;
      _favoritesCountCacheTimestamp = now;
      return map;
    } catch (e) {
      if (kDebugMode) print('Error aggregating favorites: $e');
      return _favoritesCountCache ?? <String, int>{};
    }
  }
}

/// Helper class for scoring hotspots
class ScoredHotspot {
  final Hotspot hotspot;
  final double score;

  ScoredHotspot({
    required this.hotspot,
    required this.score,
  });
}
