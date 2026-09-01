import 'package:cloud_firestore/cloud_firestore.dart';

enum BattleRoomStatus {
  waiting,
  inProgress,
  completed,
  abandoned;

  static BattleRoomStatus fromString(String status) {
    switch (status) {
      case 'inProgress':
      case 'in_progress':
        return BattleRoomStatus.inProgress;
      case 'completed':
        return BattleRoomStatus.completed;
      case 'abandoned':
        return BattleRoomStatus.abandoned;
      case 'waiting':
      default:
        return BattleRoomStatus.waiting;
    }
  }

  String toValueString() {
    switch (this) {
      case BattleRoomStatus.inProgress:
        return 'in_progress';
      case BattleRoomStatus.completed:
        return 'completed';
      case BattleRoomStatus.abandoned:
        return 'abandoned';
      case BattleRoomStatus.waiting:
        return 'waiting';
    }
  }
}

class BattlePlayer {
  final String id;
  final String name;
  final String photoUrl;
  final int trophies;
  final int currentScore;
  final int currentRound;
  final bool isReady;
  final bool isBot;
  final bool isForfeited;
  final int? selectedAnswer;
  final int timeTakenSeconds;

  /// Round-index keyed answers, e.g. {'0': 2, '1': 0}.
  /// Used in online matches so a previous round's answer can never be
  /// mistaken for the current round's answer (single `selectedAnswer`
  /// field on Firestore was never cleared between rounds).
  final Map<String, int> roundAnswers;

  const BattlePlayer({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.trophies = 100,
    this.currentScore = 0,
    this.currentRound = 0,
    this.isReady = true,
    this.isBot = false,
    this.isForfeited = false,
    this.selectedAnswer,
    this.timeTakenSeconds = 0,
    this.roundAnswers = const {},
  });

  BattlePlayer copyWith({
    String? id,
    String? name,
    String? photoUrl,
    int? trophies,
    int? currentScore,
    int? currentRound,
    bool? isReady,
    bool? isBot,
    bool? isForfeited,
    int? selectedAnswer,
    int? timeTakenSeconds,
    Map<String, int>? roundAnswers,
    bool clearSelectedAnswer = false,
  }) {
    return BattlePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      trophies: trophies ?? this.trophies,
      currentScore: currentScore ?? this.currentScore,
      currentRound: currentRound ?? this.currentRound,
      isReady: isReady ?? this.isReady,
      isBot: isBot ?? this.isBot,
      isForfeited: isForfeited ?? this.isForfeited,
      selectedAnswer: clearSelectedAnswer ? null : (selectedAnswer ?? this.selectedAnswer),
      timeTakenSeconds: timeTakenSeconds ?? this.timeTakenSeconds,
      roundAnswers: roundAnswers ?? this.roundAnswers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'trophies': trophies,
      'currentScore': currentScore,
      'currentRound': currentRound,
      'isReady': isReady,
      'isBot': isBot,
      'isForfeited': isForfeited,
      'selectedAnswer': selectedAnswer,
      'timeTakenSeconds': timeTakenSeconds,
      'roundAnswers': roundAnswers,
    };
  }

  factory BattlePlayer.fromMap(Map<String, dynamic> map) {
    final rawRoundAnswers = map['roundAnswers'];
    final roundAnswers = <String, int>{};
    if (rawRoundAnswers is Map) {
      rawRoundAnswers.forEach((k, v) {
        if (v is num) roundAnswers['$k'] = v.toInt();
      });
    }
    return BattlePlayer(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Player',
      photoUrl: map['photoUrl'] ?? '',
      trophies: (map['trophies'] as num?)?.toInt() ?? 100,
      currentScore: (map['currentScore'] as num?)?.toInt() ?? 0,
      currentRound: (map['currentRound'] as num?)?.toInt() ?? 0,
      isReady: map['isReady'] ?? true,
      isBot: map['isBot'] ?? false,
      isForfeited: map['isForfeited'] ?? false,
      selectedAnswer: map['selectedAnswer'] as int?,
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt() ?? 0,
      roundAnswers: roundAnswers,
    );
  }
}

class BattleQuestion {
  final String id;
  final String question;
  final String bangla;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final String category;
  final int timeLimit;

  const BattleQuestion({
    required this.id,
    required this.question,
    required this.bangla,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.category,
    this.timeLimit = 15,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'bangla': bangla,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'category': category,
      'timeLimit': timeLimit,
    };
  }

  factory BattleQuestion.fromMap(Map<String, dynamic> map) {
    return BattleQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      bangla: map['bangla'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: (map['correctAnswer'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] ?? '',
      category: map['category'] ?? 'grammar',
      timeLimit: (map['timeLimit'] as num?)?.toInt() ?? 15,
    );
  }
}

class BattleRoom {
  final String id;
  final BattlePlayer player1;
  final BattlePlayer player2;
  final List<BattleQuestion> questions;
  final BattleRoomStatus status;
  final String? winnerId;
  final int currentRoundIndex; // 0 to 4
  final String? activeEmote;
  final String? emoteSenderId;
  final DateTime createdAt;

