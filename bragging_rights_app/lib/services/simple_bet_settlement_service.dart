import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/simple_bet.dart';
import '../models/simple_bet_slip.dart';
import 'game_results_cache_service.dart';

/// Service for settling simple bets after game completion
/// Uses GameResultsCacheService for efficient ESPN API usage
class SimpleBetSettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameResultsCacheService _cacheService = GameResultsCacheService();

  // Singleton
  static final SimpleBetSettlementService _instance = SimpleBetSettlementService._internal();
  factory SimpleBetSettlementService() => _instance;
  SimpleBetSettlementService._internal();

  /// Settle a simple bet slip after game completion
  /// Returns updated bet slip with results and points earned
  Future<SimpleBetSlip?> settleBetSlip({
    required String betSlipId,
    required String gameId,
    required String sport,
  }) async {
    try {
      debugPrint('[SimpleBetSettlement] Settling bet slip $betSlipId for game $gameId');

      // 1. Get cached game result (or fetch from ESPN)
      final gameData = await _cacheService.getGameResult(
        gameId: gameId,
        sport: sport,
        fetchIfMissing: true,
      );

      if (gameData == null) {
        debugPrint('[SimpleBetSettlement] No game data available for $gameId');
        return null;
      }

      // 2. Get bet slip from Firestore
      final betSlipDoc = await _firestore
          .collection('simple_bet_slips')
          .doc(betSlipId)
          .get();

      if (!betSlipDoc.exists) {
        debugPrint('[SimpleBetSettlement] Bet slip $betSlipId not found');
        return null;
      }

      final betSlipData = betSlipDoc.data()!;

      // 3. Reconstruct SimpleBetSlip from Firestore data
      final winnerBet = SimpleBet.fromMap(betSlipData['winnerBet']);
      final optionalBets = (betSlipData['optionalBets'] as List)
          .map((b) => SimpleBet.fromMap(b))
          .toList();

      // 4. Settle each bet
      final settledWinnerBet = await _settleSingleBet(winnerBet, gameData, sport);
      final settledOptionalBets = await Future.wait(
        optionalBets.map((bet) => _settleSingleBet(bet, gameData, sport))
      );

      // 5. Calculate total points earned
      final totalPointsEarned = [settledWinnerBet, ...settledOptionalBets]
          .where((bet) => bet.result == true)
          .fold<double>(0, (sum, bet) => sum + (bet.pointsEarned ?? 0));

      // 6. Update bet slip in Firestore
      await _firestore.collection('simple_bet_slips').doc(betSlipId).update({
        'settled': true,
        'settledAt': FieldValue.serverTimestamp(),
        'winnerBet': settledWinnerBet.toMap(),
        'optionalBets': settledOptionalBets.map((b) => b.toMap()).toList(),
        'totalEarnedPoints': totalPointsEarned,
      });

      debugPrint('[SimpleBetSettlement] Settled $betSlipId - ${totalPointsEarned} points earned');

      // 7. Return updated bet slip with settlement data
      return SimpleBetSlip.fromMap({
        ...betSlipData,
        'id': betSlipId,
        'settled': true,
        'settledAt': DateTime.now(),
        'winnerBet': settledWinnerBet.toMap(),
        'optionalBets': settledOptionalBets.map((b) => b.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error settling bet slip: $e');
      return null;
    }
  }

  /// Settle a single simple bet against game data
  Future<SimpleBet> _settleSingleBet(
    SimpleBet bet,
    Map<String, dynamic> gameData,
    String sport,
  ) async {
    try {
      final competition = gameData['competition'];
      final competitors = competition?['competitors'] as List? ?? [];

      if (competitors.length < 2) {
        debugPrint('[SimpleBetSettlement] Insufficient competitor data');
        return bet.copyWith(result: false, pointsEarned: 0);
      }

      final home = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => {});
      final away = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => {});

      // Determine bet result based on bet type
      bool result = false;

      switch (bet.betType) {
        case 'winner':
          result = _checkWinnerBet(bet, home, away);
          break;

        case 'team_score_threshold':
          result = _checkTeamScoreThreshold(bet, home, away);
          break;

        case 'game_total_threshold':
        case 'total_score_threshold': // Alias for NCAA configs
          result = _checkGameTotalThreshold(bet, home, away);
          break;

        case 'margin_threshold':
          result = _checkMarginThreshold(bet, home, away);
          break;

        case 'margin_range':
          result = _checkMarginRange(bet, home, away);
          break;

        case 'player_performance':
          result = await _checkPlayerPerformance(bet, gameData);
          break;

        case 'team_stat_threshold':
          result = await _checkTeamStatThreshold(bet, home, away, gameData);
          break;

        case 'special_event':
          result = await _checkSpecialEvent(bet, gameData);
          break;

        default:
          debugPrint('[SimpleBetSettlement] Unknown bet type: ${bet.betType}');
          result = false;
      }

      // Calculate points earned
      final pointsEarned = result ? bet.potentialPoints : 0.0;

      debugPrint('[SimpleBetSettlement] ${bet.description}: ${result ? "WON" : "LOST"} (${pointsEarned} pts)');

      return bet.copyWith(
        result: result,
        pointsEarned: pointsEarned,
      );
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error settling bet: $e');
      return bet.copyWith(result: false, pointsEarned: 0);
    }
  }

  /// Check winner bet
  bool _checkWinnerBet(SimpleBet bet, Map<String, dynamic> home, Map<String, dynamic> away) {
    if (bet.team == 'home') {
      return home['winner'] == true;
    } else if (bet.team == 'away') {
      return away['winner'] == true;
    } else if (bet.team == 'draw') {
      // Check if game ended in a draw (no winner)
      return home['winner'] != true && away['winner'] != true;
    }
    return false;
  }

  /// Check team score threshold bet
  bool _checkTeamScoreThreshold(SimpleBet bet, Map<String, dynamic> home, Map<String, dynamic> away) {
    if (bet.team == null || bet.threshold == null) return false;

    final teamData = bet.team == 'home' ? home : away;
    final score = int.tryParse(teamData['score']?.toString() ?? '0') ?? 0;

    return score >= bet.threshold!;
  }

  /// Check game total score threshold bet
  bool _checkGameTotalThreshold(SimpleBet bet, Map<String, dynamic> home, Map<String, dynamic> away) {
    if (bet.threshold == null) return false;

    final homeScore = int.tryParse(home['score']?.toString() ?? '0') ?? 0;
    final awayScore = int.tryParse(away['score']?.toString() ?? '0') ?? 0;
    final totalScore = homeScore + awayScore;

    // Check if bet is "over" or "under"
    if (bet.statType == 'over') {
      return totalScore > bet.threshold!;
    } else if (bet.statType == 'under') {
      return totalScore < bet.threshold!;
    } else {
      return totalScore >= bet.threshold!;
    }
  }

  /// Check margin of victory threshold bet
  bool _checkMarginThreshold(SimpleBet bet, Map<String, dynamic> home, Map<String, dynamic> away) {
    if (bet.threshold == null) return false;

    final homeScore = int.tryParse(home['score']?.toString() ?? '0') ?? 0;
    final awayScore = int.tryParse(away['score']?.toString() ?? '0') ?? 0;
    final margin = (homeScore - awayScore).abs();

    // Check if bet is for margin over/under threshold
    if (bet.statType == 'over') {
      return margin > bet.threshold!;
    } else if (bet.statType == 'under') {
      return margin < bet.threshold!;
    } else {
      return margin >= bet.threshold!;
    }
  }

  /// Check margin range bet (e.g., "decided by 1-7 points")
  /// Used for bets where margin must fall within a specific range
  bool _checkMarginRange(SimpleBet bet, Map<String, dynamic> home, Map<String, dynamic> away) {
    if (bet.threshold == null) return false;

    final homeScore = int.tryParse(home['score']?.toString() ?? '0') ?? 0;
    final awayScore = int.tryParse(away['score']?.toString() ?? '0') ?? 0;
    final margin = (homeScore - awayScore).abs();

    // Check based on statType which indicates the range
    if (bet.statType == 'close') {
      // For NCAAF: 1-7 points (threshold = 7)
      // For NCAAB: 1-5 points (threshold = 5)
      return margin >= 1 && margin <= bet.threshold!;
    } else if (bet.statType == 'moderate') {
      // For NCAAF: 8-14 points (threshold = 14, assumes previous range was 7)
      // For NCAAB: 6-10 points (threshold = 10, assumes previous range was 5)
      // Calculate lower bound based on common patterns
      int lowerBound;
      if (bet.threshold! <= 10) {
        // NCAAB pattern: 1-5, 6-10
        lowerBound = 6;
      } else {
        // NCAAF pattern: 1-7, 8-14
        lowerBound = 8;
      }
      return margin >= lowerBound && margin <= bet.threshold!;
    }

    // Default: just check if within threshold (1 to threshold)
    return margin >= 1 && margin <= bet.threshold!;
  }

  /// Check player performance bet
  Future<bool> _checkPlayerPerformance(SimpleBet bet, Map<String, dynamic> gameData) async {
    try {
      // Extract player stats from game data
      final competition = gameData['competition'];
      final competitors = competition?['competitors'] as List? ?? [];

      for (final competitor in competitors) {
        final statistics = competitor['statistics'] as List? ?? [];

        // Look for relevant player stat based on bet.statType
        // This will vary by sport - implement sport-specific logic here
        // For now, return false as a placeholder
      }

      return false;
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error checking player performance: $e');
      return false;
    }
  }

  /// Check team stat threshold bet (e.g., FG%, rebounds, etc.)
  Future<bool> _checkTeamStatThreshold(
    SimpleBet bet,
    Map<String, dynamic> home,
    Map<String, dynamic> away,
    Map<String, dynamic> gameData,
  ) async {
    try {
      if (bet.team == null || bet.threshold == null || bet.statType == null) return false;

      final teamData = bet.team == 'home' ? home : away;
      final statistics = teamData['statistics'] as List? ?? [];

      // Find the relevant stat
      for (final stat in statistics) {
        final name = stat['name']?.toString().toLowerCase() ?? '';

        // Match stat type to ESPN stat name
        if (_matchesStatType(name, bet.statType!)) {
          final value = double.tryParse(stat['displayValue']?.toString() ?? '0') ?? 0.0;
          return value >= bet.threshold!;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error checking team stat: $e');
      return false;
    }
  }

  /// Check special event bet (e.g., overtime, shutout, etc.)
  Future<bool> _checkSpecialEvent(SimpleBet bet, Map<String, dynamic> gameData) async {
    try {
      final competition = gameData['competition'];

      switch (bet.statType) {
        case 'overtime':
          // Check if game went to overtime
          final status = competition?['status']?['type']?['description']?.toString().toLowerCase() ?? '';
          return status.contains('overtime') || status.contains('ot');

        case 'shutout':
          // Check if either team scored 0
          final competitors = competition?['competitors'] as List? ?? [];
          if (competitors.length >= 2) {
            final homeScore = int.tryParse(competitors[0]['score']?.toString() ?? '0') ?? 0;
            final awayScore = int.tryParse(competitors[1]['score']?.toString() ?? '0') ?? 0;
            return homeScore == 0 || awayScore == 0;
          }
          return false;

        case 'comeback':
          // Check if trailing team won - requires detailed play-by-play data
          // Placeholder: return false
          return false;

        default:
          return false;
      }
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error checking special event: $e');
      return false;
    }
  }

  /// Helper: Match stat type to ESPN stat name
  bool _matchesStatType(String espnStatName, String betStatType) {
    final statMap = {
      'fieldGoalPct': ['fieldgoalpct', 'fg%', 'fieldgoal%'],
      'threePointPct': ['threepointpct', '3p%', 'threepoint%'],
      'threesMade': ['threepointfieldgoalsmade', 'threepointmade', '3pm', 'threes', 'threesmade'],
      'rebounds': ['rebounds', 'totalrebounds', 'reb'],
      'assists': ['assists', 'ast'],
      'blocks': ['blocks', 'blk'],
      'steals': ['steals', 'stl'],
      'turnovers': ['turnovers', 'to'],
      'hits': ['hits', 'h'],
      'homeRuns': ['homeruns', 'hr'],
      'possession': ['possession', 'poss%'],
      'shots': ['shots', 'totalshots'],
      'saves': ['saves', 'sv'],
      'goals': ['goals', 'g'],
    };

    final matchTerms = statMap[betStatType] ?? [];
    final normalizedEspnName = espnStatName.replaceAll(' ', '').toLowerCase();

    return matchTerms.any((term) => normalizedEspnName.contains(term));
  }

  /// Batch settle multiple bet slips for a completed game
  Future<void> settleBetsForGame({
    required String gameId,
    required String sport,
  }) async {
    try {
      debugPrint('[SimpleBetSettlement] Settling all bets for game $gameId');

      // Get all pending bet slips for this game
      final pendingBets = await _firestore
          .collection('simple_bet_slips')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'pending')
          .get();

      debugPrint('[SimpleBetSettlement] Found ${pendingBets.docs.length} pending bet slips');

      // Settle each bet slip
      for (final doc in pendingBets.docs) {
        await settleBetSlip(
          betSlipId: doc.id,
          gameId: gameId,
          sport: sport,
        );
      }

      debugPrint('[SimpleBetSettlement] Completed settling bets for game $gameId');
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error settling bets for game: $e');
    }
  }

  /// Award points to user after bet settlement
  Future<void> awardPointsToUser({
    required String userId,
    required String betSlipId,
    required double points,
  }) async {
    try {
      // Update user's points in leaderboard
      await _firestore.collection('users').doc(userId).update({
        'totalPoints': FieldValue.increment(points),
        'betsWon': FieldValue.increment(1),
      });

      debugPrint('[SimpleBetSettlement] Awarded $points points to user $userId');
    } catch (e) {
      debugPrint('[SimpleBetSettlement] Error awarding points: $e');
    }
  }
}
