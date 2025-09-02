import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_model.dart';

/// Tennis Tournament Event Model - Similar to Fight Card
class TennisTournamentModel extends GameModel {
  final String tournamentName;      // "US Open", "Wimbledon", etc.
  final String tournamentType;      // "Grand Slam", "Masters 1000", "ATP 500", etc.
  final String surface;              // "Hard", "Clay", "Grass", "Indoor"
  final String location;             // "New York, USA"
  final DateTime startDate;
  final DateTime endDate;
  final List<TennisMatch> matches;  // All matches in tournament
  final int totalRounds;            // 7 for Grand Slams
  final int totalPlayers;           // 128 for Grand Slams
  final double prizeMoney;          // Total prize pool
  final bool isGrandSlam;
  final bool isMasters;
  final String? defendingChampion;
  
  TennisTournamentModel({
    required String id,
    required DateTime gameTime,
    required this.tournamentName,
    required this.tournamentType,
    required this.surface,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.matches,
    required this.totalRounds,
    required this.totalPlayers,
    required this.prizeMoney,
    required this.isGrandSlam,
    required this.isMasters,
    this.defendingChampion,
    String? venue,
    String? league,
    Map<String, dynamic>? odds,
  }) : super(
    id: id,
    sport: 'Tennis',
    gameTime: gameTime,
    homeTeam: tournamentName,  // Use tournament name as "team"
    awayTeam: tournamentType,  // Use type as secondary identifier
    status: 'scheduled',
    venue: venue,
    league: league ?? 'ATP/WTA',
    odds: odds,
  );
  
  /// Get matches by round
  List<TennisMatch> getMatchesByRound(String round) {
    return matches.where((m) => m.round == round).toList();
  }
  
  /// Get current round matches
  List<TennisMatch> get currentRoundMatches {
    // Find the earliest incomplete round
    final rounds = ['First Round', 'Second Round', 'Third Round', 'Fourth Round', 
                   'Quarter-Finals', 'Semi-Finals', 'Final'];
    
    for (final round in rounds) {
      final roundMatches = getMatchesByRound(round);
      if (roundMatches.any((m) => !m.isCompleted)) {
        return roundMatches;
      }
    }
    
    return [];
  }
  
  /// Get featured matches (top seeds, main court)
  List<TennisMatch> get featuredMatches {
    return matches.where((m) => 
      m.isMainCourt || 
      m.hasTopSeed ||
      m.round == TennisRounds.finals ||
      m.round == TennisRounds.semiFinals
    ).toList();
  }
  
  /// Get today's matches
  List<TennisMatch> get todaysMatches {
    final today = DateTime.now();
    return matches.where((m) => 
      m.scheduledTime.year == today.year &&
      m.scheduledTime.month == today.month &&
      m.scheduledTime.day == today.day
    ).toList();
  }
  
  /// Get upcoming matches
  List<TennisMatch> get upcomingMatches {
    final now = DateTime.now();
    return matches
      .where((m) => m.scheduledTime.isAfter(now) && !m.isCompleted)
      .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }
  
  factory TennisTournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse matches
    List<TennisMatch> matches = [];
    if (data['matches'] != null) {
      matches = (data['matches'] as List)
          .map((m) => TennisMatch.fromMap(m))
          .toList();
    }
    
