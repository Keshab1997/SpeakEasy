import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';
import 'daily_quiz_result_screen.dart';

/// Play screen for Daily Quiz.
///
/// Displays one question at a time with a per-question countdown timer,
/// interactive option cards, answer feedback, and auto-advance.
class DailyQuizPlayScreen extends ConsumerStatefulWidget {
  const DailyQuizPlayScreen({super.key});

  @override
  ConsumerState<DailyQuizPlayScreen> createState() =>
      _DailyQuizPlayScreenState();
}

class _DailyQuizPlayScreenState extends ConsumerState<DailyQuizPlayScreen> {
  // ---------------------------------------------------------------------------
  // Timer & stopwatch
  // ---------------------------------------------------------------------------
  Timer? _countdownTimer;
  final Stopwatch _stopwatch = Stopwatch();

  int _remainingSeconds = 30;
  int _timeLimit = 30;

  // ---------------------------------------------------------------------------
  // Answer / feedback state
  // ---------------------------------------------------------------------------
  int? _selectedAnswer;
  bool _isAnswerChecked = false;
  bool _isCorrect = false;
  bool _isTimeOut = false;
  bool _isAutoAdvancing = false;
  DailyQuizQuestion? _answeredQuestion; // freeze question during feedback

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetForNewQuestion());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Question lifecycle helpers
  // ---------------------------------------------------------------------------

  /// Reset all local state and start timer / stopwatch for the current question.
  void _resetForNewQuestion() {
    final quiz = ref.read(dailyQuizProvider).quiz;
    if (quiz == null) return;

    final question =
        quiz.questions[ref.read(dailyQuizProvider).currentQuestionIndex];
    _timeLimit = question.timeLimit > 0 ? question.timeLimit : 30;

    _selectedAnswer = null;
    _isAnswerChecked = false;
    _isCorrect = false;
    _isTimeOut = false;
    _isAutoAdvancing = false;
    _answeredQuestion = null;
    _remainingSeconds = _timeLimit;

    _stopwatch..reset()..start();
    _startCountdown();
  }

  /// Start a 1 Hz countdown timer that decrements [_remainingSeconds].
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds = _timeLimit - _stopwatch.elapsed.inSeconds;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Answer / timeout handlers
  // ---------------------------------------------------------------------------

  /// Called when the user taps an option card.
  void _handleAnswerTap(int index) {
    if (_isAnswerChecked || _isAutoAdvancing) return;

    _countdownTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;

    final quiz = ref.read(dailyQuizProvider).quiz;
    if (quiz == null) return;
    final question =
        quiz.questions[ref.read(dailyQuizProvider).currentQuestionIndex];
    final isCorrect = index == question.correctAnswer;

    // Freeze the current question BEFORE provider advances the index
    _answeredQuestion = question;

    // Record the answer via provider (this advances currentQuestionIndex)
    ref.read(dailyQuizProvider.notifier).answerQuestion(index, elapsed);

    setState(() {
      _selectedAnswer = index;
      _isCorrect = isCorrect;
      _isAnswerChecked = true;
      _isAutoAdvancing = true;
    });

    // Wait 2 s so the user can see the feedback, then auto-advance
    Future.delayed(const Duration(seconds: 2), _autoAdvance);
  }

  /// Called when the countdown reaches zero.
  void _handleTimeout() {
    if (_isAutoAdvancing) return;

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;

    // Freeze the current question BEFORE provider advances the index
    final quiz = ref.read(dailyQuizProvider).quiz;
    if (quiz != null) {
      _answeredQuestion =
          quiz.questions[ref.read(dailyQuizProvider).currentQuestionIndex];
    }

    // Record the timeout answer via provider
    ref.read(dailyQuizProvider.notifier).timeoutQuestion(elapsed);

    setState(() {
      _isTimeOut = true;
      _isAnswerChecked = true;
      _isAutoAdvancing = true;
    });

    // Brief delay so the user sees the "Time's up!" message
    Future.delayed(const Duration(milliseconds: 1500), _autoAdvance);
  }

  /// Advance to the next question, or navigate to the result screen if the quiz
  /// is complete.
  void _autoAdvance() {
    if (!mounted) return;

    final state = ref.read(dailyQuizProvider);
    if (!state.isPlaying || state.quiz?.isCompleted == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
      );
    } else {
      setState(() => _resetForNewQuestion());
    }
  }

  // ---------------------------------------------------------------------------
  // Quit confirmation
  // ---------------------------------------------------------------------------

  Future<void> _showQuitDialog() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Quiz?'),
        content: const Text('Your progress will be saved. You can resume later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Quiz'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      Navigator.pop(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(dailyQuizProvider);
    final quiz = quizState.quiz;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- Loading / empty states ----------------------------------------------
    if (quizState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Daily Quiz'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (quiz == null || quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Daily Quiz'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No questions available', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Use answered question for feedback display (provider advances index)
  final displayQuestion = _isAnswerChecked && _answeredQuestion != null
      ? _answeredQuestion!
      : quiz.questions[quizState.currentQuestionIndex];
  final question = displayQuestion;

    // --- Main scaffold -------------------------------------------------------
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showQuitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Question ${quizState.currentQuestionIndex + 1}/${quiz.totalQuestions}',
          ),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // -- Timer bar --
            _buildTimerBar(theme),

            // -- Content --
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Type badge + timer badge
                    _buildHeaderRow(question),
                    const SizedBox(height: 20),

                    // Question card
                    _buildQuestionCard(question, theme),
                    const SizedBox(height: 24),

                    // Option cards
                    ...question.options.asMap().entries.map((entry) {
                      return _buildOptionCard(
                        entry.key,
                        entry.value,
                        question,
                        theme,
                        isDark,
                      );
                    }),

                    // Timeout message
                    if (_isTimeOut) _buildTimeoutMessage(theme),

                    // Explanation panel (not shown for timeouts – the timeout
                    // message is shown instead)
                    if (_isAnswerChecked && !_isTimeOut)
                      _buildExplanationPanel(question, theme, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  /// Shrinking timer bar with colour-coded remaining-seconds badge.
  Widget _buildTimerBar(ThemeData theme) {
    final fraction =
        _timeLimit > 0 ? (_remainingSeconds / _timeLimit).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (_remainingSeconds <= 5) {
      barColor = AppColors.error; // red
    } else if (_remainingSeconds <= 10) {
      barColor = AppColors.warning; // orange
    } else {
      barColor = AppColors.success; // green
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visual bar
        ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: SizedBox(
            height: 4,
            width: double.infinity,
            child: Stack(
              children: [
                Container(height: 4, color: Colors.grey.shade300),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 4,
                  width: MediaQuery.of(context).size.width * fraction,
                  color: barColor,
                ),
              ],
            ),
          ),
        ),
        // Seconds badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_remainingSeconds}s',
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Row with the question-type badge on the left.
  Widget _buildHeaderRow(DailyQuizQuestion question) {
    final typeLabel =
        question.type == 'vocabulary' ? '📖 Vocabulary' : '📝 Grammar';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary),
          ),
          child: Text(
            typeLabel,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  /// Gradient-backed question text card.
  Widget _buildQuestionCard(DailyQuizQuestion question, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: AppColors.primaryGradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        question.question,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// An interactive option card (A/B/C/D).
  Widget _buildOptionCard(
    int index,
    String option,
    DailyQuizQuestion question,
    ThemeData theme,
    bool isDark,
  ) {
    const letters = ['A', 'B', 'C', 'D'];
    final isSelected = _selectedAnswer == index;
    final isCorrectOption = index == question.correctAnswer;

    Color cardBgColor = theme.cardColor;
    Color borderColor =
        isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    double borderWidth = 1.0;
    Color letterBgColor = AppColors.primary;
    Color letterTextColor = Colors.white;
    Widget? suffixIcon;

    if (_isAnswerChecked) {
      if (isCorrectOption) {
        cardBgColor =
            isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50;
        borderColor = Colors.green;
        borderWidth = 2.0;
        letterBgColor = Colors.green;
        suffixIcon =
            const Icon(Icons.check_circle, color: Colors.green, size: 24);
      } else if (isSelected) {
        cardBgColor =
            isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50;
        borderColor = Colors.red;
        borderWidth = 2.0;
        letterBgColor = Colors.red;
        suffixIcon =
            const Icon(Icons.cancel, color: Colors.red, size: 24);
      } else {
        cardBgColor = theme.cardColor.withOpacity(0.6);
        borderColor =
            (isDark ? Colors.grey.shade600 : Colors.grey.shade300)
                .withOpacity(0.4);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _isAnswerChecked && (isCorrectOption || isSelected)
              ? [
                  BoxShadow(
                    color:
                        (isCorrectOption ? Colors.green : Colors.red)
                            .withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isAnswerChecked ? null : () => _handleAnswerTap(index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Letter circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: letterBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letters[index],
                        style: TextStyle(
                          color: letterTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Option text
                  Expanded(
                    child: Text(
                      option,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: _isAnswerChecked &&
                                (isCorrectOption || isSelected)
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _isAnswerChecked &&
                                !isCorrectOption &&
                                !isSelected
                            ? theme.textTheme.bodyLarge?.color
                                ?.withOpacity(0.5)
                            : null,
                      ),
                    ),
                  ),
                  // Suffix icon
                  if (suffixIcon != null) ...[
                    const SizedBox(width: 12),
                    suffixIcon,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Explanation panel shown after a correct / wrong answer.
  Widget _buildExplanationPanel(
    DailyQuizQuestion question,
    ThemeData theme,
    bool isDark,
  ) {
    final bgColor = _isCorrect
        ? (isDark ? const Color(0xFF1E3A1E) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF3A1E1E) : const Color(0xFFFFEBEE));
    final textColor = _isCorrect
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFE57373) : const Color(0xFFC62828));
    final icon =
        _isCorrect ? Icons.check_circle_outline : Icons.error_outline;
    final title =
        _isCorrect ? 'অসাধারণ! সঠিক উত্তর' : 'ভুল উত্তর হয়েছে';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCorrect
              ? (isDark
                    ? Colors.green.withOpacity(0.3)
                    : Colors.green.shade200)
              : (isDark
                    ? Colors.red.withOpacity(0.3)
                    : Colors.red.shade200),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'বিস্তারিত ব্যাখ্যা:',
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.explanation,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black87,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Timeout message shown when the countdown reaches zero.
  Widget _buildTimeoutMessage(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_off, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Text(
            "Time's up! ⏰",
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
