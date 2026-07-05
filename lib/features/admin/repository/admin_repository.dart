import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/config/app_config_model.dart';
import '../../../services/remote_config_service.dart';
import '../../../services/ai_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Users ──

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream({int? limit}) {
    var query = _firestore
        .collection('users')
        .orderBy('joinedAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .orderBy('joinedAt', descending: true)
        .get();
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
      'roleUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<Map<String, dynamic>?> getUserProgress(String uid) async {
    final doc = await _firestore.collection('progress').doc(uid).get();
    return doc.data();
  }

  Future<int> getTotalUsers() async {
    final snapshot = await _firestore.collection('users').count().get();
    return snapshot.count ?? 0;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadMoreUsers({
    DocumentSnapshot? lastDoc,
    int pageSize = 50,
  }) {
    var query = _firestore
        .collection('users')
        .orderBy('joinedAt', descending: true)
        .limit(pageSize);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    return query.get();
  }

  // ── Feedback ──

  Stream<QuerySnapshot<Map<String, dynamic>>> feedbackStream({
    String? statusFilter,
    int? limit,
  }) {
    var query = _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Future<void> markFeedbackResolved(String docId) async {
    await _firestore.collection('feedback').doc(docId).update({
      'status': 'resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitFeedbackReply(String docId, String reply) async {
    await _firestore.collection('feedback').doc(docId).update({
      'adminReply': reply,
      'status': 'resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> generateAiReply(String category, String message) async {
    final systemPrompt = _aiReplySystemPrompt(category);
    try {
      final aiResponse = await AIService().sendMessageWithSystem(
        'User feedback: $message',
        systemPrompt: systemPrompt,
      );
      return aiResponse;
    } catch (_) {
      return _buildFallbackAiReply(category);
    }
  }

  String _aiReplySystemPrompt(String category) {
    switch (category) {
      case 'Bug Report':
        return 'You are a polite app support agent. Acknowledge the bug, thank the user, and say the team is looking into it. Be concise.';
      case 'Feature Request':
        return 'You are a polite app support agent. Thank the user for the suggestion and say the team will review it. Be concise.';
      case 'Complaint':
        return 'You are a polite app support agent. Apologize sincerely and assure the user their feedback will help improve the app. Be concise.';
      case 'Suggestion':
        return 'You are a polite app support agent. Thank the user and say their input is valuable. Be concise.';
      default:
        return 'You are a polite app support agent. Thank the user for their feedback. Be concise.';
    }
  }

  String _buildFallbackAiReply(String category) {
    if (category == 'Bug Report') {
      return 'Thank you for reporting this issue. Our team is looking into it and will fix it soon.';
    } else if (category == 'Complaint') {
      return 'We apologize for the inconvenience. Your feedback helps us improve.';
    }
    return 'Thank you for your feedback! We appreciate your input.';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadMoreFeedback({
    String? statusFilter,
    DocumentSnapshot? lastDoc,
    int pageSize = 50,
  }) {
    var query = _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    return query.get();
  }

  // ── Notifications ──

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream({int? limit}) {
    var query = _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadMoreNotifications({
    DocumentSnapshot? lastDoc,
    int pageSize = 50,
  }) {
    var query = _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    return query.get();
  }

  Future<String> sendNotification({
    required String title,
    required String body,
    String? link,
    String targetRole = 'all',
    int? targetCount,
  }) async {
    final ref = await _firestore.collection('admin_notifications').add({
      'title': title,
      'body': body,
      'link': link,
      'targetRole': targetRole,
      if (targetCount != null) 'targetCount': targetCount,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deleteNotification(String docId) async {
    await _firestore.collection('admin_notifications').doc(docId).delete();
  }

  Future<void> clearAllNotifications() async {
    final snapshot =
        await _firestore.collection('admin_notifications').get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>?> _getOneSignalConfig() async {
    try {
      final doc =
          await _firestore.collection('Config').doc('app_settings').get();
      if (!doc.exists) return null;
      return doc.data()?['onesignal'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? link,
    String? firestoreDocId,
  }) async {
    try {
      final oneSignalConfig = await _getOneSignalConfig();
      final appId = oneSignalConfig?['AppId'] as String? ?? '';
      final apiKey = oneSignalConfig?['ApiKey'] as String? ?? '';
      if (appId.isEmpty || apiKey.isEmpty) {
        debugPrint(
          'OneSignal sendPushNotification: appId or apiKey is empty. '
          'Set them in Firestore config/app_settings → onesignal.',
        );
        return false;
      }

      final payload = <String, dynamic>{
        'app_id': appId,
        // Use 'All' — OneSignal's default segment for all active subscriptions.
        // If you renamed it in the dashboard, update this value accordingly.
        'included_segments': ['All'],
        'headings': {'en': title},
        'contents': {'en': body},
        'priority': 10,
        'small_icon': 'ic_stat_onesignal_default',
        'large_icon': 'ic_stat_onesignal_default',
      };
      if (link != null) payload['url'] = link;
      if (firestoreDocId != null) {
        payload['data'] = {
          'notification_id': 'admin_$firestoreDocId',
          'type': 'admin_announcement',
          'payload': firestoreDocId,
          if (link != null) 'actionUrl': link,
        };
      }

      final http.Response response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $apiKey',
        },
        body: jsonEncode(payload),
      );

      // Parse response body for diagnostics
      final responseBody = response.body;
      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          final errors = decoded['errors'] as List<dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            debugPrint(
              'OneSignal API returned errors: $errors',
            );
            return false;
          }
          debugPrint(
            'OneSignal: notification sent! id=${decoded['id']} '
            'recipients=${decoded['recipients']}',
          );
          return true;
        } catch (_) {
          // Response body not JSON — treat as success since status is 200
          return true;
        }
      } else {
        debugPrint(
          'OneSignal API error (${response.statusCode}): $responseBody',
        );
        return false;
      }
    } catch (e) {
      debugPrint('OneSignal sendPushNotification exception: $e');
      return false;
    }
  }

  Future<String> generateNotificationContent(String idea) async {
    const systemPrompt =
        'You write short, beautiful in-app notifications for a spoken English learning app. '
        'Use friendly Bangla/Banglish tone, useful emojis, and motivating language. '
        'Return only this exact format with no markdown:\n'
        'TITLE: <max 55 chars>\n'
        'BODY: <max 180 chars>';
    try {
      final response = await AIService().sendMessageWithSystem(
        'Idea/topic: $idea',
        systemPrompt: systemPrompt,
        maxTokens: 180,
      );
      return response;
    } catch (_) {
      return 'TITLE: 📢 Important Update!\nBODY: $idea ✨ Keep practicing English today!';
    }
  }

  // ── Config ──

  Future<AppConfig> getConfig() => RemoteConfigService.getConfig();

  Future<void> updateConfig(Map<String, dynamic> updates) =>
      RemoteConfigService.updateConfig(updates);

  // ── Content: Vocabulary Chapters ──

  Stream<QuerySnapshot<Map<String, dynamic>>> vocabularyChaptersStream() {
    return _firestore
        .collection('content_vocabulary_chapters')
        .orderBy('chapterNumber', descending: false)
        .snapshots();
  }

  Future<void> addVocabularyChapter(Map<String, dynamic> data) async {
    await _firestore.collection('content_vocabulary_chapters').add(data);
  }

  Future<void> updateVocabularyChapter(
      String docId, Map<String, dynamic> data) async {
    await _firestore.collection('content_vocabulary_chapters').doc(docId).update(data);
  }

  Future<void> deleteVocabularyChapter(String docId) async {
    await _firestore.collection('content_vocabulary_chapters').doc(docId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> vocabularyWordsStream(
      String chapterId) {
    return _firestore
        .collection('content_vocabulary_words')
        .where('chapterId', isEqualTo: chapterId)
        .orderBy('word', descending: false)
        .snapshots();
  }

  // ── Content: Grammar Chapters ──

  Stream<QuerySnapshot<Map<String, dynamic>>> grammarChaptersStream() {
    return _firestore
        .collection('content_grammar_chapters')
        .orderBy('chapterNumber', descending: false)
        .snapshots();
  }

  // ── Content: Daily Word ──

  Future<DocumentSnapshot<Map<String, dynamic>>> getDailyWordConfig() {
    return _firestore.collection('Config').doc('daily_word').get();
  }

  Future<void> updateDailyWordConfig(Map<String, dynamic> data) async {
    await _firestore
        .collection('Config')
        .doc('daily_word')
        .set(data, SetOptions(merge: true));
  }
}
