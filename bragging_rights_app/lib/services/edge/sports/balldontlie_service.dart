import 'package:flutter/foundation.dart';
import '../../cloud_api_service.dart';
import '../event_matcher.dart';
import 'package:intl/intl.dart';

/// Balldontlie NBA Service
/// Now uses Cloud Functions proxy for secure API access
/// Free tier provides: Teams, Players, Games (5 req/min limit)
class BalldontlieService {
  final CloudApiService _cloudApi = CloudApiService();
  final EventMatcher _matcher = EventMatcher();
  
  // No more hardcoded API key!
  
  // Balldontlie endpoints
  static const String _gamesEndpoint = '/games';
  static const String _teamsEndpoint = '/teams';
  static const String _playersEndpoint = '/players';
  static const String _statsEndpoint = '/stats';
  static const String _seasonAveragesEndpoint = '/season_averages';
  static const String _playerEndpoint = '/players/{id}';
  static const String _teamEndpoint = '/teams/{id}';
  static const String _gameEndpoint = '/games/{id}';

  /// Get games for today
  Future<BalldontlieGamesResponse?> getTodaysGames() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      debugPrint('🏀 Fetching NBA games via Cloud Functions for $today...');
      
      // Use Cloud Functions proxy instead of direct API call
      final data = await _cloudApi.getNBAGames(
        season: DateTime.now().year,
        perPage: 100,
      );

