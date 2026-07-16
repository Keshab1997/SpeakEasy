import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/streak_widget.dart';
import '../../../core/widgets/feature_gate_widget.dart';
import '../../../services/hive_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/remote_config_service.dart';
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
import '../widgets/mini_leaderboard_widget.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../daily_quiz/screens/daily_quiz_screen.dart';
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
	final newStreak = await streakNotifier.checkAndUpdateStreak();
	
	// 2.5 Check if weekly streak should update (new week)
	await streakNotifier.checkAndUpdateWeeklyStreak();
	
	// 3. Record today as active (updates lastActiveDate, totalActiveDays)
	await streakNotifier.recordActiveDay();

// 4. Handle streak freeze — if streak was reset to 1 and we have a freeze, restore it
if (newStreak == 1) {
final progress = ref.read(progressProvider).asData?.value;
final oldStreak = progress?.streakDays ?? 0;
if (oldStreak > 1) {
final hadFreeze = await HiveService.useStreakFreeze();
if (hadFreeze) {
// Restore the streak from before the reset
for (int i = 1; i < oldStreak; i++) {
await streakNotifier.incrementStreak();
}
}
}
}

// 4.5 Sync the final streak back to the main progress provider (Firestore 'progress' collection)

// if it wasn't refreshed yet use the one from service directly or 
await ref.read(progressProvider.notifier).syncStreak(ref.read(streakServiceProvider).getCurrentStreak());

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

/// Returns true if user practiced today (checked via last active date)
bool _hasPracticedToday() {
final lastActive = HiveService.getLastPracticeDate();
if (lastActive == null) return false;
final now = DateTime.now();
return lastActive.year == now.year &&
lastActive.month == now.month &&
lastActive.day == now.day;
}

/// Shows streak info dialog (Duolingo-style)
void _showStreakInfoDialog(BuildContext context) {
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: const Row(
children: [
Text('🔥 ', style: TextStyle(fontSize: 24)),
Text('My Streak'),
],
),
content: const Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'• Practice daily to keep your streak alive.\n'
'• Complete at least one lesson each day.\n'
'• Buy a Streak Freeze (🛡️) to protect your streak '
'if you miss a day.\n'
'• Longer streaks unlock special badges & rewards!',
style: TextStyle(fontSize: 14, height: 1.5),
),
SizedBox(height: 16),
Text(
'💡 Tip: Set a daily reminder in Settings '
'to never miss a practice day!',
style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Got it!'),
),
],
),
);
}

/// Buy streak freeze (cost from remote config)
Future<void> _buyStreakFreeze(BuildContext context, WidgetRef ref, int currentCoins) async {
final cost = await RemoteConfigService.getStreakFreezeCost();
if (!context.mounted) return;
if (currentCoins < cost) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: const Text('Not enough coins! Play games to earn more.'),
backgroundColor: Colors.red.shade400,
behavior: SnackBarBehavior.floating,
),
);
return;
}
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('🛡️ Buy Streak Freeze'),
content: Text('Spend $cost coins to buy a Streak Freeze?\n'
'You can protect your streak if you miss a day.'),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel'),
),
TextButton(
onPressed: () async {
await ref.read(coinProvider.notifier).spendCoins(cost);
await HiveService.addStreakFreeze();
if (context.mounted) {
Navigator.pop(ctx);
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('🛡️ Streak Freeze purchased!'),
behavior: SnackBarBehavior.floating,
),
);
}
},
child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
),
],
),
);
}

/// Share streak on social media
void _shareStreak(BuildContext context, int streak) {
final message = streak > 0
? "🔥 I'm on a $streak-day streak on SpeakEasy! Practicing English every day. Join me! 🚀"
: "Start your English learning journey with SpeakEasy! 🚀";
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('📤 Share: "$message"'),
behavior: SnackBarBehavior.floating,
action: SnackBarAction(
label: 'Copy',
onPressed: () {
// In a real app, use share_plus package
},
),
),
);
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
final xpState = ref.watch(xpProvider);
final coinState = ref.watch(coinProvider);
final streakState = ref.watch(streakProvider);
final notificationState = ref.watch(notificationProvider);

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
final int currentStreak = streakState.currentStreak > 0
? streakState.currentStreak
: (progress?.streakDays ?? 0);
final lessonsCompleted = studyState.completedCount;
final totalLessons = studyState.totalCount > 0 ? studyState.totalCount : 1;
final progressPct = (lessonsCompleted / totalLessons).clamp(0.0, 1.0);
final favoritesCount = allWords.where((w) => w.isFavorite).length;
final int currentXP = xpState.currentXP;
final int currentCoins = coinState.currentCoins;
final int currentLevel = xpState.currentLevel;

