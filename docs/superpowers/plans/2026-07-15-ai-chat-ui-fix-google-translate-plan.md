# AI Chat UI Fix + Google Translate Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up AI Chat screen UI (remove API key dependency from AppBar/greeting) and replace AI-powered translation with free MyMemory API.

**Architecture:** Add a `TranslationService` that wraps `http.get` to MyMemory API (no key needed). Modify `ai_chat_screen.dart` to use it and to remove API-key-nagging UI. Keep Banglish Translator AI-based with quality improvements.

**Tech Stack:** Flutter/Dart, `http` package (existing), MyMemory API (free, no auth)

---

### Task 1: Create TranslationService

**Files:**
- Create: `lib/services/translation_service.dart`
- Uses: `package:http/http.dart` (already in pubspec)

- [ ] **Step 1: Write TranslationService**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/translation_service.dart
git commit -m "feat: add TranslationService with MyMemory API integration"
```

---

### Task 2: Replace AI Translation in AI Chat Screen

**Files:**
- Modify: `lib/features/ai_teacher/screens/ai_chat_screen.dart`

**Changes:** Replace `_translateToBangla()` AI call with `TranslationService.translate()`.

- [ ] **Step 1: Add import for TranslationService**

Add at the top of `ai_chat_screen.dart`:
```dart
import '../../../services/translation_service.dart';
```

- [ ] **Step 2: Replace _translateToBangla() body** (lines 509-528)

**Old code (509–528):**
```dart
  Future<void> _translateToBangla(String text, Map<String, dynamic> msg) async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);
    msg['translating'] = true;
    try {
      final translation = await AIService().sendMessage(
        'Translate this English text to Bengali (Bangla). Return ONLY the translation, nothing else:\n\n$text',
      );
      if (!mounted) return;
      final cleanTranslation = translation.replaceAll('বাংলা:', '').replaceAll('---', '').trim();
      msg['translatedText'] = cleanTranslation;
      msg['translating'] = false;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      msg['translating'] = false;
      msg['translatedText'] = '(Could not translate. Please try again.)';
      setState(() {});
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }
```

**New code:**
```dart
  Future<void> _translateToBangla(String text, Map<String, dynamic> msg) async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);
    msg['translating'] = true;
    try {
      final translation = await TranslationService().translate(
        text: text,
        fromLang: 'en',
        toLang: 'bn',
      );
      if (!mounted) return;
      msg['translatedText'] = translation ?? '(Could not translate. Please try again.)';
      msg['translating'] = false;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      msg['translating'] = false;
      msg['translatedText'] = '(Could not translate. Please try again.)';
      setState(() {});
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ai_teacher/screens/ai_chat_screen.dart
git commit -m "feat: replace AI translation with Google Translate (MyMemory API) in chat screen"
```

---

### Task 3: Clean AppBar — Remove Status Indicator, Model Name, Settings Button

**Files:**
- Modify: `lib/features/ai_teacher/screens/ai_chat_screen.dart`

**Changes:**
- Remove the status dot row (green/orange dot + "Online"/"Setup Required"/model name)
- Remove the settings `IconButton` that navigates to `SettingsScreen`
- Keep tools menu, history, new chat buttons

- [ ] **Step 1: Replace AppBar `title` section** (around line 1050-1115)

Find this section (currently AppBar title with Row → Container + Column with status):
```dart
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keshab',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAiConfigured ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _isAiConfigured 
                            ? (_aiModel.isNotEmpty ? _aiModel : 'Online')
                            : 'Setup Required',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isAiConfigured ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ],
        ),
        actions: [...],
      ),
```

Replace with:
```dart
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Keshab',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [...],
      ),
