import 'dart:async';
import 'package:flutter/material.dart';
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
  StreamSubscription<BattleRoom?>? _roomSubscription;

  BattleArenaNotifier({this.currentUser})
      : super(
          BattleArenaState(
            localPlayer: BattlePlayer(
              id: currentUser?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
              name: currentUser?.name ?? 'Player',
              photoUrl: currentUser?.photoUrl ?? '',
              trophies: 100,
            ),
            opponent: const BattlePlayer(
              id: 'opponent',
              name: 'Opponent',
              photoUrl: '',
              trophies: 100,
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
    state = state.copyWith(
      status: BattleArenaStatus.searching,
      searchStatusMessage: 'Initializing radar scanner... 📡',
    );

    try {
      final room = await _matchmakingService.findMatch(
        localPlayer: state.localPlayer,
        onProgress: (msg) {
          state = state.copyWith(searchStatusMessage: msg);
        },
      );

      final isPlayer1 = room.player1.id == state.localPlayer.id;
      final opp = isPlayer1 ? room.player2 : room.player1;

      state = state.copyWith(
        status: BattleArenaStatus.inDuel,
        room: room,
        opponent: opp,
        currentRoundIndex: 0,
        remainingSeconds: 15,
        isAnswerSubmitted: false,
        isOpponentAnswered: false,
        clearSelectedAnswer: true,
        clearOpponentAnswer: true,
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
      opponent: opp,
      currentRoundIndex: 0,
      remainingSeconds: 15,
      isAnswerSubmitted: false,
      isOpponentAnswered: false,
      clearSelectedAnswer: true,
      clearOpponentAnswer: true,
    );

    if (!opp.isBot) {
      _subscribeToRoom(room.id, isPlayer1);
    }

    _startRoundTimer();
  }

  void _subscribeToRoom(String roomId, bool isPlayer1) {
    _roomSubscription?.cancel();
    _roomSubscription = _matchmakingService.streamRoom(roomId).listen((room) {
      if (room == null) return;

      final opp = isPlayer1 ? room.player2 : room.player1;

      // Check if opponent forfeited / surrendered!
      if (opp.isForfeited || (room.status == BattleRoomStatus.completed && room.winnerId == state.localPlayer.id && !state.localPlayer.isForfeited)) {
        _handleOpponentForfeited();
        return;
      }

      // Check opponent answer & score
      if (opp.selectedAnswer != null && opp.selectedAnswer != state.opponentAnswerIndex) {
        state = state.copyWith(
          opponentAnswerIndex: opp.selectedAnswer,
          isOpponentAnswered: true,
          opponent: state.opponent.copyWith(currentScore: opp.currentScore),
        );
      }

      // Check opponent emote
      if (room.activeEmote != null && room.emoteSenderId == opp.id) {
        _showOpponentEmote(room.activeEmote!);
      }
    });
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    state = state.copyWith(remainingSeconds: 15);

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      if (state.status != BattleArenaStatus.inDuel) return;

      final roundScore = BattleGameService.calculateRoundScore(
        isCorrect: decision.isCorrect,
        timeTakenSeconds: decision.reactionSeconds,
      );

      final newBotScore = state.opponent.currentScore + roundScore;

      state = state.copyWith(
        opponentAnswerIndex: decision.selectedAnswer,
        isOpponentAnswered: true,
        opponent: state.opponent.copyWith(currentScore: newBotScore),
      );

      // Bot maybe sends emote
      final botEmote = BattleBotSimulator.maybeGenerateEmote();
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

    final timeTaken = 15 - state.remainingSeconds;
    final isCorrect = answerIndex == question.correctAnswer;
    final roundScore = BattleGameService.calculateRoundScore(
      isCorrect: isCorrect,
      timeTakenSeconds: timeTaken,
    );

    final newLocalScore = state.localPlayer.currentScore + roundScore;

    state = state.copyWith(
      selectedAnswerIndex: answerIndex,
      isAnswerSubmitted: true,
      localPlayer: state.localPlayer.copyWith(
        currentScore: newLocalScore,
        selectedAnswer: answerIndex,
        timeTakenSeconds: timeTaken,
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
        roundIndex: state.currentRoundIndex,
      );
    }

    // If opponent has also answered, proceed
    if (state.isOpponentAnswered || state.opponent.isBot == false) {
      _completeRoundWithDelay();
    }
  }

  void _onRoundTimeExpired() {
    state = state.copyWith(remainingSeconds: 0);
    _completeRoundWithDelay();
  }

  void _completeRoundWithDelay() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();

    Timer(const Duration(milliseconds: 1800), () {
      if (state.status != BattleArenaStatus.inDuel) return;

      final nextRound = state.currentRoundIndex + 1;
      final totalRounds = state.room?.questions.length ?? 5;

      if (nextRound >= totalRounds) {
        _finishDuel();
      } else {
        // Next round
        state = state.copyWith(
          currentRoundIndex: nextRound,
          remainingSeconds: 15,
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
    _roomSubscription?.cancel();

    final localScore = state.localPlayer.currentScore;
    final oppScore = state.opponent.currentScore;

    final isWin = localScore > oppScore;
    final isDraw = localScore == oppScore;
    final trophyDelta = BattleGameService.calculateTrophyDelta(isWin: isWin, isDraw: isDraw);

    final updatedStats = await BattleGameService.saveMatchResult(
      isWin: isWin,
      isDraw: isDraw,
      score: localScore,
    );

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
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roomSubscription?.cancel();

    final updatedStats = await BattleGameService.saveMatchResult(
      isWin: true,
      isDraw: false,
      score: state.localPlayer.currentScore,
    );

    state = state.copyWith(
      status: BattleArenaStatus.completed,
      isOpponentForfeited: true,
      isWinner: true,
      isDraw: false,
      trophyDelta: 25,
      stats: updatedStats,
      localPlayer: state.localPlayer.copyWith(trophies: updatedStats.trophies),
    );
  }

  /// When user exits or leaves mid-match: forfeits match & rewards opponent
  Future<void> forfeitCurrentMatch() async {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roomSubscription?.cancel();

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

      // Deduct 10 trophies for forfeiting
      await BattleGameService.saveMatchResult(
        isWin: false,
        isDraw: false,
        score: state.localPlayer.currentScore,
      );
    }

    state = state.copyWith(status: BattleArenaStatus.idle);
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
    state = state.copyWith(opponentEmote: emote);
    Timer(const Duration(seconds: 3), () {
      state = state.copyWith(opponentEmote: null);
    });
  }

  void resetLobby() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _roomSubscription?.cancel();
    state = state.copyWith(
      status: BattleArenaStatus.idle,
      isAnswerSubmitted: false,
      isOpponentAnswered: false,
      clearSelectedAnswer: true,
      clearOpponentAnswer: true,
      isOpponentForfeited: false,
    );
    _initLocalStats();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _botActionTimer?.cancel();
    _emoteDismissTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }
}
