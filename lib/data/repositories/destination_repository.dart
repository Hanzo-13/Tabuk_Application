// ===========================================
// lib/data/repositories/destination_repository.dart
// Lightweight repository relying on Firestore offline persistence
// ===========================================

import 'package:cloud_firestore/cloud_firestore.dart';

class DestinationRepository {
  final FirebaseFirestore _db;

  DestinationRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('destination');

  /// Stream all active destinations (filters archived if present).
  Stream<List<Map<String, dynamic>>> getDestinationsStream() {
    return _collection.snapshots().map(
      (snap) =>
          snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .where(
                (m) => !(m['isArchived'] == true || m['status'] == 'Archived'),
              )
              .toList(),
    );
  }

  /// One-shot fetch (cache/remote).
  Future<List<Map<String, dynamic>>> getDestinationsOnce() async {
    final snap = await _collection.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}

