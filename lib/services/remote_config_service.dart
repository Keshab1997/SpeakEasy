import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/config/app_config_model.dart';

/// Service to fetch and cache remote app configuration from Firestore.
///
/// The config is stored at `config/app_settings` and allows:
/// - Feature toggle control
/// - Force update announcements
/// - Maintenance mode
/// - Gameplay settings
class RemoteConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static AppConfig? _cachedConfig;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Reference to the config document
  static DocumentReference get _configRef =>
      _firestore.collection('config').doc('app_settings');

  /// Fetches the app config from Firestore with caching.
  ///
  /// Returns cached config if it was fetched within [_cacheDuration].
  /// Otherwise fetches fresh data from Firestore.
  static Future<AppConfig> getConfig() async {
    // Return cached config if still valid
    if (_cachedConfig != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedConfig!;
    }

    try {
      final doc = await _configRef.get();
      if (doc.exists) {
        _cachedConfig = AppConfig.fromSnapshot(doc);
      } else {
        // If document doesn't exist, create it with defaults
        _cachedConfig = const AppConfig();
        await _configRef.set(_cachedConfig!.toMap());
      }
      _lastFetchTime = DateTime.now();
      return _cachedConfig!;
    } catch (e) {
      // Return cached config or defaults on error
      if (_cachedConfig != null) return _cachedConfig!;
      return const AppConfig();
    }
  }

  /// Checks if a specific feature is enabled.
  ///
  /// Features: aiTeacher, games, homework, sentenceAnalyzer, speaking, listening
  static Future<bool> isFeatureEnabled(String feature) async {
    final config = await getConfig();
    return config.featureToggles.isEnabled(feature);
  }

  /// Checks if maintenance mode is active.
  static Future<bool> isMaintenanceMode() async {
    final config = await getConfig();
    return config.maintenanceMode.enabled;
  }

  /// Returns force update info if force update is enabled.
  static Future<ForceUpdateInfo?> getForceUpdateInfo() async {
    final config = await getConfig();
    if (config.forceUpdate.enabled) {
      return config.forceUpdate;
    }
    return null;
  }

  /// Returns the streak freeze cost from gameplay settings.
  static Future<int> getStreakFreezeCost() async {
    final config = await getConfig();
    return config.gameplay.streakFreezeCost;
  }

  /// Returns the daily goal XP from gameplay settings.
  static Future<int> getDailyGoalXP() async {
    final config = await getConfig();
    return config.gameplay.dailyGoalXP;
  }

  /// Returns the max streak freezes from gameplay settings.
  static Future<int> getMaxStreakFreezes() async {
    final config = await getConfig();
    return config.gameplay.maxStreakFreezes;
  }

  /// Returns the maintenance message if maintenance mode is active.
  static Future<String?> getMaintenanceMessage() async {
    final config = await getConfig();
    if (config.maintenanceMode.enabled) {
      return config.maintenanceMode.message;
    }
    return null;
  }

  /// Updates the entire config document in Firestore.
  ///
  /// This is an admin operation. Pass the full updated map.
  static Future<void> updateConfig(Map<String, dynamic> updates) async {
    await _configRef.set(updates, SetOptions(merge: true));
    // Invalidate cache so next read fetches fresh data
    _cachedConfig = null;
    _lastFetchTime = null;
  }

  /// Updates only specific sections of the config.
  ///
  /// Example: updateSection('featureToggles', {'aiTeacher': false})
  static Future<void> updateSection(
      String section, Map<String, dynamic> sectionData) async {
    await _configRef.set({section: sectionData}, SetOptions(merge: true));
    _cachedConfig = null;
    _lastFetchTime = null;
  }

  /// Seeds the default config document in Firestore if it doesn't exist.
  static Future<void> seedDefaultConfig() async {
    try {
      final doc = await _configRef.get();
      if (!doc.exists) {
        await _configRef.set(const AppConfig().toMap());
      }
    } catch (_) {
      // Silently fail - Firestore might not be available
    }
  }
}