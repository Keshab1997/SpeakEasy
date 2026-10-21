import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_spoken_english_app/features/battle_arena/models/battle_models.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/providers/battle_arena_provider.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/providers/battle_presence_provider.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/screens/battle_lobby_screen.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/services/battle_matchmaking_service.dart';
import 'package:flutter_spoken_english_app/features/battle_arena/services/battle_presence_service.dart';
import 'package:flutter_spoken_english_app/models/user_model.dart';
import 'package:flutter_spoken_english_app/providers/auth_provider.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _FakeAuthNotifier(UserModel? user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'user_test_1',
    name: 'Keshab',
    email: 'test@example.com',
    joinedAt: DateTime(2026, 10, 21),
  );

  const localPlayer = BattlePlayer(
    id: 'user_test_1',
    name: 'Keshab',
    trophies: 250,
  );

  tearDown(() {
    battleBotOnlyMode = true;
    BattleMatchmakingService.botConnectDelay =
        const Duration(milliseconds: 800);
  });

  group('Battle Arena bot-only mode', () {
    test('battleBotOnlyMode is enabled by default', () {
      expect(battleBotOnlyMode, isTrue);
    });

    test(
      'findMatch pairs directly with a trophy-matched AI Bot without touching Firestore',
      () async {
        BattleMatchmakingService.botConnectDelay = Duration.zero;
        final progressMessages = <String>[];

        final room = await BattleMatchmakingService().findMatch(
          localPlayer: localPlayer,
          onProgress: progressMessages.add,
        );

        expect(room.id, startsWith('local_bot_room_'));
        expect(room.player1.id, localPlayer.id);
        expect(room.player2.isBot, isTrue);
        expect(room.player2.id, startsWith('bot_'));
        expect((room.player2.trophies - localPlayer.trophies).abs(),
            lessThanOrEqualTo(15));
        expect(room.status, BattleRoomStatus.inProgress);
        expect(room.questions.length, 5);
        expect(progressMessages, isNotEmpty);
      },
    );

    test('cancelling matchmaking token aborts before bot duel starts',
        () async {
      BattleMatchmakingService.botConnectDelay = const Duration(seconds: 5);
      final token = MatchmakingToken();

      final future = BattleMatchmakingService().findMatch(
        localPlayer: localPlayer,
        onProgress: (_) {},
        token: token,
      );
      Future<void>.delayed(const Duration(milliseconds: 20), token.cancel);

      await expectLater(future, throwsA(isA<MatchmakingCancelledException>()));
    });

    test('direct PvP room creation & challenges are blocked in bot-only mode',
        () async {
      const realPeer = BattlePlayer(
        id: 'user_peer_2',
        name: 'Peer',
        trophies: 240,
      );
      final mm = BattleMatchmakingService();

      await expectLater(
        mm.createWaitingRoom(player1: localPlayer, player2: realPeer),
        throwsA(isA<MatchmakingFailedException>()),
      );
      await expectLater(
        mm.createDirectChallengeRoom(player1: localPlayer, player2: realPeer),
        throwsA(isA<MatchmakingFailedException>()),
      );
      await expectLater(
        BattlePresenceService().sendChallenge(
          fromUserId: localPlayer.id,
          fromUserName: localPlayer.name,
          fromUserPhoto: '',
          fromUserTrophies: localPlayer.trophies,
          toUserId: realPeer.id,
        ),
        throwsA(isA<ChallengeBlockedException>()),
      );
    });

    test('presence & challenge streams emit empty immediately in bot-only mode',
        () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(lobbyPresenceProvider.future), isEmpty);
      expect(await container.read(blockedIdsProvider.future), isEmpty);
      expect(await container.read(incomingChallengesProvider.future), isEmpty);
      expect(await container.read(outgoingChallengesProvider.future), isEmpty);
      expect(
        await container.read(acceptedIncomingChallengesProvider.future),
        isEmpty,
      );
    });

    testWidgets(
      'BattleLobbyScreen hides real-player sections and launches bot duel on Quick Match',
      (tester) async {
        BattleMatchmakingService.botConnectDelay = Duration.zero;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _FakeAuthNotifier(testUser)),
            ],
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(home: BattleLobbyScreen());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('QUICK 1v1 MATCH'), findsOneWidget);
        expect(find.text('AI Challenger Mode 🤖'), findsOneWidget);
        expect(find.text('ONLINE LEARNERS'), findsNothing);
        expect(find.text('MY FRIENDS'), findsNothing);
        expect(find.text('RECENTLY ACTIVE'), findsNothing);

        await tester.tap(find.text('QUICK 1v1 MATCH'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final arenaState = container.read(battleArenaProvider);
        expect(arenaState.status, BattleArenaStatus.inDuel);
        expect(arenaState.opponent.isBot, isTrue);
        expect(arenaState.room?.questions.length, 5);

        // Clean up active round/bot timers before widget teardown.
        container.read(battleArenaProvider.notifier).resetLobby();
        await tester.pumpAndSettle();
      },
    );
  });
}
