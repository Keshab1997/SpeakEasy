import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/feature_gate_widget.dart';
import '../../../services/hive_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/progress_provider.dart';
import '../../../providers/chapter_vocabulary_provider.dart';
import '../../../providers/todo_list_provider.dart';
import '../../../models/todo_item.dart';
import '../../../providers/grammar_provider.dart';
import '../../../providers/last_opened_chapter_provider.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../grammar/screens/grammar_detail_screen.dart';
import '../../grammar/screens/grammar_list_screen.dart';
import '../../grammar/screens/grammar_test_list_screen.dart';
import '../../vocabulary/screens/chapter_words_screen.dart';
import '../../vocabulary/screens/vocabulary_screen.dart';
import '../../vocabulary/screens/vocabulary_test_screen.dart';
import '../../conversation/screens/conversation_screen.dart';
import '../../listening/screens/listening_screen.dart';
import '../../speaking/screens/speaking_screen.dart';
import '../../translator/screens/banglish_translator_screen.dart';
import '../../game/screens/game_home_screen.dart';
import '../../game/screens/tense_categories_screen.dart';
import '../widgets/study_plan_section.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../daily_quiz/screens/daily_quiz_screen.dart';
import '../../battle_arena/screens/battle_lobby_screen.dart';
import '../../daily_quiz/providers/daily_quiz_provider.dart';
import '../widgets/spoken_rules_screen.dart';
import '../widgets/notification_dialog.dart';
import '../widgets/notification_history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../guides/screens/guides_screen.dart';
import '../../verb_forms/screens/verb_forms_screen.dart';
import '../../verb_forms/screens/verb_form_practice_screen.dart';
import '../../practice/screens/bangla_english_practice_screen.dart';
import '../../mock_test/screens/mock_test_list_screen.dart';
import '../../homework/screens/homework_screen.dart';
import '../../sentence_analyzer/screens/sentence_analyzer_screen.dart';
import 'dart:async';
import '../../../providers/idle_tracker_provider.dart';
import '../../../core/widgets/reminder_overlay.dart';
import '../../../services/idle_tracker_service.dart';

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
	Timer? _idleCheckTimer;

@override
void initState() {
	super.initState();
	// Start idle tracker periodic check (every 15 minutes)
	_idleCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
	final notifier = ref.read(idleTrackerProvider.notifier);
	await notifier.checkIdleStatus();
	});
	// Fetch progress & game stats on load
	WidgetsBinding.instance.addPostFrameCallback((_) async {
ref.read(notificationProvider.notifier).refresh();
ref.read(progressProvider.notifier).fetchProgress();
ref.read(xpProvider.notifier).refresh();
ref.read(coinProvider.notifier).refresh();
ref.read(statisticsProvider.notifier).refresh();
// 🏆 Refresh daily quest (auto-regenerates if new day)
ref.read(dailyQuizProvider.notifier).loadTodayQuiz();

// 🔥 STREAK CALCULATION — called every time the app opens:
final now = DateTime.now();
final authUser = ref.read(authProvider).asData?.value;

// 0. If user is authenticated, first try to sync progress FROM Firestore
//    so streak persists across reinstalls
final streakNotifier = ref.read(streakProvider.notifier);
if (authUser?.id.isNotEmpty == true) {
try {
final progressRepo = ref.read(progressRepositoryProvider);
final hiveProgress = progressRepo.getProgress();
// If Hive is empty or has no userId, fetch from Firestore
if (hiveProgress == null || hiveProgress.userId.isEmpty) {
await progressRepo.syncProgressFromFirestoreToHive(authUser!.id);
// Refresh the streak provider with restored data
streakNotifier.refresh();
}
} catch (_) {
// Silently handle Firestore fetch failure
}
}

// 0.5 Restore weekly activity from game_progress (Firebase-synced) to settings
//    so the weekly calendar survives cache clears
HiveService.restoreWeeklyActivityFromProgress();

	// 1. Update HiveService weekly activity + last practice date FIRST
	await HiveService.resetWeeklyActivityIfNewWeek();
	await HiveService.markDayActive(now.weekday);
	await HiveService.setLastPracticeDate(now);

	// 2. Check if streak should increment (new day) or reset (missed >48h)
	await streakNotifier.checkAndUpdateStreak();
	
	// 2.5 Check if weekly streak should update (new week)
	await streakNotifier.checkAndUpdateWeeklyStreak();
	
	// 3. Record today as active (updates lastActiveDate, totalActiveDays)
	await streakNotifier.recordActiveDay();

	// 4. Sync the final streak to the main progress provider
	await ref.read(progressProvider.notifier).syncStreak(
		ref.read(streakServiceProvider).getCurrentStreak(),
	);
	// 5. Upload streak data to Firestore for persistent storage
		if (authUser?.id.isNotEmpty == true) {
			try {
				final progressRepo = ref.read(progressRepositoryProvider);
				var gameProgress = progressRepo.getProgress();
				if (gameProgress != null) {
					// Ensure progress has the correct userId before uploading
					final uploadProgress = gameProgress.userId.isEmpty
						? gameProgress.copyWith(userId: authUser!.id)
						: gameProgress;
					await progressRepo.uploadProgressToFirestore(uploadProgress);
				}
			} catch (_) {
				// Silently handle Firestore upload failure
			}
		}

	// 6. Refresh ALL providers after streak updates
	streakNotifier.refresh();
	ref.read(progressProvider.notifier).fetchProgress();
	// Record initial activity for idle tracker
	await IdleTrackerService.recordActivity();
	});
	}

