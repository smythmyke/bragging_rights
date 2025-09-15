import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_model.dart';

/// Represents a complete UFC/MMA fight card event
class FightCardEventModel extends GameModel {
  final String eventName;        // "UFC 310", "Bellator 300"
  final String promotion;        // UFC, Bellator, PFL, ONE
  final String mainEventTitle;   // "Jones vs Miocic"
  final String? eventPoster;
  final String? location;
  
  // Typed fights list
  List<Fight> get typedFights => _typedFights;
  final List<Fight> _typedFights;
  
  FightCardEventModel({
    required String id,
    required DateTime gameTime,
    required String status,
    required this.eventName,
    required this.promotion,
    required int totalFights,
    required this.mainEventTitle,
    required List<Fight> fights,
    this.eventPoster,
    this.location,
    String? venue,
    String? broadcast,
  }) : _typedFights = fights,
        super(
    id: id,
    sport: 'UFC',
    homeTeam: mainEventTitle.split(' vs ').length > 1 ? mainEventTitle.split(' vs ')[1] : 'Fighter 2',  // For compatibility
    awayTeam: mainEventTitle.split(' vs ')[0] ?? 'Fighter 1',   // For compatibility
    gameTime: gameTime,
    status: status,
    venue: venue,
    broadcast: broadcast,
    league: promotion,
    totalFights: totalFights,
    isCombatSport: true,
    fights: fights.map((f) => f.toMap()).toList(),  // Convert to Map for parent class
  );
  
  @override
  String get gameTitle => '$eventName: $mainEventTitle';
  
  // Categorized access
  List<Fight> get mainCard => _typedFights.where((f) => f.cardPosition == 'main').toList();
  List<Fight> get prelims => _typedFights.where((f) => f.cardPosition == 'prelim').toList();
  List<Fight> get earlyPrelims => _typedFights.where((f) => f.cardPosition == 'early').toList();
  
  // Get specific fight
  Fight? get mainEvent => _typedFights.firstWhere(
    (f) => f.fightOrder == 1,
    orElse: () => _typedFights.first,
  );
  
  Fight? get coMainEvent => _typedFights.where((f) => f.fightOrder == 2).firstOrNull;
  
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
      broadcast: data['broadcast'],
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
      'broadcast': broadcast,
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
  final Map<String, dynamic>? fighter1Odds;
  
  // Fighter 2 (Blue Corner)
  final String fighter2Id;
  final String fighter2Name;
  final String fighter2Record;
  final String fighter2Country;
  final String? fighter2FlagUrl;
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
  final String? method;          // KO/TKO, Submission, Decision
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
    this.fighter1Odds,
    required this.fighter2Id,
    required this.fighter2Name,
    required this.fighter2Record,
    required this.fighter2Country,
    this.fighter2FlagUrl,
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
      fighter1Odds: map['fighter1Odds'],
      fighter2Id: map['fighter2Id'] ?? '',
      fighter2Name: map['fighter2Name']?.toString().isNotEmpty == true ? map['fighter2Name'] : 'TBD',
      fighter2Record: map['fighter2Record'] ?? '0-0',
      fighter2Country: map['fighter2Country'] ?? '',
      fighter2FlagUrl: map['fighter2FlagUrl'],
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
      'fighter1Odds': fighter1Odds,
      'fighter2Id': fighter2Id,
      'fighter2Name': fighter2Name,
      'fighter2Record': fighter2Record,
      'fighter2Country': fighter2Country,
      'fighter2FlagUrl': fighter2FlagUrl,
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
  
