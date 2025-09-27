import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_model.dart';

/// Model for an MMA/Boxing fight card event
class FightCardEventModel extends GameModel {
  final String eventName;      // UFC 294, ONE Fight Night, etc.
  final String promotion;      // UFC, ONE, Bellator, PFL
  final int totalFights;
  final String mainEventTitle; // "Makhachev vs Volkanovski"

  // Store fights as Fight objects internally
  final List<Fight> _typedFights;

  // Optional event details
  final String? eventPoster;
  final String? location;
  @override
  final String? venue;
  final List<String>? broadcastList;

  // Access typed fights
  List<Fight> get typedFights => _typedFights;

  FightCardEventModel({
    required String id,
    required DateTime gameTime,
    required String status,
    required this.eventName,
    required this.promotion,
    required this.totalFights,
    required this.mainEventTitle,
    required List<Fight> fights,
    this.eventPoster,
    this.location,
    String? venue,
    this.broadcastList,
  }) : _typedFights = fights,
        venue = venue,
        super(
    id: id,
    homeTeam: mainEventTitle.split(' vs ').first,
    awayTeam: mainEventTitle.split(' vs ').last,
    gameTime: gameTime,
    status: status,
    sport: 'MMA',
    venue: venue,
    odds: null,
    league: promotion,
    totalFights: totalFights,
    isCombatSport: true,
    fights: fights.map((f) => f.toMap()).toList(),  // Convert to Map for parent class
  );

  @override
  String get gameTitle => '$eventName: $mainEventTitle';

  // Categorized access with proper sorting
  // Main card fights sorted by fightOrder (ascending - main event first)
  List<Fight> get mainCard {
    final mainFights = _typedFights.where((f) => f.cardPosition == 'main').toList();
    mainFights.sort((a, b) => a.fightOrder.compareTo(b.fightOrder));
    return mainFights;
  }

  // Prelim fights sorted by fightOrder
  List<Fight> get prelims {
    final prelimFights = _typedFights.where((f) => f.cardPosition == 'prelim').toList();
    prelimFights.sort((a, b) => a.fightOrder.compareTo(b.fightOrder));
    return prelimFights;
  }

  // Early prelim fights sorted by fightOrder
  List<Fight> get earlyPrelims {
    final earlyFights = _typedFights.where((f) => f.cardPosition == 'early').toList();
    earlyFights.sort((a, b) => a.fightOrder.compareTo(b.fightOrder));
    return earlyFights;
  }

  // Get specific fight
  Fight? get mainEvent => _typedFights.firstWhere(
    (f) => f.fightOrder == 1 || f.isMainEvent,
    orElse: () => _typedFights.first,
  );

  Fight? get coMainEvent => _typedFights.where((f) => f.fightOrder == 2 || f.isCoMain).firstOrNull;

  factory FightCardEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fightsList = (data['fights'] as List?)
        ?.map((f) => Fight.fromMap(f))
        .toList() ?? [];

    // Handle both Timestamp and int types for gameTime
    DateTime gameTime;
    if (data['gameTime'] is Timestamp) {
      gameTime = (data['gameTime'] as Timestamp).toDate();
    } else if (data['gameTime'] is int) {
      gameTime = DateTime.fromMillisecondsSinceEpoch(data['gameTime'] as int);
    } else {
      gameTime = DateTime.now(); // Fallback
    }

    return FightCardEventModel(
      id: doc.id,
      gameTime: gameTime,
      status: data['status'] ?? 'scheduled',
      eventName: data['eventName'] ?? '',
      promotion: data['promotion'] ?? 'UFC',
      totalFights: data['totalFights'] ?? fightsList.length,
      mainEventTitle: data['mainEventTitle'] ?? '',
      fights: fightsList,
      eventPoster: data['eventPoster'],
      location: data['location'],
      venue: data['venue'],
      broadcastList: data['broadcast'] is List ? data['broadcast'] as List<String>? : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sport': 'MMA',
      'gameTime': Timestamp.fromDate(gameTime),
      'status': status,
      'eventName': eventName,
      'promotion': promotion,
      'totalFights': totalFights,
      'mainEventTitle': mainEventTitle,
      'fights': _typedFights.map((f) => f.toMap()).toList(),
      'eventPoster': eventPoster,
      'location': location,
      'venue': venue,
      'broadcast': broadcastList,
      'league': promotion,
    };
  }
}

