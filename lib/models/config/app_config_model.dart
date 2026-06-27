import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the remote app configuration stored in Firestore at config/app_settings.
class AppConfig {
  final FeatureToggles featureToggles;
  final ForceUpdateInfo forceUpdate;
  final MaintenanceModeInfo maintenanceMode;
  final GameplaySettings gameplay;

  const AppConfig({
    this.featureToggles = const FeatureToggles(),
    this.forceUpdate = const ForceUpdateInfo(),
    this.maintenanceMode = const MaintenanceModeInfo(),
    this.gameplay = const GameplaySettings(),
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      featureToggles: FeatureToggles.fromMap(
        map['featureToggles'] as Map<String, dynamic>? ?? {},
      ),
      forceUpdate: ForceUpdateInfo.fromMap(
        map['forceUpdate'] as Map<String, dynamic>? ?? {},
      ),
      maintenanceMode: MaintenanceModeInfo.fromMap(
        map['maintenanceMode'] as Map<String, dynamic>? ?? {},
      ),
      gameplay: GameplaySettings.fromMap(
        map['gameplay'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featureToggles': featureToggles.toMap(),
      'forceUpdate': forceUpdate.toMap(),
      'maintenanceMode': maintenanceMode.toMap(),
      'gameplay': gameplay.toMap(),
    };
  }

  factory AppConfig.fromSnapshot(DocumentSnapshot doc) {
    return AppConfig.fromMap(doc.data() as Map<String, dynamic>? ?? {});
  }
}

class FeatureToggles {
  final bool aiTeacher;
  final bool games;
  final bool homework;
  final bool sentenceAnalyzer;
  final bool speaking;
  final bool listening;

  const FeatureToggles({
    this.aiTeacher = true,
    this.games = true,
    this.homework = true,
    this.sentenceAnalyzer = true,
    this.speaking = true,
    this.listening = true,
  });

  factory FeatureToggles.fromMap(Map<String, dynamic> map) {
    return FeatureToggles(
      aiTeacher: map['aiTeacher'] as bool? ?? true,
      games: map['games'] as bool? ?? true,
      homework: map['homework'] as bool? ?? true,
      sentenceAnalyzer: map['sentenceAnalyzer'] as bool? ?? true,
      speaking: map['speaking'] as bool? ?? true,
      listening: map['listening'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aiTeacher': aiTeacher,
      'games': games,
      'homework': homework,
      'sentenceAnalyzer': sentenceAnalyzer,
      'speaking': speaking,
      'listening': listening,
    };
  }

  /// Returns all feature keys for UI iteration.
  static List<String> get allKeys => [
        'aiTeacher',
        'games',
        'homework',
        'sentenceAnalyzer',
        'speaking',
        'listening',
      ];

  String displayName(String key) {
    switch (key) {
      case 'aiTeacher':
        return 'AI Teacher';
      case 'games':
        return 'Games';
      case 'homework':
        return 'Homework';
      case 'sentenceAnalyzer':
        return 'Sentence Analyzer';
      case 'speaking':
        return 'Speaking';
      case 'listening':
        return 'Listening';
      default:
        return key;
    }
  }

  bool isEnabled(String key) {
    switch (key) {
      case 'aiTeacher':
        return aiTeacher;
      case 'games':
        return games;
      case 'homework':
        return homework;
      case 'sentenceAnalyzer':
        return sentenceAnalyzer;
      case 'speaking':
        return speaking;
      case 'listening':
        return listening;
      default:
        return true;
    }
  }
}

class ForceUpdateInfo {
  final bool enabled;
  final String message;
  final String targetVersion;
  final String playStoreUrl;

  const ForceUpdateInfo({
    this.enabled = false,
    this.message = 'Please update to the latest version',
    this.targetVersion = '2.0.0',
    this.playStoreUrl = '',
  });

  factory ForceUpdateInfo.fromMap(Map<String, dynamic> map) {
    return ForceUpdateInfo(
      enabled: map['enabled'] as bool? ?? false,
      message: map['message'] as String? ?? 'Please update to the latest version',
      targetVersion: map['targetVersion'] as String? ?? '2.0.0',
      playStoreUrl: map['playStoreUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'message': message,
      'targetVersion': targetVersion,
      'playStoreUrl': playStoreUrl,
    };
  }
}

class MaintenanceModeInfo {
  final bool enabled;
  final String message;

  const MaintenanceModeInfo({
    this.enabled = false,
    this.message = 'App is under maintenance. Please come back later.',
  });

  factory MaintenanceModeInfo.fromMap(Map<String, dynamic> map) {
    return MaintenanceModeInfo(
      enabled: map['enabled'] as bool? ?? false,
      message: map['message'] as String? ?? 'App is under maintenance. Please come back later.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'message': message,
    };
  }
}

class GameplaySettings {
  final int streakFreezeCost;
  final int dailyGoalXP;
  final int maxStreakFreezes;

  const GameplaySettings({
    this.streakFreezeCost = 100,
    this.dailyGoalXP = 50,
    this.maxStreakFreezes = 3,
  });

  factory GameplaySettings.fromMap(Map<String, dynamic> map) {
    return GameplaySettings(
      streakFreezeCost: map['streakFreezeCost'] as int? ?? 100,
      dailyGoalXP: map['dailyGoalXP'] as int? ?? 50,
      maxStreakFreezes: map['maxStreakFreezes'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streakFreezeCost': streakFreezeCost,
      'dailyGoalXP': dailyGoalXP,
      'maxStreakFreezes': maxStreakFreezes,
    };
  }
}