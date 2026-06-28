import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/bangla_english_model.dart';
import '../../../services/speech_service.dart';
import '../../../services/tts_service.dart';
import 'speaking_screen.dart';

/// A complete speaking exercise screen supporting multiple practice modes.
///
/// Modes:
/// - [SpeakingMode.readAloud]: Shows an English sentence → user reads it aloud → their
///   speech is transcribed so they can self-compare.
/// - [SpeakingMode.listenAndRepeat]: TTS speaks an English sentence → user repeats →
///   speech is transcribed.
/// - [SpeakingMode.banglaToEnglish]: Shows a Bangla sentence → user speaks the English
///   translation → transcription shown for comparison.
/// - [SpeakingMode.freeSpeaking]: Open microphone – any speech is transcribed live.
class PronunciationScreen extends StatefulWidget {
  final SpeakingMode mode;

  const PronunciationScreen({super.key, required this.mode});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────
  final SpeechService _speechService = SpeechService();
  final TtsService _tts = TtsService();

  // ── Exercise data ───────────────────────────────────────────────────────
  List<BanglaEnglishExercise> _exercises = [];
  List<BanglaEnglishExercise> _allExercises = [];
  int _currentIndex = 0;
  bool _loadingExercises = true;

  // ─── Speech / UI state ──────────────────────────────────────────────────
  bool _isListening = false;
  bool _hasResult = false;
  bool _ttsPlaying = false;
  String _transcribedText = '';
  String _partialText = '';
  int _score = 0;
  int _totalAttempted = 0;

  // For free-speaking mode – keeps a running log
  final List<String> _speechLog = [];

