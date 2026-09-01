import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../services/battle_bot_simulator.dart';
import '../services/battle_game_service.dart';
import '../services/battle_matchmaking_service.dart';

enum BattleArenaStatus {
  idle,
  searching,
  inDuel,
  roundSummary,
  completed,
}

class BattleArenaState {
  final BattleArenaStatus status;
  final BattleRoom? room;
  final BattlePlayer localPlayer;
  final BattlePlayer opponent;
  final int currentRoundIndex; // 0 to 4
  final int remainingSeconds; // 15 down to 0
  final int? selectedAnswerIndex;
  final int? opponentAnswerIndex;
  final bool isAnswerSubmitted;
  final bool isOpponentAnswered;
  final String searchStatusMessage;
  final String? activeEmote;
  final String? opponentEmote;
  final BattleStats stats;
  final bool isWinner;
  final bool isDraw;
  final int trophyDelta;
  final bool isOpponentForfeited;

  const BattleArenaState({
    this.status = BattleArenaStatus.idle,
    this.room,
    required this.localPlayer,
    required this.opponent,
    this.currentRoundIndex = 0,
    this.remainingSeconds = 15,
    this.selectedAnswerIndex,
    this.opponentAnswerIndex,
    this.isAnswerSubmitted = false,
    this.isOpponentAnswered = false,
    this.searchStatusMessage = 'Searching for opponents...',
    this.activeEmote,
    this.opponentEmote,
    this.stats = const BattleStats(),
    this.isWinner = false,
    this.isDraw = false,
    this.trophyDelta = 0,
    this.isOpponentForfeited = false,
  });

  BattleQuestion? get currentQuestion {
    if (room == null || room!.questions.isEmpty) return null;
    if (currentRoundIndex >= 0 && currentRoundIndex < room!.questions.length) {
      return room!.questions[currentRoundIndex];
    }
    return null;
  }

  BattleArenaState copyWith({
    BattleArenaStatus? status,
    BattleRoom? room,
    BattlePlayer? localPlayer,
    BattlePlayer? opponent,
    int? currentRoundIndex,
    int? remainingSeconds,
    int? selectedAnswerIndex,
    int? opponentAnswerIndex,
    bool? isAnswerSubmitted,
    bool? isOpponentAnswered,
    String? searchStatusMessage,
    String? activeEmote,
    String? opponentEmote,
    BattleStats? stats,
    bool? isWinner,
    bool? isDraw,
    int? trophyDelta,
    bool? isOpponentForfeited,
    bool clearSelectedAnswer = false,
    bool clearOpponentAnswer = false,
  }) {
    return BattleArenaState(
      status: status ?? this.status,
      room: room ?? this.room,
      localPlayer: localPlayer ?? this.localPlayer,
      opponent: opponent ?? this.opponent,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      selectedAnswerIndex: clearSelectedAnswer ? null : (selectedAnswerIndex ?? this.selectedAnswerIndex),
      opponentAnswerIndex: clearOpponentAnswer ? null : (opponentAnswerIndex ?? this.opponentAnswerIndex),
      isAnswerSubmitted: isAnswerSubmitted ?? this.isAnswerSubmitted,
      isOpponentAnswered: isOpponentAnswered ?? this.isOpponentAnswered,
      searchStatusMessage: searchStatusMessage ?? this.searchStatusMessage,
      activeEmote: activeEmote ?? this.activeEmote,
      opponentEmote: opponentEmote ?? this.opponentEmote,
      stats: stats ?? this.stats,
      isWinner: isWinner ?? this.isWinner,
      isDraw: isDraw ?? this.isDraw,
      trophyDelta: trophyDelta ?? this.trophyDelta,
      isOpponentForfeited: isOpponentForfeited ?? this.isOpponentForfeited,
    );
  }
}

final battleArenaProvider = StateNotifierProvider.autoDispose<BattleArenaNotifier, BattleArenaState>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  return BattleArenaNotifier(currentUser: currentUser);
});

class BattleArenaNotifier extends StateNotifier<BattleArenaState> {
  final UserModel? currentUser;
  final BattleMatchmakingService _matchmakingService = BattleMatchmakingService();

