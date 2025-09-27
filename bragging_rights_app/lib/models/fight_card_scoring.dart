import 'fight_card_model.dart';
import 'fight_pool_rules.dart';

/// BR-based scoring system for fight cards - NO HOUSE FEES
class FightCardScoring {
  /// Calculate user's score based on correct picks and odds
  static double calculateUserScore({
    required List<FightPick> picks,
    required List<Fight> results,
    required Map<String, FightOdds> odds,
  }) {
    double score = 0;
    
    for (final pick in picks) {
      final result = results.firstWhere(
        (r) => r.id == pick.fightId,
        orElse: () => results.first,
      );
      
      if (!result.isCompleted) continue;
      
      final fightOdds = odds[pick.fightId];
      
      if (pick.winnerId == result.winnerId) {
        // Base point for correct winner
        score += 1.0;
        
        // Underdog bonus (based on odds)
        if (fightOdds != null) {
          final pickedOdds = pick.winnerId == result.fighter1Id
              ? fightOdds.fighter1Odds
              : fightOdds.fighter2Odds;
              
          if (pickedOdds > 0) {
            // Underdog pick - scale bonus by odds
            // +200 = 0.5 bonus, +300 = 0.75 bonus, etc.
            score += (pickedOdds / 400);
          }
        }
        
        // Method bonus (smaller since it's harder)
        if (pick.method != null && pick.method == result.method) {
          score += 0.3;
        }
        
        // Round bonus
        if (pick.round != null && pick.round == result.winRound) {
          score += 0.2;
        }
        
        // Apply confidence multiplier (1-5 stars)
        final pickConfidence = pick.confidence ?? 3; // Default to 3 if null
        final confidenceMultiplier = 0.8 + (pickConfidence * 0.1);
        score *= confidenceMultiplier;
      }
    }
    
    return score;
  }
  
  /// Distribute BR prize pool based on rankings - NO HOUSE CUT
  static Map<String, int> distributePrizePool({
    required List<UserScore> rankings,
    required int totalPool,
    required PoolPayoutStructure structure,
  }) {
    final payouts = <String, int>{};
    
    // 100% of pool goes to winners (no house cut)
    final availablePool = totalPool;
    
    // Calculate number of winners based on structure
    final totalPlayers = rankings.length;
    final winnersCount = (totalPlayers * structure.payoutPercent).ceil();
    
    // Distribute based on position
    for (int i = 0; i < winnersCount && i < rankings.length; i++) {
      final position = i + 1;
      final percentage = structure.getPayoutForPosition(position);
      
      if (percentage > 0) {
        final payout = (availablePool * percentage).round();
        payouts[rankings[i].userId] = payout;
      }
    }
    
    return payouts;
  }
}

/// User score tracking
class UserScore {
  final String userId;
  final String username;
  final double score;
  final int correctPicks;
  final int totalPicks;
  final int underdogWins;
  
  UserScore({
    required this.userId,
    required this.username,
    required this.score,
    required this.correctPicks,
    required this.totalPicks,
    required this.underdogWins,
  });
  
  double get accuracy => totalPicks > 0 ? correctPicks / totalPicks : 0;
  
  String get displayScore => score.toStringAsFixed(1);
  
  String get accuracyDisplay => '${(accuracy * 100).round()}%';
}

/// Odds data for a fight
class FightOdds {
  final String fightId;
  final double fighter1Odds;  // e.g., -350 for favorite
  final double fighter2Odds;  // e.g., +280 for underdog
  final DateTime fetchedAt;
  
  FightOdds({
    required this.fightId,
    required this.fighter1Odds,
    required this.fighter2Odds,
    required this.fetchedAt,
  });
  
  bool get fighter1IsFavorite => fighter1Odds < 0;
  bool get fighter2IsFavorite => fighter2Odds < 0;
  
  String get fighter1OddsDisplay {
    return fighter1Odds > 0 ? '+${fighter1Odds.round()}' : '${fighter1Odds.round()}';
  }
  
  String get fighter2OddsDisplay {
    return fighter2Odds > 0 ? '+${fighter2Odds.round()}' : '${fighter2Odds.round()}';
  }
  
  // Calculate implied probability
  double getFighterProbability(bool isFighter1) {
    final odds = isFighter1 ? fighter1Odds : fighter2Odds;
    
    if (odds < 0) {
      // Favorite formula
      return odds.abs() / (odds.abs() + 100);
    } else {
      // Underdog formula
      return 100 / (odds + 100);
    }
  }
}

