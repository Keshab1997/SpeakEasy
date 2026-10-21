import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/speech_service.dart';
import '../../../services/tts_service.dart';
import '../models/daily_quiz_model.dart';
import '../providers/daily_quiz_provider.dart';

/// Dedicated Spoken Mistake Bank ("ভুল হওয়া Spoken বাক্য").
///
/// Automatically collects every Daily Quiz question the learner got wrong or
/// timed out on, letting them listen to native pronunciation, practice speaking
/// aloud with instant pronunciation match feedback, and mark sentences mastered.
class DailyQuizWeakSentencesScreen extends ConsumerStatefulWidget {
  const DailyQuizWeakSentencesScreen({super.key});

  @override
  ConsumerState<DailyQuizWeakSentencesScreen> createState() =>
      _DailyQuizWeakSentencesScreenState();
}

class _DailyQuizWeakSentencesScreenState
    extends ConsumerState<DailyQuizWeakSentencesScreen> {
  final TtsService _tts = TtsService();
  final SpeechService _speech = SpeechService();

  String? _listeningQuestionId;
  final Map<String, String> _spokenTextByQuestion = {};
  final Map<String, int> _matchScoreByQuestion = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dailyQuizProvider.notifier).reloadWeakQuestions();
      }
    });
  }

  @override
  void dispose() {
    _tts.dispose();
    _speech.dispose();
    super.dispose();
  }

  int _computeSpokenSimilarity(String target, String spoken) {
    List<String> normalize(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final targetWords = normalize(target);
    final spokenWords = normalize(spoken);
    if (targetWords.isEmpty || spokenWords.isEmpty) return 0;

    final spokenSet = spokenWords.toSet();
    final matched = targetWords.where(spokenSet.contains).length;
    return ((matched / targetWords.length) * 100).round().clamp(0, 100);
  }

  Future<void> _togglePracticeSpeaking(
    DailyQuizQuestion question,
    String targetSentence,
  ) async {
    if (_listeningQuestionId == question.id) {
      await _speech.stopListening();
      if (mounted) setState(() => _listeningQuestionId = null);
      return;
    }

    await _tts.stop();
    setState(() {
      _listeningQuestionId = question.id;
      _spokenTextByQuestion[question.id] = '';
    });

    await _speech.startListening(
      onPartialResult: (partial) {
        if (!mounted) return;
        setState(() {
          _spokenTextByQuestion[question.id] = partial;
        });
      },
      onResult: (finalWords) {
        if (!mounted) return;
        final score = _computeSpokenSimilarity(targetSentence, finalWords);
        setState(() {
          _spokenTextByQuestion[question.id] = finalWords;
          _matchScoreByQuestion[question.id] = score;
          _listeningQuestionId = null;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _listeningQuestionId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Microphone unavailable')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weakQuestions = ref.watch(dailyQuizProvider).weakQuestions;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('📌 Practice Weak Sentences (${weakQuestions.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: weakQuestions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌟', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      Text(
                        'সব বাক্য আয়ত্তে আছে!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daily Quiz-এ কোনো প্রশ্নে ভুল বা Time-out হলে সেই বাক্যগুলো এখানে অটোমেটিক জমা হবে—যাতে পরে শুনে ও মুখে বলে ঝালিয়ে নিতে পারেন।',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: weakQuestions.length,
                itemBuilder: (context, index) {
                  final q = weakQuestions[index];
                  final correctSentence =
                      q.correctAnswer >= 0 && q.correctAnswer < q.options.length
                          ? q.options[q.correctAnswer]
                          : '';
                  final isListening = _listeningQuestionId == q.id;
                  final spoken = _spokenTextByQuestion[q.id];
                  final matchScore = _matchScoreByQuestion[q.id];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.question,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  correctSentence,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            '💡 ${q.explanation}',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.black87,
                            ),
                          ),
                        ],
                        if (spoken != null && spoken.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              matchScore != null
                                  ? '🎤 "$spoken" · Match: $matchScore%'
                                  : '🎤 Listening: "$spoken"...',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.lightBlue.shade200
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _tts.speak(correctSentence),
                              icon: const Icon(Icons.volume_up_rounded,
                                  size: 18),
                              label: const Text('Listen'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _togglePracticeSpeaking(
                                q,
                                correctSentence,
                              ),
                              icon: Icon(
                                isListening
                                    ? Icons.stop_circle_outlined
                                    : Icons.mic_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isListening ? 'Stop' : 'Speak & Check',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isListening
                                    ? AppColors.error
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                ref
                                    .read(dailyQuizProvider.notifier)
                                    .markWeakQuestionMastered(q.question);
                              },
                              icon: const Icon(Icons.done_all_rounded,
                                  size: 18),
                              label: const Text('Mastered'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
