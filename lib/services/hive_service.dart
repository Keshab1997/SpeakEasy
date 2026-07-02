import 'package:hive_flutter/hive_flutter.dart';
import '../models/game/game_progress_model.dart';

class HiveService {
  static const String _favoritesBox = 'favorites';
  static const String _settingsBox = 'settings';
  static const String _historyBox = 'history';
  static const String _vocabProgressBox = 'vocab_progress';
  static const String _vocabTestHistoryBox = 'vocab_test_history';
  static const String _masterGuideHistoryBox = 'master_guide_history';
  static const String _studyPlanBox = 'study_plan';
  static const String _translatorHistoryBox = 'translator_history';
  static const String _homeworkHistoryBox = 'homework_history';
  static const String _sentenceAnalysisHistoryBox = 'sentence_analysis_history';
  static const String _gameProgressBox = 'game_progress';
  static const String _gameStatisticsBox = 'game_statistics';
  static const String _gameAchievementsBox = 'game_achievements';
  static const String _notificationHistoryBox = 'notification_history';
  static const String _mockTestProgressBox = 'mock_test_progress';
  static const String _aiSavedVocabBox = 'ai_saved_vocab';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_vocabProgressBox);
    await Hive.openBox('vocab_cache');
    await Hive.openBox(_masterGuideHistoryBox);
    await Hive.openBox(_studyPlanBox);
    await Hive.openBox(_translatorHistoryBox);
    await Hive.openBox(_homeworkHistoryBox);
    await Hive.openBox(_sentenceAnalysisHistoryBox);
    await Hive.openBox(_gameProgressBox);
    await Hive.openBox(_gameStatisticsBox);
    await Hive.openBox(_gameAchievementsBox);
    await Hive.openBox(_notificationHistoryBox);
    await Hive.openBox(_mockTestProgressBox);
    await Hive.openBox(_aiSavedVocabBox);
  }

  static Box get _vocabProgress => Hive.box(_vocabProgressBox);

  // Vocabulary Chapter Progress
  static Future<void> markChapterRead(int chapterNumber) async {
    if (!Hive.isBoxOpen(_vocabProgressBox)) {
      await Hive.openBox(_vocabProgressBox);
    }
    final read = getReadChapters();
    if (!read.contains(chapterNumber)) {
      read.add(chapterNumber);
      await _vocabProgress.put('readChapters', read);
    }
  }

  static List<int> getReadChapters() {
    if (!Hive.isBoxOpen(_vocabProgressBox)) return [];
    return (_vocabProgress.get('readChapters', defaultValue: <int>[]) as List)
        .cast<int>();
  }

  static bool isChapterRead(int chapterNumber) {
    return getReadChapters().contains(chapterNumber);
  }

  // Vocabulary Test History
  static Future<void> saveTestSession(List<String> words, int score) async {
    if (!Hive.isBoxOpen(_vocabTestHistoryBox)) {
      await Hive.openBox(_vocabTestHistoryBox);
    }
    final box = Hive.box(_vocabTestHistoryBox);
    final sessions = getTestHistory();
    sessions.insert(0, {
      'words': words,
      'score': score,
      'total': words.length,
      'date': DateTime.now().toIso8601String(),
    });
    if (sessions.length > 20) sessions.removeLast();
    await box.put('sessions', sessions);
  }

  static List<Map<String, dynamic>> getTestHistory() {
    if (!Hive.isBoxOpen(_vocabTestHistoryBox)) return [];
    final box = Hive.box(_vocabTestHistoryBox);
    final raw = box.get('sessions', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteTestSession(int index) async {
    if (!Hive.isBoxOpen(_vocabTestHistoryBox)) return;
    final box = Hive.box(_vocabTestHistoryBox);
    final sessions = getTestHistory();
    if (index < 0 || index >= sessions.length) return;
    sessions.removeAt(index);
    await box.put('sessions', sessions);
  }

  static Future<void> clearAllTestSessions() async {
    if (!Hive.isBoxOpen(_vocabTestHistoryBox)) return;
    await Hive.box(_vocabTestHistoryBox).put('sessions', <Map<String, dynamic>>[]);
  }

  // Master Guide History
  static Future<void> saveMasterGuideSession(Map<String, dynamic> session) async {
    if (!Hive.isBoxOpen(_masterGuideHistoryBox)) {
      await Hive.openBox(_masterGuideHistoryBox);
    }
    final box = Hive.box(_masterGuideHistoryBox);
    final sessions = getMasterGuideHistory();
    sessions.insert(0, session);
    if (sessions.length > 30) sessions.removeLast();
    await box.put('sessions', sessions);
  }

  static List<Map<String, dynamic>> getMasterGuideHistory() {
    if (!Hive.isBoxOpen(_masterGuideHistoryBox)) return [];
    final box = Hive.box(_masterGuideHistoryBox);
    final raw = box.get('sessions', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteMasterGuideSession(int index) async {
    if (!Hive.isBoxOpen(_masterGuideHistoryBox)) return;
    final box = Hive.box(_masterGuideHistoryBox);
    final sessions = getMasterGuideHistory();
    if (index < 0 || index >= sessions.length) return;
    sessions.removeAt(index);
    await box.put('sessions', sessions);
  }

  static Future<void> clearAllMasterGuideSessions() async {
    if (!Hive.isBoxOpen(_masterGuideHistoryBox)) return;
    await Hive.box(_masterGuideHistoryBox).put('sessions', <Map<String, dynamic>>[]);
  }

  static Box get _favorites => Hive.box(_favoritesBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box get _history => Hive.box(_historyBox);

  // Favorites
  static Future<void> addFavorite(String wordId) async {
    final favorites = _favorites.get('wordIds', defaultValue: <String>[]) as List<String>;
    if (!favorites.contains(wordId)) {
      favorites.add(wordId);
      await _favorites.put('wordIds', favorites);
    }
  }

  static Future<void> removeFavorite(String wordId) async {
    final favorites = _favorites.get('wordIds', defaultValue: <String>[]) as List<String>;
    favorites.remove(wordId);
    await _favorites.put('wordIds', favorites);
  }

  static List<String> getFavorites() {
    return _favorites.get('wordIds', defaultValue: <String>[]) as List<String>;
  }

  static bool isFavorite(String wordId) {
    return getFavorites().contains(wordId);
  }

  // Settings
  static Future<void> setDarkMode(bool value) async {
    await _settings.put('darkMode', value);
  }

  static bool isDarkMode() {
    return _settings.get('darkMode', defaultValue: false) as bool;
  }

  static Future<void> setNotificationEnabled(bool value) async {
    await _settings.put('notifications', value);
  }

  static bool isNotificationEnabled() {
    return _settings.get('notifications', defaultValue: true) as bool;
  }

  // Notification sub-preferences
  static Future<void> setDailyWordNotification(bool value) async {
    await _settings.put('notify_daily_word', value);
  }

  static bool isDailyWordNotification() {
    return _settings.get('notify_daily_word', defaultValue: true) as bool;
  }

  static Future<void> setPracticeReminderNotification(bool value) async {
    await _settings.put('notify_practice_reminder', value);
  }

  static bool isPracticeReminderNotification() {
    return _settings.get('notify_practice_reminder', defaultValue: true) as bool;
  }

  static Future<void> setStreakNotification(bool value) async {
    await _settings.put('notify_streak', value);
  }

  static bool isStreakNotification() {
    return _settings.get('notify_streak', defaultValue: true) as bool;
  }

  // Streak (for notifications)
  static Future<void> setStreak(int value) async {
    await _settings.put('notification_streak', value);
  }

  static int getStreak() {
    return _settings.get('notification_streak', defaultValue: 0) as int;
  }

  // ── Duolingo-style Streak Freeze ──

  static Future<void> setStreakFreezeCount(int count) async {
    await _settings.put('streak_freezes', count);
  }

  static int getStreakFreezeCount() {
    return _settings.get('streak_freezes', defaultValue: 0) as int;
  }

  static Future<void> addStreakFreeze() async {
    final current = getStreakFreezeCount();
    await setStreakFreezeCount(current + 1);
  }

  static Future<bool> useStreakFreeze() async {
    final current = getStreakFreezeCount();
    if (current <= 0) return false;
    await setStreakFreezeCount(current - 1);
    return true;
  }

  // ── Last App Open Date (for re-engagement tracking) ──

  static Future<void> setLastAppOpenDate(DateTime date) async {
    await _settings.put('last_app_open_date', date.toIso8601String());
  }

  static DateTime? getLastAppOpenDate() {
    final raw = _settings.get('last_app_open_date');
    if (raw == null) return null;
    return DateTime.tryParse(raw as String);
  }

  // ── Re-engagement Notification Toggle ──

  static Future<void> setReEngagementEnabled(bool value) async {
    await _settings.put('re_engagement_notifications', value);
  }

  static bool isReEngagementEnabled() {
    return _settings.get('re_engagement_notifications', defaultValue: true) as bool;
  }

  // ── Weekly Activity Calendar (7 days) ──
  // Tracks which days this week the user practiced
  // Keys: '0'=Monday ... '6'=Sunday, value=true if practiced

  static Future<void> markDayActive(int weekday) async {
    // weekday: 1=Monday ... 7=Sunday (DateTime convention)
    final map = getWeeklyActivity();
    map[weekday.toString()] = true;
    await _settings.put('weekly_activity', map);

    // Also persist to game_progress box so it gets synced to Firebase
    await _saveWeeklyActivityToGameProgress(map);
  }

  static Map<String, dynamic> getWeeklyActivity() {
    final raw = _settings.get('weekly_activity', defaultValue: <String, dynamic>{}) as Map;
    return Map<String, dynamic>.from(raw);
  }

  static bool isDayActive(int weekday) {
    final map = getWeeklyActivity();
    return map[weekday.toString()] == true;
  }

  /// Returns active days for current week (used for calendar grid)
  static List<bool> getWeekActivityList() {
    final raw = _settings.get('weekly_activity', defaultValue: <String, dynamic>{}) as Map;
    final map = Map<String, dynamic>.from(raw);
    return List.generate(7, (i) => map[(i + 1).toString()] == true);
  }

  /// Reset weekly activity (call at start of new week)
  static Future<void> resetWeeklyActivity() async {
    await _settings.put('weekly_activity', <String, dynamic>{});
    // Also reset in game_progress box
    await _saveWeeklyActivityToGameProgress(<String, dynamic>{});
  }

  /// Get the Monday of current week as "YYYY-MM-DD" string
  static String _getCurrentWeekStart() {
    final now = DateTime.now();
    final daysSinceMonday = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysSinceMonday));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  /// Save weekly activity map to game_progress box (for Firebase sync)
  static Future<void> _saveWeeklyActivityToGameProgress(Map<String, dynamic> activity) async {
    if (!Hive.isBoxOpen(_gameProgressBox)) return;
    final box = Hive.box(_gameProgressBox);
    final raw = box.get('user_progress');
    if (raw == null) return;
    try {
      final progress = GameProgressModel.fromMap(
        Map<String, dynamic>.from(raw as Map),
        '',
      );
      final updated = progress.copyWith(
        weeklyActivity: activity.map((k, v) => MapEntry(k, v == true)),
        weeklyActivityWeekStart: _getCurrentWeekStart(),
      );
      await box.put('user_progress', updated.toMap());
    } catch (_) {
      // Silently ignore parse errors
    }
  }

  /// Restore weekly activity from game_progress box to settings box.
  /// Call this after syncing progress from Firestore to Hive.
  static void restoreWeeklyActivityFromProgress() {
    if (!Hive.isBoxOpen(_gameProgressBox)) return;
    final box = Hive.box(_gameProgressBox);
    final raw = box.get('user_progress');
    if (raw == null) return;

    try {
      final progress = GameProgressModel.fromMap(
        Map<String, dynamic>.from(raw as Map),
        '',
      );

      // Only restore if the stored week matches the current week
      if (progress.weeklyActivityWeekStart == _getCurrentWeekStart()) {
        final restoredMap = progress.weeklyActivity
            .map((k, v) => MapEntry(k, v as dynamic));
        _settings.put('weekly_activity', restoredMap);
      }
    } catch (_) {
      // Silently ignore parse errors
    }
  }

  // ── Streak Freeze Shop / Cost ──

  static int getStreakFreezeCost() {
    return 100; // coins per freeze
  }

  /// Last practiced date (separate from game progress date)
  static Future<void> setLastPracticeDate(DateTime date) async {
    await _settings.put('last_practice_date', date.toIso8601String());
  }

  static DateTime? getLastPracticeDate() {
    final raw = _settings.get('last_practice_date');
    if (raw == null) return null;
    return DateTime.tryParse(raw as String);
  }

  // ── Homework History ──

  static Future<void> saveHomeworkSession(Map<String, dynamic> session) async {
    if (!Hive.isBoxOpen(_homeworkHistoryBox)) {
      await Hive.openBox(_homeworkHistoryBox);
    }
    final box = Hive.box(_homeworkHistoryBox);
    final history = getHomeworkHistory();
    history.insert(0, session);
    if (history.length > 50) history.removeLast();
    await box.put('sessions', history);
  }

  static List<Map<String, dynamic>> getHomeworkHistory() {
    if (!Hive.isBoxOpen(_homeworkHistoryBox)) return [];
    final box = Hive.box(_homeworkHistoryBox);
    final raw = box.get('sessions', defaultValue: []) as List;
    return raw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      if (map['questions'] is List) {
        map['questions'] = (map['questions'] as List).map((q) => Map<String, dynamic>.from(q as Map)).toList();
      }
      return map;
    }).toList();
  }

  static Future<void> deleteHomeworkSession(int index) async {
    if (!Hive.isBoxOpen(_homeworkHistoryBox)) return;
    final box = Hive.box(_homeworkHistoryBox);
    final history = getHomeworkHistory();
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    await box.put('sessions', history);
  }

  static Future<void> clearAllHomeworkSessions() async {
    if (!Hive.isBoxOpen(_homeworkHistoryBox)) return;
    await Hive.box(_homeworkHistoryBox).put('sessions', <Map<String, dynamic>>[]);
  }

  // ── Sentence Analyzer History ──

  static Future<void> saveSentenceAnalysis(Map<String, dynamic> entry) async {
    if (!Hive.isBoxOpen(_sentenceAnalysisHistoryBox)) {
      await Hive.openBox(_sentenceAnalysisHistoryBox);
    }
    final box = Hive.box(_sentenceAnalysisHistoryBox);
    final history = getSentenceAnalysisHistory();
    history.insert(0, entry);
    if (history.length > 100) history.removeLast();
    await box.put('entries', history);
  }

  static List<Map<String, dynamic>> getSentenceAnalysisHistory() {
    if (!Hive.isBoxOpen(_sentenceAnalysisHistoryBox)) return [];
    final box = Hive.box(_sentenceAnalysisHistoryBox);
    final raw = box.get('entries', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteSentenceAnalysis(int index) async {
    if (!Hive.isBoxOpen(_sentenceAnalysisHistoryBox)) return;
    final box = Hive.box(_sentenceAnalysisHistoryBox);
    final history = getSentenceAnalysisHistory();
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    await box.put('entries', history);
  }

  static Future<void> clearSentenceAnalysisHistory() async {
    if (!Hive.isBoxOpen(_sentenceAnalysisHistoryBox)) return;
    await Hive.box(_sentenceAnalysisHistoryBox).put('entries', <Map<String, dynamic>>[]);
  }

  // ── Game Settings ──
  static Future<void> setGameTimerSeconds(int value) async {
    await _settings.put('game_timer_seconds', value);
  }

  static int getGameTimerSeconds() {
    return _settings.get('game_timer_seconds', defaultValue: 60) as int;
  }

  static Future<void> setGameQuestionCount(int value) async {
    await _settings.put('game_question_count', value);
  }

  static int getGameQuestionCount() {
    return _settings.get('game_question_count', defaultValue: 10) as int;
  }

  static Future<void> setGameDifficulty(String value) async {
    await _settings.put('game_difficulty', value);
  }

  static String getGameDifficulty() {
    return _settings.get('game_difficulty', defaultValue: 'easy') as String;
  }

  // ── Sound Settings ──
  static Future<void> setSoundMuted(bool value) async {
    await _settings.put('sound_muted', value);
  }

  static bool isSoundMuted() {
    return _settings.get('sound_muted', defaultValue: false) as bool;
  }

  static Future<void> setSoundVolume(double value) async {
    await _settings.put('sound_volume', value);
  }

  static double getSoundVolume() {
    return _settings.get('sound_volume', defaultValue: 0.8) as double;
  }

  // AI Settings — Multiple Keys
  static Future<void> saveAiKey(Map<String, dynamic> keyConfig) async {
    final keys = getAiKeys();
    final idx = keys.indexWhere((k) => k['id'] == keyConfig['id']);
    if (idx >= 0) {
      keys[idx] = keyConfig;
    } else {
      keys.add(keyConfig);
    }
    await _settings.put('aiKeys', keys);
  }

  static List<Map<String, dynamic>> getAiKeys() {
    final raw = _settings.get('aiKeys', defaultValue: <Map<String, dynamic>>[]) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteAiKey(String id) async {
    final keys = getAiKeys();
    keys.removeWhere((k) => k['id'] == id);
    await _settings.put('aiKeys', keys);
  }

  static Future<void> setActiveAiKey(String id) async {
    final keys = getAiKeys();
    for (final k in keys) {
      k['isActive'] = k['id'] == id;
    }
    await _settings.put('aiKeys', keys);
  }

  static Map<String, dynamic>? getActiveAiKey() {
    final keys = getAiKeys();
    for (final k in keys) {
      if (k['isActive'] == true) return Map<String, dynamic>.from(k as Map);
    }
    return keys.isNotEmpty ? Map<String, dynamic>.from(keys.first as Map) : null;
  }

  // User Profile
  static Future<void> setUserName(String value) async {
    await _settings.put('userName', value);
  }

  static String getUserName() {
    return _settings.get('userName', defaultValue: '') as String;
  }

  // Chat Sessions
  static Future<void> saveChatSession(Map<String, dynamic> session) async {
    final sessions = getChatSessions();
    final idx = sessions.indexWhere((s) => s['id'] == session['id']);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    await _settings.put('chatSessions', sessions);
  }

  static List<Map<String, dynamic>> getChatSessions() {
    final raw = _settings.get('chatSessions', defaultValue: <Map<String, dynamic>>[]) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteChatSession(String id) async {
    final sessions = getChatSessions();
    sessions.removeWhere((s) => s['id'] == id);
    await _settings.put('chatSessions', sessions);
  }

  static Future<void> deleteAllChatSessions() async {
    await _settings.put('chatSessions', <Map<String, dynamic>>[]);
  }

  // Last Active Conversation
  static Future<void> setLastActiveConversationId(String id) async {
    await _settings.put('lastActiveConvId', id);
  }

  static String getLastActiveConversationId() {
    return _settings.get('lastActiveConvId', defaultValue: '') as String;
  }

  // Last Active AI Chat
  static Future<void> setLastActiveChatId(String id) async {
    await _settings.put('lastActiveChatId', id);
  }

  static String getLastActiveChatId() {
    return _settings.get('lastActiveChatId', defaultValue: '') as String;
  }

  // API Key Form Draft (remember partial entries across dialog opens)
  static Future<void> saveApiKeyDraft(Map<String, String> draft) async {
    await _settings.put('api_key_draft', draft);
  }

  static Map<String, String> getApiKeyDraft() {
    final raw = _settings.get('api_key_draft', defaultValue: <String, String>{}) as Map;
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<void> clearApiKeyDraft() async {
    await _settings.put('api_key_draft', <String, String>{});
  }

  // Cached Free OpenRouter Models (with speed tier)
  static Future<void> saveFreeOpenRouterModels(List<Map<String, dynamic>> models) async {
    await _settings.put('free_or_models', models);
  }

  static List<Map<String, dynamic>> getFreeOpenRouterModels() {
    final raw = _settings.get('free_or_models', defaultValue: <Map<String, dynamic>>[]) as List;
    if (raw.isEmpty) return [];
    if (raw.first is String) {
      return (raw as List<String>).map((id) => {'id': id, 'tier': 'medium'}).toList();
    }
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // History
  static Future<void> addToHistory(String lessonId) async {
    final history = _history.get('lessonIds', defaultValue: <String>[]) as List<String>;
    history.remove(lessonId);
    history.insert(0, lessonId);
    if (history.length > 50) history.removeLast();
    await _history.put('lessonIds', history);
  }

  static List<String> getHistory() {
    return _history.get('lessonIds', defaultValue: <String>[]) as List<String>;
  }

  // ── Study Plan (Todo List) ──

  static Future<void> saveTodoItems(List<Map<String, dynamic>> items) async {
    await Hive.box(_studyPlanBox).put('items', items);
  }

  static List<Map<String, dynamic>> getTodoItems() {
    return (Hive.box(_studyPlanBox).get('items', defaultValue: <Map<String, dynamic>>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> updateTodoItem(Map<String, dynamic> item) async {
    final items = getTodoItems();
    final idx = items.indexWhere((i) => i['id'] == item['id']);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    await saveTodoItems(items);
  }

  static Future<void> saveWeeklyTestInfo(Map<String, dynamic> info) async {
    await Hive.box(_studyPlanBox).put('weekly_test', info);
  }

  static Map<String, dynamic>? getWeeklyTestInfo() {
    final raw = Hive.box(_studyPlanBox).get('weekly_test');
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  // ── Translator History ──

  static Future<void> saveTranslation(Map<String, dynamic> entry) async {
    if (!Hive.isBoxOpen(_translatorHistoryBox)) {
      await Hive.openBox(_translatorHistoryBox);
    }
    final box = Hive.box(_translatorHistoryBox);
    final history = getTranslationHistory();
    history.insert(0, entry);
    if (history.length > 100) history.removeLast();
    await box.put('entries', history);
  }

  static List<Map<String, dynamic>> getTranslationHistory() {
    if (!Hive.isBoxOpen(_translatorHistoryBox)) return [];
    final box = Hive.box(_translatorHistoryBox);
    final raw = box.get('entries', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> deleteTranslation(int index) async {
    if (!Hive.isBoxOpen(_translatorHistoryBox)) return;
    final box = Hive.box(_translatorHistoryBox);
    final history = getTranslationHistory();
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    await box.put('entries', history);
  }

  static Future<void> clearTranslationHistory() async {
    if (!Hive.isBoxOpen(_translatorHistoryBox)) return;
    await Hive.box(_translatorHistoryBox).put('entries', <Map<String, dynamic>>[]);
  }

  // ── Last Opened Chapter (for Continue Learning resume) ──

  static Future<void> setLastOpenedChapter(String type, int chapterNumber) async {
    await _settings.put('last_opened_chapter', {'type': type, 'chapter': chapterNumber});
  }

  static Map<String, dynamic>? getLastOpenedChapter() {
    final raw = _settings.get('last_opened_chapter');
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  // ── Chapter Scroll Progress (for Continue Learning %) ──

  static Future<void> setChapterProgress(String type, int chapterNumber, double progress) async {
    final key = 'chapter_progress_${type}_$chapterNumber';
    await _settings.put(key, progress.clamp(0.0, 1.0));
  }

  static double getChapterProgress(String type, int chapterNumber) {
    final key = 'chapter_progress_${type}_$chapterNumber';
    return _settings.get(key, defaultValue: 0.0) as double;
  }

  // ── Notification History ──

  static Future<void> saveNotificationToHistory(Map<String, dynamic> notification) async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) {
      await Hive.openBox(_notificationHistoryBox);
    }
    final box = Hive.box(_notificationHistoryBox);
    final history = getNotificationHistory();
    history.insert(0, notification);
    if (history.length > 100) history.removeLast(); // Keep last 100 notifications
    await box.put('notifications', history);
  }

  static Future<bool> saveNotificationToHistoryIfNew(Map<String, dynamic> notification) async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) {
      await Hive.openBox(_notificationHistoryBox);
    }
    final history = getNotificationHistory();
    final id = notification['id'];
    if (history.any((item) => item['id'] == id)) return false;
    await saveNotificationToHistory(notification);
    return true;
  }

  static List<Map<String, dynamic>> getNotificationHistory() {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) return [];
    final box = Hive.box(_notificationHistoryBox);
    final raw = box.get('notifications', defaultValue: []) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) return;
    final box = Hive.box(_notificationHistoryBox);
    final history = getNotificationHistory();
    final index = history.indexWhere((n) => n['id'] == notificationId);
    if (index >= 0) {
      history[index]['isRead'] = true;
      await box.put('notifications', history);
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) return;
    final box = Hive.box(_notificationHistoryBox);
    final history = getNotificationHistory();
    for (final notification in history) {
      notification['isRead'] = true;
    }
    await box.put('notifications', history);
  }

  static int getUnreadNotificationCount() {
    final history = getNotificationHistory();
    return history.where((n) => n['isRead'] != true).length;
  }

  static Future<void> deleteNotification(String notificationId) async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) return;
    final box = Hive.box(_notificationHistoryBox);
    final history = getNotificationHistory();
    history.removeWhere((n) => n['id'] == notificationId);
    await box.put('notifications', history);
  }

  static Future<void> clearNotificationHistory() async {
    if (!Hive.isBoxOpen(_notificationHistoryBox)) return;
    await Hive.box(_notificationHistoryBox).put('notifications', <Map<String, dynamic>>[]);
  }

  // ── Mock Test Progress ──

  static Future<void> saveMockTestProgress(Map<String, dynamic> progress) async {
    if (!Hive.isBoxOpen(_mockTestProgressBox)) {
      await Hive.openBox(_mockTestProgressBox);
    }
    await Hive.box(_mockTestProgressBox).put('progress', progress);
  }

  static Map<String, dynamic>? getMockTestProgress() {
    if (!Hive.isBoxOpen(_mockTestProgressBox)) return null;
    final raw = Hive.box(_mockTestProgressBox).get('progress');
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  static Future<void> clearMockTestProgress() async {
    if (!Hive.isBoxOpen(_mockTestProgressBox)) return;
    await Hive.box(_mockTestProgressBox).clear();
  }

  // ── AI Teacher Saved Vocabulary ──

  static Future<void> saveAiVocabWord(Map<String, dynamic> word) async {
    final box = Hive.box(_aiSavedVocabBox);
    final words = getAiSavedVocabWords();
    // Avoid duplicates by word text
    words.removeWhere((w) => w['word'] == word['word']);
    words.insert(0, word);
    await box.put('words', words);
  }

  static List<Map<String, dynamic>> getAiSavedVocabWords() {
    return (Hive.box(_aiSavedVocabBox).get('words', defaultValue: <Map<String, dynamic>>[]) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> deleteAiVocabWord(String word) async {
    final words = getAiSavedVocabWords();
    words.removeWhere((w) => w['word'] == word);
    await Hive.box(_aiSavedVocabBox).put('words', words);
  }

  /// Clears all locally cached/stored data used by the app (Hive boxes).
  /// Note: Firebase-backed progress will reload/sync again on next fetch/login.
  static Future<void> clearAllCaches() async {
    // Favorites
    if (Hive.isBoxOpen(_favoritesBox)) {
      await Hive.box(_favoritesBox).clear();
    }

    // Settings (includes user prefs + AI keys + chat sessions + last opened chapter, etc.)
    if (Hive.isBoxOpen(_settingsBox)) {
      await Hive.box(_settingsBox).clear();
    }

    // History
    if (Hive.isBoxOpen(_historyBox)) {
      await Hive.box(_historyBox).clear();
    }

    // Vocabulary progress/cache
    if (Hive.isBoxOpen(_vocabProgressBox)) {
      await Hive.box(_vocabProgressBox).clear();
    }
    if (Hive.isBoxOpen('vocab_cache')) {
      await Hive.box('vocab_cache').clear();
    }

    // Master guide history
    if (Hive.isBoxOpen(_masterGuideHistoryBox)) {
      await Hive.box(_masterGuideHistoryBox).clear();
    }

    // Study plan (todo items + weekly test info)
    if (Hive.isBoxOpen(_studyPlanBox)) {
      await Hive.box(_studyPlanBox).clear();
    }

    // Translator history
    if (Hive.isBoxOpen(_translatorHistoryBox)) {
      await Hive.box(_translatorHistoryBox).clear();
    }

    // Homework history
    if (Hive.isBoxOpen(_homeworkHistoryBox)) {
      await Hive.box(_homeworkHistoryBox).clear();
    }

    // Sentence analyzer history
    if (Hive.isBoxOpen(_sentenceAnalysisHistoryBox)) {
      await Hive.box(_sentenceAnalysisHistoryBox).clear();
    }

    // Vocabulary test history
    if (Hive.isBoxOpen(_vocabTestHistoryBox)) {
      await Hive.box(_vocabTestHistoryBox).clear();
    }

    // Notification history
    if (Hive.isBoxOpen(_notificationHistoryBox)) {
      await Hive.box(_notificationHistoryBox).clear();
    }

    // 🔥 GAME DATA - Clear game progress and statistics
    if (Hive.isBoxOpen(_gameProgressBox)) {
      await Hive.box(_gameProgressBox).clear();
    }
    if (Hive.isBoxOpen(_gameStatisticsBox)) {
      await Hive.box(_gameStatisticsBox).clear();
    }
    
    if (Hive.isBoxOpen(_gameAchievementsBox)) {
      await Hive.box(_gameAchievementsBox).clear();
    }

    // Mock test progress
    if (Hive.isBoxOpen(_mockTestProgressBox)) {
      await Hive.box(_mockTestProgressBox).clear();
    }
  }
}
