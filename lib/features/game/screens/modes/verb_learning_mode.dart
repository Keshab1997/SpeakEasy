import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/tts_service.dart';
import '../result_screen.dart';

// ─────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────

class _VerbEntry {
  final String v1, v2, v3, v4, v5;
  final String bangla;
  final String meaning;
  final String bnSentence;
  final String enSentence;
  final String explanation;

  const _VerbEntry({
    required this.v1,
    required this.v2,
    required this.v3,
    required this.v4,
    required this.v5,
    required this.bangla,
    required this.meaning,
    required this.bnSentence,
    required this.enSentence,
    required this.explanation,
  });

  factory _VerbEntry.fromJson(Map<String, dynamic> json) => _VerbEntry(
        v1: json['v1'] as String? ?? '',
        v2: json['v2'] as String? ?? '',
        v3: json['v3'] as String? ?? '',
        v4: json['v4'] as String? ?? '',
        v5: json['v5'] as String? ?? '',
        bangla: json['bangla'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        bnSentence: json['bn_sentence'] as String? ?? '',
        enSentence: json['en_sentence'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────
// Quiz Question Model
// ─────────────────────────────────────────────────────────────

class _QuizQuestion {
  final String question;
  final String correctAnswer;
  final List<String> options;
  final _VerbEntry verb;

  _QuizQuestion({
    required this.question,
    required this.correctAnswer,
    required this.options,
    required this.verb,
  });
}

// ─────────────────────────────────────────────────────────────
// Main Game Screen
// ─────────────────────────────────────────────────────────────

class VerbLearningModeScreen extends ConsumerStatefulWidget {
  const VerbLearningModeScreen({super.key});

  @override
  ConsumerState<VerbLearningModeScreen> createState() =>
      _VerbLearningModeScreenState();
}

class _VerbLearningModeScreenState
    extends ConsumerState<VerbLearningModeScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();

  // Game data
  List<_VerbEntry> _allVerbs = [];
  List<_VerbEntry> _sessionVerbs = [];
  int _currentVerbIndex = 0;
  bool _isLoading = true;
  // Learning phase
  bool _isLearningPhase = true;
  bool _showExplanation = false;

  // Quiz phase
  List<_QuizQuestion> _quizQuestions = [];
  int _currentQuizIndex = 0;
  String _selectedAnswer = '';
  bool _isQuizAnswered = false;
  bool _isQuizCorrect = false;

  // Scoring
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _streak = 0;
  int _bestStreak = 0;

  // Session config
  final int _totalVerbs = 10;

  // Animations
  late AnimationController _slideAnimCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;
  @override
  void initState() {
    super.initState();

    _slideAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimCtrl,
      curve: Curves.easeOutCubic,
    ));

    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeInOut),
    );