/// Individual fight within a card
class Fight {
  final String id;
  final String eventId;

  // Fighter 1 (Red Corner)
  final String fighter1Id;
  final String fighter1Name;
  final String fighter1Record;
  final String fighter1Country;
  final String? fighter1FlagUrl;
  final String? fighter1ImageUrl;  // Fighter headshot URL
  final Map<String, dynamic>? fighter1Odds;

  // Fighter 2 (Blue Corner)
  final String fighter2Id;
  final String fighter2Name;
  final String fighter2Record;
  final String fighter2Country;
  final String? fighter2FlagUrl;
  final String? fighter2ImageUrl;  // Fighter headshot URL
  final Map<String, dynamic>? fighter2Odds;

  // Fight details
  final String weightClass;
  final int rounds;               // 3 or 5
  final int fightOrder;          // 1 = main event, 2 = co-main, etc.
  final String cardPosition;     // main, prelim, early
  final bool isTitle;
  final bool isInterim;
  final DateTime? scheduledTime;

  // Result (if completed)
  final String? winnerId;
  final String? method;          // KO, TKO, Submission, Decision
  final int? winRound;
  final String? winTime;

  Fight({
    required this.id,
    required this.eventId,
    required this.fighter1Id,
    required this.fighter1Name,
    required this.fighter1Record,
    required this.fighter1Country,
    this.fighter1FlagUrl,
    this.fighter1ImageUrl,
    this.fighter1Odds,
    required this.fighter2Id,
    required this.fighter2Name,
    required this.fighter2Record,
    required this.fighter2Country,
    this.fighter2FlagUrl,
    this.fighter2ImageUrl,
    this.fighter2Odds,
    required this.weightClass,
    required this.rounds,
    required this.fightOrder,
    required this.cardPosition,
    this.isTitle = false,
    this.isInterim = false,
    this.scheduledTime,
    this.winnerId,
    this.method,
    this.winRound,
    this.winTime,
  });

  // Helper getters
  bool get isMainCard => cardPosition == 'main';
  bool get isPrelim => cardPosition == 'prelim' || cardPosition == 'early';
  bool get isMainEvent => fightOrder == 1;
  bool get isCoMain => fightOrder == 2;
  bool get isCompleted => winnerId != null;
  bool get isChampionship => isTitle || isInterim;

  String get fightTitle => '$fighter1Name vs $fighter2Name';
  String get shortTitle => '${_getLastName(fighter1Name)} vs ${_getLastName(fighter2Name)}';

  String get positionLabel {
    if (isMainEvent) return 'MAIN EVENT';
    if (isCoMain) return 'CO-MAIN EVENT';
    if (isMainCard) return 'MAIN CARD';
    if (cardPosition == 'prelim') return 'PRELIMINARY';
    return 'EARLY PRELIMS';
  }

  String get roundsLabel {
    if (isChampionship) return '$rounds ROUNDS (TITLE)';
    return '$rounds ROUNDS';
  }

  String _getLastName(String fullName) {
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts.last : fullName;
  }

