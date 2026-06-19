import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String _favoritesBox = 'favorites';
  static const String _settingsBox = 'settings';
  static const String _historyBox = 'history';
  static const String _vocabProgressBox = 'vocab_progress';
  static const String _vocabTestHistoryBox = 'vocab_test_history';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_vocabProgressBox);
    await Hive.openBox('vocab_cache');
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
}
