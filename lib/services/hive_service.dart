import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String _favoritesBox = 'favorites';
  static const String _settingsBox = 'settings';
  static const String _historyBox = 'history';
  static const String _vocabProgressBox = 'vocab_progress';
  static const String _vocabTestHistoryBox = 'vocab_test_history';
  static const String _masterGuideHistoryBox = 'master_guide_history';
  static const String _studyPlanBox = 'study_plan';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_vocabProgressBox);
    await Hive.openBox('vocab_cache');
    await Hive.openBox(_masterGuideHistoryBox);
    await Hive.openBox(_studyPlanBox);
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
}
