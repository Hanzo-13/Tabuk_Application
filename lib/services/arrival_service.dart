import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;

class ArrivalService {
  static final _firestore = FirebaseFirestore.instance;
  static const String arrivalsCollection = 'Arrivals';
  static const String destinationHistoryCollection = 'DestinationHistory';

  /// Outcome of attempting to record an arrival
  static const String outcomeArrivedNow = 'arrived_now';
  static const String outcomeAlreadyArrived = 'already_arrived';
  static const String outcomeTooFar = 'too_far';
  static const String outcomeError = 'error';

  /// Compute distance in meters between two lat/lng using Haversine
  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  /// Check proximity and record arrival only once per day.
  /// Returns one of the outcome constants above.
  static Future<String> recordArrivalIfFirstToday({
    required String hotspotId,
    required double userLatitude,
    required double userLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    double proximityThresholdMeters = 75.0,
    String? businessName,
    String? destinationName,
    String? destinationCategory,
    String? destinationType,
    String? destinationDistrict,
    String? destinationMunicipality,
    List<String>? destinationImages,
    String? destinationDescription,
  }) async {
    try {
      // Optional proximity gate if destination coordinates provided
      if (destinationLatitude != null && destinationLongitude != null) {
        final distance = _haversineMeters(
          userLatitude,
          userLongitude,
          destinationLatitude,
          destinationLongitude,
        );
        if (distance > proximityThresholdMeters) {
          return outcomeTooFar;
        }
      }

      final already = await hasArrivedToday(hotspotId);
      if (already) {
        return outcomeAlreadyArrived;
      }

      await saveArrival(
        hotspotId: hotspotId,
        latitude: userLatitude,
        longitude: userLongitude,
        businessName: businessName,
        destinationName: destinationName,
        destinationCategory: destinationCategory,
        destinationType: destinationType,
        destinationDistrict: destinationDistrict,
        destinationMunicipality: destinationMunicipality,
        destinationImages: destinationImages,
        destinationDescription: destinationDescription,
        useServerTimestamp: true,
      );

      return outcomeArrivedNow;
    } catch (_) {
      return outcomeError;
    }
  }

