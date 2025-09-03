import 'package:cloud_firestore/cloud_firestore.dart';

enum GameStatus {
  scheduled,
  pregame,
  live,
  halftime,
  roundBreak,
  setBreak,
  suspended,
  completed,
  cancelled,
}

enum SportType {
  nfl,
  nba,
  mlb,
  nhl,
  ufc,
  tennis,
  soccer,
}

class PollConfig {
  final int normal;
  final int critical;
  final int suspended;

  const PollConfig({
    required this.normal,
    required this.critical,
    required this.suspended,
  });
}

class GameState {
  final String gameId;
  final SportType sport;
  final GameStatus status;
  final int? period;
  final String? periodName;
  final String? clock;
  final Map<String, int> score;
  final Map<String, dynamic> sportSpecific;
  final List<String> availableCards;
  final bool isCriticalMoment;
  final DateTime lastUpdate;
  final bool isManualUpdate;

  GameState({
    required this.gameId,
    required this.sport,
    required this.status,
    this.period,
    this.periodName,
    this.clock,
    required this.score,
    required this.sportSpecific,
    required this.availableCards,
    required this.isCriticalMoment,
    required this.lastUpdate,
    this.isManualUpdate = false,
  });

  // Sport-specific helpers
  bool get isHalftime {
    if (sport == SportType.nfl || sport == SportType.nba) {
      return status == GameStatus.halftime;
    }
    return false;
  }

  bool get isBetweenRounds {
    return sport == SportType.ufc && status == GameStatus.roundBreak;
  }

  bool get isSetBreak {
    return sport == SportType.tennis && status == GameStatus.setBreak;
  }

  bool get isIntermission {
    return isHalftime || isBetweenRounds || isSetBreak;
  }

  // Card availability checks
  bool canPlayCard(String cardId) {
    switch (cardId) {
      case 'double_down':
        // Before halftime for team sports, before round 3 for UFC
        if (status != GameStatus.live) return false;
        if (sport == SportType.ufc) {
          return period != null && period! < 3;
        }
        return period != null && period! < 3;

      case 'insurance':
        // Before 4th quarter/period/round
        if (status != GameStatus.live) return false;
        return period != null && period! < 4;

      case 'mulligan':
        // Only before game starts
        return status == GameStatus.scheduled || status == GameStatus.pregame;

      case 'hedge':
        // Anytime during live play (not during breaks)
        return status == GameStatus.live && !isIntermission;

      case 'split_bet':
        // Before halftime/round 3
        if (status != GameStatus.live) return false;
        return period != null && period! < 3;

      case 'time_freeze':
        // Only pregame
        return status == GameStatus.pregame;

      case 'crystal_ball':
      case 'copycat':
        // Before game starts
        return status == GameStatus.scheduled || status == GameStatus.pregame;

      default:
        return false;
    }
  }

