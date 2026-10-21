import 'dart:ui' show Color;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'achievement_model.g.dart';

@HiveType(typeId: 4)
class AchievementModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final bool unlocked;

  @HiveField(4)
  final DateTime? unlockDate;

  @HiveField(5)
  final String icon; // emoji badge

  @HiveField(6)
  final String category;

  @HiveField(7)
  final int xpReward;

  @HiveField(8)
  final int coinReward;

  /// NEW: Game mode type this achievement belongs to (null = any/all games)
  @HiveField(9)
  final String? gameType;

  /// NEW: Condition description for how to unlock (e.g., "score >= 100")
  @HiveField(10)
  final String? condition;

  /// NEW: Display order for sorting
  @HiveField(11)
  final int order;

  /// NEW: Rarity tier for visual styling
  @HiveField(12)
  final String rarity; // 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.unlockDate,
    this.icon = '🏅',
    this.category = 'General',
    this.xpReward = 0,
    this.coinReward = 0,
    this.gameType,
    this.condition,
    this.order = 0,
    this.rarity = 'Common',
  });

  // ── Static Achievements Map (ID → AchievementModel) ──

  static final Map<String, AchievementModel> achievementsMap = {
    for (final a in _defaultAchievements) a.id: a,
  };

  /// Returns all achievement definitions grouped by game type
  static Map<String?, List<AchievementModel>> get groupedByGameType {
    final map = <String?, List<AchievementModel>>{};
    for (final a in _defaultAchievements) {
      map.putIfAbsent(a.gameType, () => []).add(a);
    }
    return map;
  }

  /// Returns achievements filtered by game type (null = general/all)
  static List<AchievementModel> getByGameType(String? gameType) {
    return _defaultAchievements
        .where((a) => a.gameType == gameType)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Returns achievements for a specific category
  static List<AchievementModel> getByCategory(String category) {
    return _defaultAchievements
        .where((a) => a.category == category)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Default achievement definitions organized by game type
  static final List<AchievementModel> _defaultAchievements = [
    // ── 🎯 GENERAL / MILESTONE (any game) ──
    AchievementModel(
      id: 'first_win',
      title: 'First Win',
      description: 'Win your very first game',
      icon: '🎉',
      category: 'Milestone',
      xpReward: 50,
      coinReward: 25,
      gameType: null,
      condition: 'games_played >= 1',
      order: 1,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'ten_correct',
      title: '10 Correct Answers',
      description: 'Answer 10 questions correctly in total',
      icon: '🎯',
      category: 'Milestone',
      xpReward: 75,
      coinReward: 40,
      gameType: null,
      condition: 'total_correct >= 10',
      order: 2,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'xp_100',
      title: '100 XP',
      description: 'Earn a total of 100 XP',
      icon: '⚡',
      category: 'XP',
      xpReward: 0,
      coinReward: 30,
      gameType: null,
      condition: 'total_xp >= 100',
      order: 3,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'xp_1000',
      title: '1,000 XP',
      description: 'Earn a total of 1,000 XP',
      icon: '⚡',
      category: 'XP',
      xpReward: 0,
      coinReward: 100,
      gameType: null,
      condition: 'total_xp >= 1000',
      order: 4,
      rarity: 'Uncommon',
    ),
    AchievementModel(
      id: 'xp_5000',
      title: '5,000 XP',
      description: 'Earn a total of 5,000 XP',
      icon: '💎',
      category: 'XP',
      xpReward: 0,
      coinReward: 250,
      gameType: null,
      condition: 'total_xp >= 5000',
      order: 5,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'streak_7',
      title: '7-Day Streak',
      description: 'Keep a 7-day learning streak',
      icon: '🔥',
      category: 'Streak',
      xpReward: 100,
      coinReward: 50,
      gameType: null,
      condition: 'streak >= 7',
      order: 6,
      rarity: 'Uncommon',
    ),
    AchievementModel(
      id: 'streak_30',
      title: '30-Day Streak',
      description: 'Keep a 30-day learning streak',
      icon: '🔥',
      category: 'Streak',
      xpReward: 300,
      coinReward: 150,
      gameType: null,
      condition: 'streak >= 30',
      order: 7,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'perfect_round',
      title: 'Perfect Round',
      description: 'Finish a round with 100% accuracy',
      icon: '💯',
      category: 'Skill',
      xpReward: 100,
      coinReward: 50,
      gameType: null,
      condition: 'accuracy >= 1.0 && correct_answers > 0',
      order: 8,
      rarity: 'Uncommon',
    ),
    AchievementModel(
      id: 'speed_master',
      title: 'Speed Master',
      description: 'Answer 5 questions in a row with full time bonus',
      icon: '💨',
      category: 'Skill',
      xpReward: 120,
      coinReward: 60,
      gameType: null,
      condition: 'speed_bonus_count >= 5',
      order: 9,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'games_50',
      title: '50 Games Played',
      description: 'Play 50 games in total',
      icon: '🎮',
      category: 'Milestone',
      xpReward: 150,
      coinReward: 75,
      gameType: null,
      condition: 'games_played >= 50',
      order: 10,
      rarity: 'Uncommon',
    ),
    AchievementModel(
      id: 'games_200',
      title: '200 Games Played',
      description: 'Play 200 games in total',
      icon: '🎮',
      category: 'Milestone',
      xpReward: 300,
      coinReward: 200,
      gameType: null,
      condition: 'games_played >= 200',
      order: 11,
      rarity: 'Rare',
    ),

    // ── 🧩 FILL IN THE BLANK ──
    AchievementModel(
      id: 'fill_blank_pro',
      title: 'Blank Filler Pro',
      description: 'Answer 50 Fill in the Blank questions correctly',
      icon: '✏️',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'fillInBlank',
      condition: 'fillInBlank_correct >= 50',
      order: 20,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'fill_blank_master',
      title: 'Blank Filler Master',
      description: 'Answer 200 Fill in the Blank questions correctly',
      icon: '✏️',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'fillInBlank',
      condition: 'fillInBlank_correct >= 200',
      order: 21,
      rarity: 'Rare',
    ),

    // ── ✅ CHOOSE CORRECT TENSE ──
    AchievementModel(
      id: 'tense_picker_pro',
      title: 'Tense Picker Pro',
      description: 'Answer 50 Tense questions correctly',
      icon: '⏱️',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'chooseCorrectTense',
      condition: 'chooseCorrectTense_correct >= 50',
      order: 30,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'tense_picker_master',
      title: 'Tense Picker Master',
      description: 'Answer 200 Tense questions correctly',
      icon: '⏱️',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'chooseCorrectTense',
      condition: 'chooseCorrectTense_correct >= 200',
      order: 31,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'present_tense_master',
      title: 'Present Tense Master',
      description: 'Complete all Present Tense levels',
      icon: '⏳',
      category: 'Tense',
      xpReward: 150,
      coinReward: 75,
      gameType: 'chooseCorrectTense',
      condition: 'present_tense_levels_complete',
      order: 32,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'past_tense_master',
      title: 'Past Tense Master',
      description: 'Complete all Past Tense levels',
      icon: '📜',
      category: 'Tense',
      xpReward: 150,
      coinReward: 75,
      gameType: 'chooseCorrectTense',
      condition: 'past_tense_levels_complete',
      order: 33,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'future_tense_master',
      title: 'Future Tense Master',
      description: 'Complete all Future Tense levels',
      icon: '🔮',
      category: 'Tense',
      xpReward: 150,
      coinReward: 75,
      gameType: 'chooseCorrectTense',
      condition: 'future_tense_levels_complete',
      order: 34,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'tense_champion',
      title: 'Tense Champion',
      description: 'Master Present, Past, and Future tenses',
      icon: '👑',
      category: 'Tense',
      xpReward: 300,
      coinReward: 150,
      gameType: 'chooseCorrectTense',
      condition: 'all_tenses_levels_complete',
      order: 35,
      rarity: 'Epic',
    ),

    // ── 🏗️ SENTENCE BUILDER ──
    AchievementModel(
      id: 'builder_pro',
      title: 'Sentence Builder Pro',
      description: 'Build 50 correct sentences',
      icon: '🧱',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'sentenceBuilder',
      condition: 'sentenceBuilder_correct >= 50',
      order: 40,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'builder_master',
      title: 'Sentence Builder Master',
      description: 'Build 200 correct sentences',
      icon: '🧱',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'sentenceBuilder',
      condition: 'sentenceBuilder_correct >= 200',
      order: 41,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'builder_speedster',
      title: 'Speed Builder',
      description: 'Build a sentence in under 10 seconds',
      icon: '⚡',
      category: 'Game Mode',
      xpReward: 80,
      coinReward: 40,
      gameType: 'sentenceBuilder',
      condition: 'sentenceBuilder_time < 10',
      order: 42,
      rarity: 'Uncommon',
    ),

    // ── 🔍 ERROR DETECTION ──
    AchievementModel(
      id: 'error_hunter_pro',
      title: 'Error Hunter Pro',
      description: 'Detect 50 errors correctly',
      icon: '🔍',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'errorDetection',
      condition: 'errorDetection_correct >= 50',
      order: 50,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'error_hunter_master',
      title: 'Error Hunter Master',
      description: 'Detect 200 errors correctly',
      icon: '🔍',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'errorDetection',
      condition: 'errorDetection_correct >= 200',
      order: 51,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'error_perfect_round',
      title: 'Perfect Eye',
      description: 'Finish an Error Detection round with 100% accuracy',
      icon: '👁️',
      category: 'Game Mode',
      xpReward: 120,
      coinReward: 60,
      gameType: 'errorDetection',
      condition: 'errorDetection_accuracy >= 1.0 && questions > 0',
      order: 52,
      rarity: 'Epic',
    ),

    // ── 🌐 TRANSLATION CHALLENGE ──
    AchievementModel(
      id: 'translator_pro',
      title: 'Translator Pro',
      description: 'Complete 50 translations correctly',
      icon: '🌐',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'translationChallenge',
      condition: 'translationChallenge_correct >= 50',
      order: 60,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'translator_master',
      title: 'Translator Master',
      description: 'Complete 200 translations correctly',
      icon: '🌐',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'translationChallenge',
      condition: 'translationChallenge_correct >= 200',
      order: 61,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'translator_bilingual',
      title: 'Bilingual Champion',
      description: 'Translate 500 sentences between English and Bengali',
      icon: '🗣️',
      category: 'Game Mode',
      xpReward: 400,
      coinReward: 200,
      gameType: 'translationChallenge',
      condition: 'translationChallenge_correct >= 500',
      order: 62,
      rarity: 'Epic',
    ),

    // ── ⚡ SPEED QUIZ ──
    AchievementModel(
      id: 'speed_demon',
      title: 'Speed Demon',
      description: 'Answer 20 questions in Speed Quiz',
      icon: '💨',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'speedQuiz',
      condition: 'speedQuiz_answered >= 20',
      order: 70,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'speed_lightning',
      title: 'Lightning Strikes',
      description: 'Answer 50 questions in Speed Quiz',
      icon: '⚡',
      category: 'Game Mode',
      xpReward: 200,
      coinReward: 100,
      gameType: 'speedQuiz',
      condition: 'speedQuiz_answered >= 50',
      order: 71,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'speed_perfect',
      title: 'Speed Perfectionist',
      description: 'Get 100% accuracy in a Speed Quiz round',
      icon: '🏆',
      category: 'Game Mode',
      xpReward: 150,
      coinReward: 75,
      gameType: 'speedQuiz',
      condition: 'speedQuiz_accuracy >= 1.0 && questions >= 10',
      order: 72,
      rarity: 'Epic',
    ),

    // ── 🎮 WORD MATCH ──
    AchievementModel(
      id: 'word_match_pro',
      title: 'Word Match Pro',
      description: 'Match 50 word pairs correctly',
      icon: '🔄',
      category: 'Game Mode',
      xpReward: 100,
      coinReward: 50,
      gameType: 'wordMatch',
      condition: 'wordMatch_correct >= 50',
      order: 80,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'word_match_master',
      title: 'Word Match Master',
      description: 'Match 200 word pairs correctly',
      icon: '🔄',
      category: 'Game Mode',
      xpReward: 250,
      coinReward: 125,
      gameType: 'wordMatch',
      condition: 'wordMatch_correct >= 200',
      order: 81,
      rarity: 'Rare',
    ),
    AchievementModel(
      id: 'word_match_lightning',
      title: 'Lightning Matcher',
      description: 'Match 5 pairs in under 30 seconds',
      icon: '⚡',
      category: 'Game Mode',
      xpReward: 120,
      coinReward: 60,
      gameType: 'wordMatch',
      condition: 'wordMatch_time < 30 && pairs >= 5',
      order: 82,
      rarity: 'Epic',
    ),

    // ── 📅 DAILY CHALLENGE ──
    AchievementModel(
      id: 'daily_starter',
      title: 'Daily Challenger',
      description: 'Complete your first Daily Challenge',
      icon: '📅',
      category: 'Daily',
      xpReward: 50,
      coinReward: 25,
      gameType: 'dailyChallenge',
      condition: 'daily_challenge_completed >= 1',
      order: 100,
      rarity: 'Common',
    ),
    AchievementModel(
      id: 'daily_7',
      title: 'Week Warrior',
      description: 'Complete 7 Daily Challenges',
      icon: '📅',
      category: 'Daily',
      xpReward: 200,
      coinReward: 100,
      gameType: 'dailyChallenge',
      condition: 'daily_challenge_completed >= 7',
      order: 101,
      rarity: 'Uncommon',
    ),
	    AchievementModel(
	      id: 'daily_30',
	      title: 'Monthly Master',
	      description: 'Complete 30 Daily Challenges',
	      icon: '📅',
	      category: 'Daily',
	      xpReward: 500,
	      coinReward: 250,
	      gameType: 'dailyChallenge',
	      condition: 'daily_challenge_completed >= 30',
	      order: 102,
	      rarity: 'Epic',
	    ),

	    // ── ⚡ QUICK QUIZ ──
	    AchievementModel(
	      id: 'quick_quiz_starter',
	      title: 'Quick Start',
	      description: 'Answer 20 Quick Quiz questions',
	      icon: '⚡',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'quickQuiz',
	      condition: 'quickQuiz_correct >= 20',
	      order: 110,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'quick_quiz_pro',
	      title: 'Quick Quiz Pro',
	      description: 'Answer 100 Quick Quiz questions correctly',
	      icon: '⚡',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'quickQuiz',
	      condition: 'quickQuiz_correct >= 100',
	      order: 111,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'quick_quiz_master',
	      title: 'Quick Quiz Master',
	      description: 'Answer 300 Quick Quiz questions correctly',
	      icon: '⚡',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'quickQuiz',
	      condition: 'quickQuiz_correct >= 300',
	      order: 112,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'quick_quiz_speedster',
	      title: 'Speedster',
	      description: 'Answer 10 Quick Quiz questions correctly in under 30 seconds',
	      icon: '💨',
	      category: 'Game Mode',
	      xpReward: 200,
	      coinReward: 100,
	      gameType: 'quickQuiz',
	      condition: 'quickQuiz_time < 30 && quickQuiz_correct >= 10',
	      order: 113,
	      rarity: 'Epic',
	    ),
	    AchievementModel(
	      id: 'quick_quiz_perfect',
	      title: 'Quick Perfectionist',
	      description: 'Get 100% accuracy in a Quick Quiz round',
	      icon: '🏆',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'quickQuiz',
	      condition: 'quickQuiz_accuracy >= 1.0 && questions >= 10',
	      order: 114,
	      rarity: 'Rare',
	    ),

	    // ── 📚 VERB LEARNING ──
	    AchievementModel(
	      id: 'verb_learner',
	      title: 'Verb Learner',
	      description: 'Complete 10 Verb exercises',
	      icon: '📖',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'verbLearning',
	      condition: 'verbLearning_completed >= 10',
	      order: 120,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'verb_pro',
	      title: 'Verb Pro',
	      description: 'Complete 50 Verb exercises',
	      icon: '📖',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'verbLearning',
	      condition: 'verbLearning_completed >= 50',
	      order: 121,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'verb_master',
	      title: 'Verb Master',
	      description: 'Complete 200 Verb exercises',
	      icon: '📚',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'verbLearning',
	      condition: 'verbLearning_completed >= 200',
	      order: 122,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'verb_conqueror',
	      title: 'Verb Conqueror',
	      description: 'Master all verb forms in Verb Learning',
	      icon: '👑',
	      category: 'Game Mode',
	      xpReward: 500,
	      coinReward: 250,
	      gameType: 'verbLearning',
	      condition: 'verbLearning_all_complete',
	      order: 123,
	      rarity: 'Legendary',
	    ),

	    // ── 🔍 GRAMMAR DETECTIVE ──
	    AchievementModel(
	      id: 'grammar_detective_starter',
	      title: 'Grammar Recruit',
	      description: 'Detect 20 grammar errors',
	      icon: '🔍',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'grammarDetective',
	      condition: 'grammarDetective_correct >= 20',
	      order: 130,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'grammar_detective_pro',
	      title: 'Grammar Detective Pro',
	      description: 'Detect 80 grammar errors correctly',
	      icon: '🔍',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'grammarDetective',
	      condition: 'grammarDetective_correct >= 80',
	      order: 131,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'grammar_detective_master',
	      title: 'Grammar Detective Master',
	      description: 'Detect 300 grammar errors correctly',
	      icon: '🕵️',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'grammarDetective',
	      condition: 'grammarDetective_correct >= 300',
	      order: 132,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'grammar_detective_perfect',
	      title: 'Perfect Eye',
	      description: 'Finish a Grammar Detective round with 100% accuracy',
	      icon: '👁️',
	      category: 'Game Mode',
	      xpReward: 200,
	      coinReward: 100,
	      gameType: 'grammarDetective',
	      condition: 'grammarDetective_accuracy >= 1.0 && questions >= 5',
	      order: 133,
	      rarity: 'Epic',
	    ),

	    // ── 🌐 BANGLA TO ENGLISH ──
	    AchievementModel(
	      id: 'bangla_starter',
	      title: 'Bangla Beginner',
	      description: 'Complete 20 Bangla to English translations',
	      icon: '🌐',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'banglaToEnglish',
	      condition: 'banglaToEnglish_correct >= 20',
	      order: 140,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'bangla_pro',
	      title: 'Bangla Translator Pro',
	      description: 'Complete 100 Bangla to English translations',
	      icon: '🌐',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'banglaToEnglish',
	      condition: 'banglaToEnglish_correct >= 100',
	      order: 141,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'bangla_master',
	      title: 'Bangla Master',
	      description: 'Complete 500 Bangla to English translations',
	      icon: '🌍',
	      category: 'Game Mode',
	      xpReward: 400,
	      coinReward: 200,
	      gameType: 'banglaToEnglish',
	      condition: 'banglaToEnglish_correct >= 500',
	      order: 142,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'bangla_expert',
	      title: 'Bilingual Expert',
	      description: 'Complete 1000 Bangla to English translations',
	      icon: '🗣️',
	      category: 'Game Mode',
	      xpReward: 600,
	      coinReward: 300,
	      gameType: 'banglaToEnglish',
	      condition: 'banglaToEnglish_correct >= 1000',
	      order: 143,
	      rarity: 'Epic',
	    ),

	    // ── 📖 STORY COMPLETION ──
	    AchievementModel(
	      id: 'story_starter',
	      title: 'Story Starter',
	      description: 'Complete 5 stories',
	      icon: '📖',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'storyCompletion',
	      condition: 'storyCompletion_completed >= 5',
	      order: 150,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'story_teller',
	      title: 'Story Teller',
	      description: 'Complete 20 stories',
	      icon: '📖',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'storyCompletion',
	      condition: 'storyCompletion_completed >= 20',
	      order: 151,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'story_master',
	      title: 'Story Master',
	      description: 'Complete 50 stories',
	      icon: '📚',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'storyCompletion',
	      condition: 'storyCompletion_completed >= 50',
	      order: 152,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'story_perfect',
	      title: 'Perfect Storyteller',
	      description: 'Complete a story with 100% accuracy',
	      icon: '💯',
	      category: 'Game Mode',
	      xpReward: 200,
	      coinReward: 100,
	      gameType: 'storyCompletion',
	      condition: 'storyCompletion_accuracy >= 1.0 && questions >= 5',
	      order: 153,
	      rarity: 'Epic',
	    ),

	    // ── 🃏 FLASHCARDS ──
	    AchievementModel(
	      id: 'flashcard_learner',
	      title: 'Flashcard Starter',
	      description: 'Review 50 flashcards',
	      icon: '🃏',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'flashcard',
	      condition: 'flashcard_reviewed >= 50',
	      order: 160,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'flashcard_pro',
	      title: 'Flashcard Pro',
	      description: 'Review 200 flashcards',
	      icon: '🃏',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'flashcard',
	      condition: 'flashcard_reviewed >= 200',
	      order: 161,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'flashcard_master',
	      title: 'Flashcard Master',
	      description: 'Review 500 flashcards',
	      icon: '🃏',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'flashcard',
	      condition: 'flashcard_reviewed >= 500',
	      order: 162,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'flashcard_expert',
	      title: 'Flashcard Expert',
	      description: 'Review 1000 flashcards',
	      icon: '🎴',
	      category: 'Game Mode',
	      xpReward: 500,
	      coinReward: 250,
	      gameType: 'flashcard',
	      condition: 'flashcard_reviewed >= 1000',
	      order: 163,
	      rarity: 'Epic',
	    ),

	    // ── 🎯 NORMAL QUIZ ──
	    AchievementModel(
	      id: 'quiz_starter',
	      title: 'Quiz Beginner',
	      description: 'Complete 10 normal quizzes',
	      icon: '🎯',
	      category: 'Game Mode',
	      xpReward: 50,
	      coinReward: 25,
	      gameType: 'normal',
	      condition: 'normal_quiz_completed >= 10',
	      order: 170,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'quiz_pro',
	      title: 'Quiz Pro',
	      description: 'Complete 50 normal quizzes',
	      icon: '🎯',
	      category: 'Game Mode',
	      xpReward: 150,
	      coinReward: 75,
	      gameType: 'normal',
	      condition: 'normal_quiz_completed >= 50',
	      order: 171,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'quiz_champion',
	      title: 'Quiz Champion',
	      description: 'Complete 100 normal quizzes',
	      icon: '🏆',
	      category: 'Game Mode',
	      xpReward: 300,
	      coinReward: 150,
	      gameType: 'normal',
	      condition: 'normal_quiz_completed >= 100',
	      order: 172,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'quiz_perfect',
	      title: 'Quiz Perfectionist',
	      description: 'Get 100% accuracy in a normal quiz round',
	      icon: '💯',
	      category: 'Game Mode',
	      xpReward: 200,
	      coinReward: 100,
	      gameType: 'normal',
	      condition: 'normal_quiz_accuracy >= 1.0 && questions >= 10',
	      order: 173,
	      rarity: 'Epic',
	    ),

	    // ── 🏆 MEGA MILESTONES ──
	    AchievementModel(
	      id: 'xp_10000',
	      title: '10,000 XP',
	      description: 'Earn a total of 10,000 XP',
	      icon: '💎',
	      category: 'XP',
	      xpReward: 0,
	      coinReward: 500,
	      gameType: null,
	      condition: 'total_xp >= 10000',
	      order: 12,
	      rarity: 'Epic',
	    ),
	    AchievementModel(
	      id: 'xp_25000',
	      title: '25,000 XP',
	      description: 'Earn a total of 25,000 XP',
	      icon: '💎',
	      category: 'XP',
	      xpReward: 0,
	      coinReward: 1000,
	      gameType: null,
	      condition: 'total_xp >= 25000',
	      order: 13,
	      rarity: 'Legendary',
	    ),
	    AchievementModel(
	      id: 'xp_50000',
	      title: '50,000 XP',
	      description: 'Earn a total of 50,000 XP',
	      icon: '👑',
	      category: 'XP',
	      xpReward: 0,
	      coinReward: 2000,
	      gameType: null,
	      condition: 'total_xp >= 50000',
	      order: 14,
	      rarity: 'Legendary',
	    ),
	    AchievementModel(
	      id: 'games_500',
	      title: '500 Games Played',
	      description: 'Play 500 games in total',
	      icon: '🎮',
	      category: 'Milestone',
	      xpReward: 500,
	      coinReward: 300,
	      gameType: null,
	      condition: 'games_played >= 500',
	      order: 15,
	      rarity: 'Epic',
	    ),
	    AchievementModel(
	      id: 'games_1000',
	      title: '1,000 Games Played',
	      description: 'Play 1000 games in total — incredible dedication!',
	      icon: '🏆',
	      category: 'Milestone',
	      xpReward: 1000,
	      coinReward: 500,
	      gameType: null,
	      condition: 'games_played >= 1000',
	      order: 16,
	      rarity: 'Legendary',
	    ),
	    AchievementModel(
	      id: 'accuracy_80',
	      title: 'Sharp Mind',
	      description: 'Maintain 80% overall accuracy across all games',
	      icon: '🎯',
	      category: 'Skill',
	      xpReward: 200,
	      coinReward: 100,
	      gameType: null,
	      condition: 'overall_accuracy >= 0.8 && total_games >= 20',
	      order: 17,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'accuracy_90',
	      title: 'Precision Master',
	      description: 'Maintain 90% overall accuracy across all games',
	      icon: '🎯',
	      category: 'Skill',
	      xpReward: 500,
	      coinReward: 250,
	      gameType: null,
	      condition: 'overall_accuracy >= 0.9 && total_games >= 50',
	      order: 18,
	      rarity: 'Epic',
	    ),
	    AchievementModel(
	      id: 'coins_500',
	      title: 'Coin Collector',
	      description: 'Earn a total of 500 coins',
	      icon: '🪙',
	      category: 'Wealth',
	      xpReward: 0,
	      coinReward: 50,
	      gameType: null,
	      condition: 'total_coins >= 500',
	      order: 19,
	      rarity: 'Common',
	    ),
	    AchievementModel(
	      id: 'coins_2000',
	      title: 'Coin Hoarder',
	      description: 'Earn a total of 2,000 coins',
	      icon: '🪙',
	      category: 'Wealth',
	      xpReward: 0,
	      coinReward: 200,
	      gameType: null,
	      condition: 'total_coins >= 2000',
	      order: 20,
	      rarity: 'Uncommon',
	    ),
	    AchievementModel(
	      id: 'coins_10000',
	      title: 'Coin Millionaire',
	      description: 'Earn a total of 10,000 coins',
	      icon: '💰',
	      category: 'Wealth',
	      xpReward: 0,
	      coinReward: 1000,
	      gameType: null,
	      condition: 'total_coins >= 10000',
	      order: 21,
	      rarity: 'Rare',
	    ),
	    AchievementModel(
	      id: 'perfect_streak_7',
	      title: 'Perfect Streak',
	      description: 'Achieve 7 perfect rounds in a row',
	      icon: '🔥',
	      category: 'Skill',
	      xpReward: 1000,
	      coinReward: 500,
	      gameType: null,
	      condition: 'perfect_streak >= 7',
	      order: 22,
	      rarity: 'Legendary',
	    ),
	  ];

  // ── Factory & Helpers ──

  factory AchievementModel.fromMap(Map<String, dynamic> map, String docId) {
    return AchievementModel(
      id: map['id'] as String? ?? docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      unlocked: map['unlocked'] as bool? ?? false,
      unlockDate: _parseDate(map['unlockDate']),
      icon: map['icon'] as String? ?? '🏅',
      category: map['category'] as String? ?? 'General',
      xpReward: map['xpReward'] as int? ?? 0,
      coinReward: map['coinReward'] as int? ?? 0,
      gameType: map['gameType'] as String?,
      condition: map['condition'] as String?,
      order: map['order'] as int? ?? 0,
      rarity: map['rarity'] as String? ?? 'Common',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlocked': unlocked,
      'unlockDate': unlockDate != null ? Timestamp.fromDate(unlockDate!) : null,
      'icon': icon,
      'category': category,
      'xpReward': xpReward,
      'coinReward': coinReward,
      'gameType': gameType,
      'condition': condition,
      'order': order,
      'rarity': rarity,
    };
  }

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? unlocked,
    DateTime? unlockDate,
    String? icon,
    String? category,
    int? xpReward,
    int? coinReward,
    String? gameType,
    String? condition,
    int? order,
    String? rarity,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      unlocked: unlocked ?? this.unlocked,
      unlockDate: unlockDate ?? this.unlockDate,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      gameType: gameType ?? this.gameType,
      condition: condition ?? this.condition,
      order: order ?? this.order,
      rarity: rarity ?? this.rarity,
    );
  }

  /// Get rarity color for UI
  Color get rarityColor {
    switch (rarity) {
      case 'Common':
        return const Color(0xFF9E9E9E);
      case 'Uncommon':
        return const Color(0xFF4CAF50);
      case 'Rare':
        return const Color(0xFF2196F3);
      case 'Epic':
        return const Color(0xFF9C27B0);
      case 'Legendary':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Get game type display name
  String? get gameTypeDisplay {
    if (gameType == null) return null;
    switch (gameType) {
      case 'fillInBlank':
        return 'Fill in the Blank';
      case 'chooseCorrectTense':
        return 'Choose Correct Tense';
      case 'sentenceBuilder':
        return 'Sentence Builder';
      case 'errorDetection':
        return 'Error Detection';
      case 'translationChallenge':
        return 'Translation Challenge';
      case 'speedQuiz':
        return 'Speed Quiz';
      case 'wordMatch':
        return 'Word Match';
      case 'dailyChallenge':
        return 'Daily Challenge';
      case 'quickQuiz':
        return 'Quick Quiz';
      case 'verbLearning':
        return 'Verb Learning';
      case 'grammarDetective':
        return 'Grammar Detective';
      case 'banglaToEnglish':
        return 'Bangla to English';
      case 'storyCompletion':
        return 'Story Completion';
      case 'flashcard':
        return 'Flashcards';
      case 'normal':
        return 'Normal Quiz';
      default:
        return gameType;
    }
  }

  @override
  String toString() {
    return 'AchievementModel(id: $id, title: $title, unlocked: $unlocked, gameType: $gameType, rarity: $rarity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}