  Timer? _roundTimer;
  Timer? _botActionTimer;
  Timer? _emoteDismissTimer;
  Timer? _opponentEmoteTimer;
  Timer? _roundTransitionTimer;
  StreamSubscription<BattleRoom?>? _roomSubscription;

  /// True while the 1.8s round-summary delay is running — prevents the
  /// round from being advanced twice (answer + timer expiry racing).
  bool _roundTransitioning = false;

  /// Seconds for the current question (questions may define their own limit).
  int get _roundTimeLimit => state.currentQuestion?.timeLimit ?? 15;

  BattleArenaNotifier({this.currentUser})
      : super(
          BattleArenaState(
            localPlayer: BattlePlayer(
              id: currentUser?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
              name: currentUser?.name ?? 'Player',
              photoUrl: currentUser?.photoUrl ?? '',
              trophies: 100,
              currentScore: 0,
            ),
            opponent: const BattlePlayer(
              id: 'opponent',
              name: 'Opponent',
              photoUrl: '',
              trophies: 100,
              currentScore: 0,
            ),
          ),
        ) {
    _initLocalStats();
  }

  Future<void> _initLocalStats() async {
    final stats = await BattleGameService.getLocalStats();
    state = state.copyWith(
      stats: stats,
      localPlayer: state.localPlayer.copyWith(trophies: stats.trophies),
    );
  }

  /// Starts quick matchmaking
  Future<void> startQuickMatch() async {
    final freshLocal = state.localPlayer.copyWith(
      currentScore: 0,
      currentRound: 0,
      selectedAnswer: null,
      isForfeited: false,
      timeTakenSeconds: 0,
    );

    state = state.copyWith(
      status: BattleArenaStatus.searching,
      searchStatusMessage: 'Initializing radar scanner... 📡',
      localPlayer: freshLocal,
      opponent: const BattlePlayer(id: 'opponent', name: 'Opponent', trophies: 100, currentScore: 0),
      currentRoundIndex: 0,
      remainingSeconds: 15,
      isAnswerSubmitted: false,
      isOpponentAnswered: false,
      clearSelectedAnswer: true,
      clearOpponentAnswer: true,
      isWinner: false,
      isDraw: false,
      trophyDelta: 0,
      isOpponentForfeited: false,
    );

    try {
      final room = await _matchmakingService.findMatch(
        localPlayer: freshLocal,
        onProgress: (msg) {
          state = state.copyWith(searchStatusMessage: msg);
        },
      );

      final isPlayer1 = room.player1.id == freshLocal.id;
      final opp = isPlayer1 ? room.player2 : room.player1;

      state = state.copyWith(
        status: BattleArenaStatus.inDuel,
        room: room,
        localPlayer: freshLocal,
        opponent: opp.copyWith(
          currentScore: 0,
          currentRound: 0,
          selectedAnswer: null,
          isForfeited: false,
          timeTakenSeconds: 0,
        ),
        currentRoundIndex: 0,
        isAnswerSubmitted: false,
        isOpponentAnswered: false,
        clearSelectedAnswer: true,
        clearOpponentAnswer: true,
        isWinner: false,
        isDraw: false,
        trophyDelta: 0,
        isOpponentForfeited: false,
      );

      // Listen to real room if online
      if (!opp.isBot) {
        _subscribeToRoom(room.id, isPlayer1);
      }

      _startRoundTimer();
      if (opp.isBot) {
        _scheduleBotAnswer();
      }
    } catch (e) {
      state = state.copyWith(status: BattleArenaStatus.idle);
    }
  }

  /// Starts a match from a direct challenge
  void startFromRoom(BattleRoom room) {
    final isPlayer1 = room.player1.id == state.localPlayer.id;
    final opp = isPlayer1 ? room.player2 : room.player1;

    state = state.copyWith(
      status: BattleArenaStatus.inDuel,
      room: room,
      localPlayer: state.localPlayer.copyWith(
        currentScore: 0,
        currentRound: 0,
        selectedAnswer: null,
        isForfeited: false,
        timeTakenSeconds: 0,
        roundAnswers: const {},
      ),
      opponent: opp.copyWith(
        currentScore: 0,
        currentRound: 0,
        selectedAnswer: null,
        isForfeited: false,
        timeTakenSeconds: 0,
      ),
      currentRoundIndex: 0,
      isAnswerSubmitted: false,
      isOpponentAnswered: false,
      clearSelectedAnswer: true,
      clearOpponentAnswer: true,
      isWinner: false,
      isDraw: false,
      trophyDelta: 0,
      isOpponentForfeited: false,
    );

    if (!opp.isBot) {
      _subscribeToRoom(room.id, isPlayer1);
    }

    _startRoundTimer();
  }