@override
void dispose() {
	_idleCheckTimer?.cancel();
	super.dispose();
	}



String _getTimeGreeting() {
final hour = DateTime.now().hour;
if (hour < 12) return 'Good Morning';
if (hour < 17) return 'Good Afternoon';
return 'Good Evening';
}

	@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final authAsync = ref.watch(authProvider);
final progressAsync = ref.watch(progressProvider);
	final chaptersAsync = ref.watch(allChaptersProvider);
final grammarAsync = ref.watch(allGrammarChaptersProvider);
final studyState = ref.watch(todoListProvider);
final lastOpenedChapter = ref.watch(lastOpenedChapterProvider);
	final notificationState = ref.watch(notificationProvider);
	final idleTrackerState = ref.watch(idleTrackerProvider);

final user = authAsync.asData?.value;
if (user?.name != null && user!.name.isNotEmpty) {
HiveService.setUserName(user.name);
}
final progress = progressAsync.asData?.value;
	final allVocabChapters = chaptersAsync.asData?.value ?? [];
	final allGrammarChapters = grammarAsync.asData?.value ?? [];

// Group lessons by level for Continue Learning
return Scaffold(
appBar: AppBar(
title: const Row(
children: [
Icon(Icons.translate_rounded, color: AppColors.primary, size: 28),
SizedBox(width: 8),
Flexible(
child: Text(
'SpeakEasy',
style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
overflow: TextOverflow.ellipsis,
),
),
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
	GestureDetector(
	onLongPress: () {
	  showDialog(
	    context: context,
	    builder: (_) => NotificationDialog(
	      onNavigateToSettings: () {
	        Navigator.pop(context);
	        Navigator.push(
	          context,
	          MaterialPageRoute(
	            builder: (_) => const SettingsScreen(),
	          ),
	        );
	      },
	    ),
	  );
	},
	child: IconButton(
	onPressed: () async {
	await Navigator.push(
	context,
	MaterialPageRoute(
	builder: (_) => const NotificationHistoryScreen(),
	),
	);
	// Update notification count when returning from history screen
	ref.read(notificationProvider.notifier).refresh();
	},
	icon: Stack(
	children: [
	const Icon(Icons.notifications_outlined, size: 28),
	if (notificationState.unreadCount > 0)
	Positioned(
	right: 0,
top: 0,
child: Container(
padding: const EdgeInsets.all(4),
decoration: BoxDecoration(
color: Colors.red,
shape: BoxShape.circle,
border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
),
constraints: const BoxConstraints(
minWidth: 18,
minHeight: 18,
),
child: Center(
child: Text(
'${notificationState.unreadCount}',
style: const TextStyle(
color: Colors.white,
fontSize: 10,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
),
),
),
],
		),
	),
		),
		IconButton(
onPressed: () async {
await Navigator.push(
context,
MaterialPageRoute(
builder: (context) => const SettingsScreen(),
),
);
ref.read(notificationProvider.notifier).refresh();
},
icon: const Icon(Icons.settings_outlined, size: 26),
),
const SizedBox(width: 8),
GestureDetector(
onTap: () => widget.onNavigateToTab?.call(4),
child: Container(
margin: const EdgeInsets.only(right: 16),
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
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
	body: Stack(
	children: [
	SafeArea(
	child: SingleChildScrollView(
	physics: const BouncingScrollPhysics(),
	padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
	child: Column(
	crossAxisAlignment: CrossAxisAlignment.start,
	children: [
	// 1. Greeting
	_buildGreetingSection(theme, user?.name),
	const SizedBox(height: 18),

	// 📝 Daily Quiz & ⚔️ Battle Arena (Side-by-Side Dual Cards)
	_buildDailyQuizAndBattleRow(context, theme, isDark),
	const SizedBox(height: 16),

	// 🎮 Learning Games (Directly below Quiz & Battle Arena)
	FeatureGateWidget(
	featureKey: 'games',
	child: _buildGameCard(theme, isDark),
	),
	const SizedBox(height: 24),

		// 3. Guides & Resources (Student Guide & Study Routine)
	_buildGuidesSection(theme, isDark),
	const SizedBox(height: 24),

	// 5. Continue Learning (Most Important - Keep at top)
	_buildContinueLearningSection(
	theme, isDark, studyState, allGrammarChapters, allVocabChapters, lastOpenedChapter,
	),
	const SizedBox(height: 24),

		// 6. Study Plan (To-Do)
		const StudyPlanSection(),
		const SizedBox(height: 24),
		
		// 7. AI Features (Important for modern learning)
	_buildAIFeaturesSection(theme, isDark),
	const SizedBox(height: 24),

	// 9. Learning Modules
	_buildHomeLearningSection(theme, isDark),
	const SizedBox(height: 24),

	// 10. Practice Section
	_buildHomePracticeSection(theme, isDark),
	const SizedBox(height: 24),

	// 12. Banner Ad
	const BannerAdWidget(),
	const SizedBox(height: 16),
	],
	),
	),
	),
	// Idle reminder overlay at bottom
	if (idleTrackerState.showingReminder)
	Positioned(
	left: 0,
	right: 0,
	bottom: MediaQuery.of(context).padding.bottom + 8,
	child: ReminderOverlay(
	hoursIdle: idleTrackerState.hoursIdle,
	onStartPractice: () async {
	await ref.read(idleTrackerProvider.notifier).recordActivity();
	widget.onNavigateToLessons?.call();
	},
	onDismiss: () async {
	await ref.read(idleTrackerProvider.notifier).dismissReminder();
	},
	),
	),
	],
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
_getTimeGreeting(),
style: theme.textTheme.headlineLarge?.copyWith(
fontWeight: FontWeight.w800,
fontSize: 26,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
const Text('👋', style: TextStyle(fontSize: 26)),
],
),
const SizedBox(height: 4),
Text(
name != null && name.isNotEmpty ? name : 'User',
style: theme.textTheme.titleLarge?.copyWith(
fontWeight: FontWeight.w800,
fontSize: 18,
),
),
const SizedBox(height: 4),
Text(
'Keep practicing English every day.',
style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
),
],
);
}





// TODAY'S WORDS — multi-word card

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

// 🔍 DEBUG: Log study plan state to help diagnose "All chapters completed" issue
debugPrint('📚 [ContinueLearning] items.length: ${items.length}');
debugPrint('📚 [ContinueLearning] nextGrammarId: ${studyState.nextGrammarId}');
debugPrint('📚 [ContinueLearning] nextVocabId: ${studyState.nextVocabId}');
debugPrint('📚 [ContinueLearning] lastOpened: $lastOpened');
debugPrint('📚 [ContinueLearning] grammarDone: $grammarDone / $grammarTotal');
debugPrint('📚 [ContinueLearning] vocabDone: $vocabDone / $vocabTotal');

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

// Fallback: first pending of each type if no resume found
TodoItem? firstPendingGrammar;
for (var item in items) {
if (item.type == 'grammar' && item.status == TodoStatus.pending) {
firstPendingGrammar = item;
break;
}
}
TodoItem? firstPendingVocab;
for (var item in items) {
if (item.type == 'vocabulary' && item.status == TodoStatus.pending) {
firstPendingVocab = item;
break;
}
}

final resumeGrammar = resumeFromLastOpened('grammar', 'grammar')
?? findById(items, studyState.nextGrammarId)
?? firstPendingGrammar;
final resumeVocab = resumeFromLastOpened('vocabulary', 'vocab')
?? findById(items, studyState.nextVocabId)
?? firstPendingVocab;

// 🔍 DEBUG: Log what we resolved
debugPrint('📚 [ContinueLearning] resumeGrammar: ${resumeGrammar?.id ?? 'null'}');
debugPrint('📚 [ContinueLearning] resumeVocab: ${resumeVocab?.id ?? 'null'}');
debugPrint('📚 [ContinueLearning] firstPendingGrammar: ${firstPendingGrammar?.id ?? 'null'}');
debugPrint('📚 [ContinueLearning] firstPendingVocab: ${firstPendingVocab?.id ?? 'null'}');

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
color: Colors.green.withValues(alpha: 0.06),
borderRadius: BorderRadius.circular(20),
border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
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
boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
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
	Column(
	mainAxisSize: MainAxisSize.min,
	crossAxisAlignment: CrossAxisAlignment.start,
	children: [
	Container(
	padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
	decoration: BoxDecoration(
	color: color.withValues(alpha: 0.1),
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
	],
	),
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

  // ── Daily Quiz & Battle Arena (Side-by-Side Dual Cards) ──
  Widget _buildDailyQuizAndBattleRow(BuildContext context, ThemeData theme, bool isDark) {
    final quizState = ref.watch(dailyQuizProvider);
    final quiz = quizState.quiz;
    final isCompleted = quiz?.isCompleted ?? false;
    final progress = quiz == null || quiz.totalQuestions == 0
        ? 0.0
        : quiz.answeredCount / quiz.totalQuestions;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── LEFT: Daily Quiz Card ──
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyQuizScreen()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -12,
                        child: Icon(
                          Icons.quiz_outlined,
                          size: 76,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isCompleted ? 'COMPLETED' : 'DAILY QUIZ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isCompleted)
                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)
                                else
                                  const Text('📝', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Daily Quiz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCompleted
                                  ? 'Score: ${quiz!.score} pts 🎉'
                                  : (quiz == null
                                      ? '10 Qs • ~5 min'
                                      : '${quiz.answeredCount}/${quiz.totalQuestions} answered'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (quiz != null && !isCompleted) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ],
                            const Spacer(),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isCompleted
                                        ? 'Results'
                                        : (quiz == null
                                            ? 'Start'
                                            : (quiz.answeredCount > 0 ? 'Resume' : 'Start')),
                                    style: const TextStyle(
                                      color: Color(0xFF4338CA),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isCompleted ? Icons.celebration_rounded : Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: const Color(0xFF4338CA),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── RIGHT: Battle Arena Card ──
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BattleLobbyScreen()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.sports_kabaddi_rounded,
                          size: 76,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '1v1 DUEL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                const Text('⚔️', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Battle Arena',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Speed quiz & live duel with learners or AI 🤖',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Enter Arena',
                                    style: TextStyle(
                                      color: Color(0xFF1E1B4B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeLearningSection(ThemeData theme, bool isDark) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 22),
const SizedBox(width: 8),
Text('Learning', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
const Spacer(),
GestureDetector(
onTap: () => widget.onNavigateToTab?.call(1),
child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
),
],
),
const SizedBox(height: 12),
SizedBox(
height: 120,
child: ListView.separated(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
itemCount: 5,
separatorBuilder: (_, __) => const SizedBox(width: 14),
itemBuilder: (_, i) {
final items = [
{
'title': 'Tense Rules',
'icon': Icons.auto_stories,
'gradient': [const Color(0xFFE94057), const Color(0xFFF27121)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenseCategoriesScreen())),
},
{
'title': 'Spoken Rules',
'icon': Icons.record_voice_over_rounded,
'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpokenRulesScreen())),
},
{
'title': 'Vocabulary',
'icon': Icons.menu_book_rounded,
'gradient': AppColors.primaryGradient,
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyScreen())),
},
{
'title': 'Verb Forms',
'icon': Icons.transform_rounded,
'gradient': [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerbFormsScreen())),
},
{
'title': 'Grammar',
'icon': Icons.edit_note_rounded,
'gradient': AppColors.purpleGradient,
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarListScreen())),
},
];
final item = items[i];
final grad = item['gradient'] as List<Color>;
return GestureDetector(
onTap: item['onTap'] as VoidCallback,
child: Container(
width: 180,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
borderRadius: BorderRadius.circular(20),
boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(12),
),
child: Icon(item['icon'] as IconData, color: Colors.white, size: 24),
),
Text(item['title'] as String,
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

// HOME PRACTICE SECTION — Tests & practice modes
Widget _buildHomePracticeSection(ThemeData theme, bool isDark) {
final items = [
{'title': 'Vocab Test', 'icon': Icons.quiz_rounded, 'gradient': AppColors.accentGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyTestScreen()))},
{'title': 'Mock Test', 'icon': Icons.assignment_rounded, 'gradient': AppColors.primaryGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MockTestListScreen()))},
{'title': 'Verb Quiz', 'icon': Icons.transform_rounded, 'gradient': AppColors.accentGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerbFormPracticeScreen()))},
{'title': 'Grammar Test', 'icon': Icons.quiz_rounded, 'gradient': AppColors.infoGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarTestListScreen()))},
{'title': 'Bangla English', 'icon': Icons.translate_rounded, 'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BanglaEnglishCategoryScreen()))},
{'title': 'Conversation', 'icon': Icons.forum_rounded, 'gradient': AppColors.secondaryGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationScreen()))},
{'title': 'Listening', 'icon': Icons.headset_rounded, 'gradient': AppColors.infoGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningScreen()))},
{'title': 'Speaking', 'icon': Icons.mic_rounded, 'gradient': AppColors.pinkGradient, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakingScreen()))},
{'title': 'Translate', 'icon': Icons.translate_rounded, 'gradient': [const Color(0xFF00BCD4), const Color(0xFF009688)], 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BanglishTranslatorScreen()))},
];

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 22),
const SizedBox(width: 8),
Text('Practice', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
const Spacer(),
GestureDetector(
onTap: () => widget.onNavigateToTab?.call(2),
child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
),
],
),
const SizedBox(height: 12),
GridView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 3,
crossAxisSpacing: 12,
mainAxisSpacing: 12,
childAspectRatio: 0.9,
),
itemCount: items.length,
itemBuilder: (_, i) {
final item = items[i];
final grad = item['gradient'] as List<Color>;
return GestureDetector(
onTap: item['onTap'] as VoidCallback,
child: Container(
decoration: BoxDecoration(
gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
borderRadius: BorderRadius.circular(18),
boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(14),
),
child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
),
const SizedBox(height: 8),
Text(item['title'] as String,
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
textAlign: TextAlign.center),
],
),
),
);
},
),
],
);
}