    _loadVerbs();
  }

  @override
  void dispose() {
    _slideAnimCtrl.dispose();
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVerbs() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/json/game/verb_game_data.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final verbsList = data['verbs'] as List<dynamic>;
      _allVerbs = verbsList
          .map((v) => _VerbEntry.fromJson(v as Map<String, dynamic>))
          .toList();

      _allVerbs.shuffle(Random());
      _sessionVerbs =
          _allVerbs.take(min(_totalVerbs, _allVerbs.length)).toList();

      // Start learning phase
      if (mounted) {
        setState(() => _isLoading = false);
        _slideAnimCtrl.forward();
        _speakCurrentVerb();
      }
    } catch (e) {
      debugPrint('Error loading verb data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _speakCurrentVerb() {
    if (_sessionVerbs.isEmpty) return;
    final verb = _sessionVerbs[_currentVerbIndex];
    _tts.speak(verb.v1);
  }

  // ── Navigate to next verb in learning phase ──
  void _goToNextVerb() {
    if (_currentVerbIndex < _sessionVerbs.length - 1) {
      setState(() {
        _currentVerbIndex++;
        _showExplanation = false;
      });
      _slideAnimCtrl.reset();
      _slideAnimCtrl.forward();
      _speakCurrentVerb();
    } else {
      // All verbs learned — start quiz!
      _startQuiz();
    }
  }

  void _goToPreviousVerb() {
    if (_currentVerbIndex > 0) {
      setState(() {
        _currentVerbIndex--;
        _showExplanation = false;
      });
      _slideAnimCtrl.reset();
      _slideAnimCtrl.forward();
      _speakCurrentVerb();
    }
  }

  void _toggleExplanation() {
    setState(() => _showExplanation = !_showExplanation);
  }

  void _startQuiz() {
    final random = Random();
    _quizQuestions = [];

    for (final verb in _sessionVerbs) {
      // Create a question about one of the verb forms
      final questionTypes = [
        _QuizQuestionType.v2,
        _QuizQuestionType.v3,
        _QuizQuestionType.meaning,
        _QuizQuestionType.v1,
      ];
      final qType = questionTypes[random.nextInt(questionTypes.length)];

      String question;
      String correctAnswer;

      switch (qType) {
        case _QuizQuestionType.v2:
          question = 'What is the past tense (V2) of "${verb.v1}"?';
          correctAnswer = verb.v2;
          break;
        case _QuizQuestionType.v3:
          question = 'What is the past participle (V3) of "${verb.v1}"?';
          correctAnswer = verb.v3;
          break;
        case _QuizQuestionType.meaning:
          question = 'What does "${verb.v1}" mean?';
          correctAnswer = verb.meaning;
          break;
        case _QuizQuestionType.v1:
          question = 'Which verb means "${verb.bangla}"?';
          correctAnswer = verb.v1;
          break;
      }

      // Generate distractors
      final distractors = _allVerbs
          .where((v) => v.v1 != verb.v1)
          .toList()
        ..shuffle(random);

      List<String> options;

      switch (qType) {
        case _QuizQuestionType.v2:
          options = [
            verb.v2,
            ...distractors.take(3).map((v) => v.v2),
          ];
          break;
        case _QuizQuestionType.v3:
          options = [
            verb.v3,
            ...distractors.take(3).map((v) => v.v3),
          ];
          break;
        case _QuizQuestionType.meaning:
          options = [
            verb.meaning,
            ...distractors.take(3).map((v) => v.meaning),
          ];
          break;
        case _QuizQuestionType.v1:
          options = [
            verb.v1,
            ...distractors.take(3).map((v) => v.v1),
          ];
          break;
      }

      options.shuffle(random);

      _quizQuestions.add(_QuizQuestion(
        question: question,
        correctAnswer: correctAnswer,
        options: options,
        verb: verb,
      ));
    }

    setState(() {
      _isLearningPhase = false;
      _currentQuizIndex = 0;
      _selectedAnswer = '';
      _isQuizAnswered = false;
    });
    _slideAnimCtrl.reset();
    _slideAnimCtrl.forward();
  }

  void _selectQuizAnswer(String answer) {
    if (_isQuizAnswered) return;
    setState(() => _selectedAnswer = answer);
  }

  void _submitQuizAnswer() {
    if (_selectedAnswer.isEmpty || _isQuizAnswered) return;

    final question = _quizQuestions[_currentQuizIndex];
    final isCorrect = _selectedAnswer == question.correctAnswer;

    setState(() {
      _isQuizAnswered = true;
      _isQuizCorrect = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      final streakBonus = (_streak - 1) * 2;
      _score += 10 + streakBonus;

      HapticFeedback.lightImpact();
      _scoreAnimCtrl.forward().then((_) => _scoreAnimCtrl.reverse());
    } else {
      _wrongCount++;
      _streak = 0;
      HapticFeedback.mediumImpact();
    }
  }

  void _goToNextQuiz() {
    if (_currentQuizIndex < _quizQuestions.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswer = '';
        _isQuizAnswered = false;
      });
      _slideAnimCtrl.reset();
      _slideAnimCtrl.forward();
    } else {
      _endGame();
    }
  }

  Future<void> _endGame() async {
    final int xpEarned = _score * 2 + (_bestStreak >= 3 ? 20 : 0);
    final int coinsEarned = _score + (_bestStreak >= 5 ? 15 : 0);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            correctAnswers: _correctCount,
            wrongAnswers: _wrongCount,
            earnedXP: xpEarned,
            earnedCoins: coinsEarned,
            gameMode: 'verbLearning',
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF58CC02)),
            )
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  if (_isLearningPhase) ...[
                    Expanded(child: _buildLearningPhase()),
                  ] else ...[
                    Expanded(child: _buildQuizPhase()),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    final total = _isLearningPhase ? _sessionVerbs.length : _quizQuestions.length;
    final current = _isLearningPhase ? _currentVerbIndex : _currentQuizIndex;
    final progress = total > 0 ? (current + 1) / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFFAFAFAF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 16,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: const Color(0xFF58CC02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        margin:
                            const EdgeInsets.only(top: 3, left: 6, right: 6, bottom: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFFC800), size: 28),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) => Transform.scale(
                  scale: _scoreAnim.value,
                  child: Text(
                    '$_score',
                    style: const TextStyle(
                      color: Color(0xFFFFC800),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LEARNING PHASE
  // ─────────────────────────────────────────────────────────

  Widget _buildLearningPhase() {
    if (_sessionVerbs.isEmpty) {
      return const Center(child: Text('No verbs loaded'));
    }

    final verb = _sessionVerbs[_currentVerbIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Learn the Verb',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFAFAFAF),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Verb name — large
          GestureDetector(
            onTap: () => _tts.speak(verb.v1),
            child: Row(
              children: [
                Text(
                  verb.v1.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4B4B4B),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.volume_up_rounded,
                    color: Color(0xFFAFAFAF), size: 24),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Verb forms
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildFormRow('V1 (Present)', verb.v1),
                const SizedBox(height: 8),
                _buildFormRow('V2 (Past)', verb.v2),
                const SizedBox(height: 8),
                _buildFormRow('V3 (Participle)', verb.v3),
                const SizedBox(height: 8),
                _buildFormRow('V4 (-ing)', verb.v4),
                const SizedBox(height: 8),
                _buildFormRow('V5 (-s)', verb.v5),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meanings
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: Color(0xFF58CC02), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Bangla:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAFAFAF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verb.bangla,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B4B4B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: Color(0xFF1CB0F6), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'English:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAFAFAF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verb.meaning,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B4B4B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Example sentences
          GestureDetector(
            onTap: () => _tts.speak(verb.enSentence),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF58CC02).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_quote_rounded,
                          color: Color(0xFF58CC02), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Example Sentence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFAFAFAF),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.volume_up_rounded,
                          color: Color(0xFF58CC02), size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verb.enSentence,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B4B4B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    verb.bnSentence,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Explanation (collapsible)
          GestureDetector(
            onTap: _toggleExplanation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFFC800).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded,
                          color: Color(0xFFFFC800), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Explanation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B4B4B),
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _showExplanation ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: Color(0xFFAFAFAF),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        verb.explanation,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    crossFadeState: _showExplanation
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Navigation buttons
          Row(
            children: [
              // Previous button
              if (_currentVerbIndex > 0)
                Expanded(
                  child: _buildNavButton(
                    text: 'Previous',
                    icon: Icons.arrow_back_rounded,
                    onTap: _goToPreviousVerb,
                    isOutlined: true,
                  ),
                ),
              if (_currentVerbIndex > 0) const SizedBox(width: 12),
              // Next / Start Quiz button
              Expanded(
                flex: _currentVerbIndex > 0 ? 1 : 2,
                child: _buildNavButton(
                  text: _currentVerbIndex < _sessionVerbs.length - 1
                      ? 'Next →'
                      : 'Start Quiz →',
                  icon: _currentVerbIndex < _sessionVerbs.length - 1
                      ? Icons.arrow_forward_rounded
                      : Icons.quiz_rounded,
                  onTap: _goToNextVerb,
                  isOutlined: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFormRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFAFAFAF),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B4B4B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required bool isOutlined,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : const Color(0xFF58CC02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOutlined ? const Color(0xFFE5E5E5) : const Color(0xFF58CC02),
            width: 2,
          ),
          boxShadow: isOutlined
              ? null
              : [
                  const BoxShadow(
                    color: Color(0xFF3DA302),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOutlined)
              Icon(icon, color: const Color(0xFF4B4B4B), size: 16),
            if (isOutlined) const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isOutlined
                    ? const Color(0xFF4B4B4B)
                    : Colors.white,
              ),
            ),
            if (!isOutlined) const SizedBox(width: 6),
            if (!isOutlined)
              Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // QUIZ PHASE
  // ─────────────────────────────────────────────────────────

  Widget _buildQuizPhase() {
    if (_quizQuestions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final question = _quizQuestions[_currentQuizIndex];
    final verb = question.verb;

    return SlideTransition(
      position: _slideAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quiz badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_rounded, size: 16, color: Color(0xFFFF9600)),
                  SizedBox(width: 6),
                  Text(
                    'Quiz Time!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Question
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4B4B4B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),

            // Verb hint card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFAFAFAF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'বাংলা: ${verb.bangla}  •  Meaning: ${verb.meaning}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Options
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];
              final isSelected = _selectedAnswer == option;
              final isCorrectOption = option == question.correctAnswer;

              Color bgColor = Colors.white;
              Color borderColor = const Color(0xFFE5E5E5);
              Color bottomBorderColor = const Color(0xFFC4C4C4);
              Color textColor = const Color(0xFF4B4B4B);
              double bottomThickness = 4.0;
              double topTranslate = 0.0;

              if (_isQuizAnswered) {
                if (isCorrectOption) {
                  bgColor = const Color(0xFFE5F5E1);
                  borderColor = const Color(0xFF58CC02);
                  textColor = const Color(0xFF58CC02);
                  bottomThickness = 0;
                  topTranslate = 4;
                } else if (isSelected && !isCorrectOption) {
                  bgColor = const Color(0xFFFFDFE0);
                  borderColor = const Color(0xFFFF4B4B);
                  textColor = const Color(0xFFFF4B4B);
                  bottomThickness = 0;
                  topTranslate = 4;
                } else {
                  bgColor = const Color(0xFFF7F7F7);
                  borderColor = const Color(0xFFE5E5E5);
                  textColor = const Color(0xFFB0B0B0);
                  bottomThickness = 0;
                  topTranslate = 2;
                }
              } else if (isSelected) {
                bgColor = const Color(0xFFDDF4FF);
                borderColor = const Color(0xFF1CB0F6);
                bottomBorderColor = const Color(0xFF1CB0F6);
                textColor = const Color(0xFF1CB0F6);
                bottomThickness = 0;
                topTranslate = 4;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _selectQuizAnswer(option),
                  child: Transform.translate(
                    offset: Offset(0, topTranslate),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 2),
                        boxShadow: bottomThickness > 0
                            ? [
                                BoxShadow(
                                  color: bottomBorderColor,
                                  offset: Offset(0, bottomThickness),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Option letter
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isQuizAnswered && isCorrectOption
                                  ? const Color(0xFF58CC02)
                                  : _isQuizAnswered && isSelected && !isCorrectOption
                                      ? const Color(0xFFFF4B4B)
                                      : isSelected
                                          ? const Color(0xFF1CB0F6)
                                          : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: _isQuizAnswered && isCorrectOption
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 18)
                                  : _isQuizAnswered && isSelected && !isCorrectOption
                                      ? const Icon(Icons.close_rounded,
                                          color: Colors.white, size: 18)
                                      : Text(
                                          String.fromCharCode(
                                              65 + index), // A, B, C, D
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFFAFAFAF),
                                          ),
                                        ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                          // Check/correct icon
                          if (_isQuizAnswered && isCorrectOption)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF58CC02), size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Feedback card (shown after answering)
            if (_isQuizAnswered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isQuizCorrect
                      ? const Color(0xFFE5F5E1)
                      : const Color(0xFFFFDFE0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isQuizCorrect
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                      color: _isQuizCorrect
                          ? const Color(0xFF58CC02)
                          : const Color(0xFFFF4B4B),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isQuizCorrect
                            ? 'Correct! +${10 + max(0, (_streak - 1) * 2)} points'
                            : 'Oops! The answer was: ${question.correctAnswer}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isQuizCorrect
                              ? const Color(0xFF58CC02)
                              : const Color(0xFFFF4B4B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Continue button
              GestureDetector(
                onTap: _goToNextQuiz,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF58CC02), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF3DA302),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentQuizIndex < _quizQuestions.length - 1
                            ? 'Continue →'
                            : 'See Results →',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Submit button
              if (_selectedAnswer.isNotEmpty)
                GestureDetector(
                  onTap: _submitQuizAnswer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58CC02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF58CC02), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF3DA302),
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Check Answer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

enum _QuizQuestionType { v2, v3, meaning, v1 }