      if (data != null) {
        debugPrint('✅ NBA games received from Cloud Functions');
        return BalldontlieGamesResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('❌ Error fetching NBA games: $e');
    }
    return null;
  }

  /// Get games for a date range
  Future<BalldontlieGamesResponse?> getGames({
    DateTime? startDate,
    DateTime? endDate,
    int? teamId,
    int perPage = 25,
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };

      if (startDate != null) {
        params['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        params['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }
      if (teamId != null) {
        params['team_ids[]'] = teamId.toString();
      }

      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _gamesEndpoint,
        queryParams: params,
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontlieGamesResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching games: $e');
    }
    return null;
  }

  /// Get specific game details
  Future<BalldontlieGame?> getGame(int gameId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: '/games/$gameId',
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontlieGame.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching game: $e');
    }
    return null;
  }

  /// Get all NBA teams
  Future<BalldontlieTeamsResponse?> getTeams() async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _teamsEndpoint,
        queryParams: {'per_page': '30'},
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontlieTeamsResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching teams: $e');
    }
    return null;
  }

  /// Get specific team details
  Future<BalldontlieTeam?> getTeam(int teamId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: '/teams/$teamId',
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontlieTeam.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching team: $e');
    }
    return null;
  }

  /// Search for players
  Future<BalldontliePlayersResponse?> searchPlayers({
    String? search,
    int perPage = 25,
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }

      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _playersEndpoint,
        queryParams: params,
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontliePlayersResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error searching players: $e');
    }
    return null;
  }

  /// Get player details
  Future<BalldontliePlayer?> getPlayer(int playerId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: '/players/$playerId',
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontliePlayer.fromJson(response.data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching player: $e');
    }
    return null;
  }

  /// Get game statistics
  Future<BalldontlieStatsResponse?> getGameStats({
    required int gameId,
    int perPage = 100,
    int page = 1,
  }) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _statsEndpoint,
        queryParams: {
          'game_ids[]': gameId.toString(),
          'per_page': perPage.toString(),
          'page': page.toString(),
        },
        headers: _getHeaders(),
      );

      if (response.data != null) {
        return BalldontlieStatsResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching game stats: $e');
    }
    return null;
  }

  /// Get player season averages
  Future<List<BalldontlieSeasonAverage>?> getSeasonAverages({
    required List<int> playerIds,
    String season = '2024',
  }) async {
    try {
      final playerParams = playerIds.map((id) => 'player_ids[]=$id').join('&');
      
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: '$_seasonAveragesEndpoint?season=$season&$playerParams',
        headers: _getHeaders(),
      );

      if (response.data != null) {
        final data = response.data['data'] as List;
        return data.map((item) => BalldontlieSeasonAverage.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching season averages: $e');
    }
    return null;
  }

  /// Get Edge intelligence for a game
  Future<Map<String, dynamic>> getGameIntelligence({
    required int gameId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('🧠 Gathering Balldontlie intelligence for game $gameId...');
    
    final intelligence = <String, dynamic>{
      'gameId': gameId,
      'source': 'Balldontlie',
      'statistics': {},
      'players': {},
      'teamComparison': {},
    };

    // Fetch game details and stats in parallel
    final futures = <Future>[];

    // Get game details
    futures.add(getGame(gameId).then((game) {
      if (game != null) {
        intelligence['gameDetails'] = game.toMap();
        intelligence['status'] = game.status;
        intelligence['score'] = {
          'home': game.homeTeamScore,
          'visitor': game.visitorTeamScore,
        };
      }
    }).catchError((e) {
      debugPrint('Error getting game details: $e');
    }));

    // Get game statistics
    futures.add(getGameStats(gameId: gameId).then((stats) {
      if (stats != null) {
        intelligence['statistics'] = _analyzeGameStats(stats);
        intelligence['topPerformers'] = _getTopPerformers(stats);
      }
    }).catchError((e) {
      debugPrint('Error getting game stats: $e');
    }));

    await Future.wait(futures);

    // Generate insights based on data
    intelligence['insights'] = _generateInsights(intelligence);

    return intelligence;
  }

  /// Analyze game statistics
  Map<String, dynamic> _analyzeGameStats(BalldontlieStatsResponse stats) {
    final analysis = <String, dynamic>{
      'totalPlayers': stats.data.length,
      'homeTeamStats': {},
      'visitorTeamStats': {},
    };

    // Aggregate team stats
    for (final stat in stats.data) {
      final isHome = stat.team['id'] == stat.game['home_team_id'];
      final teamStats = isHome ? analysis['homeTeamStats'] : analysis['visitorTeamStats'];
      
      teamStats['points'] = (teamStats['points'] ?? 0) + (stat.pts ?? 0);
      teamStats['rebounds'] = (teamStats['rebounds'] ?? 0) + (stat.reb ?? 0);
      teamStats['assists'] = (teamStats['assists'] ?? 0) + (stat.ast ?? 0);
      teamStats['steals'] = (teamStats['steals'] ?? 0) + (stat.stl ?? 0);
      teamStats['blocks'] = (teamStats['blocks'] ?? 0) + (stat.blk ?? 0);
    }

    return analysis;
  }

  /// Get top performers from stats
  List<Map<String, dynamic>> _getTopPerformers(BalldontlieStatsResponse stats) {
    final performers = <Map<String, dynamic>>[];
    
    // Sort by points
    final sorted = List<BalldontlieStat>.from(stats.data)
      ..sort((a, b) => (b.pts ?? 0).compareTo(a.pts ?? 0));

    // Get top 5 scorers
    for (final stat in sorted.take(5)) {
      performers.add({
        'player': '${stat.player['first_name']} ${stat.player['last_name']}',
        'team': stat.team['abbreviation'],
        'points': stat.pts,
        'rebounds': stat.reb,
        'assists': stat.ast,
        'minutes': stat.min,
      });
    }

    return performers;
  }

  /// Generate insights from intelligence
  List<String> _generateInsights(Map<String, dynamic> intelligence) {
    final insights = <String>[];

    // Add score-based insights
    if (intelligence['score'] != null) {
      final home = intelligence['score']['home'] ?? 0;
      final visitor = intelligence['score']['visitor'] ?? 0;
      final diff = (home - visitor).abs();
      
      if (diff > 20) {
        insights.add('Blowout alert: ${diff} point difference');
      } else if (diff < 5) {
        insights.add('Close game: Only ${diff} point difference');
      }
    }

    // Add top performer insights
    if (intelligence['topPerformers'] != null) {
      final top = intelligence['topPerformers'] as List;
      if (top.isNotEmpty) {
        final leader = top.first;
        insights.add('${leader['player']} leading with ${leader['points']} points');
      }
    }

    return insights;
  }

  // Headers no longer needed - Cloud Functions handle authentication
}

// Balldontlie Data Models

class BalldontlieGamesResponse {
  final List<BalldontlieGame> data;
  final Map<String, dynamic> meta;

  BalldontlieGamesResponse({required this.data, required this.meta});

  factory BalldontlieGamesResponse.fromJson(Map<String, dynamic> json) {
    return BalldontlieGamesResponse(
      data: (json['data'] as List)
          .map((g) => BalldontlieGame.fromJson(g))
          .toList(),
      meta: json['meta'] ?? {},
    );
  }
}

class BalldontlieGame {
  final int id;
  final DateTime date;
  final int homeTeamScore;
  final int visitorTeamScore;
  final int season;
  final int period;
  final String status;
  final String? time;
  final bool postseason;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> visitorTeam;

  BalldontlieGame({
    required this.id,
    required this.date,
    required this.homeTeamScore,
    required this.visitorTeamScore,
    required this.season,
    required this.period,
    required this.status,
    this.time,
    required this.postseason,
    required this.homeTeam,
    required this.visitorTeam,
  });

  factory BalldontlieGame.fromJson(Map<String, dynamic> json) {
    return BalldontlieGame(
      id: json['id'],
      date: DateTime.parse(json['date']),
      homeTeamScore: json['home_team_score'] ?? 0,
      visitorTeamScore: json['visitor_team_score'] ?? 0,
      season: json['season'],
      period: json['period'],
      status: json['status'],
      time: json['time'],
      postseason: json['postseason'],
      homeTeam: json['home_team'],
      visitorTeam: json['visitor_team'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'homeTeamScore': homeTeamScore,
    'visitorTeamScore': visitorTeamScore,
    'season': season,
    'period': period,
    'status': status,
    'time': time,
    'postseason': postseason,
    'homeTeam': homeTeam,
    'visitorTeam': visitorTeam,
  };
}

class BalldontlieTeamsResponse {
  final List<BalldontlieTeam> data;
  final Map<String, dynamic> meta;

  BalldontlieTeamsResponse({required this.data, required this.meta});

  factory BalldontlieTeamsResponse.fromJson(Map<String, dynamic> json) {
    return BalldontlieTeamsResponse(
      data: (json['data'] as List)
          .map((t) => BalldontlieTeam.fromJson(t))
          .toList(),
      meta: json['meta'] ?? {},
    );
  }
}

class BalldontlieTeam {
  final int id;
  final String abbreviation;
  final String city;
  final String conference;
  final String division;
  final String fullName;
  final String name;

  BalldontlieTeam({
    required this.id,
    required this.abbreviation,
    required this.city,
    required this.conference,
    required this.division,
    required this.fullName,
    required this.name,
  });

  factory BalldontlieTeam.fromJson(Map<String, dynamic> json) {
    return BalldontlieTeam(
      id: json['id'],
      abbreviation: json['abbreviation'],
      city: json['city'],
      conference: json['conference'],
      division: json['division'],
      fullName: json['full_name'],
      name: json['name'],
    );
  }
}

class BalldontliePlayersResponse {
  final List<BalldontliePlayer> data;
  final Map<String, dynamic> meta;

  BalldontliePlayersResponse({required this.data, required this.meta});

  factory BalldontliePlayersResponse.fromJson(Map<String, dynamic> json) {
    return BalldontliePlayersResponse(
      data: (json['data'] as List)
          .map((p) => BalldontliePlayer.fromJson(p))
          .toList(),
      meta: json['meta'] ?? {},
    );
  }
}

class BalldontliePlayer {
  final int id;
  final String firstName;
  final String lastName;
  final String position;
  final String? height;
  final String? weight;
  final String? jerseyNumber;
  final String? college;
  final String? country;
  final int? draftYear;
  final int? draftRound;
  final int? draftNumber;
  final Map<String, dynamic> team;

  BalldontliePlayer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.position,
    this.height,
    this.weight,
    this.jerseyNumber,
    this.college,
    this.country,
    this.draftYear,
    this.draftRound,
    this.draftNumber,
    required this.team,
  });

  factory BalldontliePlayer.fromJson(Map<String, dynamic> json) {
    return BalldontliePlayer(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      position: json['position'] ?? '',
      height: json['height'],
      weight: json['weight'],
      jerseyNumber: json['jersey_number'],
      college: json['college'],
      country: json['country'],
      draftYear: json['draft_year'],
      draftRound: json['draft_round'],
      draftNumber: json['draft_number'],
      team: json['team'] ?? {},
    );
  }
}

class BalldontlieStatsResponse {
  final List<BalldontlieStat> data;
  final Map<String, dynamic> meta;

  BalldontlieStatsResponse({required this.data, required this.meta});

  factory BalldontlieStatsResponse.fromJson(Map<String, dynamic> json) {
    return BalldontlieStatsResponse(
      data: (json['data'] as List)
          .map((s) => BalldontlieStat.fromJson(s))
          .toList(),
      meta: json['meta'] ?? {},
    );
  }
}

class BalldontlieStat {
  final int id;
  final int? ast;
  final int? blk;
  final int? dreb;
  final double? fg3Pct;
  final int? fg3a;
  final int? fg3m;
  final double? fgPct;
  final int? fga;
  final int? fgm;
  final double? ftPct;
  final int? fta;
  final int? ftm;
  final Map<String, dynamic> game;
  final String? min;
  final int? oreb;
  final int? pf;
  final Map<String, dynamic> player;
  final int? pts;
  final int? reb;
  final int? stl;
  final Map<String, dynamic> team;
  final int? turnover;

  BalldontlieStat({
    required this.id,
    this.ast,
    this.blk,
    this.dreb,
    this.fg3Pct,
    this.fg3a,
    this.fg3m,
    this.fgPct,
    this.fga,
    this.fgm,
    this.ftPct,
    this.fta,
    this.ftm,
    required this.game,
    this.min,
    this.oreb,
    this.pf,
    required this.player,
    this.pts,
    this.reb,
    this.stl,
    required this.team,
    this.turnover,
  });

  factory BalldontlieStat.fromJson(Map<String, dynamic> json) {
    return BalldontlieStat(
      id: json['id'],
      ast: json['ast'],
      blk: json['blk'],
      dreb: json['dreb'],
      fg3Pct: json['fg3_pct']?.toDouble(),
      fg3a: json['fg3a'],
      fg3m: json['fg3m'],
      fgPct: json['fg_pct']?.toDouble(),
      fga: json['fga'],
      fgm: json['fgm'],
      ftPct: json['ft_pct']?.toDouble(),
      fta: json['fta'],
      ftm: json['ftm'],
      game: json['game'] ?? {},
      min: json['min'],
      oreb: json['oreb'],
      pf: json['pf'],
      player: json['player'] ?? {},
      pts: json['pts'],
      reb: json['reb'],
      stl: json['stl'],
      team: json['team'] ?? {},
      turnover: json['turnover'],
    );
  }
}

class BalldontlieSeasonAverage {
  final int playerId;
  final int season;
  final int gamesPlayed;
  final double? min;
  final double? pts;
  final double? ast;
  final double? reb;
  final double? stl;
  final double? blk;
  final double? fgPct;
  final double? fg3Pct;
  final double? ftPct;

  BalldontlieSeasonAverage({
    required this.playerId,
    required this.season,
    required this.gamesPlayed,
    this.min,
    this.pts,
    this.ast,
    this.reb,
    this.stl,
    this.blk,
    this.fgPct,
    this.fg3Pct,
    this.ftPct,
  });

  factory BalldontlieSeasonAverage.fromJson(Map<String, dynamic> json) {
    return BalldontlieSeasonAverage(
      playerId: json['player_id'],
      season: json['season'],
      gamesPlayed: json['games_played'],
      min: json['min']?.toDouble(),
      pts: json['pts']?.toDouble(),
      ast: json['ast']?.toDouble(),
      reb: json['reb']?.toDouble(),
      stl: json['stl']?.toDouble(),
      blk: json['blk']?.toDouble(),
      fgPct: json['fg_pct']?.toDouble(),
      fg3Pct: json['fg3_pct']?.toDouble(),
      ftPct: json['ft_pct']?.toDouble(),
    );
  }
}