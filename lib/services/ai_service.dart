import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_api_key.dart';
import 'api_key_manager.dart';
import 'hive_service.dart';

class AIService {
  static final AIService _instance = AIService._();
  factory AIService() => _instance;
  AIService._();

  /// Cached admin key for the current request cycle.
  AdminApiKey? _currentAdminKey;

  /// Returns key from the cached admin key, or user's own key.
  String get _apiKey {
    if (HiveService.getUseApiKeyManager()) {
      _currentAdminKey ??= ApiKeyManager.instance.getNextKey();
      return _currentAdminKey?.key ?? '';
    }
    final active = HiveService.getActiveAiKey();
    return active?['key'] as String? ?? '';
  }

  String get _baseUrl {
    if (HiveService.getUseApiKeyManager()) {
      return _currentAdminKey?.baseUrl ?? 'https://openrouter.ai/api/v1';
    }
    final active = HiveService.getActiveAiKey();
    return active?['baseUrl'] as String? ?? 'https://api.chatanywhere.tech/v1';
  }

  String get _model {
    if (HiveService.getUseApiKeyManager()) {
      return _currentAdminKey?.model ?? 'gpt-4o-mini';
    }
    final active = HiveService.getActiveAiKey();
    return active?['model'] as String? ?? 'gpt-4o-mini';
  }

  /// Fetch free models from OpenRouter.
  /// If [apiKey] is provided, uses it; otherwise peeks at admin key pool or user key.
  Future<List<Map<String, dynamic>>> fetchFreeOpenRouterModels(
      {String? apiKey}) async {
    try {
      String keyForFetch;
      if (apiKey != null && apiKey.isNotEmpty) {
        keyForFetch = apiKey;
      } else if (HiveService.getUseApiKeyManager()) {
        keyForFetch = ApiKeyManager.instance.peekFirstKey()?.key ?? '';
      } else {
        final active = HiveService.getActiveAiKey();
        keyForFetch = active?['key'] as String? ?? '';
      }
      if (keyForFetch.isEmpty) return [];

      final url = Uri.parse(
          'https://openrouter.ai/api/v1/models?sort=latency-low-to-high');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $keyForFetch',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final allModels = data['data'] as List<dynamic>? ?? [];
        final free = allModels.where((m) {
          final map = m as Map<String, dynamic>;
          final pricing = map['pricing'] as Map<String, dynamic>? ?? {};
          final modality = (map['architecture'] as Map<String, dynamic>? ??
                  {})['modality'] as String? ??
              '';
          return modality == 'text->text' &&
              pricing['prompt'] == '0' &&
              pricing['completion'] == '0';
        }).toList();

        final total = free.length;
        return free.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value as Map<String, dynamic>;
          final tier = idx < total ~/ 3
              ? 'fast'
              : idx < 2 * total ~/ 3
                  ? 'medium'
                  : 'slow';
          return {
            'id': m['id'] as String,
            'tier': tier,
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> testConnection() async {
    _currentAdminKey = null;
    if (_apiKey.isEmpty) return false;
    try {
      final url = Uri.parse('$_baseUrl/chat/completions');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': 'Hi'}
              ],
              'max_tokens': 5,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> sendMessage(String message) async {
    _currentAdminKey = null;
    if (_apiKey.isEmpty) {
      if (HiveService.getUseApiKeyManager()) {
        return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
      }
      throw Exception('API_KEY_MISSING');
    }

    try {
      return await _callOpenAI(message);
    } catch (e) {
      if (e.toString().contains('API_KEY_MISSING')) rethrow;
      throw Exception('API_CALL_FAILED');
    }
  }

  Future<String> sendMessageWithSystem(String message,
      {String? systemPrompt,
      List<Map<String, String>>? history,
      int? maxTokens}) async {
    _currentAdminKey = null;
    if (_apiKey.isEmpty) {
      if (HiveService.getUseApiKeyManager()) {
        return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
      }
      throw Exception('API_KEY_MISSING');
    }

    try {
      return await _callOpenAI(message,
          systemPrompt: systemPrompt, history: history, maxTokens: maxTokens);
    } catch (e) {
      if (e.toString().contains('API_KEY_MISSING')) rethrow;
      throw Exception('API_CALL_FAILED');
    }
  }

  Future<String> _callOpenAI(String message,
      {String? systemPrompt,
      List<Map<String, String>>? history,
      int? maxTokens,
      bool isRetry = false}) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final userName = HiveService.getUserName();

    final messages = <Map<String, String>>[];
    messages.add({
      'role': 'system',
      'content': systemPrompt ??
          'You are Keshab, an AI English teacher for Bengali speakers. '
              '${userName.isNotEmpty ? "Your student is $userName. " : ""}'
              'Your job: help the student improve their English through natural conversation.\n\n'
              'RULES:\n'
              '1. CRITICAL: Check BOTH grammar AND factual accuracy. If a sentence is '
              'grammatically correct but factually wrong (e.g., "The Sun revolves around '
              'the Earth"), politely correct the fact.\n'
              '2. When the student writes an English sentence, first acknowledge what they '
              'said, then point out any errors (grammar OR fact).\n'
              '3. Keep responses in English only. There is a separate translate button for Bangla.\n'
              '4. If the student asks in Bangla, respond in English with simple words.\n'
              '5. Be concise — 2-4 sentences max unless explaining a complex topic.\n'
              '6. Always encourage the student, but be honest about mistakes.\n'
              '7. Address the student by name when possible.'
    });
    if (history != null && history.isNotEmpty) {
      messages.addAll(history);
    }
    messages.add({'role': 'user', 'content': message});

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': maxTokens ?? 1024,
      }),
    );

    // Report success/failure to ApiKeyManager (for admin key health tracking)
    if (response.statusCode == 200) {
      if (HiveService.getUseApiKeyManager() && _currentAdminKey != null) {
        ApiKeyManager.instance.reportSuccess(_currentAdminKey!);
      }
      final bodyString = utf8.decode(response.bodyBytes);
      final data = jsonDecode(bodyString);
      final content = data['choices']?[0]?['message']?['content'];
      if (content != null) return content;
    } else {
      // Report failure so the key goes on cooldown
      if (HiveService.getUseApiKeyManager() && _currentAdminKey != null) {
        ApiKeyManager.instance.reportFailure(
          _currentAdminKey!,
          response.statusCode,
          'conversation',
          '',
        );
      }
      // Auto-retry once with next healthy key if admin keys are enabled
      if (!isRetry && HiveService.getUseApiKeyManager()) {
        _currentAdminKey = null;
        final nextKey = ApiKeyManager.instance.getNextKey();
        if (nextKey != null) {
          _currentAdminKey = nextKey;
          return _callOpenAI(message,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: maxTokens,
              isRetry: true);
        }
      }
    }
    return _getLocalResponse(message);
  }

  /// Returns a clear fallback message when the AI service is unavailable.
  /// This is NOT an AI response — it tells the user the service is temporarily down.
  String _getLocalResponse(String message) {
    return '⚠️ AI service is temporarily unavailable. Our team has been notified. '
        'Please try again in a few moments.\n\n'
        'বাংলা: ⚠️ AI সার্ভিস সাময়িকভাবে কাজ করছে না। আমাদের টিমকে জানানো হয়েছে। '
        'অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।';
  }
}
