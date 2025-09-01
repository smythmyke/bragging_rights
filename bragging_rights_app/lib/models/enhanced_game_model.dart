import 'package:cloud_firestore/cloud_firestore.dart';
import 'participant_model.dart';

/// Enhanced Game Model that properly handles teams vs individual players
class EnhancedGameModel {
  final String id;
  final String sport;
  final Participant homeParticipant;
  final Participant awayParticipant;
  final DateTime gameTime;
  final String status; // scheduled, live, final
  final double? homeScore;
  final double? awayScore;
  final String? period;
  final String? timeRemaining;
  final Map<String, dynamic>? odds;
  final String? venue;
  final String? broadcast;
  final String? league;
  final String? tournament; // For tennis, golf
  final String? round; // For tournament sports
  final Map<String, dynamic>? metadata; // Sport-specific data

  EnhancedGameModel({
    required this.id,
    required this.sport,
    required this.homeParticipant,
    required this.awayParticipant,
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
    this.tournament,
    this.round,
    this.metadata,
  });

  /// Create from legacy GameModel
  factory EnhancedGameModel.fromLegacy(Map<String, dynamic> data) {
    final sport = data['sport'] ?? '';
    final participantType = sport.participantType;
    
    // Create participants based on sport type
    Participant homeParticipant;
    Participant awayParticipant;
    
    if (participantType == ParticipantType.individual) {
      // Individual sport (tennis, boxing, etc.)
      homeParticipant = Participant.individual(
        id: data['homeTeam'] ?? '',
        name: data['homeTeam'] ?? '',
        ranking: data['homeRanking'],
        seed: data['homeSeed'],
        country: data['homeCountry'],
        logo: data['homeTeamLogo'],
        metadata: data['homeMetadata'],
      );
      
      awayParticipant = Participant.individual(
        id: data['awayTeam'] ?? '',
        name: data['awayTeam'] ?? '',
        ranking: data['awayRanking'],
        seed: data['awaySeed'],
        country: data['awayCountry'],
        logo: data['awayTeamLogo'],
        metadata: data['awayMetadata'],
      );
    } else {
      // Team sport
      homeParticipant = Participant.team(
        id: data['homeTeam'] ?? '',
        name: data['homeTeam'] ?? '',
        logo: data['homeTeamLogo'],
        city: data['homeCity'],
        abbreviation: data['homeAbbr'],
        conference: data['homeConference'],
        metadata: data['homeMetadata'],
      );
      
      awayParticipant = Participant.team(
        id: data['awayTeam'] ?? '',
        name: data['awayTeam'] ?? '',
        logo: data['awayTeamLogo'],
        city: data['awayCity'],
        abbreviation: data['awayAbbr'],
        conference: data['awayConference'],
        metadata: data['awayMetadata'],
      );
    }
    
    return EnhancedGameModel(
      id: data['id'] ?? '',
      sport: sport,
      homeParticipant: homeParticipant,
      awayParticipant: awayParticipant,
      gameTime: data['gameTime'] is Timestamp 
        ? (data['gameTime'] as Timestamp).toDate()
        : DateTime.parse(data['gameTime'].toString()),
      status: data['status'] ?? 'scheduled',
      homeScore: data['homeScore']?.toDouble(),
      awayScore: data['awayScore']?.toDouble(),
      period: data['period'],
      timeRemaining: data['timeRemaining'],
      odds: data['odds'],
      venue: data['venue'],
      broadcast: data['broadcast'],
      league: data['league'],
      tournament: data['tournament'],
      round: data['round'],
      metadata: data['metadata'],
    );
  }

