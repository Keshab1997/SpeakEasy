import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_key_manager.dart';
import 'hive_service.dart';

class AIService {
  static final AIService _instance = AIService._();
  factory AIService() => _instance;
  AIService._();

  /// Returns key from ApiKeyManager if admin keys are enabled, else user's own key.
  String? get _adminKey {
    final keyData = ApiKeyManager.instance.getNextKey();
    return keyData?.key;
  }

  String? get _adminBaseUrl {
    final keyData = ApiKeyManager.instance.getNextKey();
    return keyData?.baseUrl;
  }

  String? get _adminModel {
    final keyData = ApiKeyManager.instance.getNextKey();
    return keyData?.model;
  }

  String get _apiKey {
    if (HiveService.getUseApiKeyManager()) {
      return _adminKey ?? '';
    }
    final active = HiveService.getActiveAiKey();
    return active?['key'] as String? ?? '';
  }

  String get _baseUrl {
    if (HiveService.getUseApiKeyManager()) {
      return _adminBaseUrl ?? 'https://openrouter.ai/api/v1';
    }
    final active = HiveService.getActiveAiKey();
    return active?['baseUrl'] as String? ?? 'https://api.chatanywhere.tech/v1';
  }

  String get _model {
    if (HiveService.getUseApiKeyManager()) {
      return _adminModel ?? 'gpt-4o-mini';
    }
    final active = HiveService.getActiveAiKey();
    return active?['model'] as String? ?? 'gpt-4o-mini';
  }

  /// Fetch free models from OpenRouter.
  /// If [apiKey] is provided, uses it; otherwise peeks at admin key pool or user key.
  Future<List<Map<String, dynamic>>> fetchFreeOpenRouterModels({String? apiKey}) async {
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

      final url = Uri.parse('https://openrouter.ai/api/v1/models?sort=latency-low-to-high');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $keyForFetch',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final allModels = data['data'] as List<dynamic>? ?? [];
        final free = allModels.where((m) {
          final map = m as Map<String, dynamic>;
          final pricing = map['pricing'] as Map<String, dynamic>? ?? {};
          final modality = (map['architecture'] as Map<String, dynamic>? ?? {})['modality'] as String? ?? '';
          return modality == 'text->text'
              && pricing['prompt'] == '0'
              && pricing['completion'] == '0';
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
    if (_apiKey.isEmpty) return false;
    try {
      final url = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [{'role': 'user', 'content': 'Hi'}],
          'max_tokens': 5,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> sendMessage(String message) async {
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

  Future<String> sendMessageWithSystem(String message, {String? systemPrompt, List<Map<String, String>>? history, int? maxTokens}) async {
    if (_apiKey.isEmpty) {
      if (HiveService.getUseApiKeyManager()) {
        return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
      }
      throw Exception('API_KEY_MISSING');
    }

    try {
      return await _callOpenAI(message, systemPrompt: systemPrompt, history: history, maxTokens: maxTokens);
    } catch (e) {
      if (e.toString().contains('API_KEY_MISSING')) rethrow;
      throw Exception('API_CALL_FAILED');
    }
  }

  Future<String> _callOpenAI(String message, {String? systemPrompt, List<Map<String, String>>? history, int? maxTokens}) async {
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

    if (response.statusCode == 200) {
      final bodyString = utf8.decode(response.bodyBytes);
      final data = jsonDecode(bodyString);
      return data['choices']?[0]?['message']?['content'] ?? _getLocalResponse(message);
    }
    return _getLocalResponse(message);
  }

  String _getLocalResponse(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return "Hello! Great to hear from you. Let's start practicing English. Would you like to check grammar or talk about a topic?\n\nবাংলা: হ্যালো! তোমার কাছ থেকে শুনে很开心। চলো ইংরেজি চর্চা শুরু করি। তুমি কি গ্রামার চেক করতে চাও নাকি কোনো বিষয় নিয়ে কথা বলতে চাও?";
    } else if (lower.contains('grammar') || lower.contains('mistake')) {
      return "Write any sentence, and I will highlight grammar mistakes or suggest more natural alternatives!\n\nবাংলা: যেকোনো বাক্য লিখো, আমি গ্রামার ভুল দেখিয়ে দেব বা আরও স্বাভাবিক বিকল্প suggest করব!";
    } else if (lower.contains('vocabulary') || lower.contains('word')) {
      return "Learning new words daily is key! Try using new words in sentences. What word would you like to learn about?\n\nবাংলা: প্রতিদিন নতুন শব্দ শেখা খুবই গুরুত্বপূর্ণ! বাক্যে নতুন শব্দ ব্যবহার করার চেষ্টা করো। তুমি কোন শব্দ সম্পর্কে জানতে চাও?";
    } else if (lower.contains('fluency') || lower.contains('speak')) {
      return "To build fluency, try speaking out loud for 5 minutes every day. Use simple, correct sentences. Would you like to practice now?\n\nবাংলা: সাবলীল হতে প্রতিদিন ৫ মিনিট জোরে জোরে কথা বলার চেষ্টা করো। সহজ, সঠিক বাক্য ব্যবহার করো। এখনই প্র্যাকটিস করতে চাও?";
    } else if (lower.contains('how are you')) {
      return "I am doing great! How is your English learning journey going? Have you practiced today?\n\nবাংলা: আমি খুব ভালো আছি! তোমার ইংরেজি শেখার যাত্রা কেমন চলছে? আজ কি প্র্যাকটিস করেছ?";
    }
    return "That's interesting! Keep practicing. Try to use complete sentences. How can I help you improve your English today?\n\nবাংলা: এটা মজার! প্র্যাকটিস চালিয়ে যাও। সম্পূর্ণ বাক্য ব্যবহার করার চেষ্টা করো। আজ আমি তোমার ইংরেজি উন্নতিতে কীভাবে সাহায্য করতে পারি?";
  }
}
