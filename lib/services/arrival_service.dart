import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArrivalService {
  static final _firestore = FirebaseFirestore.instance;
  static const String arrivalsCollection = 'Arrivals';
  static const String destinationHistoryCollection = 'DestinationHistory';

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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final now = DateTime.now();
    
    // Save to Arrivals collection (existing functionality)
    await _firestore.collection(arrivalsCollection).add({
      'userId': user.uid,
      'hotspotId': hotspotId,
      'timestamp': now,
      'location': {'lat': latitude, 'lng': longitude},
      if (businessName != null && businessName.isNotEmpty) 'business_name': businessName,
    });

    // Save to DestinationHistory collection with enhanced details
    await _firestore.collection(destinationHistoryCollection).add({
      'userId': user.uid,
      'hotspotId': hotspotId,
      'timestamp': now,
      'location': {'lat': latitude, 'lng': longitude},
      'destinationName': destinationName ?? businessName ?? 'Unknown Destination',
      'destinationCategory': destinationCategory ?? 'Unknown',
      'destinationType': destinationType ?? 'Unknown',
      'destinationDistrict': destinationDistrict ?? 'Unknown',
      'destinationMunicipality': destinationMunicipality ?? 'Unknown',
      'destinationImages': destinationImages ?? [],
      'destinationDescription': destinationDescription ?? '',
      'businessName': businessName,
      'visitDate': now,
      'visitYear': now.year,
      'visitMonth': now.month,
      'visitDay': now.day,
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
    
    return _firestore
        .collection(destinationHistoryCollection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
          final data = d.data();
          return {
            ...data,
            'documentId': d.id,
          };
        }).toList());
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
      final arrivalsSnapshot = await _firestore
          .collection(arrivalsCollection)
          .where('userId', isEqualTo: user.uid)
          .where('hotspotId', isEqualTo: hotspotId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .limit(1)
          .get();
      
      if (arrivalsSnapshot.docs.isNotEmpty) {
        return true;
      }
      
      // Check DestinationHistory collection (more reliable check)
      final historySnapshot = await _firestore
          .collection(destinationHistoryCollection)
          .where('userId', isEqualTo: user.uid)
          .where('hotspotId', isEqualTo: hotspotId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .limit(1)
          .get();
      
      return historySnapshot.docs.isNotEmpty;
    } catch (e) {
      // If query fails (e.g., missing index), fallback to checking Arrivals only
      try {
        final fallbackSnapshot = await _firestore
            .collection(arrivalsCollection)
            .where('userId', isEqualTo: user.uid)
            .where('hotspotId', isEqualTo: hotspotId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .limit(1)
            .get();
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
