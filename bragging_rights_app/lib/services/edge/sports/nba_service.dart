import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import 'package:intl/intl.dart';

/// NBA Stats API Service
/// Official NBA statistics and game data
class NbaService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  
  static const String _apiName = 'nba_stats';
  
  // NBA Stats API endpoints
  static const String _scoreboardEndpoint = '/stats/scoreboardv3';
  static const String _todaysGamesEndpoint = '/stats/scoreboard';
  static const String _teamStatsEndpoint = '/stats/leaguedashteamstats';
  static const String _playerStatsEndpoint = '/stats/leaguedashplayerstats';
  static const String _boxScoreEndpoint = '/stats/boxscoretraditionalv3';
  static const String _playByPlayEndpoint = '/stats/playbyplayv3';
  static const String _teamDetailsEndpoint = '/stats/teamdetails';
  static const String _playerDetailsEndpoint = '/stats/commonplayerinfo';
  static const String _standingsEndpoint = '/stats/leaguestandingsv3';
  static const String _injuriesEndpoint = '/stats/commonteamroster';

  /// Get today's NBA games
  Future<NbaGamesResponse?> getTodaysGames() async {
    try {
      final today = DateFormat('MM/dd/yyyy').format(DateTime.now());
      
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _scoreboardEndpoint,
        queryParams: {
          'GameDate': today,
          'LeagueID': '00', // NBA
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaGamesResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching NBA games: $e');
    }
    return null;
  }

  /// Get games for a specific date
  Future<NbaGamesResponse?> getGamesForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('MM/dd/yyyy').format(date);
      
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _scoreboardEndpoint,
        queryParams: {
          'GameDate': dateStr,
          'LeagueID': '00',
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaGamesResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching NBA games for date: $e');
    }
    return null;
  }

  /// Get detailed box score for a game
  Future<NbaBoxScore?> getBoxScore(String gameId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _boxScoreEndpoint,
        queryParams: {
          'GameID': gameId,
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaBoxScore.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching box score: $e');
    }
    return null;
  }

  /// Get play-by-play data for live tracking
  Future<NbaPlayByPlay?> getPlayByPlay(String gameId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _playByPlayEndpoint,
        queryParams: {
          'GameID': gameId,
          'StartPeriod': '0',
          'EndPeriod': '14', // All periods including OT
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaPlayByPlay.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching play-by-play: $e');
    }
    return null;
  }

  /// Get team statistics
  Future<NbaTeamStats?> getTeamStats({
    String season = '2024-25',
    String seasonType = 'Regular Season',
  }) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _teamStatsEndpoint,
        queryParams: {
          'Season': season,
          'SeasonType': seasonType,
          'MeasureType': 'Advanced',
          'PerMode': 'PerGame',
          'LastNGames': '0',
          'Month': '0',
          'OpponentTeamID': '0',
          'Period': '0',
          'PlusMinus': 'N',
          'Rank': 'N',
          'DateFrom': '',
          'DateTo': '',
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaTeamStats.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching team stats: $e');
    }
    return null;
  }

  /// Get player statistics
  Future<NbaPlayerStats?> getPlayerStats({
    String season = '2024-25',
    String seasonType = 'Regular Season',
  }) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _playerStatsEndpoint,
        queryParams: {
          'Season': season,
          'SeasonType': seasonType,
          'MeasureType': 'Advanced',
          'PerMode': 'PerGame',
          'LastNGames': '0',
          'Month': '0',
          'OpponentTeamID': '0',
          'Period': '0',
          'PlusMinus': 'N',
          'Rank': 'N',
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaPlayerStats.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching player stats: $e');
    }
    return null;
  }

  /// Get league standings
  Future<NbaStandings?> getStandings({
    String season = '2024-25',
    String seasonType = 'Regular Season',
  }) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _standingsEndpoint,
        queryParams: {
          'Season': season,
          'SeasonType': seasonType,
          'LeagueID': '00',
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaStandings.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching standings: $e');
    }
    return null;
  }

  /// Get team roster and injuries
  Future<NbaRoster?> getTeamRoster(String teamId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _injuriesEndpoint,
        queryParams: {
          'TeamID': teamId,
          'Season': '2024-25',
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaRoster.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching team roster: $e');
    }
    return null;
  }

  /// Get player details
  Future<NbaPlayerInfo?> getPlayerInfo(String playerId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _playerDetailsEndpoint,
        queryParams: {
          'PlayerID': playerId,
        },
        headers: _getNbaHeaders(),
      );

      if (response.data != null) {
        return NbaPlayerInfo.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching player info: $e');
    }
    return null;
  }

  /// Get Edge intelligence for an NBA game
  Future<Map<String, dynamic>> getGameIntelligence({
    required String gameId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    final intelligence = <String, dynamic>{
      'gameId': gameId,
      'analysis': {},
      'predictions': {},
      'keyFactors': [],
    };

    // Fetch multiple data points in parallel
    final futures = <Future>[];

    // Box score for current performance
    futures.add(getBoxScore(gameId).then((data) {
      if (data != null) {
        intelligence['analysis']['boxScore'] = data.toMap();
        intelligence['keyFactors'].add(_analyzeBoxScore(data));
      }
    }));

    // Team stats for season context
    futures.add(getTeamStats().then((data) {
      if (data != null) {
        intelligence['analysis']['teamStats'] = data.toMap();
        intelligence['keyFactors'].add(_analyzeTeamStats(data, homeTeam, awayTeam));
      }
    }));

    // Player stats for individual performance
    futures.add(getPlayerStats().then((data) {
      if (data != null) {
        intelligence['analysis']['playerStats'] = data.toMap();
        intelligence['keyFactors'].add(_analyzePlayerStats(data));
      }
    }));

    // Standings for playoff implications
    futures.add(getStandings().then((data) {
      if (data != null) {
        intelligence['analysis']['standings'] = data.toMap();
        intelligence['keyFactors'].add(_analyzeStandings(data, homeTeam, awayTeam));
      }
    }));

    await Future.wait(futures);

    // Generate predictions based on collected data
    intelligence['predictions'] = _generatePredictions(intelligence['analysis']);

    return intelligence;
  }

  /// Analyze box score for key insights
  Map<String, dynamic> _analyzeBoxScore(NbaBoxScore boxScore) {
    return {
      'type': 'live_performance',
      'insights': [
        'Leading scorer analysis',
        'Shooting percentage trends',
        'Rebounding battle',
      ],
    };
  }

  /// Analyze team stats for matchup advantages
  Map<String, dynamic> _analyzeTeamStats(
    NbaTeamStats stats,
    String homeTeam,
    String awayTeam,
  ) {
    return {
      'type': 'season_stats',
      'insights': [
        'Offensive/defensive ratings',
        'Pace analysis',
        'Three-point shooting trends',
      ],
    };
  }

  /// Analyze player stats for key performers
  Map<String, dynamic> _analyzePlayerStats(NbaPlayerStats stats) {
    return {
      'type': 'player_impact',
      'insights': [
        'Star player performance',
        'Bench contribution',
        'Injury impacts',
      ],
    };
  }

  /// Analyze standings for motivation factors
  Map<String, dynamic> _analyzeStandings(
    NbaStandings standings,
    String homeTeam,
    String awayTeam,
  ) {
    return {
      'type': 'playoff_implications',
      'insights': [
        'Playoff positioning',
        'Division rivalry',
        'Win streak momentum',
      ],
    };
  }

  /// Generate predictions based on analysis
  Map<String, dynamic> _generatePredictions(Map<String, dynamic> analysis) {
    return {
      'winner': 'TBD',
      'confidence': 0.0,
      'totalPoints': 'TBD',
      'spread': 'TBD',
      'keyMatchups': [],
    };
  }

  /// Get proper NBA headers for API requests
  Map<String, String> _getNbaHeaders() {
    return {
      'Host': 'stats.nba.com',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
      'Referer': 'https://www.nba.com/',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': 'https://www.nba.com',
      'x-nba-stats-origin': 'stats',
      'x-nba-stats-token': 'true',
    };
  }
}

