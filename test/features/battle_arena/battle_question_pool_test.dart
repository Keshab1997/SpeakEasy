import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_spoken_english_app/features/battle_arena/models/battle_models.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/services/battle_game_service.dart';

/// Guards the question pool that SEED rooms are hydrated from.
///
/// A room doc carries only `questionSeed`; both players regenerate the same
/// 5 questions locally. When the pool build silently lost a source, `pick()`
/// for that category returned nothing and the arena had no question to show —
/// the round timer still ran (it defaults to 15s with a null question), so the
/// duel "played" with nothing to answer. `AssetManifest.json` was one such
/// loss: Flutter removed that legacy asset key, so the whole Vocabulary
/// category vanished unless the manifest is read via
/// `AssetManifest.loadFromAssetBundle`. These tests fail the build if any
/// source silently drops out again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('battle question pool', () {
    test('exposes all three sources the match selector asks for', () async {
      final pool = await BattleGameService.loadCuratedQuestions();
      expect(pool, isNotEmpty, reason: 'pool must never be empty');

      // loadCuratedQuestions returns one match-length sample, so sample the
      // generator across several seeds to see every category represented.
      final categories = <String>{};
      for (final seed in [1, 2, 3, 7, 11]) {
        categories.addAll(
          (await BattleGameService.generateSeededQuestions(seed))
              .map((q) => q.category),
        );
      }
      expect(categories, containsAll(<String>['grammar', 'vocabulary', 'verb']),
          reason: 'a source stopped contributing — assets failed to load');
    });

    test('every generated question is answerable', () async {
      final questions = await BattleGameService.generateSeededQuestions(20260918);
      expect(questions.length, 5);
      for (final q in questions) {
        expect(q.question.trim(), isNotEmpty);
        expect(q.options.length, greaterThanOrEqualTo(2));
        expect(q.correctAnswer, inInclusiveRange(0, q.options.length - 1),
            reason: 'correctAnswer must index into options (${q.id})');
        expect(q.timeLimit, greaterThan(0),
            reason: 'a zero time limit ends the round instantly (${q.id})');
      }
    });

    test('is deterministic: both players derive the same set from one seed',
        () async {
      final a = await BattleGameService.generateSeededQuestions(424242);
      final b = await BattleGameService.generateSeededQuestions(424242);
      expect(b.map((q) => q.id), orderedEquals(a.map((q) => q.id)),
          reason: 'seed rooms must not disagree on question order');
      expect(b.map((q) => q.options), orderedEquals(a.map((q) => q.options)),
          reason: 'option order must match or the two players see different '
              'answers for the same question');
    });

    test('a seed-only room doc hydrates to exactly questionCount questions',
        () async {
      // Mirrors what a seed room looks like straight out of Firestore:
      // no embedded questions, only the seed.
      final stored = BattleRoom.fromMap({
        'status': 'in_progress',
        'questionSeed': 987654321,
        'questionCount': 5,
        'questionSetVersion': BattleGameService.questionSetVersion,
        'player1': {'id': 'p1', 'name': 'A', 'trophies': 100},
        'player2': {'id': 'p2', 'name': 'B', 'trophies': 100},
      }, 'room_fixture');

      expect(stored.isSeedRoom, isTrue);
      expect(stored.questions, isEmpty);
      expect(stored.toMap()['questionSeed'], 987654321,
          reason: 'toMap must round-trip the seed or a re-write loses it');

      final hydrated = stored.copyWith(
        questions: await BattleGameService.generateSeededQuestions(
          stored.questionSeed!,
          count: stored.questionCount,
        ),
      );
      expect(hydrated.questions.length, stored.questionCount);
      // Round-tripping through the model must not drop the hydrated list.
      expect(
        BattleRoom.fromMap(hydrated.toMap(), hydrated.id).questions.length,
        stored.questionCount,
      );
    });
  });
}
