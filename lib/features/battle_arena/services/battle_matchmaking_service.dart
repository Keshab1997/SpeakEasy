import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/battle_models.dart';
import 'battle_bot_simulator.dart';
import 'battle_game_service.dart';

/// Thrown when the user cancels matchmaking before (or while) a match starts.
class MatchmakingCancelledException implements Exception {
  const MatchmakingCancelledException();
}

/// A live handle to an in-flight [BattleMatchmakingService.findMatch] call.
/// Calling [cancel] immediately:
///   • flips [isCancelled] so the search aborts at its next checkpoint
///     (no room is entered, no bot fallback launches),
///   • deletes our `battle_queue` entry so no other player can match with us,
///   • cancels the queue snapshot listener and unblocks the wait future.
class MatchmakingToken {
  bool isCancelled = false;
  DocumentReference? queueEntryRef;
  void Function()? _abort;

  void cancel() {
    if (isCancelled) return;
    isCancelled = true;
    _abort?.call();
    final ref = queueEntryRef;
    if (ref != null) {
      ref.delete().catchError((_) {});
    }
  }
}

class BattleMatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _queueCollection = 'battle_queue';
  static const String _roomsCollection = 'battle_rooms';

  /// Starts quick matchmaking with 6-second timeout fallback to Bot.
  /// Pass a [MatchmakingToken]; if it gets cancelled, the search aborts
  /// (queue entry deleted, listener cancelled) and a
  /// [MatchmakingCancelledException] is thrown — no room, no bot fallback.
  Future<BattleRoom> findMatch({
    required BattlePlayer localPlayer,
    required void Function(String statusMessage) onProgress,
    MatchmakingToken? token,
  }) async {
    void checkCancelled() {
      if (token?.isCancelled ?? false) {
        throw const MatchmakingCancelledException();
      }
    }

    final questions = await BattleGameService.loadCuratedQuestions();
    checkCancelled();

    try {
      onProgress('Searching for live opponents... 🔍');

      // 1. Check if there is someone waiting in the queue
      final queueQuery = await _firestore
          .collection(_queueCollection)
          .where('status', isEqualTo: 'waiting')
          .limit(5)
          .get();
      checkCancelled();

      final now = DateTime.now();
      DocumentSnapshot? matchedDoc;

      for (var doc in queueQuery.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;

        // Skip own entry and stale entries older than 15s
        if (userId != localPlayer.id && now.difference(createdAt).inSeconds < 15) {
          matchedDoc = doc;
          break;
        }
      }

      if (matchedDoc != null) {
        checkCancelled(); // don't create a room after the user backed out
        // Matched with a real waiting opponent!
        onProgress('Opponent found! Initializing Arena... ⚔️');
        final oppData = matchedDoc.data() as Map<String, dynamic>;
        final opponent = BattlePlayer(
          id: oppData['userId'],
          name: oppData['userName'] ?? 'Opponent',
          photoUrl: oppData['userPhoto'] ?? '',
          trophies: (oppData['trophies'] as num?)?.toInt() ?? 100,
        );

        // Create Room
        final roomDoc = await _firestore.collection(_roomsCollection).add({
          'player1': opponent.toMap(),
          'player2': localPlayer.toMap(),
          'questions': questions.map((q) => q.toMap()).toList(),
          'status': 'in_progress',
          'currentRoundIndex': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update queue item
        await matchedDoc.reference.update({
          'status': 'matched',
          'roomId': roomDoc.id,
        });

        final room = BattleRoom(
          id: roomDoc.id,
          player1: opponent,
          player2: localPlayer,
          questions: questions,
          status: BattleRoomStatus.inProgress,
          createdAt: DateTime.now(),
        );
        // Rare race: we created the room just as the user hit cancel —
        // forfeit on their behalf so the opponent isn't left stranded.
        // Otherwise return the room normally.
        if (token?.isCancelled ?? false) {
          unawaited(_forfeitRoom(roomDoc.id, localPlayer.id));
          throw const MatchmakingCancelledException();
        }
        checkCancelled();
        return room;
      }

      // 2. No opponent waiting immediately — join queue and wait up to 6 seconds
      onProgress('Scanning online learners... 📡');
      final myQueueEntry = await _firestore.collection(_queueCollection).add({
        'userId': localPlayer.id,
        'userName': localPlayer.name,
        'userPhoto': localPlayer.photoUrl,
        'trophies': localPlayer.trophies,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });
      token?.queueEntryRef = myQueueEntry;
      // Cancelled while the entry was being created.
      if (token?.isCancelled ?? false) {
        unawaited(myQueueEntry.delete().catchError((_) {}));
        throw const MatchmakingCancelledException();
      }

      // Listen for a match for 6 seconds
      final completer = Completer<BattleRoom?>();
      late StreamSubscription subscription;

      subscription = myQueueEntry.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data != null && data['status'] == 'matched' && data['roomId'] != null) {
          final roomId = data['roomId'] as String;
          // A cancelled search must not drag us into a room.
          if (token?.isCancelled ?? false) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          subscription.cancel();
          final roomDoc = await _firestore.collection(_roomsCollection).doc(roomId).get();
          if (roomDoc.exists && !completer.isCompleted) {
            completer.complete(BattleRoom.fromMap(roomDoc.data()!, roomDoc.id));
          }
        }
      });

      // Allow an external cancel to break the wait immediately.
      token?._abort = () {
        subscription.cancel();
        if (!completer.isCompleted) completer.complete(null);
      };

      // 6-second timeout: If no user matched, launch Smart Bot!
      final matchedRoom = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          subscription.cancel();
          myQueueEntry.delete().catchError((_) {});
          return null;
        },
      );

      checkCancelled();

      if (matchedRoom != null) {
        return matchedRoom;
      }
    } on MatchmakingCancelledException {
      rethrow;
    } catch (e, st) {
      if (token?.isCancelled ?? false) {
        throw const MatchmakingCancelledException();
      }
      // Network/Firestore error — fall back to Bot, but log for diagnostics.
      debugPrint('⚠️ Matchmaking failed, falling back to bot: $e');
      debugPrintStack(stackTrace: st);
    }

    checkCancelled();

    // 3. Fallback to Smart Bot match
    onProgress('Matching with an AI Challenger... 🤖');
    final botOpponent = BattleBotSimulator.createBotPlayer(userTrophies: localPlayer.trophies);

    return BattleRoom(
      id: 'local_bot_room_${DateTime.now().millisecondsSinceEpoch}',
      player1: localPlayer,
      player2: botOpponent,
      questions: questions,
      status: BattleRoomStatus.inProgress,
      createdAt: DateTime.now(),
    );
  }

  /// Marks a freshly created room as forfeit by [forfeitedUserId] (used when
  /// matchmaking is cancelled at the exact moment a room was created, so the
  /// opponent gets their win instead of staring at an empty arena).
  Future<void> _forfeitRoom(String roomId, String forfeitedUserId) async {
    try {
      final snap = await _firestore.collection(_roomsCollection).doc(roomId).get();
      if (!snap.exists) return;
      final data = snap.data()!;
      final p1 = data['player1'] as Map<String, dynamic>?;
      final p2 = data['player2'] as Map<String, dynamic>?;
      final p1Forfeit = p1?['id'] == forfeitedUserId;
      final winnerId = p1Forfeit ? (p2?['id'] ?? '') : (p1?['id'] ?? '');
      await _firestore.collection(_roomsCollection).doc(roomId).update({
        'status': 'completed',
        'winnerId': winnerId,
        '${p1Forfeit ? 'player1' : 'player2'}.isForfeited': true,
      });
    } catch (_) {}
  }

  /// Creates a direct room for 1v1 challenge
  Future<BattleRoom> createDirectChallengeRoom({
    required BattlePlayer player1,
    required BattlePlayer player2,
  }) async {
    final questions = await BattleGameService.loadCuratedQuestions();
    final roomDoc = await _firestore.collection(_roomsCollection).add({
      'player1': player1.toMap(),
      'player2': player2.toMap(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'status': 'in_progress',
      'currentRoundIndex': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return BattleRoom(
      id: roomDoc.id,
      player1: player1,
      player2: player2,
      questions: questions,
      status: BattleRoomStatus.inProgress,
      createdAt: DateTime.now(),
    );
  }

  /// Fetches a single room by id (used by the challenge SENDER to join
  /// the room the receiver created on accept).
  Future<BattleRoom?> getRoom(String roomId) async {
    if (roomId.startsWith('local_bot_room_')) return null;
    final doc = await _firestore.collection(_roomsCollection).doc(roomId).get();
    if (!doc.exists || doc.data() == null) return null;
    return BattleRoom.fromMap(doc.data()!, doc.id);
  }

  /// Deletes a challenge doc after it was accepted/rejected (housekeeping).
  Future<void> deleteChallenge(String challengeId) async {
    try {
      await _firestore.collection('battle_challenges').doc(challengeId).delete();
    } catch (_) {}
  }

  /// Listen to real-time room updates
  Stream<BattleRoom?> streamRoom(String roomId) {
    if (roomId.startsWith('local_bot_room_')) {
      return const Stream.empty();
    }
    return _firestore.collection(_roomsCollection).doc(roomId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return BattleRoom.fromMap(doc.data()!, doc.id);
    });
  }

  /// Submit answer and score in Firestore.
  /// Answer is stored per-round (`roundAnswers.{roundIndex}`) so a stale
  /// answer from a previous round can never show up on the new question.
  /// `roundTimes` lets the Cloud Function verify the speed bonus server-side.
  Future<void> submitAnswer({
    required String roomId,
    required String playerId,
    required bool isPlayer1,
    required int selectedAnswer,
    required int newScore,
    required int roundIndex,
    int? timeTakenSeconds,
  }) async {
    if (roomId.startsWith('local_bot_room_')) return;

    try {
      final fieldPrefix = isPlayer1 ? 'player1' : 'player2';
      await _firestore.collection(_roomsCollection).doc(roomId).update({
        // roundAnswers keyed by round index for the opponent to read safely
        '$fieldPrefix.roundAnswers.$roundIndex': selectedAnswer,
        if (timeTakenSeconds != null)
          '$fieldPrefix.roundTimes.$roundIndex': timeTakenSeconds,
        '$fieldPrefix.currentScore': newScore,
        '$fieldPrefix.currentRound': roundIndex,
      });
    } catch (e) {
      debugPrint('⚠️ submitAnswer failed for room $roomId: $e');
    }
  }

  /// Marks the room completed with the winner so both clients and any
  /// future cleanup logic agree on the final state.
  Future<void> completeRoom({
    required String roomId,
    required String? winnerId,
  }) async {
    if (roomId.startsWith('local_bot_room_')) return;
    try {
      await _firestore.collection(_roomsCollection).doc(roomId).update({
        'status': 'completed',
        'winnerId': winnerId,
      });
    } catch (e) {
      debugPrint('⚠️ completeRoom failed for room $roomId: $e');
    }
  }

  /// Send in-match emote
  Future<void> sendEmote({
    required String roomId,
    required String senderId,
    required String emote,
  }) async {
    if (roomId.startsWith('local_bot_room_')) return;
    try {
      await _firestore.collection(_roomsCollection).doc(roomId).update({
        'activeEmote': emote,
        'emoteSenderId': senderId,
      });
    } catch (e) {
      debugPrint('⚠️ sendEmote failed for room $roomId: $e');
    }
  }

  /// Forfeits match: marks exiting player as forfeited and declares opponent the winner
  Future<void> forfeitMatch({
    required String roomId,
    required String forfeitedUserId,
    required String winnerUserId,
    required bool isPlayer1Forfeited,
  }) async {
    if (roomId.startsWith('local_bot_room_')) return;
    try {
      final fieldPrefix = isPlayer1Forfeited ? 'player1' : 'player2';
      await _firestore.collection(_roomsCollection).doc(roomId).update({
        'status': 'completed',
        'winnerId': winnerUserId,
        '$fieldPrefix.isForfeited': true,
      });
    } catch (e) {
      debugPrint('⚠️ forfeitMatch failed for room $roomId: $e');
    }
  }
}
