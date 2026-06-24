import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game/xp_provider.dart';
import '../../../../providers/game/coin_provider.dart';
import '../../../../providers/game/streak_provider.dart';
import '../../../../providers/game/achievement_provider.dart';
import '../../../../providers/game/sound_provider.dart';
import '../../../../services/tts_service.dart';
import '../../../../repositories/statistics_repository.dart';
import '../../../../models/game/game_result_model.dart';
import '../result_screen.dart';

class WordPair {
  final String bn;
  final String en;
  WordPair({required this.bn, required this.en});
}

class _MatchCard {
  final String id;
  final String text;
  final String pairIndex;
  final bool isBangla;
  bool isMatched;
  bool isSelected;
  bool isWrong;

  _MatchCard({
    required this.id,
    required this.text,
    required this.pairIndex,
    required this.isBangla,
    this.isMatched = false,
    this.isSelected = false,
    this.isWrong = false,
  });
}

class WordMatchModeScreen extends ConsumerStatefulWidget {
  const WordMatchModeScreen({super.key});

  @override
  ConsumerState<WordMatchModeScreen> createState() =>
      _WordMatchModeScreenState();
}

class _WordMatchModeScreenState extends ConsumerState<WordMatchModeScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();

  List<_MatchCard> _leftCards = [];
  List<_MatchCard> _rightCards = [];
  _MatchCard? _selectedLeft;
  _MatchCard? _selectedRight;

  int _score = 0;
  int _matchedCount = 0;
  final int _totalPairs = 6;
  int _streak = 0;
  int _bestStreak = 0;
  bool _isLoading = true;
  bool _isGameOver = false;
  bool _isChecking = false;

  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;
  late AnimationController _pulseAnimCtrl;
  late Animation<double> _pulseAnim;

  final List<Color> _gradientColors = [
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFF6D28D9),
  ];

  @override
  void initState() {
    super.initState();
    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeInOut),
    );
    _pulseAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimCtrl, curve: Curves.easeInOut),
    );
    _loadWords();
  }

  @override
  void dispose() {
    _scoreAnimCtrl.dispose();
    _pulseAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final jsonStr =
        await rootBundle.loadString('assets/json/game/word_match_data.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final pairs = (data['pairs'] as List)
        .map((p) => WordPair(bn: p['bn'] as String, en: p['en'] as String))
        .toList();

    final random = Random();
    pairs.shuffle(random);
    final selected = pairs.take(_totalPairs).toList();

    final left = <_MatchCard>[];
    final right = <_MatchCard>[];
    for (int i = 0; i < selected.length; i++) {
      left.add(_MatchCard(
        id: 'bn_$i',
        text: selected[i].bn,
        pairIndex: '$i',
        isBangla: true,
      ));
      right.add(_MatchCard(
        id: 'en_$i',
        text: selected[i].en,
        pairIndex: '$i',
        isBangla: false,
      ));
    }

    left.shuffle(random);
    right.shuffle(random);

    setState(() {
      _leftCards = left;
      _rightCards = right;
      _isLoading = false;
    });
  }

  void _onLeftTap(_MatchCard card) {
    if (_isChecking || card.isMatched || _isGameOver) return;
    // Play Bangla word sound
    _tts.speakBangla(card.text);
    for (final c in _leftCards) c.isSelected = false;
    for (final c in _leftCards) c.isWrong = false;
    card.isSelected = true;
    _selectedLeft = card;
    setState(() {});
    _tryMatch();
  }

  void _onRightTap(_MatchCard card) {
    if (_isChecking || card.isMatched || _isGameOver) return;
    // Play English word sound
    _tts.speak(card.text);
    for (final c in _rightCards) c.isSelected = false;
    for (final c in _rightCards) c.isWrong = false;
    card.isSelected = true;
    _selectedRight = card;
    setState(() {});
    _tryMatch();
  }

  void _tryMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;

    _isChecking = true;

    final isCorrect =
        _selectedLeft!.pairIndex == _selectedRight!.pairIndex;

    if (isCorrect) {
      _selectedLeft!.isMatched = true;
      _selectedRight!.isMatched = true;
      _matchedCount++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      final streakBonus = (_streak - 1) * 2;
      _score += 10 + streakBonus;

      ref.read(soundServiceProvider).playCorrect();
      _scoreAnimCtrl.forward().then((_) => _scoreAnimCtrl.reverse());
      _tts.speak(_selectedRight!.text);

      setState(() {});

      Future.delayed(const Duration(milliseconds: 400), () async {
        _clearSelection();
        _isChecking = false;

        if (_matchedCount >= _totalPairs) {
          await _endGame();
        }
      });
    } else {
      _streak = 0;
      ref.read(soundServiceProvider).playWrong();

      _selectedLeft!.isWrong = true;
      _selectedRight!.isWrong = true;

      setState(() {});

      Future.delayed(const Duration(milliseconds: 600), () {
        _clearSelection();
        _isChecking = false;
      });
    }
  }

  void _clearSelection() {
    for (final c in _leftCards) {
      c.isSelected = false;
      c.isWrong = false;
    }
    for (final c in _rightCards) {
      c.isSelected = false;
      c.isWrong = false;
    }
    _selectedLeft = null;
    _selectedRight = null;
    setState(() {});
  }

  Future<void> _endGame() async {
    setState(() => _isGameOver = true);

    final accuracy = _totalPairs > 0 ? 1.0 : 0.0;
    final int xpEarned = _score * 2 + (_bestStreak >= 3 ? 20 : 0);
    final int coinsEarned = _score + (_bestStreak >= 5 ? 15 : 0);

    _saveProgress(xpEarned, coinsEarned, accuracy);

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            correctAnswers: _matchedCount,
            wrongAnswers: 0,
            earnedXP: xpEarned,
            earnedCoins: coinsEarned,
            gameMode: 'word_match',
          ),
        ),
      );
    }
  }

  Future<void> _saveProgress(int xp, int coins, double accuracy) async {
    try {
      await ref.read(xpProvider.notifier).addXP(xp);
    } catch (_) {}
    try {
      await ref.read(coinProvider.notifier).addCoins(coins);
    } catch (_) {}
    try {
      await ref.read(streakProvider.notifier).recordActiveDay();
    } catch (_) {}
    try {
      await ref.read(streakProvider.notifier).checkAndUpdateStreak();
    } catch (_) {}
    try {
      await ref.read(achievementProvider.notifier).checkGameAchievements(
        score: _score,
        correctAnswers: _matchedCount,
        accuracy: accuracy,
      );
    } catch (_) {}
    try {
      final repo = StatisticsRepository();
      await repo.saveResult(GameResultModel(
        earnedXP: xp,
        earnedCoins: coins,
        correctAnswers: _matchedCount,
        wrongAnswers: 0,
        accuracy: accuracy,
        score: _score,
        gameType: 'word_match',
        completedTime: DateTime.now(),
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Gradient Header ──
                _buildHeader(theme),

                // ── Progress bar ──
                _buildProgressBar(),

                // ── Instruction ──
                _buildInstruction(),

                // ── Game Grid ──
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade50,
                          Colors.indigo.shade50.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left column — Bangla
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: 8, right: 4, top: 8),
                            child: _buildCardColumn(
                              _leftCards,
                              isLeft: true,
                              theme: theme,
                            ),
                          ),
                        ),
                        // Center divider
                        Container(
                          width: 2,
                          margin:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.indigo.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Right column — English
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: 4, right: 8, top: 8),
                            child: _buildCardColumn(
                              _rightCards,
                              isLeft: false,
                              theme: theme,
                            ),
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

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientColors[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Back button + title
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Word Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Score
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) => Transform.scale(
                  scale: _scoreAnim.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Streak
              if (_streak > 1)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.deepOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_streak',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Pairs count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(_totalPairs, (i) {
                final isMatched = i < _matchedCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isMatched
                          ? Colors.amberAccent
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      transform: Matrix4.translationValues(0, -10, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _matchedCount / _totalPairs,
          minHeight: 6,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            _matchedCount == _totalPairs
                ? Colors.green
                : _gradientColors[0],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.touch_app_rounded,
                color: Colors.indigo, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap a বাংলা word, then its English match',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_matchedCount/$_totalPairs',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardColumn(List<_MatchCard> cards,
      {required bool isLeft, required ThemeData theme}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const BouncingScrollPhysics(),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final card = cards[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () =>
                isLeft ? _onLeftTap(card) : _onRightTap(card),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: _getCardColor(card),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getBorderColor(card),
                  width: card.isSelected || card.isMatched || card.isWrong
                      ? 2.5
                      : 1.5,
                ),
                boxShadow: [
                  if (card.isSelected)
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  else if (card.isMatched)
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  if (!isLeft && card.isMatched)
                    _buildStatusIcon(),
                  Expanded(
                    child: Text(
                      card.text,
                      style: TextStyle(
                        fontSize: isLeft ? 18 : 15,
                        fontWeight: card.isMatched
                            ? FontWeight.w600
                            : card.isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                        color: _getTextColor(card),
                        decoration:
                            card.isMatched ? TextDecoration.lineThrough : null,
                      ),
                      textAlign: isLeft ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  if (isLeft && card.isMatched) _buildStatusIcon(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            color: Colors.white, size: 14),
      ),
    );
  }

  Color _getCardColor(_MatchCard card) {
    if (card.isMatched) return Colors.green.shade50;
    if (card.isWrong) return Colors.red.shade50;
    if (card.isSelected) return Colors.indigo.shade50;
    return Colors.white;
  }

  Color _getBorderColor(_MatchCard card) {
    if (card.isMatched) return Colors.green;
    if (card.isWrong) return Colors.red.shade400;
    if (card.isSelected) return Colors.indigo;
    return Colors.grey.shade200;
  }

  Color _getTextColor(_MatchCard card) {
    if (card.isMatched) return Colors.green.shade700;
    if (card.isWrong) return Colors.red.shade700;
    if (card.isSelected) return Colors.indigo;
    return Colors.black87;
  }
}