    return TennisTournamentModel(
      id: doc.id,
      gameTime: (data['gameTime'] as Timestamp).toDate(),
      tournamentName: data['tournamentName'] ?? '',
      tournamentType: data['tournamentType'] ?? '',
      surface: data['surface'] ?? '',
      location: data['location'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      matches: matches,
      totalRounds: data['totalRounds'] ?? 7,
      totalPlayers: data['totalPlayers'] ?? 128,
      prizeMoney: (data['prizeMoney'] ?? 0).toDouble(),
      isGrandSlam: data['isGrandSlam'] ?? false,
      isMasters: data['isMasters'] ?? false,
      defendingChampion: data['defendingChampion'],
      venue: data['venue'],
      league: data['league'],
      odds: data['odds'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'gameTime': Timestamp.fromDate(gameTime),
      'status': status,
      'venue': venue,
      'league': league,
      'odds': odds,
      'tournamentName': tournamentName,
      'tournamentType': tournamentType,
      'surface': surface,
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'matches': matches.map((m) => m.toMap()).toList(),
      'totalRounds': totalRounds,
      'totalPlayers': totalPlayers,
      'prizeMoney': prizeMoney,
      'isGrandSlam': isGrandSlam,
      'isMasters': isMasters,
      'defendingChampion': defendingChampion,
    };
  }
}

/// Individual Tennis Match
class TennisMatch {
  final String id;
  final String matchNumber;         // "MS001" (Men's Singles match 1)
  final String round;               // "First Round", "Quarter-Finals", etc.
  final String court;               // "Centre Court", "Court 1", etc.
  final DateTime scheduledTime;
  final String player1Id;
  final String player1Name;
  final String player1Country;
  final int? player1Seed;
  final int? player1Ranking;
  final String player2Id;
  final String player2Name;
  final String player2Country;
  final int? player2Seed;
  final int? player2Ranking;
  final String status;              // scheduled, live, completed, suspended
  final String? winnerId;
  final String? score;              // "6-4, 7-6(5), 6-2"
  final List<SetScore>? sets;
  final int? matchDuration;         // in minutes
  final bool isMainCourt;
  final bool hasTopSeed;           // Either player is top 8 seed
  final String? h2hRecord;         // "5-3" previous meetings
  
  TennisMatch({
    required this.id,
    required this.matchNumber,
    required this.round,
    required this.court,
    required this.scheduledTime,
    required this.player1Id,
    required this.player1Name,
    required this.player1Country,
    this.player1Seed,
    this.player1Ranking,
    required this.player2Id,
    required this.player2Name,
    required this.player2Country,
    this.player2Seed,
    this.player2Ranking,
    required this.status,
    this.winnerId,
    this.score,
    this.sets,
    this.matchDuration,
    required this.isMainCourt,
    required this.hasTopSeed,
    this.h2hRecord,
  });
  
  bool get isCompleted => status == 'completed';
  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isSuspended => status == 'suspended';
  
  bool get isSeededMatch => player1Seed != null || player2Seed != null;
  bool get isUpset => isCompleted && winnerId != null && _isUpsetResult();
  
  bool _isUpsetResult() {
    if (player1Seed == null && player2Seed == null) return false;
    if (player1Seed != null && player2Seed == null) {
      return winnerId == player2Id;
    }
    if (player1Seed == null && player2Seed != null) {
      return winnerId == player1Id;
    }
    // Both seeded - upset if lower seed wins
    if (player1Seed! < player2Seed!) {
      return winnerId == player2Id;
    } else {
      return winnerId == player1Id;
    }
  }
  
  String get displayName => '$player1Name vs $player2Name';
  
  String get seedDisplay {
    String p1 = player1Seed != null ? '($player1Seed) ' : '';
    String p2 = player2Seed != null ? '($player2Seed) ' : '';
    return '$p1$player1Name vs $p2$player2Name';
  }
  
