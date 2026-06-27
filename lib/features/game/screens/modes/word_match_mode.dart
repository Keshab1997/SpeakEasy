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
  late AnimationController _celebrationAnimCtrl;
  late Animation<double> _celebrationAnim;
  late AnimationController _shakeAnimCtrl;
  late Animation<double> _shakeAnim;

  final List<Color> _gradientColors = [
    const Color(0xFF667eea),
    const Color(0xFF764ba2),
  ];

  @override
  void initState() {
    super.initState();
    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.elasticOut),
    );
    
    _pulseAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseAnimCtrl, curve: Curves.easeInOut),
    );

    _celebrationAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _celebrationAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationAnimCtrl, curve: Curves.elasticOut),
    );

    _shakeAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeAnimCtrl, curve: Curves.elasticIn),
    );

    _loadWords();
  }

  @override
  void dispose() {
    _scoreAnimCtrl.dispose();
    _pulseAnimCtrl.dispose();
    _celebrationAnimCtrl.dispose();
    _shakeAnimCtrl.dispose();
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
      _celebrationAnimCtrl.forward().then((_) => _celebrationAnimCtrl.reverse());
      _tts.speak(_selectedRight!.text);

      setState(() {});

      Future.delayed(const Duration(milliseconds: 500), () async {
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
      _shakeAnimCtrl.forward().then((_) => _shakeAnimCtrl.reverse());

      setState(() {});

      Future.delayed(const Duration(milliseconds: 700), () {
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

    await Future.delayed(const Duration(milliseconds: 800));
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
      // First check/update streak (increment if new day), then record active day
      await ref.read(streakProvider.notifier).checkAndUpdateStreak();
    } catch (_) {}
    try {
      await ref.read(streakProvider.notifier).recordActiveDay();
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _gradientColors),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading words...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.purple.shade50.withOpacity(0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // ── Enhanced Gradient Header ──
                  _buildEnhancedHeader(theme),

                  // ── Progress Section ──
                  _buildProgressSection(),

                  // ── Enhanced Instruction ──
                  _buildEnhancedInstruction(),

                  // ── Game Grid ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // Left column — Bangla
                          Expanded(
                            child: _buildEnhancedCardColumn(
                              _leftCards,
                              isLeft: true,
                              theme: theme,
                            ),
                          ),
                          // Center animated divider
                          _buildCenterDivider(),
                          // Right column — English
                          Expanded(
                            child: _buildEnhancedCardColumn(
                              _rightCards,
                              isLeft: false,
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEnhancedHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientColors[0].withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Back button + title + stats
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Word Match',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Match the pairs',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Score
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) => Transform.scale(
                  scale: _scoreAnim.value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade300,
                          Colors.orange.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Streak indicator
          if (_streak > 1)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.red.shade400],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_streak Streak!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${(_streak - 1) * 2} bonus',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _gradientColors),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradientColors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_matchedCount / $_totalPairs',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _matchedCount / _totalPairs,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _matchedCount == _totalPairs
                    ? Colors.green
                    : _gradientColors[0],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPairs, (i) {
              final isMatched = i < _matchedCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isMatched ? Colors.green : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    boxShadow: isMatched
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInstruction() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.touch_app_rounded,
                color: _gradientColors[1], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap a বাংলা word, then tap its English match',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_rounded,
              color: _gradientColors[1], size: 18),
        ],
      ),
    );
  }

  Widget _buildCenterDivider() {
    return Container(
      width: 3,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _gradientColors[0].withOpacity(0.4),
            _gradientColors[1].withOpacity(0.4),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildEnhancedCardColumn(List<_MatchCard> cards,
      {required bool isLeft, required ThemeData theme}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: cards.map((card) {
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            final shouldShake = card.isWrong;
            final shakeOffset = shouldShake
                ? sin(_shakeAnim.value * pi * 3) * 10
                : 0.0;
            return Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () =>
                  isLeft ? _onLeftTap(card) : _onRightTap(card),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(card),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getBorderColor(card),
                    width: card.isSelected || card.isMatched || card.isWrong
                        ? 3.0
                        : 2.0,
                  ),
                  boxShadow: [
                    if (card.isSelected)
                      BoxShadow(
                        color: _gradientColors[0].withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    else if (card.isMatched)
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    if (!isLeft && card.isMatched)
                      _buildEnhancedStatusIcon(),
                    Expanded(
                      child: Text(
                        card.text,
                        style: TextStyle(
                          fontSize: isLeft ? 15 : 14,
                          fontWeight: card.isMatched
                              ? FontWeight.w700
                              : card.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                          color: _getTextColor(card),
                          decoration:
                              card.isMatched ? TextDecoration.lineThrough : null,
                          decorationThickness: 2,
                        ),
                        textAlign: isLeft ? TextAlign.right : TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLeft && card.isMatched) _buildEnhancedStatusIcon(),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedStatusIcon() {
    return AnimatedBuilder(
      animation: _celebrationAnim,
      builder: (context, child) => Transform.scale(
        scale: _celebrationAnim.value,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 16),
        ),
      ),
    );
  }

  LinearGradient _getCardGradient(_MatchCard card) {
    if (card.isMatched) {
      return LinearGradient(
        colors: [Colors.green.shade50, Colors.green.shade100],
      );
    }
    if (card.isWrong) {
      return LinearGradient(
        colors: [Colors.red.shade50, Colors.red.shade100],
      );
    }
    if (card.isSelected) {
      return LinearGradient(
        colors: [Colors.purple.shade50, Colors.indigo.shade50],
      );
    }
    return const LinearGradient(
      colors: [Colors.white, Colors.white],
    );
  }

  Color _getBorderColor(_MatchCard card) {
    if (card.isMatched) return Colors.green.shade500;
    if (card.isWrong) return Colors.red.shade400;
    if (card.isSelected) return _gradientColors[0];
    return Colors.grey.shade300;
  }

  Color _getTextColor(_MatchCard card) {
    if (card.isMatched) return Colors.green.shade700;
    if (card.isWrong) return Colors.red.shade700;
    if (card.isSelected) return _gradientColors[1];
    return Colors.grey.shade800;
  }
}
