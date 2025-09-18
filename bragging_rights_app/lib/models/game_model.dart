import 'package:cloud_firestore/cloud_firestore.dart';

class GameModel {
  final String id;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final DateTime gameTime;
  final String status; // scheduled, live, final
  final int? homeScore;
  final int? awayScore;
  final String? period;
  final String? timeRemaining;
  final Map<String, dynamic>? odds;
  final String? venue;
  final String? broadcast;
  final String? league;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final List<Map<String, dynamic>>? fights; // For combat sports
  final bool isCombatSport;
  final int? totalFights;
  final String? mainEventFighters;
  final String? espnId; // ESPN's game ID for API calls

  GameModel({
    required this.id,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.gameTime,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.period,
    this.timeRemaining,
    this.odds,
    this.venue,
    this.broadcast,
    this.league,
    this.homeTeamLogo,
    this.awayTeamLogo,
    this.fights,
    this.isCombatSport = false,
    this.totalFights,
    this.mainEventFighters,
    this.espnId,
  });

  factory GameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle different gameTime formats
    DateTime gameTime;
    if (data['gameTime'] is Timestamp) {
      gameTime = (data['gameTime'] as Timestamp).toDate();
    } else if (data['gameTime'] is int) {
      // Handle milliseconds since epoch
      gameTime = DateTime.fromMillisecondsSinceEpoch(data['gameTime'] as int);
    } else if (data['gameTime'] is String) {
      // Handle ISO 8601 string
      gameTime = DateTime.parse(data['gameTime'] as String);
    } else {
      // Default to current time if format is unknown
      gameTime = DateTime.now();
    }

    return GameModel(
      id: doc.id,
      sport: data['sport'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      gameTime: gameTime,
      status: data['status'] ?? 'scheduled',
      homeScore: data['homeScore'],
      awayScore: data['awayScore'],
      period: data['period'],
      timeRemaining: data['timeRemaining'],
      odds: data['odds'],
      venue: data['venue'],
      broadcast: data['broadcast'],
      league: data['league'],
      homeTeamLogo: data['homeTeamLogo'],
      awayTeamLogo: data['awayTeamLogo'],
      fights: data['fights'] != null ? List<Map<String, dynamic>>.from(data['fights']) : null,
      isCombatSport: data['isCombatSport'] ?? false,
      totalFights: data['totalFights'],
      mainEventFighters: data['mainEventFighters'],
    );
  }

  // Check if this is an individual sport
  bool get isIndividualSport => isCombatSport || ['UFC', 'BELLATOR', 'PFL', 'BOXING', 'TENNIS', 'GOLF'].contains(sport.toUpperCase());
  
  String get gameTitle => isIndividualSport ? '$awayTeam vs $homeTeam' : '$awayTeam @ $homeTeam';
  String get shortTitle => isIndividualSport 
    ? '${_getNameAbbr(awayTeam)} vs ${_getNameAbbr(homeTeam)}'
    : '${_getTeamAbbr(awayTeam)} @ ${_getTeamAbbr(homeTeam)}';
  
  bool get isLive => status == 'live';
  bool get isFinal => status == 'final';
  bool get isScheduled => status == 'scheduled';

  String _getTeamAbbr(String teamName) {
    // This would ideally come from a team database
    // For now, return first 3 letters
    if (teamName.length <= 3) return teamName.toUpperCase();
    return teamName.substring(0, 3).toUpperCase();
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'gameTime': gameTime.millisecondsSinceEpoch, // Store as milliseconds for caching
      'status': status,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'period': period,
      'timeRemaining': timeRemaining,
      'odds': odds,
      'venue': venue,
      'broadcast': broadcast,
      'league': league,
      'homeTeamLogo': homeTeamLogo,
      'awayTeamLogo': awayTeamLogo,
      'espnId': espnId ?? id, // Store ESPN ID if available
      'fights': fights,
      'isCombatSport': isCombatSport,
      'totalFights': totalFights,
      'mainEventFighters': mainEventFighters,
    };
  }

  // Alias for toMap for consistency
  Map<String, dynamic> toJson() => toMap();
  
  Map<String, dynamic> toFirestore() {
    return {
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'gameTime': Timestamp.fromDate(gameTime),
      'status': status,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'period': period,
      'timeRemaining': timeRemaining,
      'odds': odds,
      'venue': venue,
      'broadcast': broadcast,
      'league': league,
      'homeTeamLogo': homeTeamLogo,
      'awayTeamLogo': awayTeamLogo,
      'lastUpdated': FieldValue.serverTimestamp(),
      'espnId': espnId ?? id, // Store ESPN ID if available
      'fights': fights,
      'isCombatSport': isCombatSport,
      'totalFights': totalFights,
      'mainEventFighters': mainEventFighters,
    };
  }
  
  factory GameModel.fromMap(Map<String, dynamic> map) {
    // Handle gameTime which could be Timestamp or milliseconds
    DateTime gameTime;
    if (map['gameTime'] is Timestamp) {
      gameTime = (map['gameTime'] as Timestamp).toDate();
    } else if (map['gameTime'] is int) {
      gameTime = DateTime.fromMillisecondsSinceEpoch(map['gameTime']);
    } else if (map['gameTime'] is String) {
      gameTime = DateTime.parse(map['gameTime']);
    } else {
      gameTime = DateTime.now(); // Fallback
    }
    
    return GameModel(
      id: map['id'] ?? '',
      sport: map['sport'] ?? '',
      homeTeam: map['homeTeam'] ?? '',
      awayTeam: map['awayTeam'] ?? '',
      gameTime: gameTime,
      status: map['status'] ?? 'scheduled',
      homeScore: map['homeScore'],
      awayScore: map['awayScore'],
      period: map['period'],
      timeRemaining: map['timeRemaining'],
      odds: map['odds'],
      venue: map['venue'],
      broadcast: map['broadcast'],
      league: map['league'],
      homeTeamLogo: map['homeTeamLogo'],
      awayTeamLogo: map['awayTeamLogo'],
      fights: map['fights'] != null ? List<Map<String, dynamic>>.from(map['fights']) : null,
      isCombatSport: map['isCombatSport'] ?? false,
      totalFights: map['totalFights'],
      mainEventFighters: map['mainEventFighters'],
      espnId: map['espnId'] ?? map['externalId'] ?? map['eventId'],
    );
  }
  
  String _getNameAbbr(String name) {
    // For individual sports, use last name if available
    if (name.contains(' ')) {
      final parts = name.split(' ');
      return parts.last.length > 8 ? parts.last.substring(0, 8) : parts.last;
    }
    return name.length > 8 ? name.substring(0, 8) : name;
  }

  Duration get timeUntilGame {
    return gameTime.difference(DateTime.now());
  }

  String get formattedScore {
    if (homeScore != null && awayScore != null) {
      return '$awayScore - $homeScore';
    }
    return '--';
  }
}