  factory TennisMatch.fromMap(Map<String, dynamic> map) {
    List<SetScore>? sets;
    if (map['sets'] != null) {
      sets = (map['sets'] as List)
          .map((s) => SetScore.fromMap(s))
          .toList();
    }
    
    return TennisMatch(
      id: map['id'] ?? '',
      matchNumber: map['matchNumber'] ?? '',
      round: map['round'] ?? '',
      court: map['court'] ?? '',
      scheduledTime: map['scheduledTime'] is Timestamp 
          ? (map['scheduledTime'] as Timestamp).toDate()
          : DateTime.parse(map['scheduledTime']),
      player1Id: map['player1Id'] ?? '',
      player1Name: map['player1Name'] ?? '',
      player1Country: map['player1Country'] ?? '',
      player1Seed: map['player1Seed'],
      player1Ranking: map['player1Ranking'],
      player2Id: map['player2Id'] ?? '',
      player2Name: map['player2Name'] ?? '',
      player2Country: map['player2Country'] ?? '',
      player2Seed: map['player2Seed'],
      player2Ranking: map['player2Ranking'],
      status: map['status'] ?? 'scheduled',
      winnerId: map['winnerId'],
      score: map['score'],
      sets: sets,
      matchDuration: map['matchDuration'],
      isMainCourt: map['isMainCourt'] ?? false,
      hasTopSeed: map['hasTopSeed'] ?? false,
      h2hRecord: map['h2hRecord'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchNumber': matchNumber,
      'round': round,
      'court': court,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'player1Id': player1Id,
      'player1Name': player1Name,
      'player1Country': player1Country,
      'player1Seed': player1Seed,
      'player1Ranking': player1Ranking,
      'player2Id': player2Id,
      'player2Name': player2Name,
      'player2Country': player2Country,
      'player2Seed': player2Seed,
      'player2Ranking': player2Ranking,
      'status': status,
      'winnerId': winnerId,
      'score': score,
      'sets': sets?.map((s) => s.toMap()).toList(),
      'matchDuration': matchDuration,
      'isMainCourt': isMainCourt,
      'hasTopSeed': hasTopSeed,
      'h2hRecord': h2hRecord,
    };
  }
  
  TennisMatch copyWith({
    String? winnerId,
    String? score,
    List<SetScore>? sets,
    String? status,
    int? matchDuration,
  }) {
    return TennisMatch(
      id: id,
      matchNumber: matchNumber,
      round: round,
      court: court,
      scheduledTime: scheduledTime,
      player1Id: player1Id,
      player1Name: player1Name,
      player1Country: player1Country,
      player1Seed: player1Seed,
      player1Ranking: player1Ranking,
      player2Id: player2Id,
      player2Name: player2Name,
      player2Country: player2Country,
      player2Seed: player2Seed,
      player2Ranking: player2Ranking,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      score: score ?? this.score,
      sets: sets ?? this.sets,
      matchDuration: matchDuration ?? this.matchDuration,
      isMainCourt: isMainCourt,
      hasTopSeed: hasTopSeed,
      h2hRecord: h2hRecord,
    );
  }
}

/// Set Score
class SetScore {
  final int player1Games;
  final int player2Games;
  final int? tiebreakScore1;
  final int? tiebreakScore2;
  
  SetScore({
    required this.player1Games,
    required this.player2Games,
    this.tiebreakScore1,
    this.tiebreakScore2,
  });
  
  bool get isTiebreak => tiebreakScore1 != null && tiebreakScore2 != null;
  
  String get displayScore {
    if (isTiebreak) {
      return '$player1Games-$player2Games($tiebreakScore1-$tiebreakScore2)';
    }
    return '$player1Games-$player2Games';
  }
  
  factory SetScore.fromMap(Map<String, dynamic> map) {
    return SetScore(
      player1Games: map['player1Games'] ?? 0,
      player2Games: map['player2Games'] ?? 0,
      tiebreakScore1: map['tiebreakScore1'],
      tiebreakScore2: map['tiebreakScore2'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'player1Games': player1Games,
      'player2Games': player2Games,
      'tiebreakScore1': tiebreakScore1,
      'tiebreakScore2': tiebreakScore2,
    };
  }
}

/// Tennis Pick for tournament pools
class TennisPick {
  final String id;
  final String matchId;
  final String userId;
  final String poolId;
  final String tournamentId;
  final String? winnerId;
  final String? winnerName;
  final bool? straightSets;        // Bonus: predict straight sets win
  final int? totalGames;           // Bonus: predict total games
  final bool? firstSetWinner;      // Bonus: who wins first set
  final int confidence;             // 1-5 confidence level
  final DateTime pickedAt;
  
