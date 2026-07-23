import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game/sound_provider.dart';
import '../../../../services/speech_service.dart';
import '../../../../services/tts_service.dart';
import '../result_screen.dart';

// ─────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────

class _FlashCard {
  final String bn;
  final String en;
  final String pronunciation;
  final String bnExample;
  final String enExample;

  const _FlashCard({
    required this.bn,
    required this.en,
    this.pronunciation = '',
    this.bnExample = '',
    this.enExample = '',
  });

  factory _FlashCard.fromJson(Map<String, dynamic> json) => _FlashCard(
        bn: json['bn'] as String? ?? '',
        en: json['en'] as String? ?? '',
        pronunciation: json['pronunciation'] as String? ?? '',
        bnExample: json['bn_example'] as String? ?? '',
        enExample: json['en_example'] as String? ?? '',
      );
}

class _Category {
  final String id;
  final String name;
  final String icon;
  final List<_FlashCard> cards;

  const _Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.cards,
  });

  factory _Category.fromJson(Map<String, dynamic> json) => _Category(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'book',
        cards: (json['cards'] as List<dynamic>?)
                ?.map((e) => _FlashCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class _CardProgress {
  final _FlashCard card;
  bool known;

  _CardProgress({required this.card, this.known = false});
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class FlashcardsModeScreen extends ConsumerStatefulWidget {
  const FlashcardsModeScreen({super.key});

  @override
  ConsumerState<FlashcardsModeScreen> createState() => _FlashcardsModeScreenState();
}

class _FlashcardsModeScreenState extends ConsumerState<FlashcardsModeScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;

  // Data
  List<_Category> _categories = [];
  _Category? _selectedCategory;
  List<_CardProgress> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoading = true;

  // Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _slideController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadData();
    _speechService.initialize();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/game/flashcard_data.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final categoriesList = (data['categories'] as List<dynamic>?)
              ?.map((e) => _Category.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _categories = categoriesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectCategory(_Category category) {
    final shuffled = List<_FlashCard>.from(category.cards)..shuffle();
    setState(() {
      _selectedCategory = category;
      _cards = shuffled.map((c) => _CardProgress(card: c)).toList();
      _currentIndex = 0;
      _isFlipped = false;
    });
    // Auto-pronounce Bangla when category selected
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakBangla());
  }

  void _flipCard() {
    if (_isAnimating) return;
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    final newFlipped = !_isFlipped;
    setState(() => _isFlipped = newFlipped);
    // Auto-pronounce when revealing English (back) side
    if (newFlipped) {
      Future.delayed(const Duration(milliseconds: 400), _speakEnglish);
    }
  }

  void _markKnown() {
    if (_currentIndex >= _cards.length || _isAnimating) return;
    ref.read(soundProvider.notifier).playCorrect();
    setState(() {
      _cards[_currentIndex].known = true;
    });
    _nextCard();
  }

  void _markUnknown() {
    if (_currentIndex >= _cards.length || _isAnimating) return;
    ref.read(soundProvider.notifier).playWrong();
    _nextCard();
  }

  Future<void> _startSpeechCheck() async {
    if (_currentIndex >= _cards.length || _isAnimating) return;
    if (!_isFlipped) {
      _flipCard();
      return;
    }

    setState(() => _isListening = true);

    await _speechService.startListening(
      onResult: (text) {
        if (!mounted) return;
        final correct = _cards[_currentIndex].card.en.trim().toLowerCase();
        final spoken = text.trim().toLowerCase();

        setState(() => _isListening = false);

        if (spoken == correct) {
          _markKnown();
        } else {
          _markUnknown();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _markUnknown();
        }
      },
    );
  }

  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) {
      _finishSession();
      return;
    }
    _isAnimating = true;
    _slideController.forward().then((_) {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _isFlipped = false;
          _flipController.reset();
          _slideController.reset();
          _isAnimating = false;
        });
        // Auto-pronounce Bangla for next card
        _speakBangla();
      }
    });
  }

  Future<void> _speakBangla() async {
    if (_currentIndex >= _cards.length) return;
    await _tts.speakBangla(_cards[_currentIndex].card.bn);
  }

  Future<void> _speakEnglish() async {
    if (_currentIndex >= _cards.length) return;
    await _tts.speak(_cards[_currentIndex].card.en);
  }

  void _goBackToCategories() {
    setState(() {
      _selectedCategory = null;
      _cards = [];
      _currentIndex = 0;
      _isFlipped = false;
      _flipController.reset();
    });
  }

  void _finishSession() {
    final knownCount = _cards.where((c) => c.known).length;
    final total = _cards.length;
    final unknownCount = total - knownCount;
    final accuracy = total > 0 ? knownCount / total : 0.0;

    final earnedXP = knownCount * 5 + (accuracy >= 0.8 ? 20 : accuracy >= 0.5 ? 10 : 0);
    final earnedCoins = knownCount * 2 + (accuracy >= 0.8 ? 10 : 0);
    final score = knownCount * 10;

    // ResultScreen handles XP/coin addition, streak update, and stats saving
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: score,
          correctAnswers: knownCount,
          wrongAnswers: unknownCount,
          earnedXP: earnedXP,
          earnedCoins: earnedCoins,
          gameMode: 'flashcard',
        ),
      ),
    ).then((_) {
      // After returning from result, go back to category selection
      if (mounted) _goBackToCategories();
    });
  }

  // ── Category Selection UI ──

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    final iconMap = {
      'people': Icons.people,
      'restaurant': Icons.restaurant,
      'pets': Icons.pets,
      'palette': Icons.palette,
      'accessibility': Icons.accessibility,
      'directions_run': Icons.directions_run,
      'work': Icons.work,
      'wb_sunny': Icons.wb_sunny,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.style_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Flashcards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a category to study',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Categories',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return _CategoryCard(
                  name: cat.name,
                  count: cat.cards.length,
                  icon: iconMap[cat.icon] ?? Icons.book,
                  onTap: () => _selectCategory(cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Flashcard Study UI ──

  Widget _buildStudyScreen() {
    if (_cards.isEmpty) return const Center(child: Text('No cards in this category'));

    final card = _cards[_currentIndex];
    final knownCount = _cards.where((c) => c.known).length;
    final totalCount = _cards.length;

    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goBackToCategories,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCategory?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '$knownCount / $totalCount known',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_currentIndex + 1}/$totalCount',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // ── Progress Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / totalCount,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF6366F1),
              minHeight: 4,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Flashcard ──
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flipCard,
              child: _buildFlashCard(card),
            ),
          ),
        ),

        // ── Action Buttons ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Don't Know Button
              Expanded(
                child: _ActionButton(
                  icon: Icons.close_rounded,
                  label: "Don't Know",
                  color: Colors.red.shade400,
                  onTap: _markUnknown,
                ),
              ),
              const SizedBox(width: 12),
              // TTS Button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF6366F1)),
                  onPressed: _speakEnglish,
                  tooltip: 'Hear pronunciation',
                ),
              ),
              const SizedBox(width: 12),
              // Mic Button
              Expanded(
                child: _ActionButton(
                  icon: _isListening ? Icons.mic : Icons.mic_none_rounded,
                  label: _isListening ? 'Listening...' : 'Speak',
                  color: _isListening ? Colors.orange.shade400 : Colors.green.shade400,
                  onTap: _startSpeechCheck,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlashCard(_CardProgress cardData) {
    final card = cardData.card;

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final isBack = _flipAnimation.value > 0.5;
        // Front: rotate 0 → 90° (first half)
        // Back:  rotate -90° → 0 (second half)
        final angle = isBack
            ? (_flipAnimation.value - 1.0) * pi  // goes from -pi/2 to 0
            : _flipAnimation.value * pi;          // goes from 0 to pi/2

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isBack ? _buildCardBack(card) : _buildCardFront(card),
        );
      },
    );
  }

  Widget _buildCardFront(_FlashCard card) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.translate_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            card.bn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'বাংলা',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tap_and_play, color: Colors.white.withOpacity(0.7), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Tap to flip',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(_FlashCard card) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 2),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              card.en,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (card.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                card.pronunciation,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'English',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Bengali Example
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.translate, color: Color(0xFF6366F1), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'বাংলা',
                        style: TextStyle(
                          color: const Color(0xFF6366F1),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.bnExample.isNotEmpty ? card.bnExample : 'No example available',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // English Example
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, color: Colors.grey.shade400, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'English',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.enExample.isNotEmpty ? card.enExample : 'No example available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (card.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _speakEnglish,
                icon: const Icon(Icons.volume_up_rounded, size: 16),
                label: const Text('Hear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volume_up, size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(
                  'Auto',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedCategory == null
          ? null
          : AppBar(
              title: const Text('Flashcards'),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedCategory == null
              ? _buildCategoryGrid()
              : _buildStudyScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String name;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF667eea),
      const Color(0xFFf093fb),
      const Color(0xFF4facfe),
      const Color(0xFF43e97b),
      const Color(0xFFfa709a),
      const Color(0xFFa18cd1),
      const Color(0xFFfbc2eb),
      const Color(0xFF84fab0),
    ];
    final color = colors[name.hashCode % colors.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$count cards',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}