// Today's words from JSON chapters — picks 5 words every 10 minutes
final todayWords = _pickWords(allChapterWords, 5);

// Group lessons by level for Continue Learning
return Scaffold(
appBar: AppBar(
title: Row(
children: [
const Icon(Icons.translate_rounded, color: AppColors.primary, size: 28),
const SizedBox(width: 8),
Flexible(
child: const Text(
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
IconButton(
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
// 1. Greeting
_buildGreetingSection(theme, user?.name),
const SizedBox(height: 20),
// 🏆 Daily Quest
_buildDailyQuizCard(context, theme, isDark),
const SizedBox(height: 20),
	// 2. Streak & Progress (Combined in one widget)
	StreakWidget(
	currentStreak: currentStreak,
	weeklyStreak: streakState.weeklyStreak,
	weeklyMilestone: streakState.weeklyMilestone,
	weeklyMilestoneLabel: streakState.weeklyMilestoneLabel,
	thisWeekActiveDays: streakState.thisWeekActiveDays,
	todayXP: currentXP,
	dailyXPTarget: 50,
	hasPracticeToday: _hasPracticedToday(),
	isStreakFrozen: HiveService.getStreakFreezeCount() > 0,
	streakFreezeCount: HiveService.getStreakFreezeCount(),
	onTap: () => _showStreakInfoDialog(context),
	onBuyFreeze: () => _buyStreakFreeze(context, ref, currentCoins),
	onShare: () => _shareStreak(context, currentStreak),
	),
const SizedBox(height: 24),

// 3. Leaderboard (Mini)
const MiniLeaderboardWidget(),
const SizedBox(height: 24),

// 4. Guides & Resources (Student Guide & Study Routine)
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

// 7. Today's Word
_buildTodaysWordCard(theme, isDark, todayWords, isLoading: chaptersAsync.isLoading),
const SizedBox(height: 24),

// 8. AI Features (Important for modern learning)
_buildAIFeaturesSection(theme, isDark),
const SizedBox(height: 24),

// 9. Learning Modules
_buildHomeLearningSection(theme, isDark),
const SizedBox(height: 24),

// 10. Practice Section
_buildHomePracticeSection(theme, isDark),
const SizedBox(height: 24),

// 11. Game Section
FeatureGateWidget(
featureKey: 'games',
child: _buildGameCard(theme, isDark),
),
const SizedBox(height: 24),

// 12. Banner Ad
const BannerAdWidget(),
const SizedBox(height: 16),
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

// PROGRESS CARD — real data from providers
Widget _buildProgressCard(
ThemeData theme, int currentStreak, int lessonsCompleted, double progressPct, int totalLessons, int currentXP, int currentCoins, int currentLevel,
) {
final pctLabel = '${(progressPct * 100).toInt()}%';
return Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: const LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
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
'$currentStreak Day${currentStreak == 1 ? '' : 's'} Streak',
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
const SizedBox(height: 12),
// Live game stats row
Container(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.12),
borderRadius: BorderRadius.circular(14),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: [
_buildMiniStat('✨', '$currentXP', 'XP'),
Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),
_buildMiniStat('🪙', '$currentCoins', 'Coins'),
Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),
_buildMiniStat('🏆', 'Lv. $currentLevel', 'Level'),
],
),
),
],
),
);
}

Widget _buildMiniStat(String emoji, String value, String label) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(emoji, style: const TextStyle(fontSize: 14)),
const SizedBox(width: 4),
Text(
value,
style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
),
],
),
const SizedBox(height: 2),
Text(
label,
style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500),
),
],
);
}

// TODAY'S WORDS — multi-word card
List<ChapterWord> _pickWords(List<ChapterWord> words, int count) {
if (words.isEmpty) return [];
final start = _wordIndex(words.length);
final result = <ChapterWord>[];
for (int i = 0; i < count && i < words.length; i++) {
result.add(words[(start + i) % words.length]);
}
return result;
}

