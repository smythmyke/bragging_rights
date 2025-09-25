import 'package:cloud_firestore/cloud_firestore.dart';

enum FinishMethod {
  decision,    // UD, SD, MD
  koTko,       // KO or TKO
  submission,  // All submissions
  other,       // DQ, NC, etc.
}

enum CardPosition {
  mainEvent,
  coMain,
  mainCard,
  prelims,
  earlyPrelims,
}

class MMAScoringConfig {
  // Base Points
  static const int CORRECT_WINNER = 10;
  static const int CORRECT_METHOD = 5;
  static const int CORRECT_ROUND = 3;

  // Confidence Multipliers
  static const double CONFIDENCE_HIGH = 1.5;
  static const double CONFIDENCE_MEDIUM = 1.0;
  static const double CONFIDENCE_LOW = 0.75;

  // Position Multipliers
  static const Map<CardPosition, double> positionMultipliers = {
    CardPosition.mainEvent: 2.0,
    CardPosition.coMain: 1.5,
    CardPosition.mainCard: 1.2,
    CardPosition.prelims: 1.0,
    CardPosition.earlyPrelims: 0.8,
  };

  // Method mapping from fight result to scoring method
  static FinishMethod getMethodFromResult(String? method) {
    if (method == null || method.isEmpty) return FinishMethod.other;

    final methodLower = method.toLowerCase();

    if (methodLower.contains('ko') || methodLower.contains('tko')) {
      return FinishMethod.koTko;
    } else if (methodLower.contains('submission') || methodLower.contains('sub')) {
      return FinishMethod.submission;
    } else if (methodLower.contains('decision') ||
               methodLower.contains('dec') ||
               methodLower.contains('ud') ||
               methodLower.contains('sd') ||
               methodLower.contains('md')) {
      return FinishMethod.decision;
    } else {
      return FinishMethod.other;
    }
  }

  // Get card position from fight metadata
  static CardPosition getCardPosition({
    required bool isMainEvent,
    required bool isCoMain,
    required String cardType,
  }) {
    if (isMainEvent) return CardPosition.mainEvent;
    if (isCoMain) return CardPosition.coMain;

    switch (cardType.toLowerCase()) {
      case 'main':
      case 'main card':
        return CardPosition.mainCard;
      case 'prelims':
      case 'preliminary':
        return CardPosition.prelims;
      case 'early prelims':
      case 'early':
        return CardPosition.earlyPrelims;
      default:
        return CardPosition.prelims;
    }
  }

  // Calculate total points for a pick
  static int calculatePoints({
    required bool correctWinner,
    required bool correctMethod,
    required bool correctRound,
    required CardPosition position,
    double confidence = 1.0,
  }) {
    if (!correctWinner) return 0; // No points if winner is wrong

    int basePoints = CORRECT_WINNER;

    if (correctMethod) {
      basePoints += CORRECT_METHOD;
    }

    if (correctRound) {
      basePoints += CORRECT_ROUND;
    }

    // Apply position multiplier
    final multiplier = positionMultipliers[position] ?? 1.0;

    // Apply confidence multiplier
    final totalPoints = (basePoints * multiplier * confidence).round();

    return totalPoints;
  }
}

// Scoring result for a single pick
class MMAPickScore {
  final String pickId;
  final String fightId;
  final String userId;
  final String poolId;
  final bool correctWinner;
  final bool correctMethod;
  final bool correctRound;
  final CardPosition position;
  final int basePoints;
  final double multiplier;
  final int totalPoints;
  final DateTime scoredAt;
  final Map<String, dynamic>? metadata;

  MMAPickScore({
    required this.pickId,
    required this.fightId,
    required this.userId,
    required this.poolId,
    required this.correctWinner,
    required this.correctMethod,
    required this.correctRound,
    required this.position,
    required this.basePoints,
    required this.multiplier,
    required this.totalPoints,
    required this.scoredAt,
    this.metadata,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'pickId': pickId,
      'fightId': fightId,
      'userId': userId,
      'poolId': poolId,
      'correctWinner': correctWinner,
      'correctMethod': correctMethod,
      'correctRound': correctRound,
      'position': position.toString().split('.').last,
      'basePoints': basePoints,
      'multiplier': multiplier,
      'totalPoints': totalPoints,
      'scoredAt': Timestamp.fromDate(scoredAt),
      'metadata': metadata,
    };
  }

  factory MMAPickScore.fromFirestore(Map<String, dynamic> data) {
    return MMAPickScore(
      pickId: data['pickId'] ?? '',
      fightId: data['fightId'] ?? '',
      userId: data['userId'] ?? '',
      poolId: data['poolId'] ?? '',
      correctWinner: data['correctWinner'] ?? false,
      correctMethod: data['correctMethod'] ?? false,
      correctRound: data['correctRound'] ?? false,
      position: CardPosition.values.firstWhere(
        (e) => e.toString().split('.').last == data['position'],
        orElse: () => CardPosition.prelims,
      ),
      basePoints: data['basePoints'] ?? 0,
      multiplier: (data['multiplier'] ?? 1.0).toDouble(),
      totalPoints: data['totalPoints'] ?? 0,
      scoredAt: data['scoredAt'] != null
          ? (data['scoredAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: data['metadata'],
    );
  }
}

// Extended pick model for MMA with method and round predictions
class MMAExtendedPick {
  final String id;
  final String userId;
  final String poolId;
  final String eventId;
  final String fightId;
  final String pickedFighterId;
  final FinishMethod? predictedMethod;
  final int? predictedRound;
  final double confidence;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  MMAExtendedPick({
    required this.id,
    required this.userId,
    required this.poolId,
    required this.eventId,
    required this.fightId,
    required this.pickedFighterId,
    this.predictedMethod,
    this.predictedRound,
    this.confidence = 1.0,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'poolId': poolId,
      'eventId': eventId,
      'fightId': fightId,
      'pickedFighterId': pickedFighterId,
      'predictedMethod': predictedMethod?.toString().split('.').last,
      'predictedRound': predictedRound,
      'confidence': confidence,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory MMAExtendedPick.fromFirestore(String id, Map<String, dynamic> data) {
    return MMAExtendedPick(
      id: id,
      userId: data['userId'] ?? '',
      poolId: data['poolId'] ?? '',
      eventId: data['eventId'] ?? '',
      fightId: data['fightId'] ?? '',
      pickedFighterId: data['pickedFighterId'] ?? '',
      predictedMethod: data['predictedMethod'] != null
          ? FinishMethod.values.firstWhere(
              (e) => e.toString().split('.').last == data['predictedMethod'],
              orElse: () => FinishMethod.other,
            )
          : null,
      predictedRound: data['predictedRound'],
      confidence: (data['confidence'] ?? 1.0).toDouble(),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: data['metadata'],
    );
  }
}