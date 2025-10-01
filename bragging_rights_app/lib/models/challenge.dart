import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeStatus {
  pending,
  accepted,
  completed,
  expired,
}

enum ChallengeType {
  friend,
  group,
  open,
  pool,
}

class Challenge {
  final String id;
  final String challengerId;
  final String challengerName;
  final String? challengerAvatar;

  // Sport & Event Details
  final String sportType;
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final String? poolId;

  // Challenge Type
  final ChallengeType type;
  final List<String> targetFriends;
  final bool isPublic;

  // Challenge Data
  final Map<String, dynamic> picks;

  // Status
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  // Participants
  final List<ChallengeParticipant> participants;

  // Results
  final ChallengeResults? results;

  // Metadata
  final String? shareLink;
  final int shareCount;
  final int viewCount;

  // Wager
  final WagerInfo? wager;

  Challenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    this.challengerAvatar,
    required this.sportType,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    this.poolId,
    required this.type,
    this.targetFriends = const [],
    this.isPublic = false,
    required this.picks,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.participants = const [],
    this.results,
    this.shareLink,
    this.shareCount = 0,
    this.viewCount = 0,
    this.wager,
  });

  Map<String, dynamic> toMap() {
    return {
      'challengerId': challengerId,
      'challengerName': challengerName,
      'challengerAvatar': challengerAvatar,
      'sportType': sportType,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'poolId': poolId,
      'type': type.name,
      'targetFriends': targetFriends,
      'isPublic': isPublic,
      'picks': picks,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'participants': participants.map((p) => p.toMap()).toList(),
      'results': results?.toMap(),
      'shareLink': shareLink,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'wager': wager?.toMap(),
    };
  }

  factory Challenge.fromMap(String id, Map<String, dynamic> map) {
    return Challenge(
      id: id,
      challengerId: map['challengerId'] ?? '',
      challengerName: map['challengerName'] ?? '',
      challengerAvatar: map['challengerAvatar'],
      sportType: map['sportType'] ?? 'mma',
      eventId: map['eventId'] ?? '',
      eventName: map['eventName'] ?? '',
      eventDate: (map['eventDate'] as Timestamp).toDate(),
      poolId: map['poolId'],
      type: ChallengeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ChallengeType.friend,
      ),
      targetFriends: List<String>.from(map['targetFriends'] ?? []),
      isPublic: map['isPublic'] ?? false,
      picks: Map<String, dynamic>.from(map['picks'] ?? {}),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      participants: (map['participants'] as List<dynamic>?)
              ?.map((p) => ChallengeParticipant.fromMap(p))
              .toList() ??
          [],
      results: map['results'] != null
          ? ChallengeResults.fromMap(map['results'])
          : null,
      shareLink: map['shareLink'],
      shareCount: map['shareCount'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      wager: map['wager'] != null ? WagerInfo.fromMap(map['wager']) : null,
    );
  }

  Challenge copyWith({
    String? id,
    String? challengerId,
    String? challengerName,
    String? challengerAvatar,
    String? sportType,
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    String? poolId,
    ChallengeType? type,
    List<String>? targetFriends,
    bool? isPublic,
    Map<String, dynamic>? picks,
    ChallengeStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<ChallengeParticipant>? participants,
    ChallengeResults? results,
    String? shareLink,
    int? shareCount,
    int? viewCount,
    WagerInfo? wager,
  }) {
    return Challenge(
      id: id ?? this.id,
      challengerId: challengerId ?? this.challengerId,
      challengerName: challengerName ?? this.challengerName,
      challengerAvatar: challengerAvatar ?? this.challengerAvatar,
      sportType: sportType ?? this.sportType,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      poolId: poolId ?? this.poolId,
      type: type ?? this.type,
      targetFriends: targetFriends ?? this.targetFriends,
      isPublic: isPublic ?? this.isPublic,
      picks: picks ?? this.picks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      participants: participants ?? this.participants,
      results: results ?? this.results,
      shareLink: shareLink ?? this.shareLink,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      wager: wager ?? this.wager,
    );
  }
}

class ChallengeParticipant {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isFriend;
  final DateTime acceptedAt;
  final DateTime? completedAt;
  final double? score;
  final int? place;

