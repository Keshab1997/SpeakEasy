import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../../../services/tts_service.dart';

class BanglishTranslatorScreen extends ConsumerStatefulWidget {
  const BanglishTranslatorScreen({super.key});

  @override
  ConsumerState<BanglishTranslatorScreen> createState() => _BanglishTranslatorScreenState();
}

class _BanglishTranslatorScreenState extends ConsumerState<BanglishTranslatorScreen> {
  final _inputController = TextEditingController();
  final _tts = TtsService();
  final _aiService = AIService();

  bool _isLoading = false;
  bool _isSpeaking = false;
  String? _translation;
  List<WordBreakdown> _wordBreakdowns = [];
  String? _ruleSummary;
  String? _tensePattern;
  String? _banglaExplanation;
  List<String> _moreExamples = [];
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please write something in Bangla or Banglish.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _translation = null;
      _wordBreakdowns = [];
      _ruleSummary = null;
      _tensePattern = null;
      _banglaExplanation = null;
      _moreExamples = [];
    });

    try {
      final systemPrompt = '''
You are a Bangla/Banglish-to-English translator and English grammar teacher.

The user can write in either Bangla (Bengali script) or Banglish (Bengali words using English alphabets).
Example Bangla: "আমি স্কুল যাবো"
Example Banglish: "ami school jabo"

The user can write anything — a single word, a sentence, or a long paragraph/story.

Your task:
1. Translate the entire input to correct English.
2. Break down each English word with:
   - The word itself
   - Its grammar role (Subject/Verb/Object/Preposition/Auxiliary Verb/Main Verb/etc.)
   - Its Bangla meaning
   - Why it is used in this position — explain in simple Bangla
3. Identify the tense or grammar pattern used.
4. Give 2-3 more examples of the same pattern.

Respond ONLY in this exact JSON format, no other text:
{
  "translation": "The correct English sentence",
  "words": [
    {
      "word": "I",
      "role": "Subject (কর্তা)",
      "banglaMeaning": "আমি",
      "explanation": "বাংলায় বলি 'আমি যাবো' — English এ sentence শুরু হয় Subject দিয়ে। 'I' হলো 1st person singular subject।"
    }
  ],
  "tense": "Future Tense (ভবিষ্যৎ কাল)",
  "pattern": "Subject + will + verb (base form) + object",
  "banglaExplanation": "বাংলায় যখন 'বো/বে/বি' থাকে (যাবো, খাবো, করবো) → English এ 'will + verb' ব্যবহার করো।",
  "moreExamples": [
    "সে আসবে → He will come",
    "তারা খাবে → They will eat",
    "আমরা পড়বো → We will study"
  ]
}
''';

      final response = await _aiService.sendMessageWithSystem(
        input,
        systemPrompt: systemPrompt,
      );

      final jsonStr = _extractJson(response);
      if (jsonStr == null) {
        setState(() => _error = 'Invalid response format. Please try again.');
        return;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        setState(() => _error = 'Could not parse the response. Please try again.');
        return;
      }

      setState(() {
        _translation = data['translation'] as String?;
        _ruleSummary = data['tense'] as String?;
        _tensePattern = data['pattern'] as String?;
        _banglaExplanation = data['banglaExplanation'] as String?;
        _moreExamples = (data['moreExamples'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (data['words'] != null) {
          _wordBreakdowns = (data['words'] as List<dynamic>)
              .map((w) => WordBreakdown(
                    word: w['word'] as String? ?? '',
                    role: w['role'] as String? ?? '',
                    banglaMeaning: w['banglaMeaning'] as String? ?? '',
                    explanation: w['explanation'] as String? ?? '',
                  ))
              .toList();
        }
      });

      // Auto-save to history
      try {
        await HiveService.saveTranslation({
          'input': input,
          'translation': _translation ?? '',
          'tense': _ruleSummary ?? '',
          'pattern': _tensePattern ?? '',
          'date': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Silently fail — history save is non-critical
      }
    } catch (e) {
      setState(() => _error = e.toString().contains('API_KEY_MISSING')
          ? 'AI API key is not configured. Please add an API key in Settings.'
          : 'Translation failed. Please check your internet connection and try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Extracts the first valid JSON object from text
  String? _extractJson(String text) {
    final start = text.indexOf('{');
    if (start == -1) return null;

    var braceCount = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\' && inString) {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') {
        braceCount++;
      } else if (ch == '}') {
        braceCount--;
        if (braceCount == 0) {
          return text.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  void _speakTranslation() {
    if (_translation == null || _translation!.isEmpty) return;
    setState(() => _isSpeaking = true);
    _tts.speak(_translation!);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _copyTranslation() {
    if (_translation == null || _translation!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _translation!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translation copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAndTryAnother() {
    _inputController.clear();
    setState(() {
      _translation = null;
      _wordBreakdowns = [];
      _ruleSummary = null;
      _tensePattern = null;
      _banglaExplanation = null;
      _moreExamples = [];
      _error = null;
    });
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _TranslationHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Banglish Translator',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
            tooltip: 'Revision History',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'How to use',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputSection(theme, isDark),
              const SizedBox(height: 16),
              _buildTranslateButton(theme),
              const SizedBox(height: 20),
              if (_error != null) _buildErrorCard(theme, isDark),
              if (_isLoading) _buildLoadingIndicator(theme),
              if (_translation != null && !_isLoading) ...[
                _buildTranslationResult(theme, isDark),
                const SizedBox(height: 20),
                if (_wordBreakdowns.isNotEmpty) ...[
                  _buildWordBreakdownSection(theme, isDark),
                  const SizedBox(height: 20),
                ],
                if (_ruleSummary != null) ...[
                  _buildRuleSummaryCard(theme, isDark),
                  const SizedBox(height: 20),
                ],
                _buildActionButtons(theme),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Write in Bangla / Banglish',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _inputController,
              maxLines: null,
              minLines: 3,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Bangla / Banglish e likho... choto boro jekono sentence ba golpo likhte paro',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                filled: false,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _translate(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _translate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.translate_rounded, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Translate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Translating & analyzing grammar...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationResult(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'CORRECT ENGLISH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _speakTranslation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyTranslation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _translation!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordBreakdownSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.abc_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Word-by-Word Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _wordBreakdowns.map((w) {
            return GestureDetector(
              onTap: () => _showWordDetailDialog(context, w, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  w.word,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap any word to see its grammar role & explanation',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildRuleSummaryCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '📌 Rule টা কী?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_ruleSummary != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ruleSummary!,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_tensePattern != null) ...[
            Text(
              'Pattern:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Text(
                _tensePattern!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_banglaExplanation != null) ...[
            Text(
              _banglaExplanation!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (_moreExamples.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text(
              'আরো উদাহরণ:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ..._moreExamples.map((example) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          example,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _clearAndTryAnother,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Another'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showWordDetailDialog(BuildContext context, WordBreakdown word, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      word.word,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isSpeaking = true);
                      _tts.speak(word.word);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _isSpeaking = false);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildDetailRow('Grammar Role', word.role, Icons.category_rounded),
              const SizedBox(height: 12),
              _buildDetailRow('বাংলায় মানে', word.banglaMeaning, Icons.translate_rounded),
              const SizedBox(height: 12),
              _buildDetailRow('কেন এখানে বসেছে', word.explanation, Icons.psychology_rounded),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('How to Use', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Write any Bangla or Banglish sentence in the text field.',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            SizedBox(height: 8),
            Text(
              '2. Examples: "ami school jabo" or "আমি স্কুল যাবো"',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            SizedBox(height: 8),
            Text(
              '3. Tap "Translate" to get:',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Correct English translation', style: TextStyle(fontSize: 13, height: 1.6)),
                  Text('• Word-by-word grammar breakdown', style: TextStyle(fontSize: 13, height: 1.6)),
                  Text('• Tense & rule explanation in Bangla', style: TextStyle(fontSize: 13, height: 1.6)),
                  Text('• More examples of the same pattern', style: TextStyle(fontSize: 13, height: 1.6)),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '4. Tap any word chip to see detailed grammar role.',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            SizedBox(height: 8),
            Text(
              '5. Use 🔊 to hear pronunciation & 📋 to copy.',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class WordBreakdown {
  final String word;
  final String role;
  final String banglaMeaning;
  final String explanation;

  WordBreakdown({
    required this.word,
    required this.role,
    required this.banglaMeaning,
    required this.explanation,
  });
}

// ── Translation History Screen ──

class _TranslationHistoryScreen extends StatefulWidget {
  const _TranslationHistoryScreen();

  @override
  State<_TranslationHistoryScreen> createState() => _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState extends State<_TranslationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = HiveService.getTranslationHistory();
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry(int index) async {
    await HiveService.deleteTranslation(index);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will delete all saved translations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HiveService.clearTranslationHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Revision History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No translations yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your translated sentences will appear here\nfor revision later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final input = entry['input'] as String? ?? '';
                    final translation = entry['translation'] as String? ?? '';
                    final tense = entry['tense'] as String? ?? '';
                    final pattern = entry['pattern'] as String? ?? '';
                    final dateStr = entry['date'] as String? ?? '';
                    final date = DateTime.tryParse(dateStr);

                    return Dismissible(
                      key: Key('history_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteEntry(index),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main content row
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.translate_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          input,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          translation,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: AppColors.primary,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _deleteEntry(index),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (tense.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tense,
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (pattern.isNotEmpty)
                                    Text(
                                      pattern,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (date != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(date),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}