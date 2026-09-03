import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/config/app_config_model.dart';
import '../../../services/remote_config_service.dart';
import '../../../services/ai_service.dart';
import '../../../services/api_key_manager.dart';
import '../../../services/hive_service.dart';
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

  /// Lightweight aggregated counts — 1 read each via count() aggregation.
  /// Used by dashboard stats row to avoid downloading 200 user docs.
  Future<Map<String, int>> getUserCounts() async {
    final results = await Future.wait([
      _firestore.collection('users').count().get(),
      _firestore.collection('users').where('role', isEqualTo: 'admin').count().get(),
    ]);
    final total = results[0].count ?? 0;
    final admins = results[1].count ?? 0;
    return {'total': total, 'admins': admins, 'students': total - admins};
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
        'target_channel': 'push',
        'included_segments': ['All'],
        'headings': {'en': title},
        'contents': {'en': body},
        // High priority + our native channel → delivers even when app is killed / force-stopped
        'priority': 10,
        'android_channel_id': 'speakeasy_onesignal_channel',
        'small_icon': 'ic_stat_onesignal_default',
        'large_icon': 'ic_stat_onesignal_default',
        // Ensure background delivery: TTL 3 days so offline devices get it on reconnect
        'ttl': 259200,
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
        'You are SpeakEasy\'s friendly notification writer — a fun, cheerful friend, NOT a boring school teacher.\n'
        'GOAL: Write notifications that users ENJOY tapping — playful, warm, a bit funny, never boring or formal.\n'
        '\n'
        'TONE RULES:\n'
        '- Speak like a close friend: use "tumi", "cholo", "ki khobor?", "arey wah!" — never robotic/formal Bangla.\n'
        '- Mix Bangla + Banglish naturally (e.g. "Practice ta miss koro na!").\n'
        '- 1-2 relevant emojis only (front-loaded in title if possible). No emoji spam.\n'
        '- Be encouraging & funny — light humor, wordplay, or cute challenge. Never scolding or guilt-tripping.\n'
        '- Keep it SHORT, punchy, thumb-stopping. User should smile and tap.\n'
        '- Never use corporate phrases like "গুরুত্বপূর্ণ বিজ্ঞপ্তি" or "অনুরোধ করা হচ্ছে".\n'
        '\n'
        'EXAMPLES (follow this vibe):\n'
        'Idea: vocabulary test kal\n'
        'TITLE: 📚 Kal Test, Ready to Rock? 😎\n'
        'BODY: 5 min practice korlei kal hero hoye jabe! Cholo, ekta quick revision kore feli? 🔥\n'
        '\n'
        'Idea: streak miss hobe\n'
        'TITLE: 🔥 Arey, Streak Ta Kande! 🥺\n'
        'BODY: 2 min e streak bachano jabe! Ekta lesson kore streak hero hoye jao 😍\n'
        '\n'
        'Idea: new lesson added\n'
        'TITLE: ✨ Notun Lesson Eseche! 🎉\n'
        'BODY: Ekdom fresh lesson — moja kore English shikhe felo, boring lagbe na promise! 😄\n'
        '\n'
        'STRICT OUTPUT — no markdown, no extra lines, exactly:\n'
        'TITLE: <max 55 chars, fun + emoji>\n'
        'BODY: <max 180 chars, friendly + playful + 1 emoji at end>';
    try {
      // The admin API key pool loads asynchronously at app start. Wait for it
      // so a generate tapped right after launch doesn't race the Firestore
      // listener and fail with "no key". Mirror the AI teacher's key access.
      if (HiveService.getUseApiKeyManager()) {
        await ApiKeyManager.instance.ensureReady();
        if (ApiKeyManager.instance.peekFirstKey() == null) {
          throw Exception(
            'Admin → API Keys-এ কোনো healthy (active, not-in-cooldown) key নেই। '
            'একটা valid key যোগ করো, নইলে AI notification generate হবে না।',
          );
        }
      }
      final response = await AIService().sendMessageWithSystem(
        'Idea/topic: $idea\nWrite a FUN, friendly notification — make user smile and tap!',
        systemPrompt: systemPrompt,
        maxTokens: 250,
      );
      // AIService returns these fallback strings (instead of throwing) when
      // the key pool is empty or the API call fails. Parsing them as
      // TITLE:/BODY: content would publish an error message as a real
      // notification, so surface the real failure to the caller instead.
      if (_isAiServiceFallback(response)) {
        throw Exception(response);
      }
      return response;
    } catch (e) {
      throw Exception('AI notification generation failed: ${e.toString()}');
    }
  }

  /// True when [response] is one of AIService's known fallback/error texts
  /// rather than real AI-generated content.
  bool _isAiServiceFallback(String response) {
    return response.contains('সার্ভার ব্যস্ত') ||
        response.contains('AI service is temporarily unavailable');
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
