import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';
import '../../../models/tennis_tournament_model.dart';

/// ESPN Tennis API Service
/// Provides tennis tournament data, match details, rankings, and intelligence
class EspnTennisService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();

  /// Get upcoming tennis tournaments (60 days like MMA)
  Future<List<TennisTournamentModel>> getUpcomingTournaments({
    int daysAhead = 60,
  }) async {
    try {
      final tournaments = <TennisTournamentModel>[];
      final now = DateTime.now();
      final endDate = now.add(Duration(days: daysAhead));
      
      // Format date range for API
      final startStr = now.toIso8601String().split('T')[0].replaceAll('-', '');
      final endStr = endDate.toIso8601String().split('T')[0].replaceAll('-', '');
      
      // Fetch both ATP and WTA tournaments
      for (final tour in ['atp', 'wta']) {
        final response = await _gateway.request(
          apiName: 'espn',
          endpoint: '/tennis/$tour/scoreboard',
          queryParams: {
            'dates': '$startStr-$endStr',
            'limit': '500',
          },
        );
        
        if (response.data != null && response.data['events'] != null) {
          final events = response.data['events'] as List;
          
          // Group matches by tournament
          final tournamentMap = <String, List<dynamic>>{};
          
          for (final event in events) {
            final tournamentName = event['name'] ?? event['shortName'] ?? 'Unknown Tournament';
            if (!tournamentMap.containsKey(tournamentName)) {
              tournamentMap[tournamentName] = [];
            }
            tournamentMap[tournamentName]!.add(event);
          }
          
          // Create tournament models
          for (final entry in tournamentMap.entries) {
            final tournament = _createTournamentFromEvents(
              tournamentName: entry.key,
              events: entry.value,
              tour: tour.toUpperCase(),
            );
            
            if (tournament != null) {
              tournaments.add(tournament);
            }
          }
        }
      }
      
      // Sort by start date
      tournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
      
      return tournaments;
    } catch (e) {
      debugPrint('Error fetching upcoming tournaments: $e');
      return [];
    }
  }
  
  /// Create tournament model from ESPN events
  TennisTournamentModel? _createTournamentFromEvents({
    required String tournamentName,
    required List<dynamic> events,
    required String tour,
  }) {
    if (events.isEmpty) return null;
    
    try {
      final firstEvent = events.first;
      final tournamentId = '${firstEvent['id']?.toString().split('-').first ?? ''}-$tour';
      
      // Parse tournament details
      final startDate = DateTime.parse(firstEvent['date'] ?? DateTime.now().toIso8601String());
      final endDate = firstEvent['endDate'] != null 
          ? DateTime.parse(firstEvent['endDate'])
          : startDate.add(const Duration(days: 14)); // Estimate for Grand Slams
      
      // Determine tournament type
      final tournamentType = _getTournamentType(tournamentName, firstEvent['major'] == true);
      final isGrandSlam = tournamentType == TennisTournamentTypes.grandSlam;
      final isMasters = tournamentType == TennisTournamentTypes.masters1000;
      
      // Parse matches
      final matches = <LegacyTennisMatch>[];
      for (final event in events) {
        final match = _parseMatch(event, tour);
        if (match != null) {
          matches.add(match);
        }
      }
      
      // Get surface type
      final surface = _getSurfaceType(tournamentName, firstEvent);
      
      // Get location
      final location = _getLocation(firstEvent);
      
      return TennisTournamentModel(
        id: tournamentId,
        gameTime: startDate,
        tournamentName: tournamentName,
        tournamentType: tournamentType,
        surface: surface,
        location: location,
        startDate: startDate,
        endDate: endDate,
        matches: matches,
        totalRounds: isGrandSlam ? 7 : 6,
        totalPlayers: isGrandSlam ? 128 : 64,
        prizeMoney: _getPrizeMoney(tournamentType),
        isGrandSlam: isGrandSlam,
        isMasters: isMasters,
        venue: location,
        league: tour,
        odds: {
          'tour': tour,
          'espnId': firstEvent['id'],
        },
      );
    } catch (e) {
      debugPrint('Error creating tournament model: $e');
      return null;
    }
  }
  
  /// Parse individual match from ESPN event
  TennisMatch? _parseMatch(Map<String, dynamic> event, String tour) {
    try {
      // Check for competition groupings (singles, doubles, etc.)
      final groupings = event['groupings'] ?? [];
      if (groupings.isEmpty) return null;
      
      // Focus on singles matches
      final singlesGrouping = groupings.firstWhere(
        (g) => g['grouping']['slug']?.contains('singles') == true,
        orElse: () => groupings.first,
      );
      
      final competitions = singlesGrouping['competitions'] ?? [];
      if (competitions.isEmpty) return null;
      
      final competition = competitions.first;
      final competitors = competition['competitors'] ?? [];
      
      if (competitors.length != 2) return null;
      
      final player1 = competitors[0];
      final player2 = competitors[1];
      
      // Extract player details
      final player1Athlete = player1['athlete'] ?? {};
      final player2Athlete = player2['athlete'] ?? {};
      
      // Parse seeds and rankings
      final player1Seed = _extractSeed(player1);
      final player2Seed = _extractSeed(player2);
      
      // Determine court
      final venue = competition['venue'] ?? {};
      final court = venue['court'] ?? venue['fullName'] ?? 'Court TBD';
      
      // Parse round
      final round = competition['round']?['displayName'] ?? 'Unknown Round';
      
      // Parse status and score
      final status = competition['status']?['type']?['name'] ?? 'scheduled';
      final matchStatus = _getMatchStatus(status);
      
      // Parse sets if completed
      List<SetScore>? sets;
      String? score;
      String? winnerId;
      
      if (matchStatus == 'completed') {
        winnerId = player1['winner'] == true ? player1Athlete['guid'] : player2Athlete['guid'];
        sets = _parseSets(player1['linescores'], player2['linescores']);
        score = _formatScore(sets);
      }
      
      // Import the TennisMatch from tennis_tournament_model
      return TennisMatch(
        id: competition['id']?.toString() ?? '',
        matchNumber: 'MS${competition['id']}',
        round: round,
        court: court,
        scheduledTime: DateTime.parse(competition['date'] ?? DateTime.now().toIso8601String()),
        player1Id: player1Athlete['guid'] ?? '',
        player1Name: player1Athlete['displayName'] ?? 'Unknown',
        player1Country: _getCountryCode(player1Athlete),
        player1Seed: player1Seed,
        player1Ranking: null, // Would need separate API call
        player2Id: player2Athlete['guid'] ?? '',
        player2Name: player2Athlete['displayName'] ?? 'Unknown',
        player2Country: _getCountryCode(player2Athlete),
        player2Seed: player2Seed,
        player2Ranking: null,
        status: matchStatus,
        winnerId: winnerId,
        score: score,
        sets: sets,
        matchDuration: null,
        isMainCourt: court.contains('Centre') || court.contains('Stadium'),
        hasTopSeed: (player1Seed != null && player1Seed <= 8) || 
                   (player2Seed != null && player2Seed <= 8),
        h2hRecord: null,
      );
    } catch (e) {
      debugPrint('Error parsing match: $e');
      return null;
    }
  }
  
  /// Helper methods
  String _getTournamentType(String name, bool isMajor) {
    if (name.contains('Open') && isMajor) return TennisTournamentTypes.grandSlam;
    if (name.contains('Wimbledon')) return TennisTournamentTypes.grandSlam;
    if (name.contains('Masters')) return TennisTournamentTypes.masters1000;
    if (name.contains('500')) return TennisTournamentTypes.atp500;
    if (name.contains('250')) return TennisTournamentTypes.atp250;
    if (name.contains('Finals')) return TennisTournamentTypes.atpFinals;
    return TennisTournamentTypes.atp250; // Default
  }
  
  String _getSurfaceType(String name, Map<String, dynamic> event) {
    if (name.contains('Wimbledon')) return TennisSurfaces.grass;
    if (name.contains('French') || name.contains('Roland')) return TennisSurfaces.clay;
    if (name.contains('US Open') || name.contains('Australian')) return TennisSurfaces.hard;
    // Could parse from venue or other fields
    return TennisSurfaces.hard; // Default
  }
  
  String _getLocation(Map<String, dynamic> event) {
    final venue = event['venue'] ?? {};
    return venue['fullName'] ?? 'Location TBD';
  }
  
  double _getPrizeMoney(String type) {
    switch (type) {
      case TennisTournamentTypes.grandSlam: return 60000000;
      case TennisTournamentTypes.masters1000: return 8000000;
      case TennisTournamentTypes.atp500: return 3000000;
      case TennisTournamentTypes.atp250: return 1000000;
      default: return 500000;
    }
  }
  
  int? _extractSeed(Map<String, dynamic> competitor) {
    // Try to extract seed from various possible locations
    final seed = competitor['seed'];
    if (seed != null) return int.tryParse(seed.toString());
    
    // Sometimes seed is in athlete data
    final athlete = competitor['athlete'] ?? {};
    final athleteSeed = athlete['seed'];
    if (athleteSeed != null) return int.tryParse(athleteSeed.toString());
    
    return null;
  }
  
  String _getCountryCode(Map<String, dynamic> athlete) {
    final flag = athlete['flag'] ?? {};
    final href = flag['href'] ?? '';
    // Extract country code from flag URL
    final match = RegExp(r'/([a-z]{3})\.png').firstMatch(href);
    return match?.group(1)?.toUpperCase() ?? 'UNK';
  }
  
  String _getMatchStatus(String espnStatus) {
    if (espnStatus.contains('FINAL')) return 'completed';
    if (espnStatus.contains('IN_PROGRESS')) return 'live';
    if (espnStatus.contains('SUSPENDED')) return 'suspended';
    return 'scheduled';
  }
  
  List<SetScore>? _parseSets(List? p1Scores, List? p2Scores) {
    if (p1Scores == null || p2Scores == null) return null;
    if (p1Scores.isEmpty || p2Scores.isEmpty) return null;
    
    final sets = <SetScore>[];
    for (int i = 0; i < p1Scores.length && i < p2Scores.length; i++) {
      sets.add(SetScore(
        player1Games: (p1Scores[i]['value'] ?? 0).toInt(),
        player2Games: (p2Scores[i]['value'] ?? 0).toInt(),
        // Tiebreak scores would need additional parsing
      ));
    }
    
    return sets;
  }
  
  String _formatScore(List<SetScore>? sets) {
    if (sets == null || sets.isEmpty) return '';
    return sets.map((s) => s.displayScore).join(', ');
  }

  /// Get today's tennis matches (keeping for backward compatibility)
  Future<TennisScoreboard?> getScoreboard() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      return await _cache.getCachedData<TennisScoreboard>(
        collection: 'tennis_matches',
        documentId: 'tennis_$today',
        dataType: 'scoreboard',
        sport: 'tennis',
        gameState: {'date': today},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/scoreboard',
            queryParams: {'limit': '50'},
          );
          
          if (response.data != null && response.data['events'] != null) {
            return TennisScoreboard.fromJson(response.data);
          }
          // Return empty scoreboard if no data
          return TennisScoreboard(
            matches: [],
            leagues: [],
            lastUpdated: DateTime.now(),
          );
        },
      );
    } catch (e) {
      debugPrint('Error fetching tennis scoreboard: $e');
      return null;
    }
  }

  /// Get ATP rankings
  Future<Map<String, dynamic>?> getATPRankings() async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_rankings',
        documentId: 'atp_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'atp'},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/atp/rankings',
          );
          return response.data;
        },
      );
    } catch (e) {
      debugPrint('Error fetching ATP rankings: $e');
      return null;
    }
  }

  /// Get WTA rankings
  Future<Map<String, dynamic>?> getWTARankings() async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_rankings',
        documentId: 'wta_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'wta'},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/wta/rankings',
          );
          return response.data;
        },
      );
    } catch (e) {
      debugPrint('Error fetching WTA rankings: $e');
      return null;
    }
  }

  /// Get match details
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_matches',
        documentId: 'match_$matchId',
        dataType: 'match_details',
        sport: 'tennis',
        gameState: {'matchId': matchId},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/match',
            queryParams: {'event': matchId},
          );
          return response.data;
        },
      );
    } catch (e) {
      debugPrint('Error fetching match details: $e');
      return null;
    }
  }

  /// Get tennis news
  Future<List<Map<String, dynamic>>?> getNews() async {
    try {
      final response = await _gateway.request(
        apiName: 'espn',
        endpoint: '/tennis/news',
        queryParams: {'limit': '10'},
      );
      
      if (response.data != null && response.data['articles'] != null) {
        return List<Map<String, dynamic>>.from(response.data['articles']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tennis news: $e');
      return null;
    }
  }

  /// Get match intelligence for betting insights
  Future<Map<String, dynamic>> getMatchIntelligence({
    required String matchId,
    required String player1Name,
    required String player2Name,
  }) async {
    try {
      final intelligence = <String, dynamic>{
        'matchId': matchId,
        'player1': player1Name,
        'player2': player2Name,
        'insights': [],
        'data': {},
      };

      // Fetch match details
      final matchDetails = await getMatchDetails(matchId);
      if (matchDetails != null) {
        intelligence['data']['matchDetails'] = matchDetails;
        
        // Extract tournament info
        final tournament = matchDetails['tournament']?['name'] ?? 'Unknown';
        final surface = _determineSurface(tournament);
        
        intelligence['insights'].add({
          'type': 'tournament',
          'text': 'Playing at $tournament on $surface court',
          'impact': 'medium',
        });
      }

      // Fetch rankings for comparison
      final [atpRankings, wtaRankings] = await Future.wait([
        getATPRankings(),
        getWTARankings(),
      ]);

      // Find player rankings
      final p1Ranking = _findPlayerRanking(player1Name, atpRankings, wtaRankings);
      final p2Ranking = _findPlayerRanking(player2Name, atpRankings, wtaRankings);

      if (p1Ranking != null && p2Ranking != null) {
        final rankDiff = (p1Ranking - p2Ranking).abs();
        String rankingInsight;
        
        if (rankDiff <= 5) {
          rankingInsight = 'Evenly matched players (rankings within 5 spots)';
        } else if (p1Ranking < p2Ranking) {
          rankingInsight = '$player1Name ranked #$p1Ranking, significantly higher than $player2Name (#$p2Ranking)';
        } else {
          rankingInsight = '$player2Name ranked #$p2Ranking, significantly higher than $player1Name (#$p1Ranking)';
        }
        
        intelligence['insights'].add({
          'type': 'ranking',
          'text': rankingInsight,
          'impact': rankDiff > 20 ? 'high' : 'medium',
        });
      }

      // Add mock H2H data (would need separate source in production)
      intelligence['insights'].add({
        'type': 'h2h',
        'text': _generateMockH2H(player1Name, player2Name),
        'impact': 'medium',
      });

      // Add surface preference insight
      intelligence['insights'].add({
        'type': 'surface',
        'text': _generateSurfaceInsight(player1Name, player2Name, _determineSurface('current')),
        'impact': 'high',
      });

      // Recent form analysis
      intelligence['insights'].add({
        'type': 'form',
        'text': _generateFormInsight(player1Name, player2Name),
        'impact': 'medium',
      });

      return intelligence;
    } catch (e) {
      debugPrint('Error generating match intelligence: $e');
      return {
        'error': 'Failed to generate intelligence',
        'matchId': matchId,
      };
    }
  }

  // Helper methods
  String _determineSurface(String tournament) {
    final lowerTournament = tournament.toLowerCase();
    
    if (lowerTournament.contains('wimbledon')) return 'grass';
    if (lowerTournament.contains('french') || lowerTournament.contains('roland')) return 'clay';
    if (lowerTournament.contains('us open') || lowerTournament.contains('australian')) return 'hard';
    if (lowerTournament.contains('indoor')) return 'indoor hard';
    
    // Default to hard court for most tournaments
    return 'hard';
  }

  int? _findPlayerRanking(String playerName, Map<String, dynamic>? atpRankings, Map<String, dynamic>? wtaRankings) {
    // Check ATP rankings
    if (atpRankings != null) {
      final competitors = atpRankings['rankings']?['competitors'] ?? [];
      for (var i = 0; i < competitors.length; i++) {
        final athlete = competitors[i]['athlete'];
        if (athlete != null && athlete['displayName'] == playerName) {
          return competitors[i]['rank'] ?? (i + 1);
        }
      }
    }
    
    // Check WTA rankings
    if (wtaRankings != null) {
      final competitors = wtaRankings['rankings']?['competitors'] ?? [];
      for (var i = 0; i < competitors.length; i++) {
        final athlete = competitors[i]['athlete'];
        if (athlete != null && athlete['displayName'] == playerName) {
          return competitors[i]['rank'] ?? (i + 1);
        }
      }
    }
    
    return null;
  }

  String _generateMockH2H(String player1, String player2) {
    // In production, would fetch real H2H data
    final hash = (player1.hashCode + player2.hashCode).abs();
    final p1Wins = 3 + (hash % 5);
    final p2Wins = 2 + (hash % 4);
    
    if (p1Wins > p2Wins) {
      return '$player1 leads head-to-head $p1Wins-$p2Wins';
    } else if (p2Wins > p1Wins) {
      return '$player2 leads head-to-head $p2Wins-$p1Wins';
    }
    return 'Even head-to-head record at $p1Wins-$p2Wins';
  }

  String _generateSurfaceInsight(String player1, String player2, String surface) {
    // Mock surface performance data
    final p1Hash = player1.hashCode.abs();
    final p2Hash = player2.hashCode.abs();
    
    final p1SurfaceStrength = (p1Hash % 100) / 100;
    final p2SurfaceStrength = (p2Hash % 100) / 100;
    
    if (p1SurfaceStrength > p2SurfaceStrength + 0.2) {
      return '$player1 excels on $surface courts';
    } else if (p2SurfaceStrength > p1SurfaceStrength + 0.2) {
      return '$player2 has advantage on $surface surface';
    }
    return 'Both players perform similarly on $surface courts';
  }

  String _generateFormInsight(String player1, String player2) {
    // Mock recent form data
    final now = DateTime.now();
    final seed = now.day + now.month;
    
    final p1Form = 2 + (seed % 4); // Wins in last 5
    final p2Form = 1 + ((seed + 1) % 4);
    
    if (p1Form > p2Form) {
      return '$player1 in better form ($p1Form wins in last 5 matches)';
    } else if (p2Form > p1Form) {
      return '$player2 showing strong form ($p2Form recent victories)';
    }
    return 'Both players showing similar recent form';
  }
}

/// Tennis scoreboard model
class TennisScoreboard {
  final List<LegacyTennisMatch> matches;
  final List<Map<String, dynamic>> leagues;
  final DateTime lastUpdated;

  TennisScoreboard({
    required this.matches,
    required this.leagues,
    required this.lastUpdated,
  });

  factory TennisScoreboard.fromJson(Map<String, dynamic> json) {
    final events = json['events'] ?? [];
    final matches = <LegacyTennisMatch>[];
    
    for (var event in events) {
      try {
        matches.add(LegacyTennisMatch.fromJson(event));
      } catch (e) {
        debugPrint('Error parsing tennis match: $e');
      }
    }

    return TennisScoreboard(
      matches: matches,
      leagues: List<Map<String, dynamic>>.from(json['leagues'] ?? []),
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matches': matches.map((m) => m.toMap()).toList(),
      'leagues': leagues,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Tennis match model
class TennisMatch {
  final String id;
  final String name;
  final String? tournament;
  final String status;
  final DateTime? date;
  final Map<String, dynamic> player1;
  final Map<String, dynamic> player2;
  final Map<String, dynamic>? score;
  final Map<String, dynamic>? odds;

  LegacyTennisMatch({
    required this.id,
    required this.name,
    this.tournament,
    required this.status,
    this.date,
    required this.player1,
    required this.player2,
    this.score,
    this.odds,
  });

  factory LegacyTennisMatch.fromJson(Map<String, dynamic> json) {
    final competition = json['competitions']?[0] ?? {};
    final competitors = competition['competitors'] ?? [];
    
    // Extract player info
    Map<String, dynamic> p1 = {};
    Map<String, dynamic> p2 = {};
    
    if (competitors.length >= 2) {
      final comp1 = competitors[0];
      final comp2 = competitors[1];
      
      p1 = {
        'id': comp1['id'],
        'name': comp1['athlete']?['displayName'] ?? 'Unknown',
        'country': comp1['athlete']?['flag']?['alt'] ?? '',
        'seed': comp1['curatedRank']?['current'],
        'score': comp1['score'],
        'winner': comp1['winner'] ?? false,
      };
      
      p2 = {
        'id': comp2['id'],
        'name': comp2['athlete']?['displayName'] ?? 'Unknown',
        'country': comp2['athlete']?['flag']?['alt'] ?? '',
        'seed': comp2['curatedRank']?['current'],
        'score': comp2['score'],
        'winner': comp2['winner'] ?? false,
      };
    }

    // Parse date
    DateTime? matchDate;
    if (json['date'] != null) {
      try {
        matchDate = DateTime.parse(json['date']);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    // Extract score
    Map<String, dynamic>? scoreData;
    if (competition['score'] != null) {
      scoreData = {
        'displayScore': competition['score'],
        'sets': competition['sets'] ?? [],
      };
    }

    return LegacyTennisMatch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      tournament: json['season']?['name'],
      status: competition['status']?['type']?['description'] ?? 'Scheduled',
      date: matchDate,
      player1: p1,
      player2: p2,
      score: scoreData,
      odds: competition['odds'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tournament': tournament,
      'status': status,
      'date': date?.toIso8601String(),
      'player1': player1,
      'player2': player2,
      'score': score,
      'odds': odds,
    };
  }

  bool get isLive => status.toLowerCase().contains('in progress') || 
                     status.toLowerCase().contains('live');
  
  bool get isCompleted => status.toLowerCase().contains('final') || 
                          status.toLowerCase().contains('completed');
  
  bool get isScheduled => status.toLowerCase().contains('scheduled') || 
                          status.toLowerCase().contains('upcoming');
}