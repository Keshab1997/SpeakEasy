import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_spoken_english_app/core/constants/app_colors.dart';
import 'package:flutter_spoken_english_app/models/user_model.dart';
import 'package:flutter_spoken_english_app/models/game/game_result_model.dart';

void main() {
  group('AppColors', () {
    test('primary color is defined', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.primary.value, 0xFF2563EB);
    });

    test('all theme colors are defined', () {
      expect(AppColors.backgroundLight, isNotNull);
      expect(AppColors.surfaceLight, isNotNull);
      expect(AppColors.backgroundDark, isNotNull);
      expect(AppColors.surfaceDark, isNotNull);
    });

    test('status colors are defined', () {
      expect(AppColors.success, isNotNull);
      expect(AppColors.error, isNotNull);
      expect(AppColors.warning, isNotNull);
      expect(AppColors.info, isNotNull);
    });

    test('gradient lists have multiple colors', () {
      expect(AppColors.primaryGradient.length, greaterThanOrEqualTo(2));
      expect(AppColors.secondaryGradient.length, greaterThanOrEqualTo(2));
    });
  });

  group('UserModel', () {
    test('fromMap creates valid UserModel', () {
      final map = {
        'name': 'Test User',
        'email': 'test@example.com',
        'photoUrl': 'https://example.com/photo.jpg',
        'joinedAt': Timestamp.fromDate(DateTime(2024, 1, 15)),
        'streak': 5,
        'currentLevel': 'Intermediate',
        'role': 'student',
      };
      final user = UserModel.fromMap(map, 'user123');
      expect(user.id, 'user123');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.streak, 5);
      expect(user.currentLevel, 'Intermediate');
      expect(user.role, 'student');
    });

    test('fromMap handles missing fields with defaults', () {
      final map = <String, dynamic>{};
      final user = UserModel.fromMap(map, 'user456');
      expect(user.name, '');
      expect(user.email, '');
      expect(user.photoUrl, '');
      expect(user.streak, 0);
      expect(user.currentLevel, 'Beginner');
      expect(user.role, 'student');
    });

    test('toMap converts correctly', () {
      final user = UserModel(
        id: 'user789',
        name: 'Jane Doe',
        email: 'jane@example.com',
        photoUrl: 'https://example.com/jane.jpg',
        joinedAt: DateTime(2024, 6, 1),
        streak: 10,
        currentLevel: 'Advanced',
        role: 'admin',
      );
      final map = user.toMap();
      expect(map['name'], 'Jane Doe');
      expect(map['email'], 'jane@example.com');
      expect(map['streak'], 10);
      expect(map['currentLevel'], 'Advanced');
      expect(map['role'], 'admin');
      expect(map['joinedAt'], isA<Timestamp>());
    });

    test('copyWith updates specified fields', () {
      final user = UserModel(
        id: 'user1',
        name: 'Original',
        email: 'orig@example.com',
        joinedAt: DateTime(2024, 1, 1),
      );
      final updated = user.copyWith(name: 'Updated', streak: 7);
      expect(updated.name, 'Updated');
      expect(updated.streak, 7);
      expect(updated.email, 'orig@example.com'); // unchanged
      expect(updated.id, 'user1'); // unchanged
    });

    test('default role is student', () {
      final user = UserModel(
        id: 'user1',
        name: 'Test',
        email: 'test@test.com',
        joinedAt: DateTime.now(),
      );
      expect(user.role, 'student');
    });
  });

  group('GameResultModel', () {
    test('default values are set correctly', () {
      final result = GameResultModel(
        gameType: 'quick_quiz',
      );
      expect(result.correctAnswers, 0);
      expect(result.wrongAnswers, 0);
      expect(result.score, 0);
      expect(result.earnedXP, 0);
      expect(result.earnedCoins, 0);
      expect(result.isBossWin, false);
      expect(result.isDailyChallengeWin, false);
      expect(result.durationSeconds, 0);
    });

    test('fields are set via constructor', () {
      final result = GameResultModel(
        gameType: 'quiz',
        correctAnswers: 7,
        wrongAnswers: 3,
        score: 70,
        earnedXP: 50,
        earnedCoins: 20,
        durationSeconds: 120,
        isBossWin: true,
      );
      expect(result.correctAnswers, 7);
      expect(result.wrongAnswers, 3);
      expect(result.score, 70);
      expect(result.earnedXP, 50);
      expect(result.earnedCoins, 20);
      expect(result.durationSeconds, 120);
      expect(result.isBossWin, true);
      expect(result.gameType, 'quiz');
    });

    test('toFirestoreMap contains required keys', () {
      final result = GameResultModel(
        gameType: 'tense_quiz',
        correctAnswers: 4,
        wrongAnswers: 1,
        score: 80,
        earnedXP: 50,
        earnedCoins: 20,
        durationSeconds: 120,
      );
      final map = result.toFirestoreMap();
      expect(map['gameType'], 'tense_quiz');
      expect(map['correctAnswers'], 4);
      expect(map['score'], 80);
      expect(map['earnedXP'], 50);
      expect(map['earnedCoins'], 20);
      expect(map['durationSeconds'], 120);
    });

    test('copyWith updates specified fields', () {
      final result = GameResultModel(
        gameType: 'normal',
        correctAnswers: 3,
        wrongAnswers: 2,
      );
      final updated = result.copyWith(
        correctAnswers: 5,
        wrongAnswers: 0,
        isBossWin: true,
      );
      expect(updated.correctAnswers, 5);
      expect(updated.wrongAnswers, 0);
      expect(updated.isBossWin, true);
      expect(updated.gameType, 'normal'); // unchanged
    });
  });
}
