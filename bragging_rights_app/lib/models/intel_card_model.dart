import 'package:cloud_firestore/cloud_firestore.dart';
import 'injury_model.dart';

enum IntelCardType {
  gameInjuryReport, // Single game, both teams
  teamWeeklyInjury, // One team, week of games
  starPlayerDeepDive, // Individual player analysis
  leagueDaily, // All games for one day
}

class IntelCard {
  final String id;
  final IntelCardType type;
  final String title;
  final String description;
  final int brCost;
  final String? gameId; // For game-specific Intel
  final String? teamId; // For team-specific Intel
  final String? athleteId; // For player-specific Intel
  final DateTime? expiresAt; // Intel expires after game starts
  final String sport;

  IntelCard({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.brCost,
    this.gameId,
    this.teamId,
    this.athleteId,
    this.expiresAt,
    required this.sport,
  });

  factory IntelCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IntelCard(
      id: doc.id,
      type: IntelCardType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => IntelCardType.gameInjuryReport,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      brCost: data['brCost'] ?? 50,
      gameId: data['gameId'],
      teamId: data['teamId'],
      athleteId: data['athleteId'],
      expiresAt:
          data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
      sport: data['sport'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString(),
      'title': title,
      'description': description,
      'brCost': brCost,
      'sport': sport,
      'gameId': gameId,
      'teamId': teamId,
      'athleteId': athleteId,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive {
    return !isExpired;
  }

  String get timeUntilExpiration {
    if (expiresAt == null) return 'No expiration';
    if (isExpired) return 'Expired';

    final difference = expiresAt!.difference(DateTime.now());

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}

class UserIntelCard {
  final String id;
  final String userId;
  final String cardId;
  final IntelCardType cardType;
  final DateTime purchasedAt;
  final int brSpent;
  final String? gameId;
  final String? teamId;
  final String? athleteId;
  final DateTime? expiresAt;
  final bool viewed;
  final DateTime? viewedAt;

  // Cached injury data (if applicable)
  final GameInjuryReport? injuryData;

  UserIntelCard({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.cardType,
    required this.purchasedAt,
    required this.brSpent,
    this.gameId,
    this.teamId,
    this.athleteId,
    this.expiresAt,
    this.viewed = false,
    this.viewedAt,
    this.injuryData,
  });

  factory UserIntelCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserIntelCard(
      id: doc.id,
      userId: data['userId'] ?? '',
      cardId: data['cardId'] ?? '',
      cardType: IntelCardType.values.firstWhere(
        (e) => e.toString() == data['cardType'],
        orElse: () => IntelCardType.gameInjuryReport,
      ),
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      brSpent: data['brSpent'] ?? 0,
      gameId: data['gameId'],
      teamId: data['teamId'],
      athleteId: data['athleteId'],
      expiresAt:
          data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
      viewed: data['viewed'] ?? false,
      viewedAt: data['viewedAt'] != null
          ? (data['viewedAt'] as Timestamp).toDate()
          : null,
      injuryData: data['injuryData'] != null
          ? GameInjuryReport.fromJson(data['injuryData'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'cardId': cardId,
      'cardType': cardType.toString(),
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'brSpent': brSpent,
      'gameId': gameId,
      'teamId': teamId,
      'athleteId': athleteId,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'viewed': viewed,
      'viewedAt': viewedAt != null ? Timestamp.fromDate(viewedAt!) : null,
      'injuryData': injuryData?.toJson(),
    };
  }

  UserIntelCard copyWith({
    String? id,
    String? userId,
    String? cardId,
    IntelCardType? cardType,
    DateTime? purchasedAt,
    int? brSpent,
    String? gameId,
    String? teamId,
    String? athleteId,
    DateTime? expiresAt,
    bool? viewed,
    DateTime? viewedAt,
    GameInjuryReport? injuryData,
  }) {
    return UserIntelCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cardId: cardId ?? this.cardId,
      cardType: cardType ?? this.cardType,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      brSpent: brSpent ?? this.brSpent,
      gameId: gameId ?? this.gameId,
      teamId: teamId ?? this.teamId,
      athleteId: athleteId ?? this.athleteId,
      expiresAt: expiresAt ?? this.expiresAt,
      viewed: viewed ?? this.viewed,
      viewedAt: viewedAt ?? this.viewedAt,
      injuryData: injuryData ?? this.injuryData,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class IntelCardPurchaseResult {
  final bool success;
  final String message;
  final String? userCardId;
  final UserIntelCard? userCard;

  IntelCardPurchaseResult({
    required this.success,
    required this.message,
    this.userCardId,
    this.userCard,
  });

  factory IntelCardPurchaseResult.success({
    required String message,
    required String userCardId,
    UserIntelCard? userCard,
  }) {
    return IntelCardPurchaseResult(
      success: true,
      message: message,
      userCardId: userCardId,
      userCard: userCard,
    );
  }

  factory IntelCardPurchaseResult.failure(String message) {
    return IntelCardPurchaseResult(
      success: false,
      message: message,
    );
  }
}