Widget _buildTodaysWordCard(ThemeData theme, bool isDark, List<ChapterWord> todayWords, {required bool isLoading}) {
if (isLoading) return _buildLoadingWordCard(theme, isDark);
if (todayWords.isEmpty) return _buildEmptyWordCard(theme, isDark);

final featured = todayWords.first;
final more = todayWords.length > 1 ? todayWords.sublist(1) : <ChapterWord>[];

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
// Header
Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
color: AppColors.accent.withOpacity(0.1),
child: Row(
children: [
const Icon(Icons.wb_sunny_outlined, color: AppColors.accent, size: 20),
const SizedBox(width: 8),
const Text("TODAY'S WORDS", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
const Spacer(),
Text(
'${todayWords.length} words',
style: TextStyle(color: AppColors.accent.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600),
),
],
),
),
// Featured word — full detail
Padding(
padding: EdgeInsets.fromLTRB(20, 20, 20, more.isEmpty ? 20 : 0),
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
featured.word,
style: theme.textTheme.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
),
if (featured.pronunciation.isNotEmpty)
Text(
featured.pronunciation,
style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
),
],
),
),
GestureDetector(
onTap: () => _speakWord(featured.word),
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
if (featured.meaning.isNotEmpty) ...[
const Text('Meaning (ইংরেজি):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
const SizedBox(height: 4),
Text(featured.meaning, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
const SizedBox(height: 12),
],
if (featured.banglaMeaning.isNotEmpty) ...[
const Text('Meaning (বাংলা):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
const SizedBox(height: 4),
Text(featured.banglaMeaning, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 12),
],
if (featured.exampleSentence.isNotEmpty) ...[
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
featured.exampleSentence,
style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
),
),
],
],
),
),
// More words — compact horizontal list
if (more.isNotEmpty) ...[
Padding(
padding: const EdgeInsets.symmetric(horizontal: 20),
child: Row(
children: [
Text('More Words',
style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.grey)),
const Spacer(),
Text('${more.length} more',
style: const TextStyle(color: Colors.grey, fontSize: 11)),
],
),
),
const SizedBox(height: 8),
SizedBox(
height: 80,
child: ListView.separated(
scrollDirection: Axis.horizontal,
physics: const BouncingScrollPhysics(),
padding: const EdgeInsets.symmetric(horizontal: 20),
itemCount: more.length,
separatorBuilder: (_, __) => const SizedBox(width: 10),
itemBuilder: (_, i) => _buildCompactWordCard(more[i], isDark, theme),
),
),
const SizedBox(height: 16),
],
// Browse all
GestureDetector(
onTap: () => _openVocabulary(),
child: Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(vertical: 14),
decoration: BoxDecoration(
border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text('Browse Vocabulary',
style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
SizedBox(width: 4),
Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 16),
],
),
),
),
],
),
),
);
}

Widget _buildCompactWordCard(ChapterWord w, bool isDark, ThemeData theme) {
return Container(
width: 180,
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
decoration: BoxDecoration(
color: isDark ? Colors.grey[900] : Colors.grey[50],
borderRadius: BorderRadius.circular(14),
border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(w.word,
style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
maxLines: 1, overflow: TextOverflow.ellipsis),
const SizedBox(height: 2),
Text(w.banglaMeaning.isNotEmpty ? w.banglaMeaning : w.meaning,
style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
maxLines: 1, overflow: TextOverflow.ellipsis),
],
),
),
GestureDetector(
onTap: () => _speakWord(w.word),
child: Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: AppColors.primary.withOpacity(0.1),
borderRadius: BorderRadius.circular(8),
),
child: Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 16),
),
),
],
),
);
}