  String? _lastOpponentEmote;

  void _subscribeToRoom(String roomId, bool isPlayer1) {
    _roomSubscription?.cancel();
    _roomSubscription = _matchmakingService.streamRoom(roomId).listen((room) {
      if (room == null) return;
      if (state.status != BattleArenaStatus.inDuel &&
          state.status != BattleArenaStatus.roundSummary) {
        return;
      }

      final opp = isPlayer1 ? room.player2 : room.player1;

      // Opponent explicitly forfeited / surrendered → we win.
      if (opp.isForfeited) {
        _handleOpponentForfeited();
        return;
      }

      // Opponent's answer for the CURRENT round (read from per-round map).
      final currentRoundKey = state.currentRoundIndex.toString();
      final oppAnswerThisRound = opp.roundAnswers[currentRoundKey];

      // Sync the opponent's live score on every update (covers timeouts,
      // late answers — previously only synced when an answer arrived).
      if (opp.currentScore != state.opponent.currentScore ||
          (oppAnswerThisRound != null && oppAnswerThisRound != state.opponentAnswerIndex)) {
        state = state.copyWith(
          opponentAnswerIndex: oppAnswerThisRound,
          isOpponentAnswered: oppAnswerThisRound != null,
          opponent: state.opponent.copyWith(
            currentScore: opp.currentScore,
            selectedAnswer: oppAnswerThisRound,
          ),
        );

        // Both players answered the current round → advance.
        if (state.isAnswerSubmitted && state.isOpponentAnswered) {
          _completeRoundWithDelay();
        }
      }

      // Opponent emote (only react to a NEW emote, not every snapshot).
      if (room.activeEmote != null &&
          room.emoteSenderId == opp.id &&
          room.activeEmote != _lastOpponentEmote) {
        _lastOpponentEmote = room.activeEmote;
        _showOpponentEmote(room.activeEmote!);
      }
    });
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    final limit = _roundTimeLimit;
    state = state.copyWith(remainingSeconds: limit);

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.remainingSeconds > 1) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        // Time ran out for this round
        timer.cancel();
        _onRoundTimeExpired();
      }
    });
  }

  void _scheduleBotAnswer() {
    _botActionTimer?.cancel();
    final question = state.currentQuestion;
    if (question == null) return;

    final decision = BattleBotSimulator.decideAnswer(
      question: question,
      roundNumber: state.currentRoundIndex + 1,
    );

    _botActionTimer = Timer(Duration(seconds: decision.reactionSeconds), () {
      if (!mounted || state.status != BattleArenaStatus.inDuel) return;

      final roundScore = BattleGameService.calculateRoundScore(
        isCorrect: decision.isCorrect,
        timeTakenSeconds: decision.reactionSeconds,
        roundTimeLimit: _roundTimeLimit,
      );

      final newBotScore = state.opponent.currentScore + roundScore;

      state = state.copyWith(
        opponentAnswerIndex: decision.selectedAnswer,
        isOpponentAnswered: true,
        opponent: state.opponent.copyWith(
          currentScore: newBotScore,
          selectedAnswer: decision.selectedAnswer,
        ),
      );

      // Bot maybe sends emote (pass the current round so the cooldown works)
      final botEmote = BattleBotSimulator.maybeGenerateEmote(
        roundNumber: state.currentRoundIndex + 1,
      );
      if (botEmote != null) {
        _showOpponentEmote(botEmote);
      }

      // If local player has also answered, advance to next round
      if (state.isAnswerSubmitted) {
        _completeRoundWithDelay();
      }
    });
  }

  /// User selects an answer option
  void submitLocalAnswer(int answerIndex) {
    if (state.isAnswerSubmitted || state.status != BattleArenaStatus.inDuel) return;

    final question = state.currentQuestion;
    if (question == null) return;

    final timeTaken = _roundTimeLimit - state.remainingSeconds;
    final isCorrect = answerIndex == question.correctAnswer;
    final roundScore = BattleGameService.calculateRoundScore(
      isCorrect: isCorrect,
      timeTakenSeconds: timeTaken,
      roundTimeLimit: _roundTimeLimit,
    );

    final newLocalScore = state.localPlayer.currentScore + roundScore;
    final roundIndex = state.currentRoundIndex;

    // Keep our local roundAnswers map in sync as well.
    final updatedRoundAnswers = Map<String, int>.from(state.localPlayer.roundAnswers)
      ..[roundIndex.toString()] = answerIndex;

    state = state.copyWith(
      selectedAnswerIndex: answerIndex,
      isAnswerSubmitted: true,
      localPlayer: state.localPlayer.copyWith(
        currentScore: newLocalScore,
        selectedAnswer: answerIndex,
        timeTakenSeconds: timeTaken,
        roundAnswers: updatedRoundAnswers,
      ),
    );

    // If online match, sync with Firestore
    if (state.room != null && !state.opponent.isBot) {
      final isPlayer1 = state.room!.player1.id == state.localPlayer.id;
      _matchmakingService.submitAnswer(
        roomId: state.room!.id,
        playerId: state.localPlayer.id,
        isPlayer1: isPlayer1,
        selectedAnswer: answerIndex,
        newScore: newLocalScore,
        roundIndex: roundIndex,
      );
    }

    // Advance only when the opponent has ALSO answered.
    // - Bot match: bot answers on its own timer and triggers advance; the
    //   round timer handles the case where the bot is slow.
    // - Human match: the room subscription triggers advance when both are in;
    //   the round timer handles a slow opponent.
    if (state.isOpponentAnswered) {
      _completeRoundWithDelay();
    }
  }

  void _onRoundTimeExpired() {
    if (!mounted) return;
    state = state.copyWith(remainingSeconds: 0);
    _completeRoundWithDelay();
  }

  void _completeRoundWithDelay() {
    // Guard: a transition is already scheduled (answer + timer raced).
    if (_roundTransitioning) return;
    _roundTransitioning = true;

    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roundTransitionTimer?.cancel();

    // Brief window so both players see the correct/wrong answer.
    _roundTransitionTimer = Timer(const Duration(milliseconds: 1800), () {
      _roundTransitioning = false;
      if (!mounted || state.status != BattleArenaStatus.inDuel) return;

      final nextRound = state.currentRoundIndex + 1;
      final totalRounds = state.room?.questions.length ?? 5;

      if (nextRound >= totalRounds) {
        _finishDuel();
      } else {
        // Next round
        state = state.copyWith(
          currentRoundIndex: nextRound,
          remainingSeconds: _roundTimeLimit,
          isAnswerSubmitted: false,
          isOpponentAnswered: false,
          clearSelectedAnswer: true,
          clearOpponentAnswer: true,
        );

        _startRoundTimer();
        if (state.opponent.isBot) {
          _scheduleBotAnswer();
        }
      }
    });
  }

  Future<void> _finishDuel() async {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roundTransitionTimer?.cancel();

    final isOnline = state.room != null && !state.opponent.isBot;

    // For online matches, pull the freshest opponent score/answer from
    // Firestore before deciding the result (our local copy may lag if the
    // opponent answered on the final round after our timer expired).
    int oppScore = state.opponent.currentScore;
    if (isOnline) {
      try {
        final freshRoom = await _matchmakingService.getRoom(state.room!.id);
        if (freshRoom != null) {
          final isP1 = freshRoom.player1.id == state.localPlayer.id;
          final freshOpp = isP1 ? freshRoom.player2 : freshRoom.player1;
          oppScore = freshOpp.currentScore;
          state = state.copyWith(
            opponent: state.opponent.copyWith(currentScore: freshOpp.currentScore),
          );
        }
      } catch (_) {}
    }

    _roomSubscription?.cancel();

    final localScore = state.localPlayer.currentScore;

    final isWin = localScore > oppScore;
    final isDraw = localScore == oppScore;
    final trophyDelta = BattleGameService.calculateTrophyDelta(isWin: isWin, isDraw: isDraw);

    final updatedStats = await BattleGameService.saveMatchResult(
      isWin: isWin,
      isDraw: isDraw,
      score: localScore,
      userId: currentUser?.id,
    );

    // Mark the room completed so the opponent's client + cleanup agree.
    if (isOnline) {
      await _matchmakingService.completeRoom(
        roomId: state.room!.id,
        winnerId: isWin ? state.localPlayer.id : (isDraw ? null : state.opponent.id),
      );
    }

    state = state.copyWith(
      status: BattleArenaStatus.completed,
      stats: updatedStats,
      isWinner: isWin,
      isDraw: isDraw,
      trophyDelta: trophyDelta,
      localPlayer: state.localPlayer.copyWith(trophies: updatedStats.trophies),
    );
  }

  /// Handles when opponent forfeits or disconnects mid-match
  void _handleOpponentForfeited() async {
    if (state.status == BattleArenaStatus.completed) return;

    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _roomSubscription?.cancel();

    const trophyDelta = 25;
    final updatedStats = await BattleGameService.saveMatchResult(
      isWin: true,
      isDraw: false,
      score: state.localPlayer.currentScore,
      userId: currentUser?.id,
    );

    state = state.copyWith(
      status: BattleArenaStatus.completed,
      isOpponentForfeited: true,
      isWinner: true,
      isDraw: false,
      trophyDelta: trophyDelta,
      stats: updatedStats,
      localPlayer: state.localPlayer.copyWith(trophies: updatedStats.trophies),
    );
  }

  /// When user exits or leaves mid-match: forfeits match & rewards opponent
  Future<void> forfeitCurrentMatch() async {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _opponentEmoteTimer?.cancel();
    _roomSubscription?.cancel();
    _roundTransitioning = false;

    if (state.status == BattleArenaStatus.inDuel) {
      if (state.room != null && !state.opponent.isBot) {
        final isPlayer1 = state.room!.player1.id == state.localPlayer.id;
        await _matchmakingService.forfeitMatch(
          roomId: state.room!.id,
          forfeitedUserId: state.localPlayer.id,
          winnerUserId: state.opponent.id,
          isPlayer1Forfeited: isPlayer1,
        );
      }

      // Deduct trophies for forfeiting (loss recorded)
      await BattleGameService.saveMatchResult(
        isWin: false,
        isDraw: false,
        score: state.localPlayer.currentScore,
        userId: currentUser?.id,
      );
    }

    state = state.copyWith(
      status: BattleArenaStatus.idle,
      localPlayer: state.localPlayer.copyWith(currentScore: 0, currentRound: 0, selectedAnswer: null),
      opponent: state.opponent.copyWith(currentScore: 0, currentRound: 0, selectedAnswer: null),
    );
    await _initLocalStats();
  }

  /// Sends quick emote
  void sendEmote(String emote) {
    state = state.copyWith(activeEmote: emote);

    if (state.room != null && !state.opponent.isBot) {
      _matchmakingService.sendEmote(
        roomId: state.room!.id,
        senderId: state.localPlayer.id,
        emote: emote,
      );
    }

    _emoteDismissTimer?.cancel();
    _emoteDismissTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(activeEmote: null);
    });
  }

  void _showOpponentEmote(String emote) {
    _opponentEmoteTimer?.cancel();
    state = state.copyWith(opponentEmote: emote);
    _opponentEmoteTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) state = state.copyWith(opponentEmote: null);
    });
  }

  void resetLobby() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _opponentEmoteTimer?.cancel();
    _roomSubscription?.cancel();
    _roundTransitioning = false;
    _lastOpponentEmote = null;
    state = state.copyWith(
      status: BattleArenaStatus.idle,
      localPlayer: state.localPlayer.copyWith(
        currentScore: 0,
        currentRound: 0,
        selectedAnswer: null,
        isForfeited: false,
        timeTakenSeconds: 0,
      ),
      opponent: state.opponent.copyWith(
        currentScore: 0,
        currentRound: 0,
        selectedAnswer: null,
        isForfeited: false,
        timeTakenSeconds: 0,
      ),
      isAnswerSubmitted: false,
      isOpponentAnswered: false,
      clearSelectedAnswer: true,
      clearOpponentAnswer: true,
      isOpponentForfeited: false,
      isWinner: false,
      isDraw: false,
      trophyDelta: 0,
    );
    _initLocalStats();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _emoteDismissTimer?.cancel();
    _opponentEmoteTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }
}
