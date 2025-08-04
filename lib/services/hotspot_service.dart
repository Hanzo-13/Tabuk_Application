// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/destination_model.dart';
// import '../utils/constants.dart';

// /// Service for managing Hotspot CRUD operations in Firestore.
// class HotspotService {
//   /// Reference to the Firestore 'hotspots' collection.
//   static final _collection =
//       FirebaseFirestore.instance.collection(AppConstants.hotspotsCollection);

//   /// Adds a new hotspot to Firestore.
//   static Future<void> addHotspot(Hotspot hotspot) async {
//     try {
//       await _collection.doc(hotspot.hotspotId).set(hotspot.toJson());
//     } catch (e) {
//       throw Exception('${AppConstants.errorAddingHotspot}: $e');
//     }
//   }

//   /// Updates an existing hotspot in Firestore.
//   static Future<void> updateHotspot(Hotspot hotspot) async {
//     try {
//       await _collection.doc(hotspot.hotspotId).update(hotspot.toJson());
//     } catch (e) {
//       throw Exception('${AppConstants.errorUpdatingHotspot}: $e');
//     }
//   }

//   /// Deletes a hotspot from Firestore by its ID.
//   static Future<void> deleteHotspot(String hotspotId) async {
//     try {
//       await _collection.doc(hotspotId).delete();
//     } catch (e) {
//       throw Exception('${AppConstants.errorDeletingHotspot}: $e');
//     }
//   }

//   /// Returns a stream of all hotspots from Firestore.
//   static Stream<List<Hotspot>> getHotspotsStream() {
//     return _collection.snapshots().map(
//       (snapshot) => snapshot.docs
//           .map((doc) => Hotspot.fromMap(doc.data(), doc.id))
//           .toList(),
//     );
//   }
// }
