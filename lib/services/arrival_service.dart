import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArrivalService {
  static final _firestore = FirebaseFirestore.instance;
  static const String arrivalsCollection = 'Arrivals';

  /// Save an arrival event for the current user at a hotspot.
  static Future<void> saveArrival({
    required String hotspotId,
    required double latitude,
    required double longitude,
    String? businessName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    await _firestore.collection(arrivalsCollection).add({
      'userId': user.uid,
      'hotspotId': hotspotId,
      'timestamp': now,
      'location': {'lat': latitude, 'lng': longitude},
      if (businessName != null && businessName.isNotEmpty) 'business_name': businessName,
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

  /// Check if the user has already recorded an arrival at this hotspot today.
  static Future<bool> hasArrivedToday(String hotspotId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snapshot =
        await _firestore
            .collection(arrivalsCollection)
            .where('userId', isEqualTo: user.uid)
            .where('hotspotId', isEqualTo: hotspotId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .get();
    return snapshot.docs.isNotEmpty;
  }
}
