import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hive_service.dart';

class AIService {
  static final AIService _instance = AIService._();
  factory AIService() => _instance;
  AIService._();

  String get _apiKey {
    final active = HiveService.getActiveAiKey();
    return active?['key'] as String? ?? '';
  }

  String get _baseUrl {
    final active = HiveService.getActiveAiKey();
    return active?['baseUrl'] as String? ?? 'https://api.chatanywhere.tech/v1';
  }

  String get _model {
    final active = HiveService.getActiveAiKey();
    return active?['model'] as String? ?? 'gpt-4o-mini';
  }

  Future<List<Map<String, dynamic>>> fetchFreeOpenRouterModels() async {
    try {
      final url = Uri.parse('https://openrouter.ai/api/v1/models?sort=latency-low-to-high');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
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
    if (_apiKey.isEmpty) throw Exception('API_KEY_MISSING');

    try {
      return await _callOpenAI(message);
    } catch (e) {
      if (e.toString().contains('API_KEY_MISSING')) rethrow;
      throw Exception('API_CALL_FAILED');
    }
  }

  Future<String> sendMessageWithSystem(String message, {String? systemPrompt, List<Map<String, String>>? history, int? maxTokens}) async {
    if (_apiKey.isEmpty) throw Exception('API_KEY_MISSING');

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
          'You are a friendly AI English teacher named Keshab. '
          '${userName.isNotEmpty ? "Your student's name is $userName. " : ""}'
          'Your job is to help the student learn and practice English in a natural, fun way. '
          'The student can ask questions in English or Bangla (Bengali). '
          'IMPORTANT: Always respond in English first, then immediately provide the Bangla translation below. '
          'Format your response like this:\n'
          '---\n'
          '[Your English response here]\n\n'
          'বাংলা: [Bangla translation]\n'
          '---\n'
          'When correcting grammar, first show the correction in English, then explain in Bangla. '
          'When introducing new vocabulary, give the English word with meaning and example in English, '
          'then translate the example to Bangla. '
          'Keep responses friendly, concise, and encouraging. '
          'Always address the student by name when possible.'
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