  // Get time until card expires
  Duration? getCardExpirationTime(String cardId) {
    if (!canPlayCard(cardId)) return null;
    
    if (clock != null && clock!.isNotEmpty) {
      // Parse clock for timed sports
      if (sport == SportType.nfl || sport == SportType.nba || sport == SportType.nhl) {
        final parts = clock!.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]) ?? 0;
          final seconds = int.tryParse(parts[1]) ?? 0;
          final remainingSeconds = (minutes * 60) + seconds;
          
          // Calculate based on period end
          if (cardId == 'double_down' && period == 2) {
            return Duration(seconds: remainingSeconds);
          }
          if (cardId == 'insurance' && period == 3) {
            return Duration(seconds: remainingSeconds);
          }
        }
      }
    }
    
    return null;
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'sport': sport.toString().split('.').last,
      'status': status.toString().split('.').last,
      'period': period,
      'periodName': periodName,
      'clock': clock,
      'score': score,
      'sportSpecific': sportSpecific,
      'availableCards': availableCards,
      'isCriticalMoment': isCriticalMoment,
      'lastUpdate': Timestamp.fromDate(lastUpdate),
      'isManualUpdate': isManualUpdate,
    };
  }

  // Create from Firestore document
  factory GameState.fromFirestore(Map<String, dynamic> data) {
    return GameState(
      gameId: data['gameId'],
      sport: SportType.values.firstWhere(
        (e) => e.toString().split('.').last == data['sport'],
        orElse: () => SportType.nfl,
      ),
      status: GameStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => GameStatus.scheduled,
      ),
      period: data['period'],
      periodName: data['periodName'],
      clock: data['clock'],
      score: Map<String, int>.from(data['score'] ?? {}),
      sportSpecific: data['sportSpecific'] ?? {},
      availableCards: List<String>.from(data['availableCards'] ?? []),
      isCriticalMoment: data['isCriticalMoment'] ?? false,
      lastUpdate: (data['lastUpdate'] as Timestamp).toDate(),
      isManualUpdate: data['isManualUpdate'] ?? false,
    );
  }

  // Check if state has changed significantly
  bool isDifferentFrom(GameState? other) {
    if (other == null) return true;
    
    return status != other.status ||
           period != other.period ||
           clock != other.clock ||
           score['home'] != other.score['home'] ||
           score['away'] != other.score['away'] ||
           isCriticalMoment != other.isCriticalMoment;
  }

  GameState copyWith({
    GameStatus? status,
    int? period,
    String? periodName,
    String? clock,
    Map<String, int>? score,
    Map<String, dynamic>? sportSpecific,
    List<String>? availableCards,
    bool? isCriticalMoment,
    DateTime? lastUpdate,
    bool? isManualUpdate,
  }) {
    return GameState(
      gameId: gameId,
      sport: sport,
      status: status ?? this.status,
      period: period ?? this.period,
      periodName: periodName ?? this.periodName,
      clock: clock ?? this.clock,
      score: score ?? this.score,
      sportSpecific: sportSpecific ?? this.sportSpecific,
      availableCards: availableCards ?? this.availableCards,
      isCriticalMoment: isCriticalMoment ?? this.isCriticalMoment,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isManualUpdate: isManualUpdate ?? this.isManualUpdate,
    );
  }
}

// UFC-specific state
class UFCFightState extends GameState {
  final String eventId;
  final String fightId;
  final List<String> fighters;
  final String weightClass;
  final bool isMainEvent;
  final int scheduledRounds;
  final String? roundTime;

  UFCFightState({
    required String gameId,
    required GameStatus status,
    required this.eventId,
    required this.fightId,
    required this.fighters,
    required this.weightClass,
    required this.isMainEvent,
    required this.scheduledRounds,
    this.roundTime,
    int? round,
    Map<String, int>? score,
    Map<String, dynamic>? sportSpecific,
    required DateTime lastUpdate,
  }) : super(
    gameId: gameId,
    sport: SportType.ufc,
    status: status,
    period: round,
    periodName: round != null ? 'Round $round' : null,
    clock: roundTime,
    score: score ?? {'fighter1': 0, 'fighter2': 0},
    sportSpecific: sportSpecific ?? {},
    availableCards: [],
    isCriticalMoment: false,
    lastUpdate: lastUpdate,
  );

  String get fightTitle => '${fighters[0]} vs ${fighters[1]}';
  
  bool get isChampionshipFight => scheduledRounds == 5;
}

// Tennis-specific state
class TennisMatchState extends GameState {
  final List<String> players;
  final int setsToWin;
  final List<SetScore> sets;
  final String? server;
  final bool isSetPoint;
  final bool isMatchPoint;
  final bool isTiebreak;

  TennisMatchState({
    required String gameId,
    required GameStatus status,
    required this.players,
    required this.setsToWin,
    required this.sets,
    this.server,
    required this.isSetPoint,
    required this.isMatchPoint,
    required this.isTiebreak,
    Map<String, dynamic>? sportSpecific,
    required DateTime lastUpdate,
  }) : super(
    gameId: gameId,
    sport: SportType.tennis,
    status: status,
    period: sets.length,
    periodName: 'Set ${sets.length}',
    clock: null, // Tennis has no clock
    score: _calculateScore(sets),
    sportSpecific: sportSpecific ?? {},
    availableCards: [],
    isCriticalMoment: isSetPoint || isMatchPoint,
    lastUpdate: lastUpdate,
  );

  static Map<String, int> _calculateScore(List<SetScore> sets) {
    int player1Sets = 0;
    int player2Sets = 0;
    
    for (final set in sets) {
      if (set.player1Games > set.player2Games) {
        player1Sets++;
      } else if (set.player2Games > set.player1Games) {
        player2Sets++;
      }
    }
    
    return {'player1': player1Sets, 'player2': player2Sets};
  }
}

class SetScore {
  final int player1Games;
  final int player2Games;
  final bool isComplete;

  SetScore({
    required this.player1Games,
    required this.player2Games,
    required this.isComplete,
  });
}