  ChallengeParticipant({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isFriend = false,
    required this.acceptedAt,
    this.completedAt,
    this.score,
    this.place,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'isFriend': isFriend,
      'acceptedAt': Timestamp.fromDate(acceptedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'score': score,
      'place': place,
    };
  }

  factory ChallengeParticipant.fromMap(Map<String, dynamic> map) {
    return ChallengeParticipant(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'],
      isFriend: map['isFriend'] ?? false,
      acceptedAt: (map['acceptedAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      score: map['score']?.toDouble(),
      place: map['place'],
    );
  }

  ChallengeParticipant copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isFriend,
    DateTime? acceptedAt,
    DateTime? completedAt,
    double? score,
    int? place,
  }) {
    return ChallengeParticipant(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isFriend: isFriend ?? this.isFriend,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      score: score ?? this.score,
      place: place ?? this.place,
    );
  }
}

class ChallengeResults {
  final String? winnerId;
  final String? winnerName;
  final Map<String, double> scores;
  final DateTime completedAt;

  ChallengeResults({
    this.winnerId,
    this.winnerName,
    required this.scores,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'winnerId': winnerId,
      'winnerName': winnerName,
      'scores': scores,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  factory ChallengeResults.fromMap(Map<String, dynamic> map) {
    return ChallengeResults(
      winnerId: map['winnerId'],
      winnerName: map['winnerName'],
      scores: Map<String, double>.from(map['scores'] ?? {}),
      completedAt: (map['completedAt'] as Timestamp).toDate(),
    );
  }
}

class ChallengeStats {
  final int sent;
  final int received;
  final int won;
  final int lost;
  final int tied;
  final double winRate;
  final String? favoriteOpponent;
  final Map<String, SportChallengeStats> bySport;

  ChallengeStats({
    this.sent = 0,
    this.received = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.winRate = 0.0,
    this.favoriteOpponent,
    this.bySport = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'sent': sent,
      'received': received,
      'won': won,
      'lost': lost,
      'tied': tied,
      'winRate': winRate,
      'favoriteOpponent': favoriteOpponent,
      'bySport': bySport.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory ChallengeStats.fromMap(Map<String, dynamic> map) {
    return ChallengeStats(
      sent: map['sent'] ?? 0,
      received: map['received'] ?? 0,
      won: map['won'] ?? 0,
      lost: map['lost'] ?? 0,
      tied: map['tied'] ?? 0,
      winRate: (map['winRate'] ?? 0).toDouble(),
      favoriteOpponent: map['favoriteOpponent'],
      bySport: (map['bySport'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              SportChallengeStats.fromMap(value),
            ),
          ) ??
          {},
    );
  }
}

class SportChallengeStats {
  final int won;
  final int lost;
  final int tied;

  SportChallengeStats({
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'won': won,
      'lost': lost,
      'tied': tied,
    };
  }

  factory SportChallengeStats.fromMap(Map<String, dynamic> map) {
    return SportChallengeStats(
      won: map['won'] ?? 0,
      lost: map['lost'] ?? 0,
      tied: map['tied'] ?? 0,
    );
  }
}

enum WagerDistribution {
  winnerTakeAll,
  splitTop3,
  proportionalScore,
}

class WagerInfo {
  final int amount;
  final String currency; // 'BR' or 'VC'
  final String escrowId; // Reference to escrow_transactions doc
  final WagerDistribution distribution;

  WagerInfo({
    required this.amount,
    required this.currency,
    required this.escrowId,
    this.distribution = WagerDistribution.winnerTakeAll,
  });

  factory WagerInfo.fromMap(Map<String, dynamic> map) {
    return WagerInfo(
      amount: map['amount'] ?? 0,
      currency: map['currency'] ?? 'BR',
      escrowId: map['escrowId'] ?? '',
      distribution: WagerDistribution.values.firstWhere(
        (e) => e.name == map['distribution'],
        orElse: () => WagerDistribution.winnerTakeAll,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'currency': currency,
      'escrowId': escrowId,
      'distribution': distribution.name,
    };
  }

  WagerInfo copyWith({
    int? amount,
    String? currency,
    String? escrowId,
    WagerDistribution? distribution,
  }) {
    return WagerInfo(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      escrowId: escrowId ?? this.escrowId,
      distribution: distribution ?? this.distribution,
    );
  }
}