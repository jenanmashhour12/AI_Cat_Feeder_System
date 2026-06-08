import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/system_status.dart';
import '../models/feeding_schedule.dart';
import '../models/activity_log.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<SystemStatus> watchSystemStatus() {
    return _db.collection('system_status').doc('status').snapshots().map((doc) {
      final data = doc.data() ?? {};
      return SystemStatus.fromMap(data);
    });
  }

  Stream<List<FeedingSchedule>> watchSchedules() {
    return _db.collection('schedules').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => FeedingSchedule.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<void> sendFeedCommand(double portionG) async {
    await _db.collection('commands').add({
      'type': 'manual_feed',
      'portion_g': portionG,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveSchedule(FeedingSchedule schedule) async {
    await _db.collection('schedules').doc(schedule.id).set(schedule.toMap());
  }

  Future<void> deleteSchedule(String id) async {
    await _db.collection('schedules').doc(id).delete();
  }

  Future<void> updateCatSettings(String catId, double portionG) async {
    await _db
        .collection('settings')
        .doc('cats')
        .collection('items')
        .doc(catId)
        .set({
      'portion_g': portionG,
    }, SetOptions(merge: true));
  }

  Stream<List<ActivityLog>> watchFeedings() {
    return _db.collection('feedings').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => ActivityLog.fromFeeding(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }
}
