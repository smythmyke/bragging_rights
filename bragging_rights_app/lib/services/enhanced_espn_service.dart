import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_state_model.dart';
import '../models/game_model.dart';

class EnhancedESPNService {
  static EnhancedESPNService? _instance;
  factory EnhancedESPNService() {
    _instance ??= EnhancedESPNService._internal();
    return _instance!;
  }
  EnhancedESPNService._internal();

  // Polling configurations per sport
  static const Map<SportType, PollConfig> pollConfigs = {
    SportType.nfl: PollConfig(normal: 30000, critical: 10000, suspended: 600000),
    SportType.nba: PollConfig(normal: 30000, critical: 10000, suspended: 600000),
    SportType.mlb: PollConfig(normal: 30000, critical: 15000, suspended: 600000),
    SportType.nhl: PollConfig(normal: 30000, critical: 10000, suspended: 600000),
    SportType.ufc: PollConfig(normal: 15000, critical: 5000, suspended: 300000),
    SportType.tennis: PollConfig(normal: 45000, critical: 15000, suspended: 600000),
    SportType.soccer: PollConfig(normal: 30000, critical: 10000, suspended: 600000),
  };

  // Active game monitors
  final Map<String, Timer> _activeMonitors = {};
  final Map<String, GameState> _lastStates = {};
  final Map<String, StreamController<GameState>> _stateControllers = {};

  // Get ESPN endpoints
  String _getScoreboardUrl(String sport, String league) {
    return 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard';
  }

  String _getSummaryUrl(String sport, String league, String eventId) {
    return 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/summary?event=$eventId';
  }

  // Start monitoring a game
  Stream<GameState> monitorGame(String gameId, SportType sport) {
    // Cancel existing monitor if any
    stopMonitoring(gameId);

    // Create new stream controller
    final controller = StreamController<GameState>.broadcast();
    _stateControllers[gameId] = controller;

    // Start polling
    _startPolling(gameId, sport);

    return controller.stream;
  }

  // Stop monitoring a game
  void stopMonitoring(String gameId) {
    _activeMonitors[gameId]?.cancel();
    _activeMonitors.remove(gameId);
    _stateControllers[gameId]?.close();
    _stateControllers.remove(gameId);
    _lastStates.remove(gameId);
  }

  // Internal polling logic
  void _startPolling(String gameId, SportType sport) {
    final config = pollConfigs[sport]!;
    
    // Determine polling interval based on game state
    int getInterval() {
      final lastState = _lastStates[gameId];
      if (lastState == null) return config.normal;
      
      if (lastState.status == GameStatus.suspended) {
        return config.suspended;
      }
      
      if (lastState.isCriticalMoment) {
        return config.critical;
      }
      
      // Check if we're near period end for faster polling
      if (lastState.clock != null && sport != SportType.mlb && sport != SportType.tennis) {
        final timeLeft = _parseClockToSeconds(lastState.clock!);
        if (timeLeft < 120) { // Last 2 minutes
          return config.critical;
        }
      }
      
      return config.normal;
    }

    // Fetch and process game state
    Future<void> fetchState() async {
      try {
        final state = await fetchGameState(gameId, sport);
        
        if (state != null) {
          // Check for significant changes
          if (state.isDifferentFrom(_lastStates[gameId])) {
            _lastStates[gameId] = state;
            _stateControllers[gameId]?.add(state);
            
            // Emit events for specific transitions
            _checkStateTransitions(gameId, _lastStates[gameId], state);
          }
        }
      } catch (e) {
        print('Error fetching game state for $gameId: $e');
      }
    }

    // Initial fetch
    fetchState();

    // Set up recurring timer
    void scheduleNext() {
      final interval = Duration(milliseconds: getInterval());
      _activeMonitors[gameId] = Timer(interval, () {
        fetchState();
        if (_stateControllers[gameId] != null && !_stateControllers[gameId]!.isClosed) {
          scheduleNext();
        }
      });
    }
    
    scheduleNext();
  }