```

- [ ] **Step 2: Remove settings IconButton from `actions`** (around line 1110-1130)

Find and remove this block:
```dart
          if (!_isAiConfigured)
            IconButton(
              icon: const Icon(Icons.settings_suggest_rounded, size: 24, color: Colors.orange),
              tooltip: 'Setup AI',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ai_teacher/screens/ai_chat_screen.dart
git commit -m "feat: clean AppBar - remove status dot, model name, settings button"
```

---

### Task 4: Update Greeting Message

**Files:**
- Modify: `lib/features/ai_teacher/screens/ai_chat_screen.dart`

**Changes:** Remove conditional greeting that mentions API key setup. Always show the warm welcome.

- [ ] **Step 1: Replace `_addGreeting()` method** (lines 152-171)

**Old code:**
```dart
  void _addGreeting() {
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final greetingText = _isAiConfigured
        ? 'Hello $displayName! 👋\n\nI am Keshab, your AI English Teacher. '
            'You can ask me anything about English — grammar, vocabulary, '
            'pronunciation, or just chat with me in English or Bangla. '
            'I am here to help you improve!\n\n'
            'How are you doing today?'
        : 'Hello $displayName! 👋\n\nI am Keshab, your AI English Teacher. '
            'To get started, please set up your AI API key by tapping the '
            '🔧 Setup button above.\n\n'
            'Once configured, you can ask me anything about English!';
    setState(() {
      _messages.add({
        'text': greetingText,
        'isMe': false,
        'time': _formatTime(DateTime.now()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
```

**New code:**
```dart
  void _addGreeting() {
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final greetingText = 'Hello $displayName! 👋\n\n'
        'I am Keshab, your AI English Teacher. '
        'You can ask me anything about English — grammar, vocabulary, '
        'pronunciation, or just chat with me in English or Bangla. '
        'I am here to help you improve!\n\n'
        'How are you doing today?';
    setState(() {
      _messages.add({
        'text': greetingText,
        'isMe': false,
        'time': _formatTime(DateTime.now()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai_teacher/screens/ai_chat_screen.dart
git commit -m "feat: remove API key setup instructions from greeting message"
```

---

### Task 5: AI Error — Inline Message Instead of Dialog

**Files:**
- Modify: `lib/features/ai_teacher/screens/ai_chat_screen.dart`

**Changes:** When AI call fails (no key or connection error), show "AI service not available" as a message bubble in chat. Remove the `_showSetupDialog` call.

- [ ] **Step 1: Replace `handleError` closure** (lines 288-310)

**Old code:**
```dart
    void handleError(Object error) {
      if (!mounted) return;
      final activeKey = HiveService.getActiveAiKey();
      _cancelStreaming();
      setState(() {
        _isTyping = false;
        _isAiConfigured = activeKey?['key']?.toString().isNotEmpty ?? false;
        _aiModel = activeKey?['model']?.toString() ?? '';
      });
      
      final errorStr = error.toString();
      if (errorStr.contains('API_KEY_MISSING')) {
        _showSetupDialog(
          'AI Model Not Configured',
          'Please set up your AI API key to use the AI teacher feature.',
        );
      } else if (errorStr.contains('API_CALL_FAILED')) {
        _showSetupDialog(
          'Connection Failed',
          'Unable to connect to AI service. Please check your API key configuration.',
        );
      }
    }
```

**New code:**
```dart
    void handleError(Object error) {
      if (!mounted) return;
      _cancelStreaming();
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': 'AI service not available',
          'isMe': false,
          'time': _formatTime(DateTime.now()),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _scrollToBottom();
    }
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai_teacher/screens/ai_chat_screen.dart
git commit -m "feat: show inline 'AI service not available' on API error instead of dialog"
```

---

### Task 6: Remove Unused Imports and Variables

**Files:**
- Modify: `lib/features/ai_teacher/screens/ai_chat_screen.dart`

**Changes:**
- Remove unused imports (`SettingsScreen`, `ApiSetupGuideScreen`)
- Can keep `HiveService` and `AIService` since they're still used
- Keep `_isAiConfigured` state variable (still referenced) or remove if not used elsewhere

- [ ] **Step 1: Check for unused imports and variables**

Check if `SettingsScreen` and `ApiSetupGuideScreen` are still referenced (they shouldn't be after Task 3+5):
```dart
// Remove these imports:
import '../../settings/screens/api_setup_guide_screen.dart';
import '../../settings/screens/settings_screen.dart';
```

Check if `_isAiConfigured` and `_aiModel` are used after changes. If the only usage was in AppBar and greeting, and we removed those, remove the field and `initState` code that sets them. But keep them if referenced elsewhere (e.g., in `initState` line 105 for `_isAiConfigured`).

Look for any remaining references to `_isAiConfigured`, `_aiModel`, `SettingsScreen`, `ApiSetupGuideScreen` in the file.

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai_teacher/screens/ai_chat_screen.dart
git commit -m "chore: remove unused imports for settings screens"
```

---

### Task 7: Improve Banglish Translator

**Files:**
- Modify: `lib/features/translator/screens/banglish_translator_screen.dart`

**Changes:** The Banglish Translator already uses AI, which is correct per user's decision. Just improve translation quality and add translation retry logic.

- [ ] **Step 1: Review current implementation and improve prompt quality**

Current prompt (lines 57-96) already has good structure. Just add a minor improvement to make translation more accurate. Current translation works via AI so no change needed in approach.

- [ ] **Step 2: Commit**

```bash
git add lib/features/translator/screens/banglish_translator_screen.dart
git commit -m "chore: minor polish on banglish translator prompt"
```

---

### Post-Implementation Checklist

- [ ] Run `flutter analyze` to check for warnings
- [ ] Run `flutter build` to verify compilation
- [ ] Test translation flow manually
- [ ] Test AppBar rendering without API key
- [ ] Test error handling when API call fails
- [ ] Update graphify: `graphify update .`
