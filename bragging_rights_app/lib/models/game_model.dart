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
  });

  factory GameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameModel(
      id: doc.id,
      sport: data['sport'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      gameTime: (data['gameTime'] as Timestamp).toDate(),
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
    );
  }

  // Check if this is an individual sport
  bool get isIndividualSport => ['MMA', 'UFC', 'BELLATOR', 'PFL', 'BOXING', 'TENNIS', 'GOLF'].contains(sport.toUpperCase());
  
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
      'espnId': id,
    };
  }
  
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
      'espnId': id,
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
      id: map['id'] ?? map['espnId'] ?? '',
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