  /// Create from Firestore document
  factory EnhancedGameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return EnhancedGameModel.fromLegacy(data);
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'sport': sport,
      'homeTeam': homeParticipant.name, // Backward compatibility
      'awayTeam': awayParticipant.name, // Backward compatibility
      'homeParticipant': homeParticipant.toMap(),
      'awayParticipant': awayParticipant.toMap(),
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
      'tournament': tournament,
      'round': round,
      'metadata': metadata,
      // Legacy fields for backward compatibility
      'homeTeamLogo': homeParticipant.logo,
      'awayTeamLogo': awayParticipant.logo,
    };
  }

  /// Get match participants helper
  MatchParticipants get participants => MatchParticipants(
    home: homeParticipant,
    away: awayParticipant,
    sport: sport,
  );

  /// Get game title based on sport type
  String get gameTitle => participants.getBettingDisplay();

  /// Get short title for compact display
  String get shortTitle => participants.getCompactDisplay();

  /// Get appropriate versus text
  String get versusText => sport.versusText;

  /// Check game status
  bool get isLive => status == 'live' || status == 'in_progress';
  bool get isFinal => status == 'final' || status == 'completed';
  bool get isScheduled => status == 'scheduled' || status == 'upcoming';

  /// Get time until game
  Duration get timeUntilGame => gameTime.difference(DateTime.now());

  /// Get formatted score based on sport
  String get formattedScore {
    if (homeScore != null && awayScore != null) {
      final home = homeScore!;
      final away = awayScore!;
      
      // Tennis uses sets (e.g., "2-1")
      if (sport.toLowerCase() == 'tennis') {
        return '${away.toInt()}-${home.toInt()}';
      }
      // Boxing/MMA might use decimal scores for judges
      if (sport.toLowerCase() == 'boxing' || sport.toLowerCase() == 'mma') {
        if (home != home.toInt() || away != away.toInt()) {
          return '${away.toStringAsFixed(1)}-${home.toStringAsFixed(1)}';
        }
      }
      // Regular sports
      return '${away.toInt()} - ${home.toInt()}';
    }
    return '--';
  }

  /// Get period/round display
  String? get periodDisplay {
    if (period == null) return null;
    
    switch (sport.toLowerCase()) {
      case 'tennis':
        return 'Set $period';
      case 'boxing':
      case 'mma':
        return 'Round $period';
      case 'nba':
      case 'ncaab':
        return _getBasketballPeriod(period!);
      case 'nfl':
      case 'ncaaf':
        return _getFootballPeriod(period!);
      case 'nhl':
        return _getHockeyPeriod(period!);
      case 'mlb':
        return _getBaseballPeriod(period!);
      case 'soccer':
        return _getSoccerPeriod(period!);
      default:
        return period;
    }
  }

  String _getBasketballPeriod(String period) {
    switch (period) {
      case '1': return '1st Quarter';
      case '2': return '2nd Quarter';
      case '3': return '3rd Quarter';
      case '4': return '4th Quarter';
      case 'OT': return 'Overtime';
      case 'HT': return 'Halftime';
      default: return period;
    }
  }

  String _getFootballPeriod(String period) {
    switch (period) {
      case '1': return '1st Quarter';
      case '2': return '2nd Quarter';
      case '3': return '3rd Quarter';
      case '4': return '4th Quarter';
      case 'OT': return 'Overtime';
      case 'HT': return 'Halftime';
      default: return period;
    }
  }

  String _getHockeyPeriod(String period) {
    switch (period) {
      case '1': return '1st Period';
      case '2': return '2nd Period';
      case '3': return '3rd Period';
      case 'OT': return 'Overtime';
      case 'SO': return 'Shootout';
      default: return period;
    }
  }

  String _getBaseballPeriod(String period) {
    if (period.startsWith('T')) {
      return 'Top ${period.substring(1)}';
    } else if (period.startsWith('B')) {
      return 'Bottom ${period.substring(1)}';
    }
    return 'Inning $period';
  }

  String _getSoccerPeriod(String period) {
    switch (period) {
      case '1': return '1st Half';
      case '2': return '2nd Half';
      case 'ET': return 'Extra Time';
      case 'PK': return 'Penalty Kicks';
      case 'HT': return 'Halftime';
      default: return period;
    }
  }

  /// Get venue display name
  String? get venueDisplay {
    if (venue == null) return null;
    
    // For tennis, include surface type if available
    if (sport.toLowerCase() == 'tennis' && metadata?['surface'] != null) {
      return '$venue (${metadata!['surface']})';
    }
    
    return venue;
  }

  /// Get tournament/league display
  String? get competitionDisplay {
    if (tournament != null) {
      // For tournament sports
      if (round != null) {
        return '$tournament - $round';
      }
      return tournament;
    }
    return league;
  }

  /// Check if can show odds
  bool get canShowOdds {
    return odds != null && odds!.isNotEmpty && !isFinal;
  }

  /// Get primary odds display
  String? get primaryOdds {
    if (!canShowOdds) return null;
    
    // For individual sports, show moneyline
    if (homeParticipant.isIndividualSport) {
      final homeOdds = odds!['homeMoneyline'];
      final awayOdds = odds!['awayMoneyline'];
      if (homeOdds != null && awayOdds != null) {
        return '${awayParticipant.shortName} $awayOdds | ${homeParticipant.shortName} $homeOdds';
      }
    }
    
    // For team sports, show spread
    final spread = odds!['spread'];
    if (spread != null) {
      return 'Spread: $spread';
    }
    
    return null;
  }
}