  /// Save an arrival event for the current user at a hotspot with enhanced destination details.
  static Future<void> saveArrival({
    required String hotspotId,
    required double latitude,
    required double longitude,
    String? businessName,
    String? destinationName,
    String? destinationCategory,
    String? destinationType,
    String? destinationDistrict,
    String? destinationMunicipality,
    List<String>? destinationImages,
    String? destinationDescription,
    bool useServerTimestamp = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final now = DateTime.now();
    
    // Save to Arrivals collection (existing functionality)
    await _retry(() async {
      await _firestore.collection(arrivalsCollection).add({
        'userId': user.uid,
        'hotspotId': hotspotId,
        'timestamp': useServerTimestamp ? FieldValue.serverTimestamp() : now,
        'location': {'lat': latitude, 'lng': longitude},
        if (businessName != null && businessName.isNotEmpty) 'business_name': businessName,
      });
    });

    // Save to DestinationHistory collection with enhanced details
    await _retry(() async {
      await _firestore.collection(destinationHistoryCollection).add({
        'userId': user.uid,
        'hotspotId': hotspotId,
        'timestamp': useServerTimestamp ? FieldValue.serverTimestamp() : now,
        'location': {'lat': latitude, 'lng': longitude},
        'destinationName': destinationName ?? businessName ?? 'Unknown Destination',
        'destinationCategory': destinationCategory ?? 'Unknown',
        'destinationType': destinationType ?? 'Unknown',
        'destinationDistrict': destinationDistrict ?? 'Unknown',
        'destinationMunicipality': destinationMunicipality ?? 'Unknown',
        'destinationImages': destinationImages ?? [],
        'destinationDescription': destinationDescription ?? '',
        'businessName': businessName,
        'visitDate': useServerTimestamp ? FieldValue.serverTimestamp() : now,
        'visitYear': now.year,
        'visitMonth': now.month,
        'visitDay': now.day,
      });
    });
  }

  /// Fetch all arrivals for the current user, ordered by most recent.
  static Future<List<Map<String, dynamic>>> getUserArrivals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snapshot =
        await _firestore
            .collection(arrivalsCollection)
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Generic retry helper with exponential backoff and jitter
  static Future<T> _retry<T>(Future<T> Function() operation, {int maxAttempts = 3, Duration baseDelay = const Duration(milliseconds: 300)}) async {
    int attempt = 0;
    Object? lastError;
    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt >= maxAttempts) break;
        final jitterMs = 50 + (math.Random().nextInt(100));
        final multiplier = (1 << (attempt - 1));
        final delay = baseDelay * multiplier + Duration(milliseconds: jitterMs);
        await Future.delayed(delay);
      }
    }
    if (lastError != null) {
      throw Exception(lastError.toString());
    }
    throw Exception('Unknown retry failure');
  }

  /// Stream arrivals for the current user in real-time, ordered by most recent.
  static Stream<List<Map<String, dynamic>>> streamUserArrivals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    return _firestore
        .collection(arrivalsCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Fetch enhanced destination history for the current user with detailed information.
  static Future<List<Map<String, dynamic>>> getUserDestinationHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final snapshot = await _firestore
        .collection(destinationHistoryCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        'documentId': doc.id,
      };
    }).toList();
  }

  /// Stream enhanced destination history for the current user in real-time.
  static Stream<List<Map<String, dynamic>>> streamUserDestinationHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;

    void listenOrdered() {
      subscription = _firestore
          .collection(destinationHistoryCollection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snap) {
          controller.add(snap.docs.map((d) => {
                ...d.data(),
                'documentId': d.id,
              }).toList());
        },
        onError: (error, stack) {
          final message = error.toString();
          if (message.contains('FAILED_PRECONDITION') ||
              message.contains('requires an index')) {
            // Fallback to unordered query while index builds
            subscription?.cancel();
            subscription = _firestore
                .collection(destinationHistoryCollection)
                .where('userId', isEqualTo: user.uid)
                .snapshots()
                .listen((snap) {
              final docs = snap.docs.map((d) => {
                    ...d.data(),
                    'documentId': d.id,
                  }).toList();
              // Manually sort by timestamp desc if present
              docs.sort((a, b) {
                final aTs = a['timestamp'];
                final bTs = b['timestamp'];
                if (aTs is Timestamp && bTs is Timestamp) {
                  return bTs.compareTo(aTs);
                }
                return 0;
              });
              controller.add(docs);
            }, onError: controller.addError);
          } else {
            controller.addError(error, stack);
          }
        },
      );
    }

    listenOrdered();

    controller.onCancel = () async {
      await subscription?.cancel();
    };

    return controller.stream;
  }

  /// Get destination history statistics for the current user.
  static Future<Map<String, dynamic>> getUserDestinationStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    
    final snapshot = await _firestore
        .collection(destinationHistoryCollection)
        .where('userId', isEqualTo: user.uid)
        .get();
    
    final visits = snapshot.docs.map((d) => d.data()).toList();
    
    if (visits.isEmpty) return {};
    
    // Calculate statistics
    final totalVisits = visits.length;
    final uniqueDestinations = visits.map((v) => v['hotspotId']).toSet().length;
    
    // Group by category
    final categoryCounts = <String, int>{};
    for (final visit in visits) {
      final category = visit['destinationCategory'] ?? 'Unknown';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }
    
    // Group by month/year
    final monthlyVisits = <String, int>{};
    for (final visit in visits) {
      final timestamp = visit['timestamp'] as Timestamp;
      final date = timestamp.toDate();
      final monthYear = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyVisits[monthYear] = (monthlyVisits[monthYear] ?? 0) + 1;
    }
    
    return {
      'totalVisits': totalVisits,
      'uniqueDestinations': uniqueDestinations,
      'categoryCounts': categoryCounts,
      'monthlyVisits': monthlyVisits,
      'firstVisit': visits.last['timestamp'],
      'lastVisit': visits.first['timestamp'],
    };
  }

  /// Check if the user has already recorded an arrival at this hotspot today.
  /// Checks both Arrivals and DestinationHistory collections to prevent duplicates.
  static Future<bool> hasArrivedToday(String hotspotId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    
    try {
      // Check Arrivals collection
      final arrivalsSnapshot = await _retry(() async {
        return await _firestore
            .collection(arrivalsCollection)
            .where('userId', isEqualTo: user.uid)
            .where('hotspotId', isEqualTo: hotspotId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .limit(1)
            .get();
      });
      
      if (arrivalsSnapshot.docs.isNotEmpty) {
        return true;
      }
      
      // Check DestinationHistory collection (more reliable check)
      final historySnapshot = await _retry(() async {
        return await _firestore
            .collection(destinationHistoryCollection)
            .where('userId', isEqualTo: user.uid)
            .where('hotspotId', isEqualTo: hotspotId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .limit(1)
            .get();
      });
      
      return historySnapshot.docs.isNotEmpty;
    } catch (e) {
      // If query fails (e.g., missing index), fallback to checking Arrivals only
      try {
        final fallbackSnapshot = await _retry(() async {
          return await _firestore
              .collection(arrivalsCollection)
              .where('userId', isEqualTo: user.uid)
              .where('hotspotId', isEqualTo: hotspotId)
              .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
              .limit(1)
              .get();
        });
        return fallbackSnapshot.docs.isNotEmpty;
      } catch (_) {
        // If still fails, return false to allow save (better than blocking)
        return false;
      }
    }
  }

  /// Get unique destinations visited by the user.
  static Future<List<Map<String, dynamic>>> getUniqueDestinationsVisited() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final snapshot = await _firestore
        .collection(destinationHistoryCollection)
        .where('userId', isEqualTo: user.uid)
        .get();
    
    final visits = snapshot.docs.map((d) => d.data()).toList();
    
    // Group by hotspotId and get the most recent visit for each
    final Map<String, Map<String, dynamic>> uniqueDestinations = {};
    
    for (final visit in visits) {
      final hotspotId = visit['hotspotId'];
      if (!uniqueDestinations.containsKey(hotspotId) || 
          (visit['timestamp'] as Timestamp).toDate().isAfter(uniqueDestinations[hotspotId]!['timestamp'].toDate())) {
        uniqueDestinations[hotspotId] = visit;
      }
    }
    
    return uniqueDestinations.values.toList()
      ..sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
  }
}
