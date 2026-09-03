import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/config/app_config_model.dart';
import '../models/notification_templates.dart';
import '../../../services/remote_config_service.dart';
import '../../../services/ai_service.dart';
import '../../../services/api_key_manager.dart';
import '../../../services/hive_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of an OneSignal push attempt — surfaces the REAL failure reason
/// (config problem, auth problem, bad segment...) to the admin UI, instead of
/// the old generic "Check OneSignal config" message that hid the cause.
class PushSendResult {
  final bool success;
  final String detail;
  final int? recipients;
  final String? oneSignalId;
  const PushSendResult({
    required this.success,
    required this.detail,
    this.recipients,
    this.oneSignalId,
  });
}

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
    // Status starts as 'sending'; it is flipped to 'sent'/'failed' after the
    // real OneSignal API result arrives (see updateNotificationOutcome), so
    // the Sent History screen shows the truth instead of always 'sent'.
    final ref = await _firestore.collection('admin_notifications').add({
      'title': title,
      'body': body,
      'link': link,
      'targetRole': targetRole,
      if (targetCount != null) 'targetCount': targetCount,
      'status': 'sending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Records the real delivery outcome on the admin_notifications doc so the
  /// history screen reflects whether OneSignal accepted the message.
  Future<void> updateNotificationOutcome(
    String docId, {
    required String status, // 'sent' | 'failed'
    String? oneSignalId,
    int? recipients,
    String? error,
  }) async {
    try {
      await _firestore.collection('admin_notifications').doc(docId).update({
        'status': status,
        if (oneSignalId != null) 'oneSignalId': oneSignalId,
        if (recipients != null) 'recipients': recipients,
        if (error != null) 'error': error,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('OneSignal: could not persist outcome — $e');
    }
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

  /// Sends a broadcast push via OneSignal and returns a [PushSendResult]
  /// containing the REAL outcome (success flag + human-readable detail).
  ///
  /// ⚠️ OneSignal migration notes (Nov 2024 → Q1 2026):
  ///  • New REST base URL: https://api.onesignal.com/notifications
  ///    (the legacy https://onesignal.com/api/v1/notifications endpoint and
  ///    legacy app keys are deprecated — new keys look like `os_v2_app_...`).
  ///    The new endpoint accepts BOTH new and legacy keys, but the legacy
  ///    endpoint only accepts legacy keys, so always use the new URL here.
  ///  • For a broadcast, `included_segments: ['All']` works on the legacy
  ///    model; newer dashboards expose segments like 'All Subscribers' /
  ///    'Subscribed Users'. If the API rejects the segment name, the exact
  ///    error is returned to the admin UI so the segment can be fixed.
  Future<PushSendResult> sendPushNotification({
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
          'Set them in Firestore Config/app_settings → onesignal.',
        );
        return const PushSendResult(
          success: false,
          detail:
              'Firestore Config/app_settings → onesignal-এ AppId/ApiKey পাওয়া যায়নি। '
              'Fields গুলোর নাম EXACT হতে হবে: "AppId" ও "ApiKey" (collection: '
              'বড় হাতের "Config", doc: "app_settings")।',
        );
      }

      final payload = <String, dynamic>{
        'app_id': appId,
        'target_channel': 'push',
        'included_segments': ['All'],
        'headings': {'en': title},
        'contents': {'en': body},
        // High priority → delivers even when app is killed / force-stopped
        'priority': 10,
        // ⚠️ Do NOT send `android_channel_id` here: OneSignal's server now
        // REJECTS unknown channel ids with HTTP 400 "Could not find
        // android_channel_id" (verified live 2026-09-03 with this app's key).
        // Without it, OneSignal uses its default channel and delivery works.
        // Ensure background delivery: TTL 3 days so offline devices get it
        // on reconnect.
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
        // New OneSignal REST endpoint (see migration note above).
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $apiKey',
        },
        body: jsonEncode(payload),
      );

      final responseBody = response.body;

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          final errors = decoded['errors'] as List<dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            final detail = errors.map((e) => e.toString()).join('; ');
            debugPrint('OneSignal API returned errors: $errors');
            return PushSendResult(success: false, detail: 'OneSignal: $detail');
          }
          final recipients = decoded['recipients'];
          final osId = decoded['id'] as String?;
          debugPrint(
            'OneSignal: notification sent! id=$osId recipients=$recipients',
          );
          return PushSendResult(
            success: true,
            detail: 'OneSignal accepted (id=$osId)',
            recipients: recipients is int ? recipients : null,
            oneSignalId: osId,
          );
        } catch (_) {
          // Response body not JSON — treat as success since status is 2xx
          return PushSendResult(success: true, detail: 'OneSignal accepted (2xx)');
        }
      } else {
        // Show the server's real error (auth / bad segment / rate-limit...)
        final snippet = responseBody.length > 300
            ? responseBody.substring(0, 300)
            : responseBody;
        debugPrint('OneSignal API error (${response.statusCode}): $responseBody');
        return PushSendResult(
          success: false,
          detail: 'OneSignal HTTP ${response.statusCode}: $snippet',
        );
      }
    } catch (e) {
      debugPrint('OneSignal sendPushNotification exception: $e');
      return PushSendResult(
        success: false,
        detail: 'Network error: $e',
      );
    }
  }

  /// Generates a notification (title + body) for [idea] using the AI writer,
  /// with the given [tone] ('funny' | 'motivational' | 'urgent' | 'festive').
  ///
  /// Returns a record with the parsed result plus [fallbackUsed] = true when
  /// the AI failed and a template was used instead — so the UI can tell the
  /// admin the truth instead of publishing a garbled AI reply.
  ///
  /// Why a strict JSON contract? The old prompt (free-text TITLE:/BODY:) let
  /// models reply with anything — reversed fields, markdown, full English,
  /// or off-topic text ("উল্টো পাটা"). Now the model must emit one JSON
  /// object, anything else is rejected and the admin gets a template.
  Future<({String title, String body, bool fallbackUsed})>
      generateNotificationContent(String idea, {String tone = 'funny'}) async {
    const toneRules = {
      'funny': '- Tone: funny, playful, light humor. Make them laugh.',
      'motivational': '- Tone: motivational & energizing. Never guilt-tripping.',
      'urgent': "- Tone: urgent but friendly — limited time, don't miss it.",
      'festive': '- Tone: festive & celebratory.',
    };

    const systemPrompt = '''
You write short push notifications (title + body) for SpeakEasy — a Bengali-English learning app. Audience: Bengali students. The notification must make them smile and tap.

STRICT OUTPUT CONTRACT:
- Return ONLY this JSON object. No markdown fence, no comments, no extra text, no bullets:
{"title":"...","body":"..."}
- "title": 55 chars max, catchy, starts with 1-2 emojis.
- "body": 180 chars max, friendly and playful, ends with exactly 1 emoji.
- Language: Bangla + Banglish mix (tumi, cholo, arey wah!). NEVER formal Bangla, NEVER full English, NEVER corporate phrases.
- The body MUST match the title's subject. Never write the opposite meaning, never go off-topic.

TONE:
${toneRules[tone] ?? toneRules['funny']}

TOPIC TEMPLATES — follow the closest one:
- daily quiz → today's quiz (10 quick questions, points)
- quiz winner → winner name + score + "tomar turn"
- streak → save streak in 2 minutes
- new lesson → fresh lesson, fun learning
- vocabulary → new word / word of the day
- battle arena → 1v1 duel with friends
- mock test → exam-style practice
- practice reminder → 5-minute practice
- festive → festival greeting (Eid / Puja / New Year)
- general update → app news

EXAMPLES:
Idea: vocabulary test kal → {"title":"📚 Kal Test, Ready to Rock? 😎","body":"5 min practice korlei kal hero hoye jabe! Cholo, ekta quick revision kore feli? 🔥"}
Idea: streak miss hobe → {"title":"🔥 Arey, Streak Ta Kande! 🥺","body":"2 min e streak bachano jabe! Ekta lesson kore streak hero hoye jao 😍"}''';

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
        'Idea/topic: $idea',
        systemPrompt: systemPrompt,
        maxTokens: 300,
      );
      // AIService returns these fallback strings (instead of throwing) when
      // the key pool is empty or the API call fails — never publish them.
      if (_isAiServiceFallback(response)) {
        throw Exception(response);
      }
      final parsed = _parseStrictJson(response);
      if (parsed != null) {
        return (title: parsed.$1, body: parsed.$2, fallbackUsed: false);
      }
      throw Exception('AI response JSON parse failed');
    } catch (e) {
      // AI fail → deterministic template fallback so the admin ALWAYS gets a
      // correct, on-brand message (never "উল্টো পাটা").
      debugPrint('generateNotificationContent: AI failed ($e) → template fallback');
      final tpl = bestTemplateForIdea(idea);
      return (title: tpl.title, body: tpl.body, fallbackUsed: true);
    }
  }

  /// Parses the strict `{"title":...,"body":...}` contract. Returns null for
  /// anything that doesn't conform (so callers fall back to a template).
  (String, String)? _parseStrictJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    var jsonStr = raw.substring(start, end + 1);
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;
      var title = (decoded['title'] as String?)?.trim() ?? '';
      var body = (decoded['body'] as String?)?.trim() ?? '';
      if (title.isEmpty || body.isEmpty) return null;
      // Strip accidental markdown / list artifacts.
      final junk = RegExp(r'[*#`>_\-]');
      title = title.replaceAll(junk, '').trim();
      body = body.replaceAll(junk, '').trim();
      body = body.replaceAll(RegExp(r'\s+'), ' ');
      if (title.isEmpty || body.isEmpty) return null;
      if (title.length > 55) title = '${title.substring(0, 52)}...';
      if (body.length > 180) body = '${body.substring(0, 177)}...';
      return (title, body);
    } catch (_) {
      return null;
    }
  }

  /// True when [response] is one of AIService's known fallback/error texts
  /// rather than real AI-generated content.
  bool _isAiServiceFallback(String response) {
    return response.contains('সার্ভার ব্যস্ত') ||
        response.contains('AI service is temporarily unavailable');
  }

  /// Today's `daily_quiz_leaderboard/{date}/entries` top list (raw docs).
  /// Used by the admin "Ajker Quiz Winner → Send" button so the announcement
  /// carries REAL name + score from the leaderboard.
  Future<List<Map<String, dynamic>>> fetchQuizTopEntries({int limit = 3}) async {
    final date = todayQuizDateKey();
    final snapshot = await _firestore
        .collection('daily_quiz_leaderboard')
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', ascending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
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
