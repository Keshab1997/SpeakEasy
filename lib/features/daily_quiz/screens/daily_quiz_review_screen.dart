import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/speech_service.dart';
import '../../../services/tts_service.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';

/// Post-completion Spoken English review & pronunciation screen.
///
/// Displays every attempted question with native TTS playback ("🔊 Listen") and
/// live speech recognition ("🎤 Speak & Check") so learners actively speak every
/// sentence out loud instead of merely reading silently.
class DailyQuizReviewScreen extends ConsumerStatefulWidget {
  const DailyQuizReviewScreen({super.key});

  @override
  ConsumerState<DailyQuizReviewScreen> createState() =>
      _DailyQuizReviewScreenState();
}

class _DailyQuizReviewScreenState extends ConsumerState<DailyQuizReviewScreen> {
  final TtsService _tts = TtsService();
  final SpeechService _speech = SpeechService();

  String? _listeningQuestionId;
  final Map<String, String> _spokenTextByQuestion = {};
  final Map<String, int> _matchScoreByQuestion = {};

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

  Future<void> _toggleSpeakCheck(
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
    final quiz = ref.watch(dailyQuizProvider).quiz;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (quiz == null || quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📖 Quiz Review & Speaking'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('No quiz data available to review.'),
        ),
      );
    }

    final answerById = <String, DailyQuizAnswer>{
      for (final a in quiz.answers) a.questionId: a,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Review & Speak Out Loud'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listen to natural native pronunciation and practice speaking each sentence aloud.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ...quiz.questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                final answer = answerById[question.id];
                final correctSentence = question.correctAnswer >= 0 &&
                        question.correctAnswer < question.options.length
                    ? question.options[question.correctAnswer]
                    : '';

                return _ReviewQuestionCard(
                  index: index,
                  question: question,
                  answer: answer,
                  isDark: isDark,
                  isListening: _listeningQuestionId == question.id,
                  spokenText: _spokenTextByQuestion[question.id],
                  matchScore: _matchScoreByQuestion[question.id],
                  onListen: () => _tts.speak(correctSentence),
                  onSpeak: () => _toggleSpeakCheck(question, correctSentence),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single question's review & speaking card.
class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final DailyQuizQuestion question;
  final DailyQuizAnswer? answer;
  final bool isDark;
  final bool isListening;
  final String? spokenText;
  final int? matchScore;
  final VoidCallback onListen;
  final VoidCallback onSpeak;

  const _ReviewQuestionCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.isDark,
    required this.isListening,
    required this.spokenText,
    required this.matchScore,
    required this.onListen,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = answer?.isCorrect ?? false;
    final answered = answer != null;

    final correctText = _optionText(question, question.correctAnswer);
    final selectedText = _userAnswerText(question, answer);

    final statusColor = isCorrect ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? 'Correct' : (answered ? 'Wrong' : 'Skipped'),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (answer != null)
                Text(
                  '${answer!.timeTaken}s',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            question.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          _AnswerRow(
            label: 'Your answer',
            text: selectedText,
            color: isCorrect ? AppColors.success : AppColors.error,
            icon: isCorrect ? Icons.check : Icons.close,
            isDark: isDark,
          ),
          const SizedBox(height: 8),

          if (!isCorrect)
            _AnswerRow(
              label: 'Correct answer',
              text: correctText,
              color: AppColors.success,
              icon: Icons.check,
              isDark: isDark,
            ),
          const SizedBox(height: 12),

          // Listen & Speak Aloud action bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onListen,
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Listen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onSpeak,
                icon: Icon(
                  isListening ? Icons.stop_circle_outlined : Icons.mic_rounded,
                  size: 18,
                ),
                label: Text(isListening ? 'Stop' : 'Speak & Check'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isListening ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          if (spokenText != null && spokenText!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                matchScore != null
                    ? '🎤 "$spokenText" · Pronunciation Match: $matchScore%'
                    : '🎤 Listening: "$spokenText"...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (question.explanation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _optionText(DailyQuizQuestion q, int index) {
    if (q.options.isNotEmpty && index >= 0 && index < q.options.length) {
      return q.options[index];
    }
    return 'Option ${index + 1}';
  }

  String _userAnswerText(DailyQuizQuestion q, DailyQuizAnswer? answer) {
    if (answer == null) return 'Not answered';
    if (answer.selectedAnswer != null) {
      return _optionText(q, answer.selectedAnswer!);
    }
    return 'Not answered';
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _AnswerRow({
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label:  ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.92)
                          : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
