import 'package:cloud_firestore/cloud_firestore.dart';
import 'fight_card_model.dart';

/// Head-to-Head betting model
class HeadToHeadChallenge {
  final String id;
  final String eventId;
  final String eventName;        // "UFC 310" or specific fight
  final String sport;
  final ChallengeType type;
  final String challengerId;
  final String challengerName;
  final String? opponentId;      // Null until matched
  final String? opponentName;
  final int entryFee;            // BR amount
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? completedAt;
  final String? winnerId;
  final Map<String, dynamic>? eventData;  // Fight or game details
  
  // For fight cards
  final List<String>? requiredFightIds;  // Which fights to pick
  final bool isFullCard;
  
  HeadToHeadChallenge({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.sport,
    required this.type,
    required this.challengerId,
    required this.challengerName,
    this.opponentId,
    this.opponentName,
    required this.entryFee,
    required this.status,
    required this.createdAt,
    this.matchedAt,
    this.completedAt,
    this.winnerId,
    this.eventData,
    this.requiredFightIds,
    this.isFullCard = false,
  });
  
  int get totalPot => entryFee * 2;
  int get winnerPayout => totalPot;  // Winner takes all (no house cut)
  
  bool get isOpen => status == ChallengeStatus.open;
  bool get isMatched => status == ChallengeStatus.matched;
  bool get isCompleted => status == ChallengeStatus.completed;
  
