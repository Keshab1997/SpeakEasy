import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_safe.dart';

/// Repository for Mock Test progress data.
///
/// Manages two storage layers:
/// - **Hive** (local cache) — fast offline reads/writes
/// - **Firestore** (remote) — durable cross-device persistence
///
/// Follows the same pattern as [ProgressRepository].
class MockTestRepository {
  static const String _boxName = 'mock_test_progress';
  static const String _progressKey = 'progress';
  static const String _firestoreCollection = 'mock_test_progress';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MockTestRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── Helpers ──

  String? get currentUserId => _auth.currentUser?.uid;

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ── Hive (Local Cache) ──

  /// Save progress map to local Hive storage.
  Future<void> saveToHive(Map<String, dynamic> progress) async {
    final box = await _ensureBox();
    await box.put(
      _progressKey,
      HiveSafe.sanitizeMap(progress),
    );
  }

  /// Read progress map from local Hive storage.
  /// Returns `null` if no progress has been saved yet.
  Map<String, dynamic>? getFromHive() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final raw = box.get(_progressKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Clear progress from local Hive storage.
  Future<void> clearHive() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box(_boxName);
    await box.clear();
  }

  // ── Firestore (Remote) ──

  /// Read progress map from Firestore for the given [userId].
  /// Returns `null` if no document exists yet.
  Future<Map<String, dynamic>?> fetchFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection(_firestoreCollection)
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error fetching mock test progress from Firestore: $e');
      return null;
    }
  }

  /// Upload progress map to Firestore for the given [userId].
  /// Merges with any existing data so concurrent writes are less destructive.
  Future<void> uploadToFirestore(
      String userId, Map<String, dynamic> progress) async {
    try {
      final data = Map<String, dynamic>.from(progress)
        ..['lastUpdated'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(_firestoreCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error uploading mock test progress to Firestore: $e');
    }
  }

  /// Delete progress document from Firestore for the given [userId].
  Future<void> deleteFromFirestore(String userId) async {
    try {
      await _firestore
          .collection(_firestoreCollection)
          .doc(userId)
          .delete();
    } catch (e) {
      debugPrint('❌ Error deleting mock test progress from Firestore: $e');
    }
  }

  // ── Sync ──

  /// Sync progress from Firestore → Hive for the given [userId].
  /// Called on app startup / login so local cache reflects the remote truth.
  Future<void> syncFromFirestoreToHive(String userId) async {
    final data = await fetchFromFirestore(userId);
    if (data != null) {
      // Strip the server timestamp before saving to Hive (Hive can't store Timestamp)
      final hiveData = Map<String, dynamic>.from(data)
        ..remove('lastUpdated');
      await saveToHive(hiveData);
      debugPrint('✅ Mock test progress synced from Firestore to Hive');
    } else {
      debugPrint('ℹ️ No mock test progress in Firestore — starting fresh');
    }
  }

  /// Sync progress from Hive → Firestore for the current user.
  /// Called after saving a test result so remote stays current.
  Future<void> syncFromHiveToFirestore() async {
    final userId = currentUserId;
    if (userId == null) return;

    final hiveData = getFromHive();
    if (hiveData != null) {
      await uploadToFirestore(userId, hiveData);
      debugPrint('✅ Mock test progress synced from Hive to Firestore');
    }
  }
}