// Data Models

class NbaGamesResponse {
  final List<NbaGame> games;
  final String gameDate;

  NbaGamesResponse({required this.games, required this.gameDate});

  factory NbaGamesResponse.fromJson(Map<String, dynamic> json) {
    final scoreboard = json['scoreboard'] ?? {};
    final gamesData = scoreboard['games'] ?? [];
    
    return NbaGamesResponse(
      gameDate: scoreboard['gameDate'] ?? '',
      games: (gamesData as List)
          .map((g) => NbaGame.fromJson(g))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'gameDate': gameDate,
    'games': games.map((g) => g.toMap()).toList(),
  };
}

class NbaGame {
  final String gameId;
  final String gameCode;
  final String gameStatus;
  final int gameStatusText;
  final String startTime;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> awayTeam;
  final int period;
  final String gameClock;

  NbaGame({
    required this.gameId,
    required this.gameCode,
    required this.gameStatus,
    required this.gameStatusText,
    required this.startTime,
    required this.homeTeam,
    required this.awayTeam,
    required this.period,
    required this.gameClock,
  });

  factory NbaGame.fromJson(Map<String, dynamic> json) {
    return NbaGame(
      gameId: json['gameId'] ?? '',
      gameCode: json['gameCode'] ?? '',
      gameStatus: json['gameStatus'] ?? '',
      gameStatusText: json['gameStatusText'] ?? 0,
      startTime: json['gameTimeUTC'] ?? '',
      homeTeam: json['homeTeam'] ?? {},
      awayTeam: json['awayTeam'] ?? {},
      period: json['period'] ?? 0,
      gameClock: json['gameClock'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'gameId': gameId,
    'gameCode': gameCode,
    'gameStatus': gameStatus,
    'gameStatusText': gameStatusText,
    'startTime': startTime,
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'period': period,
    'gameClock': gameClock,
  };
}

class NbaBoxScore {
  final String gameId;
  final Map<String, dynamic> homeTeamStats;
  final Map<String, dynamic> awayTeamStats;
  final List<Map<String, dynamic>> homePlayerStats;
  final List<Map<String, dynamic>> awayPlayerStats;

  NbaBoxScore({
    required this.gameId,
    required this.homeTeamStats,
    required this.awayTeamStats,
    required this.homePlayerStats,
    required this.awayPlayerStats,
  });

  factory NbaBoxScore.fromJson(Map<String, dynamic> json) {
    final game = json['game'] ?? {};
    return NbaBoxScore(
      gameId: game['gameId'] ?? '',
      homeTeamStats: game['homeTeam'] ?? {},
      awayTeamStats: game['awayTeam'] ?? {},
      homePlayerStats: List<Map<String, dynamic>>.from(
        game['homeTeam']?['players'] ?? [],
      ),
      awayPlayerStats: List<Map<String, dynamic>>.from(
        game['awayTeam']?['players'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'gameId': gameId,
    'homeTeamStats': homeTeamStats,
    'awayTeamStats': awayTeamStats,
    'homePlayerStats': homePlayerStats,
    'awayPlayerStats': awayPlayerStats,
  };
}

class NbaPlayByPlay {
  final String gameId;
  final List<Map<String, dynamic>> plays;

  NbaPlayByPlay({required this.gameId, required this.plays});

  factory NbaPlayByPlay.fromJson(Map<String, dynamic> json) {
    final game = json['game'] ?? {};
    return NbaPlayByPlay(
      gameId: game['gameId'] ?? '',
      plays: List<Map<String, dynamic>>.from(game['actions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'gameId': gameId,
    'plays': plays,
  };
}

class NbaTeamStats {
  final List<Map<String, dynamic>> teams;

  NbaTeamStats({required this.teams});

  factory NbaTeamStats.fromJson(Map<String, dynamic> json) {
    final resultSets = json['resultSets'] ?? [];
    if (resultSets.isNotEmpty) {
      final data = resultSets[0]['rowSet'] ?? [];
      return NbaTeamStats(
        teams: List<Map<String, dynamic>>.from(data),
      );
    }
    return NbaTeamStats(teams: []);
  }

  Map<String, dynamic> toMap() => {'teams': teams};
}

class NbaPlayerStats {
  final List<Map<String, dynamic>> players;

  NbaPlayerStats({required this.players});

  factory NbaPlayerStats.fromJson(Map<String, dynamic> json) {
    final resultSets = json['resultSets'] ?? [];
    if (resultSets.isNotEmpty) {
      final data = resultSets[0]['rowSet'] ?? [];
      return NbaPlayerStats(
        players: List<Map<String, dynamic>>.from(data),
      );
    }
    return NbaPlayerStats(players: []);
  }

  Map<String, dynamic> toMap() => {'players': players};
}

class NbaStandings {
  final List<Map<String, dynamic>> standings;

  NbaStandings({required this.standings});

  factory NbaStandings.fromJson(Map<String, dynamic> json) {
    final resultSets = json['resultSets'] ?? [];
    if (resultSets.isNotEmpty) {
      final data = resultSets[0]['rowSet'] ?? [];
      return NbaStandings(
        standings: List<Map<String, dynamic>>.from(data),
      );
    }
    return NbaStandings(standings: []);
  }

  Map<String, dynamic> toMap() => {'standings': standings};
}

class NbaRoster {
  final String teamId;
  final List<Map<String, dynamic>> players;

  NbaRoster({required this.teamId, required this.players});

  factory NbaRoster.fromJson(Map<String, dynamic> json) {
    final resultSets = json['resultSets'] ?? [];
    if (resultSets.isNotEmpty) {
      final data = resultSets[0]['rowSet'] ?? [];
      return NbaRoster(
        teamId: json['parameters']?['TeamID'] ?? '',
        players: List<Map<String, dynamic>>.from(data),
      );
    }
    return NbaRoster(teamId: '', players: []);
  }

  Map<String, dynamic> toMap() => {
    'teamId': teamId,
    'players': players,
  };
}

class NbaPlayerInfo {
  final String playerId;
  final String playerName;
  final Map<String, dynamic> info;
  final Map<String, dynamic> stats;

  NbaPlayerInfo({
    required this.playerId,
    required this.playerName,
    required this.info,
    required this.stats,
  });

  factory NbaPlayerInfo.fromJson(Map<String, dynamic> json) {
    final resultSets = json['resultSets'] ?? [];
    if (resultSets.isNotEmpty) {
      final infoData = resultSets[0]['rowSet']?[0] ?? [];
      final statsData = resultSets.length > 1 
          ? (resultSets[1]['rowSet']?[0] ?? [])
          : [];
      
      return NbaPlayerInfo(
        playerId: infoData[0]?.toString() ?? '',
        playerName: '${infoData[1] ?? ''} ${infoData[2] ?? ''}',
        info: {'data': infoData},
        stats: {'data': statsData},
      );
    }
    return NbaPlayerInfo(
      playerId: '',
      playerName: '',
      info: {},
      stats: {},
    );
  }

  Map<String, dynamic> toMap() => {
    'playerId': playerId,
    'playerName': playerName,
    'info': info,
    'stats': stats,
  };
}