// AI FEATURES SECTION - Combined AI Teacher, Homework, Sentence Analyzer
Widget _buildAIFeaturesSection(ThemeData theme, bool isDark) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
const SizedBox(width: 8),
Text('AI-Powered Learning', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
],
),
const SizedBox(height: 12),
SizedBox(
height: 160,
child: ListView.separated(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
itemCount: 3,
separatorBuilder: (_, __) => const SizedBox(width: 16),
itemBuilder: (_, i) {
final items = [
{
'title': 'AI Teacher',
'subtitle': 'Chat & get feedback',
'icon': Icons.smart_toy_rounded,
'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
'onTap': () => widget.onNavigateToTab?.call(3),
},
{
'title': 'AI Homework',
'subtitle': 'Translation practice',
'icon': Icons.home_work_rounded,
'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeworkScreen())),
},
{
'title': 'Sentence Analyzer',
'subtitle': 'Learn grammar deeply',
'icon': Icons.auto_stories_rounded,
'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SentenceAnalyzerScreen())),
},
];
final item = items[i];
final grad = item['gradient'] as List<Color>;
return GestureDetector(
onTap: item['onTap'] as VoidCallback,
child: Container(
width: 200,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
borderRadius: BorderRadius.circular(20),
boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(12),
),
child: Icon(item['icon'] as IconData, color: Colors.white, size: 28),
),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
item['title'] as String,
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
),
const SizedBox(height: 4),
Text(
item['subtitle'] as String,
style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
),
],
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

// GUIDES SECTION — Student Guide & Study Routine PDFs
Widget _buildGuidesSection(ThemeData theme, bool isDark) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Icon(Icons.library_books_rounded, color: AppColors.accent, size: 22),
const SizedBox(width: 8),
Text('Guides & Resources',
style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
],
),
const SizedBox(height: 12),
SizedBox(
height: 150,
child: ListView.separated(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
itemCount: 2,
separatorBuilder: (_, __) => const SizedBox(width: 16),
itemBuilder: (_, i) {
final items = [
{
'title': 'Student Guide',
'subtitle': 'Complete learning guide with tips & instructions',
'icon': Icons.school_rounded,
'asset': 'assets/pdfs/STUDENT_GUIDE.pdf',
'gradient': AppColors.accentGradient,
},
{
'title': 'Study Routine',
'subtitle': 'Daily & weekly study plan for best results',
'icon': Icons.calendar_today_rounded,
'asset': 'assets/pdfs/STUDY_ROUTINE.pdf',
'gradient': AppColors.secondaryGradient,
},
];
final item = items[i];
final grad = item['gradient'] as List<Color>;
return GestureDetector(
onTap: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => const GuidesScreen()),
),
child: Container(
width: 220,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
borderRadius: BorderRadius.circular(20),
boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(12),
),
child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
),
const Spacer(),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.15),
borderRadius: BorderRadius.circular(8),
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 12),
SizedBox(width: 4),
Text('PDF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
],
),
),
],
),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
item['title'] as String,
style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
),
const SizedBox(height: 4),
Text(
item['subtitle'] as String,
style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
],
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

// GAME CARD
Widget _buildGameCard(ThemeData theme, bool isDark) {
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
BoxShadow(color: const Color(0xFF6A11CB).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
],
),
child: Stack(
children: [
Positioned(
right: -16,
bottom: -16,
child: Icon(Icons.sports_esports_rounded, size: 120, color: Colors.white.withValues(alpha: 0.1)),
),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(10),
),
child: const Text(
'GAME',
style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
),
),
const Spacer(),
const Text('🎮', style: TextStyle(fontSize: 20)),
],
),
const SizedBox(height: 12),
const Text(
'Learning Games',
style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
),
const SizedBox(height: 4),
Text(
'Play fun learning games, practice English & earn rewards!',
style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
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
}