void _openVocabulary() {
widget.onNavigateToTab?.call(1);
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
Text("TODAY'S WORDS", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
const SizedBox(
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
Text("TODAY'S WORDS", style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
print('📚 [ContinueLearning] items.length: ${items.length}');
print('📚 [ContinueLearning] nextGrammarId: ${studyState.nextGrammarId}');
print('📚 [ContinueLearning] nextVocabId: ${studyState.nextVocabId}');
print('📚 [ContinueLearning] lastOpened: $lastOpened');
print('📚 [ContinueLearning] grammarDone: $grammarDone / $grammarTotal');
print('📚 [ContinueLearning] vocabDone: $vocabDone / $vocabTotal');

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
print('📚 [ContinueLearning] resumeGrammar: ${resumeGrammar?.id ?? 'null'}');
print('📚 [ContinueLearning] resumeVocab: ${resumeVocab?.id ?? 'null'}');
print('📚 [ContinueLearning] firstPendingGrammar: ${firstPendingGrammar?.id ?? 'null'}');
print('📚 [ContinueLearning] firstPendingVocab: ${firstPendingVocab?.id ?? 'null'}');

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
	Column(
	mainAxisSize: MainAxisSize.min,
	crossAxisAlignment: CrossAxisAlignment.start,
	children: [
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

// ── Daily Quest Card (Duolingo-style, drives daily engagement) ──
  //Daily Quiz Card (replaces Daily Quest)
  Widget _buildDailyQuizCard(BuildContext context, ThemeData theme, bool isDark) {
    final quizState = ref.watch(dailyQuizProvider);
    final quiz = quizState.quiz;
    final isCompleted = quiz?.isCompleted ?? false;
    final progress = quiz == null || quiz.totalQuestions == 0
        ? 0.0
        : quiz.answeredCount / quiz.totalQuestions;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(Icons.quiz_outlined,
                  size: 100, color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'DAILY QUIZ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isCompleted)
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 22)
                      else
                        const Text('📝', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Today's Quiz Challenge",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted
                        ? 'Score: ${quiz!.score} pts! Great work today! 🎉'
                        : quiz == null
                            ? '10 questions ⏱️ ~5 min'
                            : '${quiz.answeredCount} / ${quiz.totalQuestions} answered',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  if (quiz != null && !isCompleted) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyQuizScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      isCompleted
                          ? Icons.celebration
                          : Icons.arrow_forward,
                      size: 18,
                    ),
                    label: Text(
                      isCompleted
                          ? 'View Results'
                          : quiz == null
                              ? 'Generate Quiz'
                              : quiz.answeredCount > 0
                                  ? 'Resume Quiz'
                                  : 'Start Quiz',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3F51B5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

// HOMEWORK CARD — AI-generated translation practice
Widget _buildHomeworkCard(ThemeData theme) {
return GestureDetector(
onTap: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => const HomeworkScreen()),
),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: const Color(0xFF6366F1).withOpacity(0.3),
blurRadius: 16,
offset: const Offset(0, 8),
),
],
),
child: Stack(
children: [
Positioned(
right: -16,
bottom: -16,
child: Icon(Icons.home_work_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
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
'HOMEWORK',
style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
),
),
const Spacer(),
Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
borderRadius: BorderRadius.circular(8),
),
child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
),
],
),
const SizedBox(height: 12),
const Text(
'AI Homework',
style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
),
const SizedBox(height: 4),
Text(
'Pick a topic. AI creates 10 Bangla sentences.\nTranslate them and get instant corrections.',
style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => const HomeworkScreen()),
),
icon: const Icon(Icons.auto_awesome_rounded, size: 18),
label: const Text('Start Homework', style: TextStyle(fontWeight: FontWeight.bold)),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.white,
foregroundColor: const Color(0xFF6366F1),
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

// SENTENCE ANALYZER CARD — AI grammar breakdown + practice
Widget _buildSentenceAnalyzerCard(ThemeData theme) {
return GestureDetector(
onTap: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => const SentenceAnalyzerScreen()),
),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: const Color(0xFF8B5CF6).withOpacity(0.3),
blurRadius: 16,
offset: const Offset(0, 8),
),
],
),
child: Stack(
children: [
Positioned(
right: -16,
bottom: -16,
child: Icon(Icons.auto_stories_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
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
'SENTENCE ANALYZER',
style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
),
),
const Spacer(),
Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
borderRadius: BorderRadius.circular(8),
),
child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 16),
),
],
),
const SizedBox(height: 12),
const Text(
'Learn Grammar with AI',
style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
),
const SizedBox(height: 4),
Text(
'Analyze Bangla sentences by tense.\nAI explains grammar, then gives practice tasks.',
style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: () => Navigator.push(
context,
MaterialPageRoute(builder: (_) => const SentenceAnalyzerScreen()),
),
icon: const Icon(Icons.auto_stories_rounded, size: 18),
label: const Text('Start Learning', style: TextStyle(fontWeight: FontWeight.bold)),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.white,
foregroundColor: const Color(0xFF8B5CF6),
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

// HOME LEARNING SECTION — Spoken Rules, Vocabulary, Grammar, Tense Rules
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
child: Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
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
'gradient': [Color(0xFFE94057), Color(0xFFF27121)],
'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenseCategoriesScreen())),
},
{
'title': 'Spoken Rules',
'icon': Icons.record_voice_over_rounded,
'gradient': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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
'gradient': [Color(0xFF06B6D4), Color(0xFF0891B2)],
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
boxShadow: [BoxShadow(color: grad[0].withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
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
child: Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
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
boxShadow: [BoxShadow(color: grad[0].withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
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
boxShadow: [BoxShadow(color: grad[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.2),
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
style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
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
boxShadow: [BoxShadow(color: grad[0].withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
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
color: Colors.white.withOpacity(0.2),
borderRadius: BorderRadius.circular(12),
),
child: Icon(item['icon'] as IconData, color: Colors.white, size: 26),
),
const Spacer(),
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.15),
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
style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
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
