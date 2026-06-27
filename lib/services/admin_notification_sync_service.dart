import 'package:cloud_firestore/cloud_firestore.dart';

import 'hive_service.dart';

class AdminNotificationSyncService {
  AdminNotificationSyncService._();

  static final _firestore = FirebaseFirestore.instance;

  /// Fetches latest admin notifications from Firestore, adds new ones to local
  /// storage, and removes any locally cached admin notifications whose
  /// Firestore source document no longer exists (i.e. was deleted by admin).
  static Future<int> syncLatest() async {
    final snapshot = await _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    // Collect IDs of all admin notifications still present in Firestore
    final firestoreDocIds = <String>{};
    for (final doc in snapshot.docs) {
      firestoreDocIds.add(doc.id);
    }

    // Remove locally cached admin notifications whose Firestore doc was deleted
    final localHistory = HiveService.getNotificationHistory();
    for (final item in localHistory) {
      // Only consider notifications that were synced from admin (id starts with 'admin_')
      if (item['id'] is String && (item['id'] as String).startsWith('admin_')) {
        final payload = item['payload'] as String?;
        // payload stores the Firestore document ID
        if (payload != null && !firestoreDocIds.contains(payload)) {
          await HiveService.deleteNotification(item['id'] as String);
        }
      }
    }

    // Add new notifications from Firestore that aren't already in local storage
    var added = 0;
    for (final doc in snapshot.docs.reversed) {
      final data = doc.data();
      final targetRole = (data['targetRole'] as String?) ?? 'student';
      if (targetRole != 'student' && targetRole != 'all') continue;

      final title = (data['title'] as String?)?.trim() ?? '';
      final body = (data['body'] as String?)?.trim() ?? '';
      if (title.isEmpty || body.isEmpty) continue;

      final createdAt = data['createdAt'];
      final receivedAt = createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.now();
      final localId = 'admin_${doc.id}';

      final actionUrl = data['actionUrl'] as String?;
      final notificationMap = {
        'id': localId,
        'title': title,
        'body': body,
        'type': 'admin_announcement',
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': false,
        'payload': doc.id,
      };
      if (actionUrl != null && actionUrl.isNotEmpty) {
        notificationMap['actionUrl'] = actionUrl;
      }

      final didSave = await HiveService.saveNotificationToHistoryIfNew(notificationMap);

      if (didSave) added++;
    }

    return added;
  }
}