  TennisPick({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.poolId,
    required this.tournamentId,
    this.winnerId,
    this.winnerName,
    this.straightSets,
    this.totalGames,
    this.firstSetWinner,
    required this.confidence,
    required this.pickedAt,
  });
  
  factory TennisPick.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TennisPick(
      id: doc.id,
      matchId: data['matchId'] ?? '',
      userId: data['userId'] ?? '',
      poolId: data['poolId'] ?? '',
      tournamentId: data['tournamentId'] ?? '',
      winnerId: data['winnerId'],
      winnerName: data['winnerName'],
      straightSets: data['straightSets'],
      totalGames: data['totalGames'],
      firstSetWinner: data['firstSetWinner'],
      confidence: data['confidence'] ?? 3,
      pickedAt: (data['pickedAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'userId': userId,
      'poolId': poolId,
      'tournamentId': tournamentId,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'straightSets': straightSets,
      'totalGames': totalGames,
      'firstSetWinner': firstSetWinner,
      'confidence': confidence,
      'pickedAt': Timestamp.fromDate(pickedAt),
    };
  }
  
  TennisPick copyWith({String? id}) {
    return TennisPick(
      id: id ?? this.id,
      matchId: matchId,
      userId: userId,
      poolId: poolId,
      tournamentId: tournamentId,
      winnerId: winnerId,
      winnerName: winnerName,
      straightSets: straightSets,
      totalGames: totalGames,
      firstSetWinner: firstSetWinner,
      confidence: confidence,
      pickedAt: pickedAt,
    );
  }
}

/// Tennis tournament types
class TennisTournamentTypes {
  static const String grandSlam = 'Grand Slam';
  static const String masters1000 = 'Masters 1000';
  static const String atp500 = 'ATP 500';
  static const String atp250 = 'ATP 250';
  static const String wtaFinals = 'WTA Finals';
  static const String atpFinals = 'ATP Finals';
  static const String davisCup = 'Davis Cup';
  static const String fedCup = 'Fed Cup';
  
  static const List<String> all = [
    grandSlam,
    masters1000,
    atp500,
    atp250,
    wtaFinals,
    atpFinals,
    davisCup,
    fedCup,
  ];
  
  static bool isMajor(String type) {
    return type == grandSlam || 
           type == masters1000 || 
           type == atpFinals || 
           type == wtaFinals;
  }
}

/// Surface types
class TennisSurfaces {
  static const String hard = 'Hard';
  static const String clay = 'Clay';
  static const String grass = 'Grass';
  static const String indoor = 'Indoor Hard';
  
  static const List<String> all = [hard, clay, grass, indoor];
}

/// Tennis rounds
class TennisRounds {
  static const String qualifying = 'Qualifying';
  static const String firstRound = 'First Round';
  static const String secondRound = 'Second Round';
  static const String thirdRound = 'Third Round';
  static const String fourthRound = 'Fourth Round';
  static const String quarterFinals = 'Quarter-Finals';
  static const String semiFinals = 'Semi-Finals';
  static const String finals = 'Final';  // Changed from 'final' to 'finals'
  
  static const List<String> grandSlamRounds = [
    firstRound,
    secondRound,
    thirdRound,
    fourthRound,
    quarterFinals,
    semiFinals,
    finals,  // Changed from 'final' to 'finals'
  ];
  
  static const List<String> masters1000Rounds = [
    firstRound,
    secondRound,
    thirdRound,
    quarterFinals,
    semiFinals,
    finals,  // Changed from 'final' to 'finals'
  ];
  
  static int getRoundNumber(String round) {
    switch (round) {
      case firstRound: return 1;
      case secondRound: return 2;
      case thirdRound: return 3;
      case fourthRound: return 4;
      case quarterFinals: return 5;
      case semiFinals: return 6;
      case finals: return 7;  // Changed from 'final' to 'finals'
      default: return 0;
    }
  }
}