  factory Fight.fromMap(Map<String, dynamic> map) {
    return Fight(
      id: map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      fighter1Id: map['fighter1Id'] ?? '',
      fighter1Name: map['fighter1Name']?.toString().isNotEmpty == true ? map['fighter1Name'] : 'TBD',
      fighter1Record: map['fighter1Record'] ?? '0-0',
      fighter1Country: map['fighter1Country'] ?? '',
      fighter1FlagUrl: map['fighter1FlagUrl'],
      fighter1ImageUrl: map['fighter1ImageUrl'],
      fighter1Odds: map['fighter1Odds'],
      fighter2Id: map['fighter2Id'] ?? '',
      fighter2Name: map['fighter2Name']?.toString().isNotEmpty == true ? map['fighter2Name'] : 'TBD',
      fighter2Record: map['fighter2Record'] ?? '0-0',
      fighter2Country: map['fighter2Country'] ?? '',
      fighter2FlagUrl: map['fighter2FlagUrl'],
      fighter2ImageUrl: map['fighter2ImageUrl'],
      fighter2Odds: map['fighter2Odds'],
      weightClass: map['weightClass'] ?? '',
      rounds: map['rounds'] ?? 3,
      fightOrder: map['fightOrder'] ?? 99,
      cardPosition: map['cardPosition'] ?? 'prelim',
      isTitle: map['isTitle'] ?? false,
      isInterim: map['isInterim'] ?? false,
      scheduledTime: map['scheduledTime'] != null
          ? (map['scheduledTime'] is Timestamp
              ? (map['scheduledTime'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['scheduledTime'] as int))
          : null,
      winnerId: map['winnerId'],
      method: map['method'],
      winRound: map['winRound'],
      winTime: map['winTime'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'fighter1Id': fighter1Id,
      'fighter1Name': fighter1Name,
      'fighter1Record': fighter1Record,
      'fighter1Country': fighter1Country,
      'fighter1FlagUrl': fighter1FlagUrl,
      'fighter1ImageUrl': fighter1ImageUrl,
      'fighter1Odds': fighter1Odds,
      'fighter2Id': fighter2Id,
      'fighter2Name': fighter2Name,
      'fighter2Record': fighter2Record,
      'fighter2Country': fighter2Country,
      'fighter2FlagUrl': fighter2FlagUrl,
      'fighter2ImageUrl': fighter2ImageUrl,
      'fighter2Odds': fighter2Odds,
      'weightClass': weightClass,
      'rounds': rounds,
      'fightOrder': fightOrder,
      'cardPosition': cardPosition,
      'isTitle': isTitle,
      'isInterim': isInterim,
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime!)
          : null,
      'winnerId': winnerId,
      'method': method,
      'winRound': winRound,
      'winTime': winTime,
    };
  }
}

/// User's pick for a fight
class FightPick {
  final String id;
  final String fightId;
  final String userId;
  final String poolId;
  final String eventId;

  // Required pick
  final String? winnerId;
  final String? winnerName;

  // Optional advanced picks
  final String? method;          // KO/TKO, Submission, Decision, Draw
  final int? round;              // 1-5
  final String? roundTime;       // early, mid, late
  final bool? goesDistance;
  final bool? knockdown;
  final bool? pointDeduction;
  final bool? takedowns;        // Over/Under
  final int? confidence;         // Confidence level 1-5

  // Points earned
  final int? basePoints;
  final int? advancedPoints;
  final int? totalPoints;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scoredAt;

  FightPick({
    required this.id,
    required this.fightId,
    required this.userId,
    required this.poolId,
    required this.eventId,
    this.winnerId,
    this.winnerName,
    this.method,
    this.round,
    this.roundTime,
    this.goesDistance,
    this.knockdown,
    this.pointDeduction,
    this.takedowns,
    this.confidence,
    this.basePoints,
    this.advancedPoints,
    this.totalPoints,
    required this.createdAt,
    this.updatedAt,
    this.scoredAt,
  });

  int get calculatedTotal => (basePoints ?? 0) + (advancedPoints ?? 0);

  bool get hasAdvancedPicks => method != null || round != null || goesDistance != null;

  bool get isComplete => winnerId != null;

  factory FightPick.fromMap(Map<String, dynamic> map) {
    return FightPick(
      id: map['id'] ?? '',
      fightId: map['fightId'] ?? '',
      userId: map['userId'] ?? '',
      poolId: map['poolId'] ?? '',
      eventId: map['eventId'] ?? '',
      winnerId: map['winnerId'],
      winnerName: map['winnerName'],
      method: map['method'],
      round: map['round'],
      roundTime: map['roundTime'],
      goesDistance: map['goesDistance'],
      knockdown: map['knockdown'],
      pointDeduction: map['pointDeduction'],
      takedowns: map['takedowns'],
      confidence: map['confidence'],
      basePoints: map['basePoints'],
      advancedPoints: map['advancedPoints'],
      totalPoints: map['totalPoints'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int))
          : null,
      scoredAt: map['scoredAt'] != null
          ? (map['scoredAt'] is Timestamp
              ? (map['scoredAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['scoredAt'] as int))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fightId': fightId,
      'userId': userId,
      'poolId': poolId,
      'eventId': eventId,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'method': method,
      'round': round,
      'roundTime': roundTime,
      'goesDistance': goesDistance,
      'knockdown': knockdown,
      'pointDeduction': pointDeduction,
      'takedowns': takedowns,
      'confidence': confidence,
      'basePoints': basePoints,
      'advancedPoints': advancedPoints,
      'totalPoints': totalPoints,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'scoredAt': scoredAt != null ? Timestamp.fromDate(scoredAt!) : null,
    };
  }

  // Alias for toMap to match expected method name
  Map<String, dynamic> toFirestore() => toMap();
}