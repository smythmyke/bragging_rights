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
    );
  }

  String get gameTitle => '$awayTeam @ $homeTeam';
  String get shortTitle => '${_getTeamAbbr(awayTeam)} @ ${_getTeamAbbr(homeTeam)}';
  
  bool get isLive => status == 'live';
  bool get isFinal => status == 'final';
  bool get isScheduled => status == 'scheduled';

  String _getTeamAbbr(String teamName) {
    // This would ideally come from a team database
    // For now, return first 3 letters
    if (teamName.length <= 3) return teamName.toUpperCase();
    return teamName.substring(0, 3).toUpperCase();
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