  // Fetch game state from ESPN
  Future<GameState?> fetchGameState(String gameId, SportType sport) async {
    try {
      // Determine sport and league
      final sportLeague = _getSportLeague(sport);
      final url = _getSummaryUrl(sportLeague.sport, sportLeague.league, gameId);
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse based on sport type
        switch (sport) {
          case SportType.ufc:
            return _parseUFCState(data, gameId);
          case SportType.tennis:
            return _parseTennisState(data, gameId);
          case SportType.nfl:
          case SportType.nba:
          case SportType.mlb:
          case SportType.nhl:
          case SportType.soccer:
            return _parseTeamSportState(data, gameId, sport);
        }
      }
    } catch (e) {
      print('Error fetching ESPN data for $gameId: $e');
    }
    
    return null;
  }

  // Parse team sport state (NFL, NBA, MLB, NHL, Soccer)
  GameState? _parseTeamSportState(Map<String, dynamic> data, String gameId, SportType sport) {
    try {
      final header = data['header'];
      if (header == null) return null;
      
      final competitions = header['competitions'];
      if (competitions == null || competitions.isEmpty) return null;
      
      final competition = competitions[0];
      final status = competition['status'];
      
      // Parse status
      final gameStatus = _parseGameStatus(status['type']['name'], sport);
      
      // Parse period and clock
      int? period = status['period'];
      String? clock = status['displayClock'];
      String? periodName = _getPeriodName(sport, period);
      
      // Parse score
      final competitors = competition['competitors'] ?? [];
      final score = <String, int>{};
      if (competitors.length >= 2) {
        score['home'] = int.tryParse(competitors[0]['score'] ?? '0') ?? 0;
        score['away'] = int.tryParse(competitors[1]['score'] ?? '0') ?? 0;
      }
      
      // Parse sport-specific data
      final sportSpecific = <String, dynamic>{};
      
      // NFL specific
      if (sport == SportType.nfl && data['situation'] != null) {
        final situation = data['situation'];
        sportSpecific['down'] = situation['down'];
        sportSpecific['distance'] = situation['distance'];
        sportSpecific['yardLine'] = situation['yardLine'];
        sportSpecific['possession'] = situation['possession'];
        sportSpecific['isRedZone'] = situation['isRedZone'];
        sportSpecific['homeTimeouts'] = situation['homeTimeouts'];
        sportSpecific['awayTimeouts'] = situation['awayTimeouts'];
      }
      
      // MLB specific
      if (sport == SportType.mlb && data['situation'] != null) {
        final situation = data['situation'];
        sportSpecific['inning'] = situation['inning'];
        sportSpecific['isTop'] = situation['isTop'];
        sportSpecific['outs'] = situation['outs'];
        sportSpecific['balls'] = situation['balls'];
        sportSpecific['strikes'] = situation['strikes'];
        sportSpecific['onFirst'] = situation['onFirst'];
        sportSpecific['onSecond'] = situation['onSecond'];
        sportSpecific['onThird'] = situation['onThird'];
      }
      
      // Determine critical moments
      bool isCriticalMoment = false;
      if (gameStatus == GameStatus.live) {
        // Last 2 minutes of period
        if (clock != null && _parseClockToSeconds(clock) < 120) {
          isCriticalMoment = true;
        }
        // Red zone for NFL
        if (sport == SportType.nfl && sportSpecific['isRedZone'] == true) {
          isCriticalMoment = true;
        }
        // 7th inning or later for MLB
        if (sport == SportType.mlb && period != null && period >= 7) {
          isCriticalMoment = true;
        }
      }
      
      // Calculate available cards
      final availableCards = _calculateAvailableCards(gameStatus, period, sport);
      
      return GameState(
        gameId: gameId,
        sport: sport,
        status: gameStatus,
        period: period,
        periodName: periodName,
        clock: clock,
        score: score,
        sportSpecific: sportSpecific,
        availableCards: availableCards,
        isCriticalMoment: isCriticalMoment,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing team sport state: $e');
      return null;
    }
  }

  // Parse UFC/MMA state
  UFCFightState? _parseUFCState(Map<String, dynamic> data, String gameId) {
    try {
      // UFC events have multiple competitions (fights)
      final competitions = data['competitions'] ?? [];
      if (competitions.isEmpty) return null;
      
      // For now, parse the main event or first fight
      // TODO: Implement multi-fight tracking
      final fight = competitions[0];
      final status = fight['status'];
      
      final gameStatus = _parseGameStatus(status['type']['name'], SportType.ufc);
      final round = status['period'];
      final roundTime = status['displayClock'];
      
      // Parse fighters
      final competitors = fight['competitors'] ?? [];
      final fighters = <String>[];
      if (competitors.length >= 2) {
        fighters.add(competitors[0]['athlete']['displayName'] ?? 'Fighter 1');
        fighters.add(competitors[1]['athlete']['displayName'] ?? 'Fighter 2');
      }
      
      // Parse fight details
      final notes = fight['notes'] ?? [];
      String weightClass = '';
      if (notes.isNotEmpty) {
        weightClass = notes[0]['headline'] ?? '';
      }
      
      final isMainEvent = fight['conferenceCompetition'] ?? false;
      final scheduledRounds = isMainEvent ? 5 : 3;
      
      return UFCFightState(
        gameId: gameId,
        status: gameStatus,
        eventId: data['id'] ?? '',
        fightId: fight['id'] ?? '',
        fighters: fighters,
        weightClass: weightClass,
        isMainEvent: isMainEvent,
        scheduledRounds: scheduledRounds,
        round: round,
        roundTime: roundTime,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing UFC state: $e');
      return null;
    }
  }

  // Parse Tennis state
  TennisMatchState? _parseTennisState(Map<String, dynamic> data, String gameId) {
    try {
      final header = data['header'];
      if (header == null) return null;
      
      final competitions = header['competitions'];
      if (competitions == null || competitions.isEmpty) return null;
      
      final competition = competitions[0];
      final status = competition['status'];
      
      final gameStatus = _parseGameStatus(status['type']['name'], SportType.tennis);
      
      // Parse players
      final competitors = competition['competitors'] ?? [];
      final players = <String>[];
      if (competitors.length >= 2) {
        players.add(competitors[0]['athlete']['displayName'] ?? 'Player 1');
        players.add(competitors[1]['athlete']['displayName'] ?? 'Player 2');
      }
      
      // Parse sets
      final sets = <SetScore>[];
      final linescores = competition['linescores'] ?? [];
      for (final linescore in linescores) {
        sets.add(SetScore(
          player1Games: linescore['value'] ?? 0,
          player2Games: 0, // TODO: Parse properly from ESPN data
          isComplete: true,
        ));
      }
      
      // Determine match format
      final setsToWin = competition['format']?['regulation']?['periods'] ?? 3;
      
      return TennisMatchState(
        gameId: gameId,
        status: gameStatus,
        players: players,
        setsToWin: setsToWin == 5 ? 3 : 2, // Best of 5 = first to 3, Best of 3 = first to 2
        sets: sets,
        isSetPoint: false, // TODO: Calculate from game score
        isMatchPoint: false, // TODO: Calculate from set score
        isTiebreak: false, // TODO: Determine from game score
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      print('Error parsing tennis state: $e');
      return null;
    }
  }

  // Helper: Parse game status
  GameStatus _parseGameStatus(String espnStatus, SportType sport) {
    switch (espnStatus) {
      case 'STATUS_SCHEDULED':
        return GameStatus.scheduled;
      case 'STATUS_IN_PROGRESS':
        return GameStatus.live;
      case 'STATUS_HALFTIME':
        return GameStatus.halftime;
      case 'STATUS_END_PERIOD':
        if (sport == SportType.ufc) {
          return GameStatus.roundBreak;
        } else if (sport == SportType.tennis) {
          return GameStatus.setBreak;
        }
        return GameStatus.live;
      case 'STATUS_SUSPENDED':
      case 'STATUS_POSTPONED':
        return GameStatus.suspended;
      case 'STATUS_FINAL':
        return GameStatus.final;
      case 'STATUS_CANCELED':
      case 'STATUS_FORFEIT':
        return GameStatus.cancelled;
      default:
        return GameStatus.scheduled;
    }
  }

  // Helper: Get period name
  String _getPeriodName(SportType sport, int? period) {
    if (period == null) return '';
    
    switch (sport) {
      case SportType.nfl:
      case SportType.nba:
        final quarters = ['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter', 'Overtime'];
        return period <= quarters.length ? quarters[period - 1] : 'OT $period';
      case SportType.nhl:
        final periods = ['1st Period', '2nd Period', '3rd Period', 'Overtime', 'Shootout'];
        return period <= periods.length ? periods[period - 1] : 'OT $period';
      case SportType.mlb:
        final suffix = _getOrdinalSuffix(period);
        return '$period$suffix Inning';
      case SportType.ufc:
        return 'Round $period';
      case SportType.tennis:
        return 'Set $period';
      case SportType.soccer:
        if (period == 1) return '1st Half';
        if (period == 2) return '2nd Half';
        return 'Extra Time';
    }
  }

  // Helper: Get ordinal suffix
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Helper: Parse clock to seconds
  int _parseClockToSeconds(String clock) {
    try {
      final parts = clock.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return (minutes * 60) + seconds;
      }
    } catch (e) {
      // Invalid clock format
    }
    return 0;
  }

  // Helper: Calculate available cards
  List<String> _calculateAvailableCards(GameStatus status, int? period, SportType sport) {
    final cards = <String>[];
    
    if (status == GameStatus.scheduled || status == GameStatus.pregame) {
      cards.addAll(['mulligan', 'crystal_ball', 'copycat', 'time_freeze']);
    }
    
    if (status == GameStatus.live) {
      cards.add('hedge');
      
      if (period != null) {
        if (period < 3 || (sport == SportType.mlb && period < 5)) {
          cards.addAll(['double_down', 'split_bet']);
        }
        if (period < 4 || (sport == SportType.mlb && period < 7)) {
          cards.add('insurance');
        }
      }
    }
    
    if (status == GameStatus.roundBreak && sport == SportType.ufc) {
      // All cards available during 60-second round break
      cards.addAll(['double_down', 'insurance', 'hedge', 'split_bet']);
    }
    
    if (status == GameStatus.setBreak && sport == SportType.tennis) {
      // Cards available during 120-second set break
      cards.addAll(['double_down', 'insurance', 'hedge']);
    }
    
    return cards;
  }

  // Helper: Check state transitions
  void _checkStateTransitions(String gameId, GameState? oldState, GameState newState) {
    if (oldState == null) return;
    
    // Period change
    if (oldState.period != newState.period) {
      _onPeriodChange(gameId, oldState.period, newState.period);
    }
    
    // Status change
    if (oldState.status != newState.status) {
      _onStatusChange(gameId, oldState.status, newState.status);
    }
    
    // Critical moment change
    if (!oldState.isCriticalMoment && newState.isCriticalMoment) {
      _onCriticalMoment(gameId);
    }
  }

  // Event: Period changed
  void _onPeriodChange(String gameId, int? oldPeriod, int? newPeriod) {
    print('Game $gameId: Period changed from $oldPeriod to $newPeriod');
    
    // Check for card expiration
    if (newPeriod == 3) {
      print('Game $gameId: Double Down and Split Bet cards expiring!');
    }
    if (newPeriod == 4) {
      print('Game $gameId: Insurance card expiring!');
    }
  }

  // Event: Status changed
  void _onStatusChange(String gameId, GameStatus oldStatus, GameStatus newStatus) {
    print('Game $gameId: Status changed from $oldStatus to $newStatus');
    
    if (newStatus == GameStatus.halftime) {
      print('Game $gameId: Halftime - 12 minute card window open');
    }
    if (newStatus == GameStatus.roundBreak) {
      print('Game $gameId: Round break - 60 second card window open');
    }
    if (newStatus == GameStatus.final) {
      print('Game $gameId: Game final - settling pools');
    }
    if (newStatus == GameStatus.suspended) {
      print('Game $gameId: Game suspended - switching to 10-minute polling');
    }
  }

  // Event: Critical moment
  void _onCriticalMoment(String gameId) {
    print('Game $gameId: Entering critical moment - increasing poll frequency');
  }

  // Helper: Get sport and league from SportType
  SportLeague _getSportLeague(SportType sport) {
    switch (sport) {
      case SportType.nfl:
        return SportLeague('football', 'nfl');
      case SportType.nba:
        return SportLeague('basketball', 'nba');
      case SportType.mlb:
        return SportLeague('baseball', 'mlb');
      case SportType.nhl:
        return SportLeague('hockey', 'nhl');
      case SportType.ufc:
        return SportLeague('mma', 'ufc');
      case SportType.tennis:
        return SportLeague('tennis', 'atp');
      case SportType.soccer:
        return SportLeague('soccer', 'eng.1');
    }
  }

  // Dispose all monitors
  void dispose() {
    for (final gameId in _activeMonitors.keys.toList()) {
      stopMonitoring(gameId);
    }
  }
}

class SportLeague {
  final String sport;
  final String league;
  
  SportLeague(this.sport, this.league);
}