import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/listening_model.dart';
import '../../../services/idle_tracker_service.dart';
import '../../../services/speech_service.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _tts = FlutterTts();
  final _speechService = SpeechService();

  List<ListeningCategory>? _categories;
  ListeningCategory? _selectedCat;
  ListeningStory? _selectedStory;

  int _sentenceIndex = 0;
  int _score = 0;
  bool _submitted = false;
  bool _loading = true;
  bool _speaking = false;
  bool _isListening = false;
  String _baseText = '';
  late final AnimationController _pulseCtrl;

  final _storyProgress = <String, int>{};

  @override
  void initState() {
    super.initState();
    IdleTrackerService.recordActivity();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initTts();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _tts.stop();
    _speechService.stopListening();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    final voices = await _tts.getVoices;
    if (voices != null && voices.isNotEmpty) {
      final enVoices = voices.where((v) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        return name.contains('en') || name.contains('us') || name.contains('uk');
      }).toList();
      if (enVoices.isNotEmpty) {
        final preferred = enVoices.firstWhere(
          (v) => v['name']?.toString().toLowerCase().contains('female') ?? false,
          orElse: () => enVoices.first,
        );
        await _tts.setVoice({
          'name': preferred['name'],
          'locale': preferred['locale'] ?? 'en-US',
        });
      }
    }
  }

  Future<void> _load() async {
    final cats = await ListeningCategory.loadAll();
    if (mounted) setState(() { _categories = cats; _loading = false; });
  }

  void _selectCategory(ListeningCategory cat) {
    setState(() { _selectedCat = cat; _selectedStory = null; });
  }

  void _selectStory(ListeningStory story) {
    final saved = _storyProgress[story.id] ?? 0;
    if (saved > 0 && saved < story.sentences.length) {
      _showResumePrompt(story, saved);
    } else {
      _startStory(story);
    }
  }

  void _startStory(ListeningStory story) {
    setState(() {
      _selectedStory = story;
      _sentenceIndex = 0;
      _score = 0;
      _submitted = false;
      _ctrl.clear();
    });
  }

  void _showResumePrompt(ListeningStory story, int saved) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Resume Story?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'You were at sentence ${saved + 1} of ${story.sentences.length} in "${story.title}". Continue?'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _startStory(story); },
            child: const Text('Start Over', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedStory = story;
                _sentenceIndex = saved;
                _score = 0;
                _submitted = false;
                _ctrl.clear();
              });
            },
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  void _submit() {
    if (_submitted) return;
    final user = _normalize(_ctrl.text);
    final correct = _normalize(_selectedStory!.sentences[_sentenceIndex].english);
    setState(() { _submitted = true; if (user == correct) _score++; });
  }

  void _next() {
    setState(() {
      if (_sentenceIndex + 1 >= _selectedStory!.sentences.length) {
        _sentenceIndex = _selectedStory!.sentences.length;
      } else {
        _sentenceIndex++;
      }
      _submitted = false;
      _ctrl.clear();
    });
    _focus.requestFocus();
  }

  void _backTo(String target) {
    if (target == 'stories') {
      _storyProgress.remove(_selectedStory!.id);
      setState(() { _selectedStory = null; _sentenceIndex = 0; _score = 0; });
    } else {
      setState(() { _selectedStory = null; _selectedCat = null; _sentenceIndex = 0; _score = 0; });
    }
  }

  Future<void> _speak(String text) async {
    if (_speaking) { await _tts.stop(); setState(() => _speaking = false); return; }
    setState(() => _speaking = true);
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _speakSlow(String text) async {
    if (_speaking) { await _tts.stop(); setState(() => _speaking = false); return; }
    setState(() => _speaking = true);
    await _tts.setSpeechRate(0.28);
    await _tts.speak(text);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _startListening() async {
    final available = await _speechService.initialize();
    if (!available || !mounted) return;
    _baseText = _ctrl.text;
    setState(() => _isListening = true);
    _pulseCtrl.repeat(reverse: true);
    await _speechService.startListening(
      onResult: (text) {
        if (mounted) {
          _baseText = _baseText.isEmpty ? text : '$_baseText $text';
          _ctrl.text = _baseText;
          _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _baseText.length));
        }
      },
      onPartialResult: (text) {
        if (mounted) {
          final display = _baseText.isEmpty ? text : '$_baseText $text';
          _ctrl.text = display;
          _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: display.length));
        }
      },
      onError: (_) { if (mounted) setState(() => _isListening = false); },
    );
    if (mounted) setState(() { _isListening = false; _pulseCtrl.stop(); _pulseCtrl.reset(); });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listening Practice',
            style: TextStyle(fontWeight: FontWeight.w900))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedCat == null) return _buildCategoryList(isDark, theme);
    if (_selectedStory == null) return _buildStoryList(isDark, theme);
    if (_sentenceIndex >= _selectedStory!.sentences.length) {
      return _buildResult(isDark, theme);
    }
    return _buildExercise(isDark, theme);
  }

  Widget _buildCategoryList(bool isDark, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.headphones_rounded, color: AppColors.primary, size: 26),
          SizedBox(width: 8),
          Text('Listening Practice', style: TextStyle(fontWeight: FontWeight.w900)),
        ]),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Text('Choose Level',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_categories!.length} levels',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),
            ..._categories!.map((cat) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => _selectCategory(cat),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cat.color.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: cat.color)),
                      const SizedBox(height: 2),
                      Text(cat.subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${cat.stories.length}',
                          style: TextStyle(color: cat.color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: cat.color, size: 22),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildStoryList(bool isDark, ThemeData theme) {
    final accent = _selectedCat!.color;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _backTo('levels'),
        ),
        title: Row(children: [
          Icon(Icons.headphones_rounded, color: accent, size: 26),
          const SizedBox(width: 8),
          Text(_selectedCat!.title,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ]),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Text('Choose a Story',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_selectedCat!.stories.length} stories available',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),
            ..._selectedCat!.stories.map((story) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => _selectStory(story),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(story.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(story.level,
                              style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text('${story.sentences.length} sentences',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
                  ]),
                ),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildExercise(bool isDark, ThemeData theme) {
    final ex = _selectedStory!.sentences[_sentenceIndex];
    final total = _selectedStory!.sentences.length;
    final accent = _selectedCat!.color;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _storyProgress[_selectedStory!.id] = _sentenceIndex;
            _backTo('stories');
          },
        ),
        title: Row(children: [
          Icon(Icons.headphones_rounded, color: accent, size: 26),
          const SizedBox(width: 8),
          Flexible(
            child: Text(_selectedStory!.title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_sentenceIndex + 1) / total,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                color: accent, minHeight: 6, borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('Sentence ${_sentenceIndex + 1} / $total',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text('Score: $_score',
                    style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.15)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('বাংলা:', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(ex.bangla,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  const Icon(Icons.headphones_rounded, color: AppColors.primary, size: 32),
                  const SizedBox(height: 6),
                  Text('Listen and type in English',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
                    _playBtn(Icons.volume_up_rounded, 'Play', () => _speak(ex.english)),
                    _playBtn(Icons.slow_motion_video_rounded, 'Slow', () => _speakSlow(ex.english)),
                    _playBtn(Icons.replay_rounded, 'Repeat', () => _speak(ex.english)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                enabled: !_submitted,
                textInputAction: TextInputAction.done,
                onSubmitted: _submitted ? null : (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Type what you heard...',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: !_submitted
                      ? _AnimatedMic(
                          isListening: _isListening,
                          pulseCtrl: _pulseCtrl,
                          accent: accent,
                          onTap: () {
                            if (_isListening) {
                              _speechService.stopListening();
                            } else {
                              _startListening();
                            }
                          },
                        )
                      : null,
                ),
              ),
              if (_isListening) ...[
                const SizedBox(height: 6),
                _ListeningBars(pulseCtrl: _pulseCtrl),
              ],
              const SizedBox(height: 12),
              if (!_submitted)
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Check',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              if (_submitted) ...[
                _buildResultCard(ex),
                if (_normalize(_ctrl.text) != _normalize(ex.english)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _submitted = false),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_sentenceIndex + 1 >= total ? 'See Result' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _playBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildResultCard(ListeningSentence ex) {
    final correct = _submitted && _normalize(_ctrl.text) == _normalize(ex.english);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: correct ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct ? AppColors.success : AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text(correct ? 'Correct!' : 'Incorrect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                  color: correct ? AppColors.success : AppColors.error)),
        ]),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Correct: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          TextSpan(text: ex.english, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ])),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(ex.grammarFocus,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning))),
        ]),
        if (ex.rules.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...ex.rules.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Expanded(child: Text(r, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            ]),
          )),
        ],
        if (ex.hint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.tips_and_updates_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Expanded(child: Text(ex.hint,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning))),
          ]),
        ],
      ]),
    );
  }

  Widget _buildResult(bool isDark, ThemeData theme) {
    final total = _selectedStory!.sentences.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final accent = _selectedCat!.color;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.headphones_rounded, color: accent, size: 26),
          const SizedBox(width: 8),
          Text(_selectedStory!.title,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ]),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(pct >= 80 ? Icons.emoji_events_rounded : pct >= 50 ? Icons.thumb_up_rounded : Icons.replay_rounded,
                size: 80,
                color: pct >= 80 ? AppColors.warning : pct >= 50 ? accent : Colors.grey),
            const SizedBox(height: 20),
            Text('Story Complete!',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('$_score / $total correct',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _statChip('$pct%', 'Accuracy', AppColors.success),
              const SizedBox(width: 12),
              _statChip('${total - _score}', 'Wrong', AppColors.error),
              const SizedBox(width: 12),
              _statChip('$total', 'Total', AppColors.info),
            ]),
            const SizedBox(height: 40),
            SizedBox(width: 200, height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _backTo('stories'),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('More Stories',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ]),
    );
  }
}

class _AnimatedMic extends StatelessWidget {
  final bool isListening;
  final AnimationController pulseCtrl;
  final Color accent;
  final VoidCallback onTap;

  const _AnimatedMic({
    required this.isListening,
    required this.pulseCtrl,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        final scale = isListening ? 1.0 + pulseCtrl.value * 0.15 : 1.0;
        final opacity = isListening ? 1.0 - pulseCtrl.value * 0.4 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening
                    ? AppColors.error.withOpacity(0.1 + pulseCtrl.value * 0.15)
                    : null,
              ),
              child: IconButton(
                icon: Icon(
                  isListening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                  color: isListening ? AppColors.error : accent,
                  size: isListening ? 26 : 24,
                ),
                onPressed: onTap,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ListeningBars extends StatelessWidget {
  final AnimationController pulseCtrl;

  const _ListeningBars({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final delay = i * 0.15;
            final t = (pulseCtrl.value - delay).clamp(0.0, 1.0);
            final height = 4.0 + t * 12.0;
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
}
