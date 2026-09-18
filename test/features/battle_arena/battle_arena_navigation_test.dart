// Source-contract tests for the battle arena's entry navigation.
//
// WHY these exist: the arena used to be opened only as a side effect of a
// global listener (GlobalBattleChallengeGate) that fired on `status ->
// inDuel`. The waiting room popped itself in the same frame, so the gate's
// push could run against a stale navigator context and throw — and because
// `_arenaOpen` was reset only on a *successful* await, one aborted push pinned
// it to `true` for the rest of the app's life. Result: both players stayed on
// the waiting room, hearing round sounds (the timers live in the provider,
// not the screen) with no arena ever appearing.
//
// These are deliberately cheap static assertions — no widgets, no Firebase, no
// two-device rig — but each one fails loudly if someone reintroduces the
// single-path/never-reset pattern. Run: `flutter test test/features/battle_arena`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativeToLib) =>
    File('${Directory.current.path}/lib/$relativeToLib').readAsStringSync();

const String waitingRoom =
    'features/battle_arena/screens/battle_waiting_room_screen.dart';
const String gate =
    'features/battle_arena/widgets/global_battle_challenge_gate.dart';
const String arena = 'features/battle_arena/screens/battle_arena_screen.dart';

void main() {
  group('waiting room owns its own navigation into the arena', () {
    late String src;
    setUpAll(() => src = _read(waitingRoom));

    test('it pushes BattleArenaScreen itself, not only via the gate', () {
      expect(src, contains('BattleArenaScreen()'));
      expect(src, contains('Navigator.of(context, rootNavigator: true).push('));
    });

    test(
      'the push goes through the root navigator (same one the gate uses)',
      () {
        expect(
          src,
          contains('rootNavigator: true'),
          reason:
              'a nested navigator here would put the arena under the '
              'waiting room instead of above it',
        );
      },
    );

    test('the waiting room pops only AFTER the arena is on screen', () {
      final pushAt = src.indexOf(
        'await Navigator.of(context, rootNavigator: true).push(',
      );
      final popAt = src.indexOf('_enterArena();', pushAt);
      expect(pushAt, greaterThan(0), reason: 'push call disappeared');
      expect(
        popAt,
        greaterThan(pushAt),
        reason:
            'popping before the push completes is what staled the '
            'navigator context for the gate listener',
      );
    });

    test('a duel with no questions never enters (no blank arena)', () {
      expect(src, contains('room.questions.isEmpty'));
      expect(src, contains('Could not load the questions for this duel.'));
    });

    test('the start path is fired from the room snapshot listener', () {
      expect(src, contains('unawaited(_enterArenaNow())'));
      expect(src, contains('BattleRoomStatus.inProgress'));
    });
  });

  group('gate cannot disable the arena for the whole session', () {
    late String src;
    setUpAll(() => src = _read(gate));

    test('_arenaOpen is released in a finally block', () {
      final flagSet = src.indexOf('_arenaOpen = true;');
      final finallyAt = src.indexOf('} finally {', flagSet);
      final flagClear = src.indexOf('_arenaOpen = false;', finallyAt);
      expect(flagSet, greaterThan(0));
      expect(
        finallyAt,
        greaterThan(flagSet),
        reason: '_arenaOpen = true must be followed by a try/finally',
      );
      expect(
        flagClear,
        greaterThan(finallyAt),
        reason: 'a stuck _arenaOpen=true silently blocks every later duel',
      );
    });

    test('the listener yields a frame before pushing', () {
      expect(src, contains('await Future<void>.delayed(Duration.zero);'));
    });

    test('dedup uses the mounted screen, not a guessed flag', () {
      expect(src, contains('BattleArenaScreen.routeActive'));
    });

    test('no force-unwrap of the navigator context', () {
      expect(
        src,
        isNot(contains('appNavigatorKey.currentContext!')),
        reason: 'null context here used to throw inside the listener',
      );
    });
  });

  group('arena screen reports its own presence', () {
    late String src;
    setUpAll(() => src = _read(arena));

    test('routeActive is set on mount and cleared on dispose', () {
      final initAt = src.indexOf('BattleArenaScreen.routeActive = true;');
      expect(initAt, greaterThan(0), reason: 'no mount hook sets the flag');
      expect(src.contains('static bool routeActive = false;'), isTrue,
          reason: 'the flag must default to false at the declaration, not in dispose');
      final disposeBody = src.substring(src.indexOf('void dispose()'));
      final clearAt = disposeBody.indexOf('BattleArenaScreen.routeActive = false;');
      final superAt = disposeBody.indexOf('super.dispose()');
      expect(clearAt, greaterThan(0), reason: 'dispose() must clear the flag');
      expect(
        clearAt,
        lessThan(superAt),
        reason: 'clear before super.dispose() keeps the ordering obvious',
      );
    });
  });
}
