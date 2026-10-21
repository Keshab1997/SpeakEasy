import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/repositories/progress_repository.dart';
import 'package:flutter_spoken_english_app/services/xp_service.dart';

/// The XP and level arithmetic that every game mode feeds into.
///
/// These methods are pure — they take numbers and return numbers — so they are
/// the cheap part of the game feature to pin down, and the expensive part to
/// get wrong: a boundary that flips here silently mis-ranks the player on the
/// leaderboard, because `levelFromTotalXP` is shared with Firestore and Hive.
///
/// The repositories are only constructed, never called: nothing in this file
/// touches Hive, Firebase or an asset bundle.
void main() {
  late XpService xp;

  setUp(() {
    xp = XpService(progressRepository: ProgressRepository());
  });

  group('calculateCorrectAnswerXP', () {
    test('pays the base 10 and nothing more before a streak of 5', () {
      expect(xp.calculateCorrectAnswerXP(), 10);
      expect(xp.calculateCorrectAnswerXP(streak: 1), 10);
      expect(xp.calculateCorrectAnswerXP(streak: 4), 10);
    });

    test('adds +5 for every completed group of 5 in the streak', () {
      expect(xp.calculateCorrectAnswerXP(streak: 5), 15);
      expect(xp.calculateCorrectAnswerXP(streak: 9), 15);
      expect(xp.calculateCorrectAnswerXP(streak: 10), 20);
      expect(xp.calculateCorrectAnswerXP(streak: 25), 35);
    });
  });

  group('calculateSpeedBonusXP', () {
    int speed(int remaining, int total) =>
        xp.calculateSpeedBonusXP(timeRemaining: remaining, totalTime: total);

    test('pays by the fraction of the clock left', () {
      expect(speed(100, 100), 15); // 1.00
      expect(speed(75, 100), 15); // exactly 0.75 is still the top band
      expect(speed(74, 100), 10);
      expect(speed(50, 100), 10); // exactly 0.50
      expect(speed(49, 100), 5);
      expect(speed(25, 100), 5); // exactly 0.25
      expect(speed(24, 100), 0);
      expect(speed(0, 100), 0);
    });

    test('a zero-length round cannot divide by zero', () {
      expect(speed(0, 0), 0);
      expect(speed(10, 0), 0);
      expect(speed(10, -5), 0);
    });
  });

  group('calculateAccuracyBonusXP', () {
    test('pays at each threshold and not one point below it', () {
      expect(xp.calculateAccuracyBonusXP(accuracy: 1.0), 50);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.95), 50);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.94), 30);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.85), 30);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.84), 15);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.70), 15);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0.69), 0);
      expect(xp.calculateAccuracyBonusXP(accuracy: 0), 0);
    });
  });

  group('calculateTotalGameXP', () {
    test('adds nothing beyond the base when everything else is zero', () {
      expect(
        xp.calculateTotalGameXP(
          correctCount: 5,
          totalQuestions: 10,
          accuracy: 0,
          streak: 0,
          timeRemaining: 0,
          totalTime: 100,
        ),
        50,
      );
    });

    test('stacks base + streak + speed + accuracy + perfect bonuses', () {
      expect(
        xp.calculateTotalGameXP(
          correctCount: 10,
          totalQuestions: 10,
          accuracy: 1.0,
          streak: 10,
          timeRemaining: 100,
          totalTime: 100,
          isPerfectGame: true,
        ),
        225, // 100 base + 10 streak + 15 speed + 50 accuracy + 50 perfect
      );
    });
  });

  group('levelFromTotalXP', () {
    test('a player with no XP is at the fallback level, never level 0', () {
      expect(XpService.levelFromTotalXP(0), 1);
      expect(XpService.levelFromTotalXP(-50), 1);
      expect(XpService.levelFromTotalXP(0, fallback: 7), 7);
    });

    test('levels up exactly on each 300-XP boundary', () {
      expect(XpService.levelFromTotalXP(1), 1);
      expect(XpService.levelFromTotalXP(299), 1);
      expect(XpService.levelFromTotalXP(300), 2);
      expect(XpService.levelFromTotalXP(599), 2);
      expect(XpService.levelFromTotalXP(600), 3);
      expect(XpService.levelFromTotalXP(3000), 11);
    });

    test('the instance method agrees with the shared static one', () {
      for (final value in [0, 1, 299, 300, 1500, 3000]) {
        expect(xp.levelFromXP(value), XpService.levelFromTotalXP(value));
      }
    });
  });

  group('getXPForNextLevel', () {
    test('is cumulative: finishing level n needs n x 300', () {
      expect(xp.getXPForNextLevel(0), 0); // before level 1
      expect(xp.getXPForNextLevel(1), 300);
      expect(xp.getXPForNextLevel(2), 600);
      expect(xp.getXPForNextLevel(3), 900);
      expect(xp.getXPForNextLevel(-1), 0);
    });
  });

  group('getLevelProgressFor', () {
    test('is 0 at the start of a level and 0.5 at its midpoint', () {
      expect(xp.getLevelProgressFor(1, 0), 0.0);
      expect(xp.getLevelProgressFor(1, 150), closeTo(0.5, 1e-9));
      expect(xp.getLevelProgressFor(2, 300), 0.0);
      expect(xp.getLevelProgressFor(2, 450), closeTo(0.5, 1e-9));
    });

    test('an XP total that has already crossed the level clamps to full', () {
      expect(xp.getLevelProgressFor(1, 299), closeTo(299 / 300, 1e-9));
      expect(xp.getLevelProgressFor(2, 999), 1.0);
    });

    test('XP below the level floor clamps to empty instead of going negative', () {
      expect(xp.getLevelProgressFor(3, 100), 0.0);
    });

    test('agrees with levelFromTotalXP: a level boundary starts at 0 progress', () {
      for (final xpTotal in [0, 299, 300, 599, 600, 1200]) {
        final level = XpService.levelFromTotalXP(xpTotal);
        final progress = xp.getLevelProgressFor(level, xpTotal);
        expect(progress, inInclusiveRange(0.0, 1.0),
            reason: '$xpTotal XP at level $level produced $progress');
        expect(progress, closeTo((xpTotal % 300) / 300, 1e-9),
            reason: '$xpTotal XP at level $level');
      }
    });
  });
}
