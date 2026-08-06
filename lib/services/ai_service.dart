import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/admin_api_key.dart';
import 'api_key_manager.dart';
import 'hive_service.dart';
import 'key_health_checker.dart' as key_health;

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

  /// OpenRouter serves models as `provider/model` ids (e.g. `openai/gpt-4o-mini`).
  /// ChatAnywhere-style entries store bare names (e.g. `gpt-4o-mini`), which
  /// OpenRouter rejects. Map a bare name to the right provider prefix when the
  /// request targets OpenRouter; leave every other backend untouched.
  @visibleForTesting
  static String resolveOpenRouterModel(String baseUrl, String model) =>
      key_health.resolveOpenRouterModel(baseUrl, model);

  /// Fetch free models from OpenRouter.
  /// If [apiKey] is provided, uses it; otherwise peeks at admin key pool or user key.
  Future<List<Map<String, dynamic>>> fetchFreeOpenRouterModels(
      {String? apiKey}) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        if (HiveService.getUseApiKeyManager()) {
          await ApiKeyManager.instance.ensureReady();
        }
      }
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
    if (HiveService.getUseApiKeyManager()) {
      await ApiKeyManager.instance.ensureReady();
    }
    if (_apiKey.isEmpty) return false;
    try {
      // Resolve key first so baseUrl/model come from the SAME admin key, and
      // normalize the model for OpenRouter (bare names are rejected there).
      final apiKey = _apiKey;
      final baseUrl = _baseUrl;
      final model = resolveOpenRouterModel(baseUrl, _model);
      final url = Uri.parse('$baseUrl/chat/completions');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
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

  /// Tests a specific key directly against its own base URL WITHOUT touching
  /// the current admin/user key state. Used by the admin "Test Connection"
  /// button so a test can't corrupt the saved key or the useAdminKeys toggle.
  /// [provider] is `google` (Gemini REST API) or any OpenAI-compatible backend.
  Future<bool> testConnectionWithKey(
      {required String provider,
      required String baseUrl,
      required String apiKey,
      required String model}) async {
    final status = await key_health.pingKeyStatus(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    );
    return status == 200;
  }

  Future<String> sendMessage(String message) async {
    _currentAdminKey = null;
    if (HiveService.getUseApiKeyManager()) {
      await ApiKeyManager.instance.ensureReady();
    }
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
    if (HiveService.getUseApiKeyManager()) {
      await ApiKeyManager.instance.ensureReady();
    }
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
    // Resolve key first so baseUrl/model below come from the SAME admin key,
    // and normalize the model for OpenRouter (bare names are rejected there).
    final apiKey = _apiKey;
    final baseUrl = _baseUrl;
    final provider = _currentAdminKey?.provider ?? 'custom';

    if (provider == 'google') {
      return _callGemini(message,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          isRetry: isRetry,
          apiKey: apiKey,
          baseUrl: baseUrl);
    }

    final model = resolveOpenRouterModel(baseUrl, _model);
    final url = Uri.parse('$baseUrl/chat/completions');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPromptText(systemPrompt)},
      ...?history,
      {'role': 'user', 'content': message},
    ];

    late final http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'max_tokens': maxTokens ?? 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception {
      // Network-level failure (timeout, connection refused, DNS, TLS, ...) —
      // the request never got an HTTP response. Mark this key as failed so it
      // goes on cooldown, then rotate once to the next healthy key instead of
      // failing the whole message. HTTP status codes are handled below; this
      // catch covers the requests that never returned at all.
      return _handleProviderFailure(message,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          isRetry: isRetry,
          statusCode: 0);
    }

    // Report success/failure to ApiKeyManager (for admin key health tracking)
    if (response.statusCode == 200) {
      _handleProviderSuccess();
      final bodyString = utf8.decode(response.bodyBytes);
      final data = jsonDecode(bodyString);
      final content = data['choices']?[0]?['message']?['content'];
      if (content != null) return content;
    } else {
      return _handleProviderFailure(message,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          isRetry: isRetry,
          statusCode: response.statusCode);
    }
    return _getLocalResponse(message);
  }

  /// Gemini REST (Google AI Studio) variant of [_callOpenAI]. Uses the
  /// generateContent endpoint and translates the OpenAI-style system prompt
  /// and history into Gemini's systemInstruction/contents shape. Shares the
  /// same success/failure reporting and one-key retry as the OpenAI path.
  Future<String> _callGemini(String message,
      {String? systemPrompt,
      List<Map<String, String>>? history,
      int? maxTokens,
      bool isRetry = false,
      required String apiKey,
      required String baseUrl}) async {
    final model = _model;
    final url = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');

    final systemText = _systemPromptText(systemPrompt);
    final contents = <Map<String, dynamic>>[];
    if (history != null) {
      for (final h in history) {
        final content = h['content'];
        if (content == null || content.isEmpty) continue;
        final role = (h['role'] == 'assistant' || h['role'] == 'model')
            ? 'model'
            : 'user';
        contents.add({
          'role': role,
          'parts': [
            {'text': content}
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': message}
      ],
    });

    final payload = <String, dynamic>{'contents': contents};
    if (systemText.isNotEmpty) {
      payload['systemInstruction'] = {
        'parts': [
          {'text': systemText}
        ],
      };
    }
    if (maxTokens != null) {
      payload['generationConfig'] = {'maxOutputTokens': maxTokens};
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception {
      return _handleProviderFailure(message,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          isRetry: isRetry,
          statusCode: 0);
    }

    if (response.statusCode == 200) {
      _handleProviderSuccess();
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) return text as String;
    } else {
      return _handleProviderFailure(message,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          isRetry: isRetry,
          statusCode: response.statusCode);
    }
    return _getLocalResponse(message);
  }

  /// Shared default teacher system prompt (or the caller's override), used by
  /// both the OpenAI-compatible and Gemini request paths.
  String _systemPromptText(String? systemPrompt) {
    if (systemPrompt != null) return systemPrompt;
    final userName = HiveService.getUserName();
    return 'You are Keshab, an AI English teacher for Bengali speakers. '
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
        '7. Address the student by name when possible.';
  }

  void _handleProviderSuccess() {
    if (HiveService.getUseApiKeyManager() && _currentAdminKey != null) {
      ApiKeyManager.instance.reportSuccess(_currentAdminKey!);
    }
  }

  /// Shared failure path for both providers: put the failed key on cooldown,
  /// then auto-retry once with the next healthy key when admin keys are enabled.
  Future<String> _handleProviderFailure(String message,
      {String? systemPrompt,
      List<Map<String, String>>? history,
      int? maxTokens,
      required bool isRetry,
      required int statusCode}) async {
    if (HiveService.getUseApiKeyManager() && _currentAdminKey != null) {
      ApiKeyManager.instance
          .reportFailure(_currentAdminKey!, statusCode, 'conversation', '');
    }
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
