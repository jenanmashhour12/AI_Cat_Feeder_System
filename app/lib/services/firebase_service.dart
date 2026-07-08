import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/system_status.dart';
import '../models/feeding_schedule.dart';
import '../models/activity_log.dart';
import '../models/notification_item.dart';
import '../models/cat_profile.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ============================
  /// Cats
  /// ============================

  Stream<List<CatProfile>> watchCats() {
    return _db.collection('cats').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => CatProfile.fromMap(doc.id, doc.data()))
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
        );
  }

  /// Writes an enrollment command to Firebase so the Raspberry Pi knows
  /// to start capturing the cat's face.
  Future<void> startEnrollment() async {
    await _db.collection('commands').doc('enroll').set({
      'status': 'pending',
      'frames_done': 0,
      'frames_needed': 40,
      'instruction': 'Bring your cat to the feeder camera',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Real-time stream of the enrollment progress document.
  /// Emits every time the Raspberry Pi updates the frame count,
  /// instruction, or status.
  Stream<Map<String, dynamic>> watchEnrollment() {
    return _db
        .collection('commands')
        .doc('enroll')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  /// Marks the enrollment as cancelled. The Pi will detect this and stop.
  Future<void> cancelEnrollment() async {
    await _db.collection('commands').doc('enroll').set({
      'status': 'cancelled',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Creates a new cat document using the ID assigned by the Raspberry Pi
  /// during enrollment. The [catId] must match the gallery ID the Pi saved
  /// (e.g. "cat_003"). This is what links the face gallery on the Pi to
  /// the cat profile in Firebase.
  Future<CatProfile> addCat({
    required String catId,
    required String name,
    double portionG = 30,
    double waterG = 150,
  }) async {
    final docRef = _db.collection('cats').doc(catId);
    final now = DateTime.now();

    final data = {
      'name': name,
      'portion_g': portionG,
      'water_g': waterG,
      'total_feedings': 0,
      'enrolled_at': now.toIso8601String(),
      'last_seen': now.toIso8601String(),
      'image_url': null,
      'voice_url': null,
    };

    final batch = _db.batch();

    batch.set(docRef, data);

    batch.set(_db.collection('settings').doc(catId), {
      'notifications_enabled': true,
      'low_food_alert': true,
      'low_water_alert': true,
      'feeding_complete_alert': true,
      'unrecognized_animal_alert': true,
      'device_offline_alert': true,
      'default_portion': portionG,
      'call_sound_url': null,
    });

    batch.set(_db.collection('system_status').doc(catId), {
      'food_level_pct': 100,
      'water_level_pct': 100,
      'pi_online': false,
      'last_updated': now.toIso8601String(),
    });

    await batch.commit();

    return CatProfile.fromMap(catId, data);
  }

  /// Deletes a cat along with its per-cat settings/status documents.
  /// Schedules, feedings and notifications belonging to this cat are left
  /// untouched (so activity history isn't silently lost) — delete those
  /// manually from the Firebase console if needed.
  Future<void> deleteCat(String catId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('cats').doc(catId));
    batch.delete(_db.collection('settings').doc(catId));
    batch.delete(_db.collection('system_status').doc(catId));
    await batch.commit();
  }

  /// ============================
  /// System Status (per cat)
  /// ============================

  Stream<SystemStatus> watchSystemStatus(String catId) {
    return _db
        .collection('system_status')
        .doc(catId)
        .snapshots()
        .map((doc) => SystemStatus.fromMap(doc.data() ?? {}));
  }

  /// ============================
  /// Notifications (per cat)
  /// ============================

  Stream<List<NotificationItem>> watchNotifications(String catId) {
    return _db
        .collection('notifications')
        .where('cat_id', isEqualTo: catId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationItem.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  Future<void> markNotificationRead(String id) async {
    await _db.collection('notifications').doc(id).update({
      'is_read': true,
    });
  }

  Future<void> deleteNotification(String id) async {
    await _db.collection('notifications').doc(id).delete();
  }

  /// ============================
  /// Settings (per cat)
  /// ============================

  Stream<Map<String, dynamic>> watchCatSettings(String catId) {
    return _db.collection('settings').doc(catId).snapshots().map(
          (doc) => doc.data() ?? {},
        );
  }

  Future<void> updateCatSettings(
    String catId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('settings').doc(catId).set(
          data,
          SetOptions(merge: true),
        );
  }

  /// ============================
  /// Schedules (per cat)
  /// ============================

  Stream<List<FeedingSchedule>> watchSchedules(String catId) {
    return _db
        .collection('schedules')
        .where('cat_id', isEqualTo: catId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FeedingSchedule.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> saveSchedule(FeedingSchedule schedule) async {
    await _db.collection('schedules').doc(schedule.id).set(schedule.toMap());
  }

  Future<void> deleteSchedule(String id) async {
    await _db.collection('schedules').doc(id).delete();
  }

  /// ============================
  /// Activity Logs / Feedings (per cat)
  /// ============================

  /// NOTE: this filters by `cat_id` AND orders by `timestamp`, which
  /// requires a composite Firestore index. The first time you run this,
  /// Firestore will throw an error in the console/logs with a direct link
  /// to create that index — just click it once.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLatestFeedings(
    String catId,
  ) {
    return _db
        .collection('feedings')
        .where('cat_id', isEqualTo: catId)
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots();
  }

  Stream<List<ActivityLog>> watchFeedings(String catId) {
    return _db
        .collection('feedings')
        .where('cat_id', isEqualTo: catId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ActivityLog.fromFeeding(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }
}