/// Pool payout structures - NO HOUSE FEES
class PoolPayoutStructure {
  final String name;
  final double payoutPercent;  // % of players who win something
  final Map<int, double> payouts;  // Position -> % of total pool
  
  const PoolPayoutStructure({
    required this.name,
    required this.payoutPercent,
    required this.payouts,
  });
  
  double getPayoutForPosition(int position) {
    return payouts[position] ?? 0;
  }
  
  // Predefined structures - 100% payout (no house cut)
  static const quickPlay = PoolPayoutStructure(
    name: 'Quick Play',
    payoutPercent: 0.40,  // Top 40% win
    payouts: {
      1: 0.30,   // 30% of pool
      2: 0.20,   // 20% of pool
      3: 0.15,   // 15% of pool
      4: 0.12,   // 12% of pool
      5: 0.08,   // 8% of pool
      6: 0.06,   // 6% of pool
      7: 0.05,   // 5% of pool
      8: 0.04,   // 4% of pool
      // Total: 100% of pool distributed
    },
  );
  
  static const tournament = PoolPayoutStructure(
    name: 'Tournament',
    payoutPercent: 0.25,  // Top 25% win
    payouts: {
      1: 0.40,   // 40% of pool
      2: 0.25,   // 25% of pool
      3: 0.15,   // 15% of pool
      4: 0.10,   // 10% of pool
      5: 0.10,   // 10% of pool
      // Total: 100% of pool distributed
    },
  );
  
  static const winnerTakeAll = PoolPayoutStructure(
    name: 'Winner Take All',
    payoutPercent: 0.05,  // Only winner (top 5%)
    payouts: {
      1: 1.00,   // 100% of pool
    },
  );
  
  static const top3 = PoolPayoutStructure(
    name: 'Top 3',
    payoutPercent: 0.15,  // Top 15% (3 players in 20)
    payouts: {
      1: 0.50,   // 50% of pool
      2: 0.30,   // 30% of pool
      3: 0.20,   // 20% of pool
      // Total: 100% of pool distributed
    },
  );
}

/// Pool statistics and projections
class PoolProjections {
  final int entryFee;
  final int currentPlayers;
  final int expectedPlayers;
  
  PoolProjections({
    required this.entryFee,
    required this.currentPlayers,
    required this.expectedPlayers,
  });
  
  int get currentPool => entryFee * currentPlayers;
  int get projectedPool => entryFee * expectedPlayers;
  
  Map<int, int> getPayoutProjections(PoolPayoutStructure structure) {
    final projections = <int, int>{};
    
    structure.payouts.forEach((position, percentage) {
      projections[position] = (projectedPool * percentage).round();
    });
    
    return projections;
  }
  
  String getPayoutDisplay(int position, PoolPayoutStructure structure) {
    final percentage = structure.getPayoutForPosition(position);
    if (percentage == 0) return '-';
    
    final amount = (projectedPool * percentage).round();
    final profit = amount - entryFee;
    
    return '$amount BR (+$profit)';
  }
}

/// Example pool calculations
class PoolExamples {
  // Quick Play Pool - UFC 310
  static void quickPlayExample() {
    /*
    Entry: 25 BR
    Players: 20
    Total Pool: 500 BR (NO HOUSE CUT)
    
    Top 40% win (8 players):
    1st: 150 BR (profit: +125 BR)
    2nd: 100 BR (profit: +75 BR)
    3rd: 75 BR (profit: +50 BR)
    4th: 60 BR (profit: +35 BR)
    5th: 40 BR (profit: +15 BR)
    6th: 30 BR (profit: +5 BR)
    7th: 25 BR (break even)
    8th: 20 BR (loss: -5 BR)
    
    Players 9-20: Lose 25 BR
    */
  }
  
  // Tournament Pool - UFC 310
  static void tournamentExample() {
    /*
    Entry: 100 BR
    Players: 50
    Total Pool: 5000 BR (NO HOUSE CUT)
    
    Top 25% win (12 players):
    1st: 2000 BR (profit: +1900 BR)
    2nd: 1250 BR (profit: +1150 BR)
    3rd: 750 BR (profit: +650 BR)
    4th: 500 BR (profit: +400 BR)
    5th: 500 BR (profit: +400 BR)
    
    Players 6-50: Lose 100 BR
    */
  }
}