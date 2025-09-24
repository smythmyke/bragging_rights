import 'package:cloud_firestore/cloud_firestore.dart';

enum EntryStatus {
  active,
  eliminated,
  qualified,
  winner,
  withdrawn
}

class TournamentEntryModel {
  final String id;
  final String tournamentId;
  final String userId;
  final String username;
  final String displayName;
  final Map<String, FightPick> allPicks;
  final int prelimScore;
  final int mainCardScore;
  final int mainEventScore;
  final int totalScore;
  final String currentBracket; // 'prelims', 'mainCard', 'mainEvent', 'eliminated'
  final EntryStatus status;
  final int? finalRank;
  final double? prizeWon;
  final DateTime enteredAt;
  final DateTime? lastUpdated;

  TournamentEntryModel({
    required this.id,
    required this.tournamentId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.allPicks,
    required this.prelimScore,
    required this.mainCardScore,
    required this.mainEventScore,
    required this.totalScore,
    required this.currentBracket,
    required this.status,
    this.finalRank,
    this.prizeWon,
    required this.enteredAt,
    this.lastUpdated,
  });

  factory TournamentEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentEntryModel(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      allPicks: (data['allPicks'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, FightPick.fromMap(value)),
          ) ??
          {},
      prelimScore: data['prelimScore'] ?? 0,
      mainCardScore: data['mainCardScore'] ?? 0,
      mainEventScore: data['mainEventScore'] ?? 0,
      totalScore: data['totalScore'] ?? 0,
      currentBracket: data['currentBracket'] ?? 'prelims',
      status: EntryStatus.values.firstWhere(
        (e) => e.toString() == 'EntryStatus.${data['status']}',
        orElse: () => EntryStatus.active,
      ),
      finalRank: data['finalRank'],
      prizeWon: data['prizeWon']?.toDouble(),
      enteredAt: (data['enteredAt'] as Timestamp).toDate(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'allPicks': allPicks.map((key, value) => MapEntry(key, value.toMap())),
      'prelimScore': prelimScore,
      'mainCardScore': mainCardScore,
      'mainEventScore': mainEventScore,
      'totalScore': totalScore,
      'currentBracket': currentBracket,
      'status': status.toString().split('.').last,
      'finalRank': finalRank,
      'prizeWon': prizeWon,
      'enteredAt': Timestamp.fromDate(enteredAt),
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  bool get isEliminated => status == EntryStatus.eliminated;
  bool get isActive => status == EntryStatus.active || status == EntryStatus.qualified;
  bool get hasWon => prizeWon != null && prizeWon! > 0;

  TournamentEntryModel copyWith({
    Map<String, FightPick>? allPicks,
    int? prelimScore,
    int? mainCardScore,
    int? mainEventScore,
    int? totalScore,
    String? currentBracket,
    EntryStatus? status,
    int? finalRank,
    double? prizeWon,
    DateTime? lastUpdated,
  }) {
    return TournamentEntryModel(
      id: id,
      tournamentId: tournamentId,
      userId: userId,
      username: username,
      displayName: displayName,
      allPicks: allPicks ?? this.allPicks,
      prelimScore: prelimScore ?? this.prelimScore,
      mainCardScore: mainCardScore ?? this.mainCardScore,
      mainEventScore: mainEventScore ?? this.mainEventScore,
      totalScore: totalScore ?? this.totalScore,
      currentBracket: currentBracket ?? this.currentBracket,
      status: status ?? this.status,
      finalRank: finalRank ?? this.finalRank,
      prizeWon: prizeWon ?? this.prizeWon,
      enteredAt: enteredAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class FightPick {
  final String fightId;
  final String fighterPicked;
  final String fighterName;
  final String? methodPrediction; // 'ko', 'submission', 'decision'
  final int? roundPrediction; // 1-5
  final int pointsEarned;
  final bool? isCorrect;
  final bool? isPerfectPick;
  final DateTime pickedAt;
  final double? fighterOdds;

  FightPick({
    required this.fightId,
    required this.fighterPicked,
    required this.fighterName,
    this.methodPrediction,
    this.roundPrediction,
    required this.pointsEarned,
    this.isCorrect,
    this.isPerfectPick,
    required this.pickedAt,
    this.fighterOdds,
  });

  factory FightPick.fromMap(Map<String, dynamic> map) {
    return FightPick(
      fightId: map['fightId'] ?? '',
      fighterPicked: map['fighterPicked'] ?? '',
      fighterName: map['fighterName'] ?? '',
      methodPrediction: map['methodPrediction'],
      roundPrediction: map['roundPrediction'],
      pointsEarned: map['pointsEarned'] ?? 0,
      isCorrect: map['isCorrect'],
      isPerfectPick: map['isPerfectPick'],
      pickedAt: (map['pickedAt'] as Timestamp).toDate(),
      fighterOdds: map['fighterOdds']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fightId': fightId,
      'fighterPicked': fighterPicked,
      'fighterName': fighterName,
      'methodPrediction': methodPrediction,
      'roundPrediction': roundPrediction,
      'pointsEarned': pointsEarned,
      'isCorrect': isCorrect,
      'isPerfectPick': isPerfectPick,
      'pickedAt': Timestamp.fromDate(pickedAt),
      'fighterOdds': fighterOdds,
    };
  }
}

class TournamentScoring {
  static const int BASE_WINNER_POINTS = 10;
  static const int METHOD_BONUS = 5;
  static const int ROUND_BONUS = 5;
  static const int UNDERDOG_BONUS = 10;
  static const int QUICK_FINISH_BONUS = 3;

  static int calculatePoints(FightPick pick, FightResult result) {
    if (pick.fighterPicked != result.winnerId) {
      return 0;
    }

    int points = BASE_WINNER_POINTS;

    if (pick.methodPrediction != null &&
        pick.methodPrediction == result.method) {
      points += METHOD_BONUS;
    }

    if (pick.roundPrediction != null &&
        pick.roundPrediction == result.round) {
      points += ROUND_BONUS;
    }

    if (pick.fighterOdds != null && pick.fighterOdds > 0) {
      points += UNDERDOG_BONUS;
    }

    if (result.round != null && result.round! <= 1) {
      points += QUICK_FINISH_BONUS;
    }

    return points;
  }
}

class FightResult {
  final String fightId;
  final String winnerId;
  final String method; // 'ko', 'submission', 'decision'
  final int? round;
  final String? time;
  final bool isUpset;

  FightResult({
    required this.fightId,
    required this.winnerId,
    required this.method,
    this.round,
    this.time,
    required this.isUpset,
  });
}