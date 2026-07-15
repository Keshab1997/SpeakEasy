import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final TranslationService _instance = TranslationService._();
  factory TranslationService() => _instance;
  TranslationService._();

  /// Translate [text] between [fromLang] and [toLang] using MyMemory API.
  /// Returns translated string on success, null on failure.
  Future<String?> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(text)}'
        '&langpair=$fromLang|$toLang',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final responseData = data['responseData'] as Map<String, dynamic>?;
        if (responseData != null) {
          final translated = responseData['translatedText'] as String?;
          if (translated != null && translated.isNotEmpty) {
            return translated;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