  factory HeadToHeadChallenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HeadToHeadChallenge(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      sport: data['sport'] ?? '',
      type: ChallengeType.values.firstWhere(
        (t) => t.toString() == 'ChallengeType.${data['type']}',
        orElse: () => ChallengeType.open,
      ),
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? '',
      opponentId: data['opponentId'],
      opponentName: data['opponentName'],
      entryFee: data['entryFee'] ?? 0,
      status: ChallengeStatus.values.firstWhere(
        (s) => s.toString() == 'ChallengeStatus.${data['status']}',
        orElse: () => ChallengeStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      matchedAt: data['matchedAt'] != null 
          ? (data['matchedAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      winnerId: data['winnerId'],
      eventData: data['eventData'],
      requiredFightIds: data['requiredFightIds'] != null 
          ? List<String>.from(data['requiredFightIds'])
          : null,
      isFullCard: data['isFullCard'] ?? false,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'sport': sport,
      'type': type.toString().split('.').last,
      'challengerId': challengerId,
      'challengerName': challengerName,
      'opponentId': opponentId,
      'opponentName': opponentName,
      'entryFee': entryFee,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'matchedAt': matchedAt != null ? Timestamp.fromDate(matchedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'winnerId': winnerId,
      'eventData': eventData,
      'requiredFightIds': requiredFightIds,
      'isFullCard': isFullCard,
    };
  }
}

/// Type of head-to-head challenge
enum ChallengeType {
  direct,      // Direct challenge to specific user
  open,        // Open challenge for anyone to accept
  auto,        // Auto-matched by system
}

/// Challenge status
enum ChallengeStatus {
  open,        // Waiting for opponent
  matched,     // Opponent found, picks in progress
  locked,      // Picks submitted, event pending
  live,        // Event in progress
  completed,   // Event finished, winner determined
  cancelled,   // Challenge cancelled
  expired,     // No opponent found before event
}

/// Head-to-head picks for a challenge
class H2HPicks {
  final String challengeId;
  final String userId;
  final String userName;
  final Map<String, FightPick>? fightPicks;  // For MMA
  final Map<String, dynamic>? gamePicks;      // For other sports
  final DateTime submittedAt;
  final bool isLocked;
  
  H2HPicks({
    required this.challengeId,
    required this.userId,
    required this.userName,
    this.fightPicks,
    this.gamePicks,
    required this.submittedAt,
    required this.isLocked,
  });
  
  int get totalPicks => (fightPicks?.length ?? 0) + (gamePicks?.length ?? 0);
  
  factory H2HPicks.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse fight picks if present
    Map<String, FightPick>? fightPicks;
    if (data['fightPicks'] != null) {
      fightPicks = {};
      final picks = data['fightPicks'] as Map<String, dynamic>;
      picks.forEach((key, value) {
        // Create FightPick from map data
        fightPicks![key] = FightPick(
          id: value['id'] ?? '',
          fightId: value['fightId'] ?? '',
          userId: data['userId'] ?? '',
          poolId: data['challengeId'] ?? '',
          eventId: value['eventId'] ?? '',
          winnerId: value['winnerId'],
          winnerName: value['winnerName'],
          method: value['method'],
          round: value['round'],
          confidence: value['confidence'] ?? 3,
          pickedAt: value['pickedAt'] != null 
              ? (value['pickedAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      });
    }
    
    return H2HPicks(
      challengeId: data['challengeId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      fightPicks: fightPicks,
      gamePicks: data['gamePicks'],
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      isLocked: data['isLocked'] ?? false,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    // Convert fight picks to Firestore format
    Map<String, dynamic>? picksData;
    if (fightPicks != null) {
      picksData = {};
      fightPicks!.forEach((key, pick) {
        picksData![key] = pick.toFirestore();
      });
    }
    
    return {
      'challengeId': challengeId,
      'userId': userId,
      'userName': userName,
      'fightPicks': picksData,
      'gamePicks': gamePicks,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'isLocked': isLocked,
    };
  }
}

/// Head-to-head result
class H2HResult {
  final String challengeId;
  final String winnerId;
  final String winnerName;
  final String loserId;
  final String loserName;
  final int winnerCorrectPicks;
  final int loserCorrectPicks;
  final int totalPicks;
  final int payout;  // BR won
  final DateTime completedAt;
  
  H2HResult({
    required this.challengeId,
    required this.winnerId,
    required this.winnerName,
    required this.loserId,
    required this.loserName,
    required this.winnerCorrectPicks,
    required this.loserCorrectPicks,
    required this.totalPicks,
    required this.payout,
    required this.completedAt,
  });
  
  String get winnerAccuracy => totalPicks > 0 
      ? '${(winnerCorrectPicks / totalPicks * 100).round()}%'
      : '0%';
      
  String get loserAccuracy => totalPicks > 0 
      ? '${(loserCorrectPicks / totalPicks * 100).round()}%'
      : '0%';
}

/// Quick challenge templates
class H2HTemplates {
  // Single fight challenge
  static HeadToHeadChallenge singleFight({
    required String fightId,
    required String fighterNames,
    required String userId,
    required String userName,
    required int entryFee,
  }) {
    return HeadToHeadChallenge(
      id: '',  // Will be set by Firestore
      eventId: fightId,
      eventName: fighterNames,
      sport: 'MMA',
      type: ChallengeType.open,
      challengerId: userId,
      challengerName: userName,
      entryFee: entryFee,
      status: ChallengeStatus.open,
      createdAt: DateTime.now(),
      requiredFightIds: [fightId],
      isFullCard: false,
    );
  }
  
  // Main card challenge
  static HeadToHeadChallenge mainCard({
    required String eventId,
    required String eventName,
    required List<String> mainCardFightIds,
    required String userId,
    required String userName,
    required int entryFee,
  }) {
    return HeadToHeadChallenge(
      id: '',
      eventId: eventId,
      eventName: '$eventName - Main Card',
      sport: 'MMA',
      type: ChallengeType.open,
      challengerId: userId,
      challengerName: userName,
      entryFee: entryFee,
      status: ChallengeStatus.open,
      createdAt: DateTime.now(),
      requiredFightIds: mainCardFightIds,
      isFullCard: false,
    );
  }
  
  // Full card challenge
  static HeadToHeadChallenge fullCard({
    required String eventId,
    required String eventName,
    required String userId,
    required String userName,
    required int entryFee,
  }) {
    return HeadToHeadChallenge(
      id: '',
      eventId: eventId,
      eventName: '$eventName - Full Card',
      sport: 'MMA',
      type: ChallengeType.open,
      challengerId: userId,
      challengerName: userName,
      entryFee: entryFee,
      status: ChallengeStatus.open,
      createdAt: DateTime.now(),
      isFullCard: true,
    );
  }
}

/// H2H Entry fee tiers
class H2HEntryTiers {
  static const List<int> tiers = [
    10,    // Casual
    25,    // Standard
    50,    // Competitive
    100,   // High Stakes
    250,   // Elite
    500,   // Pro
  ];
  
  static String getTierName(int fee) {
    switch (fee) {
      case 10: return 'Casual';
      case 25: return 'Standard';
      case 50: return 'Competitive';
      case 100: return 'High Stakes';
      case 250: return 'Elite';
      case 500: return 'Pro';
      default: return 'Custom';
    }
  }
}