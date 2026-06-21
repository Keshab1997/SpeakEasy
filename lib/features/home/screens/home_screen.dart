import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../services/tts_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/progress_provider.dart';
import '../../../providers/todo_list_provider.dart';
import '../../../models/todo_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../providers/chapter_vocabulary_provider.dart';
import '../../../providers/grammar_provider.dart';
import '../../../providers/last_opened_chapter_provider.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../providers/theme_provider.dart';
import '../../grammar/screens/grammar_list_screen.dart';
import '../../grammar/screens/grammar_detail_screen.dart';
import '../../grammar/screens/grammar_test_list_screen.dart';
import '../../vocabulary/screens/chapter_words_screen.dart';
import '../../vocabulary/screens/vocabulary_test_screen.dart';
import '../../conversation/screens/conversation_screen.dart';
import '../../translator/screens/banglish_translator_screen.dart';
import '../../game/screens/game_home_screen.dart';
import '../widgets/study_plan_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateToTab;
  final VoidCallback? onNavigateToLessons;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToLessons,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _tts = TtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    // Fetch progress on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressProvider.notifier).fetchProgress();
    });
  }

  void _speakWord(String word) {
    setState(() => _isSpeaking = true);
    _tts.speak(word);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Changes every 10 minutes: index = tenMinSlot % total
  int _wordIndex(int total) {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final tenMinSlot = totalMinutes ~/ 10;
    return total == 0 ? 0 : tenMinSlot % total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authAsync = ref.watch(authProvider);
    final progressAsync = ref.watch(progressProvider);
    final vocabAsync = ref.watch(vocabularyProvider);
    final chaptersAsync = ref.watch(allChaptersProvider);
    final grammarAsync = ref.watch(allGrammarChaptersProvider);
    final studyState = ref.watch(todoListProvider);
    final lastOpenedChapter = ref.watch(lastOpenedChapterProvider);

    final user = authAsync.asData?.value;
    if (user?.name != null && user!.name.isNotEmpty) {
      HiveService.setUserName(user.name);
    }
    final progress = progressAsync.asData?.value;
    final allWords = vocabAsync.asData?.value ?? [];
    final allChapterWords = (chaptersAsync.asData?.value ?? [])
        .expand((chapter) => chapter.words)
        .toList();
    final allVocabChapters = chaptersAsync.asData?.value ?? [];
    final allGrammarChapters = grammarAsync.asData?.value ?? [];

    // Derived values — progress from Study Plan (todo list)
    final streakDays = progress?.streakDays ?? 0;
    final lessonsCompleted = studyState.completedCount;
    final totalLessons = studyState.totalCount > 0 ? studyState.totalCount : 1;
    final progressPct = (lessonsCompleted / totalLessons).clamp(0.0, 1.0);
    final favoritesCount = allWords.where((w) => w.isFavorite).length;

    // Today's word from JSON chapters — changes every 10 minutes
    final todayWord = allChapterWords.isEmpty ? null : allChapterWords[_wordIndex(allChapterWords.length)];

    // Group lessons by level for Continue Learning
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.translate_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 8),
            Text('SpeakEasy', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 26,
            ),
            onPressed: () {
              final notifier = ref.read(themeModeProvider.notifier);
              notifier.state =
                  notifier.state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              HiveService.setDarkMode(notifier.state == ThemeMode.dark);
            },
          ),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications'), behavior: SnackBarBehavior.floating),
            ),
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 28),
                Positioned(
                  right: 2, top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.onNavigateToTab?.call(4),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingSection(theme, user?.name),
              const SizedBox(height: 20),
              _buildProgressCard(theme, streakDays, lessonsCompleted, progressPct, totalLessons),
              const SizedBox(height: 24),
              _buildTodaysWordCard(theme, isDark, todayWord, isLoading: chaptersAsync.isLoading),
              const SizedBox(height: 24),
              _buildAiTeacherBanner(theme),
              const SizedBox(height: 24),
              _buildContinueLearningSection(
                theme, isDark, studyState, allGrammarChapters, allVocabChapters, lastOpenedChapter,
              ),
              const SizedBox(height: 24),
              const StudyPlanSection(),
              const SizedBox(height: 24),
              _buildDailyChallengeCard(theme, streakDays),
              const SizedBox(height: 24),
              _buildQuickPracticeSection(theme, isDark),
              const SizedBox(height: 24),
              _buildTenseGameCard(theme, isDark),
              const SizedBox(height: 24),
              _buildAchievementsSection(theme, isDark, streakDays, lessonsCompleted, favoritesCount),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // GREETING
  Widget _buildGreetingSection(ThemeData theme, String? name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                '${_getTimeGreeting()}, ${name ?? 'User'} ',
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 26),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text('👋', style: TextStyle(fontSize: 26)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Keep practicing English every day.',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // PROGRESS CARD
  Widget _buildProgressCard(
    ThemeData theme, int streakDays, int lessonsCompleted, double progressPct, int totalLessons,
  ) {
    final pctLabel = '${(progressPct * 100).toInt()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Progress', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 12)),
                    Text(
                      '$streakDays Day${streakDays == 1 ? '' : 's'} Streak',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(pctLabel, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text('Overall Progress', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withOpacity(0.25)),
                FractionallySizedBox(
                  widthFactor: progressPct,
                  child: Container(height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('📚 ', style: TextStyle(fontSize: 14)),
              Text(
                '$lessonsCompleted Chapters Completed',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Text('🎯 ', style: TextStyle(fontSize: 14)),
              Text(
                'Total: $totalLessons',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TODAY'S WORD
  Widget _buildTodaysWordCard(ThemeData theme, bool isDark, ChapterWord? todayWord, {required bool isLoading}) {
    if (isLoading) return _buildLoadingWordCard(theme, isDark);
    if (todayWord == null) return _buildEmptyWordCard(theme, isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.accent.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text("TODAY'S WORD", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const Spacer(),
                  Text(
                    _timeSlotLabel(),
                    style: TextStyle(color: AppColors.accent.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todayWord.word,
                              style: theme.textTheme.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                            if (todayWord.pronunciation.isNotEmpty)
                              Text(
                                todayWord.pronunciation,
                                style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _speakWord(todayWord.word),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isSpeaking ? AppColors.primary.withOpacity(0.2) : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                            color: _isSpeaking ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (todayWord.meaning.isNotEmpty) ...[
                    const Text('Meaning (ইংরেজি):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(todayWord.meaning, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                  ],
                  if (todayWord.banglaMeaning.isNotEmpty) ...[
                    const Text('Meaning (বাংলা):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(todayWord.banglaMeaning, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  ],
                  if (todayWord.exampleSentence.isNotEmpty) ...[
                    const Text('Example Sentence:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
                      ),
                      child: Text(
                        todayWord.exampleSentence,
                        style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWordCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.accent.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, color: AppColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text("TODAY'S WORD", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('Loading vocabulary...',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWordCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.accent.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, color: AppColors.accent, size: 20),
                  SizedBox(width: 8),
                  Text("TODAY'S WORD", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Icon(Icons.menu_book_rounded, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No words available', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeSlotLabel() {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final slotStart = (totalMinutes ~/ 10) * 10;
    final slotEnd = slotStart + 10;
    final hh = slotStart ~/ 60;
    final mm = slotStart % 60;
    final hh2 = slotEnd ~/ 60;
    final mm2 = slotEnd % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} - ${hh2.toString().padLeft(2, '0')}:${mm2.toString().padLeft(2, '0')}';
  }

  // CONTINUE LEARNING — next pending Grammar + Vocabulary chapters
  Widget _buildContinueLearningSection(
    ThemeData theme, bool isDark, StudyPlanState studyState,
    List<GrammarChapter> allGrammarChapters, List<VocabularyChapter> allVocabChapters,
    LastOpenedChapter? lastOpened,
  ) {
    final items = studyState.items;
    final grammarItems = items.where((i) => i.type == 'grammar').toList();
    final vocabItems = items.where((i) => i.type == 'vocabulary').toList();
    final grammarDone = grammarItems.where((i) => i.status == TodoStatus.completed).length;
    final vocabDone = vocabItems.where((i) => i.status == TodoStatus.completed).length;
    final grammarTotal = grammarItems.length;
    final vocabTotal = vocabItems.length;

    GrammarChapter? findGrammar(int chapterNum) {
      for (final c in allGrammarChapters) {
        if (c.chapter == chapterNum) return c;
      }
      return null;
    }

    VocabularyChapter? findVocab(int chapterNum) {
      for (final c in allVocabChapters) {
        if (c.chapter == chapterNum) return c;
      }
      return null;
    }

    // Next pending items
    TodoItem? findById(List<TodoItem> list, String? id) {
      if (id == null) return null;
      for (final item in list) {
        if (item.id == id) return item;
      }
      return null;
    }

    // Resume: last opened chapter (if still pending), else next pending
    TodoItem? resumeFromLastOpened(String type, String prefix) {
      if (lastOpened == null) return null;
      if (lastOpened.type != type) return null;
      final item = findById(items, '${prefix}_${lastOpened.chapter}');
      if (item != null && item.status == TodoStatus.pending) return item;
      return null;
    }

    final resumeGrammar = resumeFromLastOpened('grammar', 'grammar')
        ?? findById(items, studyState.nextGrammarId);
    final resumeVocab = resumeFromLastOpened('vocabulary', 'vocab')
        ?? findById(items, studyState.nextVocabId);

    final hasAny = resumeGrammar != null || resumeVocab != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Continue Learning',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => widget.onNavigateToLessons?.call(),
              child: const Row(children: [Text('All Chapters'), Icon(Icons.chevron_right_rounded, size: 16)]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasAny)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text('All chapters completed! 🎉',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: (resumeGrammar != null ? 1 : 0) + (resumeVocab != null ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final isGrammar = resumeGrammar != null && (index == 0 || resumeVocab == null);
                final todo = (isGrammar ? resumeGrammar : resumeVocab)!;
                final color = isGrammar ? AppColors.purpleGradient[0] : AppColors.primary;
                final gradient = isGrammar ? AppColors.purpleGradient : AppColors.primaryGradient;
                final icon = isGrammar ? Icons.edit_note_rounded : Icons.menu_book_rounded;
                final typeLabel = isGrammar ? 'GRAMMAR' : 'VOCABULARY';
                final done = isGrammar ? grammarDone : vocabDone;
                final total = isGrammar ? grammarTotal : vocabTotal;
                final cardType = isGrammar ? 'grammar' : 'vocabulary';
                final chapterPct = (lastOpened != null &&
                        lastOpened.type == cardType &&
                        lastOpened.chapter == todo.chapterNumber)
                    ? lastOpened.progress
                    : HiveService.getChapterProgress(cardType, todo.chapterNumber);
                final pct = chapterPct > 0 ? chapterPct : (total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0));

                return GestureDetector(
                  onTap: () {
                    if (isGrammar) {
                      final ch = findGrammar(todo.chapterNumber);
                      if (ch != null) {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => GrammarDetailScreen(chapter: ch)));
                      }
                    } else {
                      final ch = findVocab(todo.chapterNumber);
                      if (ch != null) {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ChapterWordsScreen(chapter: ch)));
                      }
                    }
                  },
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.2),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(12)),
                              child: Icon(icon, color: Colors.white, size: 20),
                            ),
                            Text('${(pct * 100).toInt()}%',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(typeLabel,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 4),
                        Text(todo.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('Chapter ${todo.chapterNumber} • ${todo.level}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(height: 6, width: double.infinity,
                                color: isDark ? Colors.grey[800] : Colors.grey[200]),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(height: 6,
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient),
                                    borderRadius: BorderRadius.circular(4))),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // DAILY CHALLENGE — goal derived from streakDays
  Widget _buildDailyChallengeCard(ThemeData theme, int streakDays) {
    final goal = streakDays < 3 ? 'Speak 5 English sentences' : streakDays < 7 ? 'Speak 10 English sentences' : 'Speak 15 English sentences';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF4500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, bottom: -20,
            child: Icon(Icons.local_fire_department_rounded, size: 130, color: Colors.white.withOpacity(0.12)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Text('DAILY CHALLENGE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                    const Spacer(),
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Today's Challenge", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(goal, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    widget.onNavigateToTab?.call(2);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Launching Daily Speaking Challenge...'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Start Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // AI TEACHER BANNER
  Widget _buildAiTeacherBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.12), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text('AI TEACHER', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Practice with AI Teacher', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                Text('Get real-time feedback on speaking & grammar.', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => widget.onNavigateToTab?.call(3),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary, size: 40),
          ),
        ],
      ),
    );
  }

  // QUICK PRACTICE
  Widget _buildQuickPracticeSection(ThemeData theme, bool isDark) {
    final items = [
      {'title': 'Vocabulary', 'icon': Icons.menu_book_rounded, 'gradient': AppColors.primaryGradient, 'tab': 1},
      {'title': 'Vocab Test', 'icon': Icons.quiz_rounded, 'gradient': AppColors.accentGradient, 'tab': -1},
      {'title': 'Grammar', 'icon': Icons.edit_note_rounded, 'gradient': AppColors.purpleGradient, 'tab': -2},
      {'title': 'Grammar Test', 'icon': Icons.quiz_rounded, 'gradient': AppColors.accentGradient, 'tab': -3},
      {'title': 'Conversation', 'icon': Icons.forum_rounded, 'gradient': AppColors.secondaryGradient, 'tab': -4},
      {'title': 'Listening', 'icon': Icons.headset_rounded, 'gradient': AppColors.infoGradient, 'tab': 2},
      {'title': 'Speaking', 'icon': Icons.mic_rounded, 'gradient': AppColors.pinkGradient, 'tab': 2},
      {'title': 'Translate', 'icon': Icons.translate_rounded, 'gradient': [const Color(0xFF00BCD4), const Color(0xFF009688)], 'tab': -5},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Practice', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.45),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final grad = item['gradient'] as List<Color>;
            return GestureDetector(
              onTap: () {
                final tab = item['tab'] as int;
                if (tab == -1) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyTestScreen()));
                } else if (tab == -2) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarListScreen()));
                } else if (tab == -3) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarTestListScreen()));
                } else if (tab == -4) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationScreen()));
                } else if (tab == -5) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BanglishTranslatorScreen()));
                } else {
                  widget.onNavigateToTab?.call(tab);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: grad[0].withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(item['icon'] as IconData, color: grad[0], size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(item['title'] as String, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // TENSE GAME CARD
  Widget _buildTenseGameCard(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameHomeScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(Icons.sports_esports_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'TENSE GAME',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                    const Spacer(),
                    const Text('🎮', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tense Mastery',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Practice tenses with fun game modes, earn XP & coins!',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GameHomeScreen()),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6A11CB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ACHIEVEMENTS — dynamic badges based on real progress
  Widget _buildAchievementsSection(ThemeData theme, bool isDark, int streakDays, int lessonsCompleted, int favoritesCount) {
    final badges = <Map<String, dynamic>>[
      if (lessonsCompleted >= 1)
        {'title': 'First Step', 'icon': Icons.emoji_events_rounded, 'color': Colors.amber, 'description': 'Completed first lesson'},
      if (streakDays >= 7)
        {'title': '7 Day Streak', 'icon': Icons.local_fire_department_rounded, 'color': Colors.deepOrange, 'description': 'Daily practitioner'},
      if (streakDays >= 30)
        {'title': '30 Day Streak', 'icon': Icons.whatshot_rounded, 'color': Colors.red, 'description': 'Unstoppable!'},
      if (lessonsCompleted >= 10)
        {'title': '10 Lessons', 'icon': Icons.school_rounded, 'color': Colors.green, 'description': 'Dedicated learner'},
      if (favoritesCount >= 10)
        {'title': 'Word Collector', 'icon': Icons.stars_rounded, 'color': Colors.blue, 'description': '$favoritesCount words favorited'},
    ];

    if (badges.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Achievements', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text('Complete lessons to earn badges!', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final color = badge['color'] as Color;
              return Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(badge['icon'] as IconData, color: color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(badge['title'] as String, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(badge['description'] as String, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