  const BattleRoom({
    required this.id,
    required this.player1,
    required this.player2,
    required this.questions,
    this.status = BattleRoomStatus.waiting,
    this.winnerId,
    this.currentRoundIndex = 0,
    this.activeEmote,
    this.emoteSenderId,
    required this.createdAt,
  });

  BattleRoom copyWith({
    String? id,
    BattlePlayer? player1,
    BattlePlayer? player2,
    List<BattleQuestion>? questions,
    BattleRoomStatus? status,
    String? winnerId,
    int? currentRoundIndex,
    String? activeEmote,
    String? emoteSenderId,
    DateTime? createdAt,
  }) {
    return BattleRoom(
      id: id ?? this.id,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      questions: questions ?? this.questions,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      activeEmote: activeEmote ?? this.activeEmote,
      emoteSenderId: emoteSenderId ?? this.emoteSenderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player1': player1.toMap(),
      'player2': player2.toMap(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'status': status.toValueString(),
      'winnerId': winnerId,
      'currentRoundIndex': currentRoundIndex,
      'activeEmote': activeEmote,
      'emoteSenderId': emoteSenderId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BattleRoom.fromMap(Map<String, dynamic> map, String docId) {
    return BattleRoom(
      id: docId,
      player1: BattlePlayer.fromMap(Map<String, dynamic>.from(map['player1'] ?? {})),
      player2: BattlePlayer.fromMap(Map<String, dynamic>.from(map['player2'] ?? {})),
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => BattleQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      status: BattleRoomStatus.fromString(map['status'] ?? 'waiting'),
      winnerId: map['winnerId'] as String?,
      currentRoundIndex: (map['currentRoundIndex'] as num?)?.toInt() ?? 0,
      activeEmote: map['activeEmote'] as String?,
      emoteSenderId: map['emoteSenderId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class BattlePresenceUser {
  final String id;
  final String name;
  final String photoUrl;
  final int trophies;
  final bool isOnline;
  final DateTime lastActive;
  final bool isInBattle;
  // Career stats (synced from the server Cloud Function).
  final int wins;
  final int losses;
  final int draws;
  final int totalMatches;
  final int winStreak;

  const BattlePresenceUser({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.trophies = 100,
    this.isOnline = true,
    required this.lastActive,
    this.isInBattle = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalMatches = 0,
    this.winStreak = 0,
  });

  double get winRate => totalMatches == 0 ? 0 : (wins / totalMatches) * 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'trophies': trophies,
      'isOnline': isOnline,
      'lastActive': Timestamp.fromDate(lastActive),
      'isInBattle': isInBattle,
    };
  }

  factory BattlePresenceUser.fromMap(Map<String, dynamic> map, String docId) {
    return BattlePresenceUser(
      id: docId,
      name: map['name'] ?? 'Player',
      photoUrl: map['photoUrl'] ?? '',
      trophies: (map['trophies'] as num?)?.toInt() ?? 100,
      isOnline: map['isOnline'] ?? false,
      lastActive: (map['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isInBattle: map['isInBattle'] ?? false,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      totalMatches: (map['totalMatches'] as num?)?.toInt() ?? 0,
      winStreak: (map['winStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

class BattleChallenge {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String fromUserPhoto;
  final int fromUserTrophies;
  final String toUserId;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final String? roomId;
  final DateTime createdAt;

  const BattleChallenge({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserPhoto = '',
    this.fromUserTrophies = 100,
    required this.toUserId,
    this.status = 'pending',
    this.roomId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPhoto': fromUserPhoto,
      'fromUserTrophies': fromUserTrophies,
      'toUserId': toUserId,
      'status': status,
      'roomId': roomId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BattleChallenge.fromMap(Map<String, dynamic> map, String docId) {
    return BattleChallenge(
      id: docId,
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? 'Player',
      fromUserPhoto: map['fromUserPhoto'] ?? '',
      fromUserTrophies: (map['fromUserTrophies'] as num?)?.toInt() ?? 100,
      toUserId: map['toUserId'] ?? '',
      status: map['status'] ?? 'pending',
      roomId: map['roomId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class BattleStats {
  final int totalMatches;
  final int wins;
  final int losses;
  final int winStreak;
  final int trophies;

  const BattleStats({
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.winStreak = 0,
    this.trophies = 100,
  });

  double get winRate => totalMatches == 0 ? 0 : (wins / totalMatches) * 100;

  String get division {
    if (trophies >= 1500) return 'Grandmaster 💎';
    if (trophies >= 800) return 'Master 🥇';
    if (trophies >= 300) return 'Challenger 🥈';
    return 'Novice 🥉';
  }

  Map<String, dynamic> toMap() {
    return {
      'totalMatches': totalMatches,
      'wins': wins,
      'losses': losses,
      'winStreak': winStreak,
      'trophies': trophies,
    };
  }

  factory BattleStats.fromMap(Map<String, dynamic> map) {
    return BattleStats(
      totalMatches: (map['totalMatches'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      winStreak: (map['winStreak'] as num?)?.toInt() ?? 0,
      trophies: (map['trophies'] as num?)?.toInt() ?? 100,
    );
  }
}