  // Auto-scroll controller – scrolls to "Next" button after speech
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _pulseCtrl;

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initTts();
    _loadExercises();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scrollController.dispose();
    _speechService.stopListening();
    _tts.stop();
    super.dispose();
  }

  // ─── Initialization helpers ─────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.initialize();
  }

  Future<void> _loadExercises() async {
    try {
      // Reuse the existing Bangla→English sentence pairs as exercise content
      final cats = await BanglaEnglishCategory.loadAll();
      final all = <BanglaEnglishExercise>[];
      for (final cat in cats) {
        all.addAll(cat.exercises);
      }
      all.shuffle(Random());
      _allExercises = all;

      // Pick the appropriate subset depending on mode
      if (widget.mode == SpeakingMode.freeSpeaking) {
        // Free speaking doesn't need sentence-by-sentence data
        _exercises = [];
      } else {
        // Take up to 20 sentences for structured modes
        _exercises = all.take(20).toList();
      }
    } catch (_) {
      // If loading fails, provide a small fallback set
      _exercises = [
        BanglaEnglishExercise(
          bangla: 'আমার নাম জন।',
          english: 'My name is John.',
          grammarFocus: 'Introduction',
        ),
        BanglaEnglishExercise(
          bangla: 'আমি ইংরেজি শিখছি।',
          english: 'I am learning English.',
          grammarFocus: 'Present Continuous',
        ),
        BanglaEnglishExercise(
          bangla: 'তুমি কেমন আছো?',
          english: 'How are you?',
          grammarFocus: 'Question',
        ),
        BanglaEnglishExercise(
          bangla: 'আমি বই পড়ছি।',
          english: 'I am reading a book.',
          grammarFocus: 'Present Continuous',
        ),
        BanglaEnglishExercise(
          bangla: 'সে একজন ভালো শিক্ষক।',
          english: 'She is a good teacher.',
          grammarFocus: 'Simple Present',
        ),
      ];
      _allExercises = List.from(_exercises);
    }

    if (mounted) {
      setState(() => _loadingExercises = false);
      // Auto-play first sentence for Listen & Repeat mode
      if (widget.mode == SpeakingMode.listenAndRepeat && _exercises.isNotEmpty) {
        _playCurrentSentence();
      }
    }
  }

  // ─── Exercise navigation ────────────────────────────────────────────────

  BanglaEnglishExercise? get _currentExercise {
    if (_exercises.isEmpty || _currentIndex >= _exercises.length) return null;
    return _exercises[_currentIndex];
  }

  void _nextExercise() {
    setState(() {
      _hasResult = false;
      _transcribedText = '';
      _partialText = '';
      _isListening = false;
      _speechService.stopListening();

      if (_currentIndex < _exercises.length - 1) {
        _currentIndex++;
      } else {
        // Exercise complete!
        _showCompletionDialog();
        return;
      }

      // Auto-play for Listen & Repeat
      if (widget.mode == SpeakingMode.listenAndRepeat) {
        _playCurrentSentence();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 32),
            SizedBox(width: 12),
            Text('Great Job!', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You completed all exercises in this session.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip('$_totalAttempted', 'Attempted', AppColors.primary),
                _statChip('$_score', 'Correct', AppColors.success),
                _statChip(
                  _totalAttempted > 0
                      ? '${(_score / _totalAttempted * 100).round()}%'
                      : '-',
                  'Accuracy',
                  AppColors.warning,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Modes'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = 0;
                _score = 0;
                _totalAttempted = 0;
                _hasResult = false;
                _transcribedText = '';
                // Re-shuffle for new round
                _allExercises.shuffle(Random());
                _exercises = _allExercises.take(20).toList();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ─── Speech ─────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_isListening) return;

    final available = await _speechService.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.')),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _hasResult = false;
      _transcribedText = '';
      _partialText = '';
    });
    _pulseCtrl.repeat(reverse: true);

    await _speechService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _transcribedText = text;
            _hasResult = true;
            _isListening = false;
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();

          // Auto-scroll so the "Next" button is always visible
          _scrollToBottom();

          if (widget.mode == SpeakingMode.freeSpeaking) {
            _speechLog.add(text);
          } else {
            _evaluateAttempt(text);
          }
        }
      },
      onPartialResult: (text) {
        if (mounted) {
          setState(() => _partialText = text);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _transcribedText = 'Error: $error';
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      },
    );
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() => _isListening = false);
    _pulseCtrl.stop();
    _pulseCtrl.reset();
  }

  /// Simple heuristic evaluation: checks word overlap between expected & spoken.
  void _evaluateAttempt(String spoken) {
    final exercise = _currentExercise;
    if (exercise == null) return;

    final expected = _normalise(exercise.english);
    final actual = _normalise(spoken);

    final expectedWords = expected.split(' ');
    final actualWords = actual.split(' ');

    int matches = 0;
    for (final w in actualWords) {
      if (expectedWords.contains(w)) matches++;
    }

    final pct = expectedWords.isNotEmpty ? matches / expectedWords.length : 0.0;
    setState(() {
      _totalAttempted++;
      if (pct >= 0.6) _score++; // 60% word match = acceptable
    });
  }

  String _normalise(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ─── TTS (Listen & Repeat mode) ────────────────────────────────────────

  Future<void> _playCurrentSentence() async {
    final exercise = _currentExercise;
    if (exercise == null) return;

    setState(() => _ttsPlaying = true);
    await _tts.speak(exercise.english);
    setState(() => _ttsPlaying = false);
  }

  /// Auto-scrolls the screen so the "Next" button is visible after speaking.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loadingExercises) {
      return Scaffold(
        appBar: AppBar(title: Text(_modeTitle())),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading exercises...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (widget.mode == SpeakingMode.freeSpeaking) {
      return _buildFreeSpeakingMode(theme, isDark);
    }

    final exercise = _currentExercise;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeTitle()),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${_exercises.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
      body: exercise == null
          ? const Center(child: Text('No exercises available.'))
          : SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Progress bar ────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _exercises.length,
                        backgroundColor: isDark ? AppColors.borderDark : Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Instruction label ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _modeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _modeInstruction(),
                        style: TextStyle(
                          color: _modeColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bangla source (for Bangla→English mode) ────────
                    if (widget.mode == SpeakingMode.banglaToEnglish) ...[
                      _buildSourceCard(
                        theme: theme,
                        isDark: isDark,
                        label: 'বাংলা বাক্য',
                        text: exercise.bangla,
                        color: AppColors.accent,
                        icon: Icons.translate_rounded,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── English target ──────────────────────────────────
                    _buildSourceCard(
                      theme: theme,
                      isDark: isDark,
                      label: widget.mode == SpeakingMode.banglaToEnglish
                          ? 'Expected English'
                          : 'Read this sentence aloud',
                      text: exercise.english,
                      color: _modeColor(),
                      icon: Icons.text_fields_rounded,
                    ),
                    const SizedBox(height: 24),

                    // ── Listen button (Listen & Repeat) ─────────────────
                    if (widget.mode == SpeakingMode.listenAndRepeat)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: _ttsPlaying ? null : _playCurrentSentence,
                          icon: Icon(
                            _ttsPlaying ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                            size: 20,
                          ),
                          label: Text(_ttsPlaying ? 'Playing...' : '🔊 Listen Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                    // ── Microphone section ──────────────────────────────
                    _buildMicSection(theme, isDark),

                    // ── Transcription result ────────────────────────────
                    if (_hasResult && _transcribedText.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildTranscriptionResult(theme, isDark, exercise),
                    ],

                    const SizedBox(height: 24),

                    // ── Next button ─────────────────────────────────────
                    if (_hasResult)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _nextExercise,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                            _currentIndex < _exercises.length - 1
                                ? 'Next Sentence'
                                : 'Finish 🎉',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _modeColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Score summary ───────────────────────────────────
                    if (_totalAttempted > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statChip('$_score', 'Correct', AppColors.success),
                          const SizedBox(width: 12),
                          _statChip('$_totalAttempted', 'Attempted', AppColors.primary),
                          const SizedBox(width: 12),
                          _statChip(
                            '${(_score / max(1, _totalAttempted) * 100).round()}%',
                            'Accuracy',
                            AppColors.warning,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Free-speaking mode ─────────────────────────────────────────────────

  Widget _buildFreeSpeakingMode(ThemeData theme, bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('Free Speaking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.purpleGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎤 Free Speaking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Press the microphone and start speaking in English.\nYour speech will be transcribed live.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mic button
              _buildAnimatedMic(theme, isDark, AppColors.purpleGradient[0]),
              const SizedBox(height: 12),
              Text(
                _isListening ? 'Listening...' : 'Tap to start speaking',
                style: TextStyle(
                  color: _isListening ? AppColors.error : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Live transcription
              if (_partialText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.purpleGradient[0].withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.purpleGradient[0].withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔴 Live...',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                      const SizedBox(height: 6),
                      Text(_partialText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // Full transcription result
              if (_transcribedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Transcribed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _transcribedText = ''),
                            child: const Icon(Icons.close, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_transcribedText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Speech log history
              if (_speechLog.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History (${_speechLog.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_speechLog.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                              Expanded(
                                child: Text(
                                  _speechLog[i],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Reusable sub-widgets ───────────────────────────────────────────────

  Widget _buildSourceCard({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicSection(ThemeData theme, bool isDark) {
    return Column(
      children: [
        _buildAnimatedMic(theme, isDark, _modeColor()),
        const SizedBox(height: 8),
        Text(
          _isListening
              ? 'Listening... Speak clearly 🎤'
              : _hasResult
                  ? 'Great! Check your result below.'
                  : 'Tap mic & read the sentence aloud',
          style: TextStyle(
            color: _isListening
                ? AppColors.error
                : _hasResult
                    ? AppColors.success
                    : Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_partialText.isNotEmpty && _isListening) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _listeningBars(),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _partialText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedMic(ThemeData theme, bool isDark, Color color) {
    return GestureDetector(
      onTap: _isListening ? _stopListening : _startListening,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final scale = _isListening ? 1.0 + _pulseCtrl.value * 0.12 : 1.0;
          final opacity = _isListening ? 1.0 - _pulseCtrl.value * 0.3 : 1.0;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? AppColors.error.withOpacity(0.1 + _pulseCtrl.value * 0.2)
                      : color.withOpacity(0.1),
                  border: Border.all(
                    color: _isListening
                        ? AppColors.error.withOpacity(0.5)
                        : color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.stop_circle_outlined : Icons.mic_rounded,
                  color: _isListening ? AppColors.error : color,
                  size: 36,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _listeningBars() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final delay = i * 0.15;
            final t = (_pulseCtrl.value - delay).clamp(0.0, 1.0);
            final height = 4.0 + t * 14.0;
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.6 + t * 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTranscriptionResult(
      ThemeData theme, bool isDark, BanglaEnglishExercise exercise) {
    final expectedWords =
        _normalise(exercise.english).split(' ');
    final spokenWords = _normalise(_transcribedText).split(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Your Speech vs Expected',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expected
          _wordComparisonChip(
            label: 'Expected',
            text: exercise.english,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),

          // What you said
          _wordComparisonChip(
            label: 'You said',
            text: _transcribedText,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 12),

          // Word-by-word match
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: expectedWords.map((word) {
              final matched = spokenWords.contains(word);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (matched ? AppColors.success : AppColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (matched ? AppColors.success : AppColors.error).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: matched ? AppColors.success : AppColors.error,
                    decoration: matched ? null : TextDecoration.lineThrough,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _wordComparisonChip({
    required String label,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _modeTitle() {
    switch (widget.mode) {
      case SpeakingMode.readAloud:
        return 'Read Aloud';
      case SpeakingMode.listenAndRepeat:
        return 'Listen & Repeat';
      case SpeakingMode.banglaToEnglish:
        return 'Bangla → English';
      case SpeakingMode.freeSpeaking:
        return 'Free Speaking';
    }
  }

  String _modeInstruction() {
    switch (widget.mode) {
      case SpeakingMode.readAloud:
        return '📖 Read the English sentence aloud clearly.';
      case SpeakingMode.listenAndRepeat:
        return '🎧 Listen to the sentence, then tap mic & repeat.';
      case SpeakingMode.banglaToEnglish:
        return '🔤 See the Bangla text, then speak its English translation.';
      case SpeakingMode.freeSpeaking:
        return '🎤 Speak freely – your words will be transcribed live.';
    }
  }

  Color _modeColor() {
    switch (widget.mode) {
      case SpeakingMode.readAloud:
        return AppColors.primary;
      case SpeakingMode.listenAndRepeat:
        return AppColors.secondary;
      case SpeakingMode.banglaToEnglish:
        return AppColors.accent;
      case SpeakingMode.freeSpeaking:
        return Colors.purple;
    }
  }
}