  // Confidence for scoring
  final int confidence;          // 1-5 stars
  final DateTime pickedAt;
  final DateTime? modifiedAt;
  
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
    this.confidence = 3,
    required this.pickedAt,
    this.modifiedAt,
  });
  
  bool get isComplete => winnerId != null;
  bool get hasAdvancedPicks => method != null || round != null;
  
  /// Calculate points based on fight result and scoring system
  int calculatePoints(Fight fight, ScoringSystem scoring) {
    if (!fight.isCompleted || winnerId == null) return 0;
    
    int points = 0;
    
    // Winner points
    if (winnerId == fight.winnerId) {
      points += scoring.winnerPoints;
      
      // Method bonus
      if (method != null && method == fight.method) {
        points += scoring.methodPoints;
      }
      
      // Round bonus
      if (round != null && round == fight.winRound) {
        points += scoring.roundPoints;
        
        // Perfect round time bonus
        if (roundTime != null && _matchesRoundTime(fight.winTime)) {
          points += scoring.perfectTimeBonus;
        }
      }
      
      // Apply confidence multiplier
      final multiplier = scoring.confidenceMultipliers[confidence - 1];
      points = (points * multiplier).round();
      
      // Underdog bonus (if odds indicate underdog)
      if (winnerId != null && _isUnderdog(winnerId!, fight)) {
        points = (points * scoring.underdogMultiplier).round();
      }
    }
    
    return points;
  }
  
  bool _matchesRoundTime(String? actualTime) {
    if (actualTime == null || roundTime == null) return false;
    
    final parts = actualTime.split(':');
    if (parts.length != 2) return false;
    
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final totalSeconds = minutes * 60 + seconds;
    
    switch (roundTime) {
      case 'early':
        return totalSeconds <= 150; // First 2:30
      case 'mid':
        return totalSeconds > 150 && totalSeconds <= 240; // 2:31-4:00
      case 'late':
        return totalSeconds > 240; // After 4:00
      default:
        return false;
    }
  }
  
  bool _isUnderdog(String pickId, Fight fight) {
    // Check if picked fighter had positive odds (underdog)
    if (pickId == fight.fighter1Id) {
      final odds = fight.fighter1Odds?['moneyline'];
      return odds != null && odds > 0;
    } else if (pickId == fight.fighter2Id) {
      final odds = fight.fighter2Odds?['moneyline'];
      return odds != null && odds > 0;
    }
    return false;
  }
  
  factory FightPick.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FightPick(
      id: doc.id,
      fightId: data['fightId'] ?? '',
      userId: data['userId'] ?? '',
      poolId: data['poolId'] ?? '',
      eventId: data['eventId'] ?? '',
      winnerId: data['winnerId'],
      winnerName: data['winnerName'],
      method: data['method'],
      round: data['round'],
      roundTime: data['roundTime'],
      goesDistance: data['goesDistance'],
      knockdown: data['knockdown'],
      pointDeduction: data['pointDeduction'],
      confidence: data['confidence'] ?? 3,
      pickedAt: data['pickedAt'] is Timestamp
          ? (data['pickedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(data['pickedAt'] as int),
      modifiedAt: data['modifiedAt'] != null
          ? (data['modifiedAt'] is Timestamp
              ? (data['modifiedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['modifiedAt'] as int))
          : null,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
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
      'confidence': confidence,
      'pickedAt': Timestamp.fromDate(pickedAt),
      'modifiedAt': modifiedAt != null 
          ? Timestamp.fromDate(modifiedAt!)
          : null,
    };
  }
}

/// Scoring system for fight picks
class ScoringSystem {
  final String name;
  final int winnerPoints;
  final int methodPoints;
  final int roundPoints;
  final int perfectTimeBonus;
  final List<double> confidenceMultipliers;
  final double underdogMultiplier;
  final int perfectCardBonus;
  final int perfectMainCardBonus;
  
  const ScoringSystem({
    required this.name,
    required this.winnerPoints,
    required this.methodPoints,
    required this.roundPoints,
    required this.perfectTimeBonus,
    required this.confidenceMultipliers,
    required this.underdogMultiplier,
    required this.perfectCardBonus,
    required this.perfectMainCardBonus,
  });
  
  // Predefined scoring systems
  static const simple = ScoringSystem(
    name: 'Simple',
    winnerPoints: 10,
    methodPoints: 0,
    roundPoints: 0,
    perfectTimeBonus: 0,
    confidenceMultipliers: [1.0, 1.0, 1.0, 1.0, 1.0],
    underdogMultiplier: 1.0,
    perfectCardBonus: 0,
    perfectMainCardBonus: 0,
  );
  
  static const standard = ScoringSystem(
    name: 'Standard',
    winnerPoints: 10,
    methodPoints: 3,
    roundPoints: 2,
    perfectTimeBonus: 2,
    confidenceMultipliers: [0.5, 0.75, 1.0, 1.25, 1.5],
    underdogMultiplier: 1.25,
    perfectCardBonus: 50,
    perfectMainCardBonus: 25,
  );
  
  static const advanced = ScoringSystem(
    name: 'Advanced',
    winnerPoints: 10,
    methodPoints: 5,
    roundPoints: 5,
    perfectTimeBonus: 5,
    confidenceMultipliers: [0.6, 0.8, 1.0, 1.3, 1.6],
    underdogMultiplier: 1.5,
    perfectCardBonus: 100,
    perfectMainCardBonus: 50,
  );
  
  static const tournament = ScoringSystem(
    name: 'Tournament',
    winnerPoints: 10,
    methodPoints: 5,
    roundPoints: 3,
    perfectTimeBonus: 3,
    confidenceMultipliers: [1.0, 1.1, 1.2, 1.3, 1.5],
    underdogMultiplier: 1.5,
    perfectCardBonus: 100,
    perfectMainCardBonus: 40,
  );
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'winnerPoints': winnerPoints,
      'methodPoints': methodPoints,
      'roundPoints': roundPoints,
      'perfectTimeBonus': perfectTimeBonus,
      'confidenceMultipliers': confidenceMultipliers,
      'underdogMultiplier': underdogMultiplier,
      'perfectCardBonus': perfectCardBonus,
      'perfectMainCardBonus': perfectMainCardBonus,
    };
  }
}