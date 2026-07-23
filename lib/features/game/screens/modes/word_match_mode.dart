import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/haptic_service.dart';
import '../../../../services/tts_service.dart';
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
  late AnimationController _celebrationAnimCtrl;
  late AnimationController _shakeAnimCtrl;
  late Animation<double> _shakeAnim;


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

    _celebrationAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
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

      HapticService.correct();
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
      HapticService.wrong();

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

    final int xpEarned = _score * 2 + (_bestStreak >= 3 ? 20 : 0);
    final int coinsEarned = _score + (_bestStreak >= 5 ? 15 : 0);

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
            gameMode: 'wordMatch',
          ),
        ),
      );
    }
  }

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
                  _buildDuolingoHeader(),
                  _buildDuolingoInstruction(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildDuolingoCardColumn(_leftCards, isLeft: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDuolingoCardColumn(_rightCards, isLeft: false),
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

  Widget _buildDuolingoHeader() {
    final progress = _totalPairs == 0 ? 0.0 : _matchedCount / _totalPairs;
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
                        margin: const EdgeInsets.only(top: 3, left: 6, right: 6, bottom: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }
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
          )
        ],
      ),
    );
  }

  Widget _buildDuolingoInstruction() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Tap the matching pairs',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4B4B4B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDuolingoCardColumn(List<_MatchCard> cards, {required bool isLeft}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: cards.map((card) {
        return Expanded(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final shakeOffset = card.isWrong ? sin(_shakeAnim.value * 3.14159 * 3) * 8 : 0.0;
              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => isLeft ? _onLeftTap(card) : _onRightTap(card),
                child: _DuolingoDuoCard(card: card),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DuolingoDuoCard extends StatelessWidget {
  final _MatchCard card;

  const _DuolingoDuoCard({Key? key, required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (card.isMatched) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5E5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
        ),
      );
    }

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE5E5E5);
    Color bottomBorderColor = const Color(0xFFC4C4C4);
    Color textColor = const Color(0xFF4B4B4B);
    double bottomThickness = 4.0;
    double topTranslate = 0.0;

    if (card.isSelected) {
      bgColor = const Color(0xFFDDF4FF);
      borderColor = const Color(0xFF1CB0F6);
      bottomBorderColor = const Color(0xFF1CB0F6);
      textColor = const Color(0xFF1CB0F6);
      bottomThickness = 0.0;
      topTranslate = 4.0;
    } else if (card.isWrong) {
      bgColor = const Color(0xFFFFDFE0);
      borderColor = const Color(0xFFFF4B4B);
      bottomBorderColor = const Color(0xFFFF4B4B);
      textColor = const Color(0xFFFF4B4B);
      bottomThickness = 0.0;
      topTranslate = 4.0;
    }

    return Transform.translate(
      offset: Offset(0, topTranslate),
      child: Container(
        width: double.infinity,
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          card.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: card.isBangla ? 16 : 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
