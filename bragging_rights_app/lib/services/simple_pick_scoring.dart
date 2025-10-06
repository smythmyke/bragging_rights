import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

/// Simple pick scoring system for games without odds
/// Uses team records to calculate underdog bonuses for free tier
class SimplePickScoring {
  /// Calculate user's score for simple picks
  static double calculateScore({
    required List<SimplePick> picks,
    required List<GameResult> results,
  }) {
    double totalScore = 0;

    for (final pick in picks) {
      final result = results.firstWhere(
        (r) => r.gameId == pick.gameId,
        orElse: () => GameResult.empty(),
      );

      // Skip if game not completed
      if (!result.isCompleted) continue;

      // Check if pick was correct
      if (pick.pickedTeam == result.winningTeam) {
        // Base point for correct pick
        double score = 1.0;

        // Apply confidence multiplier (1-5 stars)
        if (pick.confidence != null) {
          // Formula: 0.9x to 1.3x based on confidence
          // 1 star = 0.9x, 2 = 1.0x, 3 = 1.1x, 4 = 1.2x, 5 = 1.3x
          final confidenceMultiplier = 0.8 + (pick.confidence! * 0.1);
          score *= confidenceMultiplier;
        }

        // Apply underdog bonus (NEW for free tier)
        if (result.underdogBonus != null) {
          score += result.underdogBonus!;
        }

        totalScore += score;
      }
    }

    return totalScore;
  }

  /// Calculate payouts for simple pick pools
  static Map<String, int> distributePrizePool({
    required List<UserScore> rankings,
    required int totalPool,
    required int minPayout,
  }) {
    final payouts = <String, int>{};

    if (rankings.isEmpty) return payouts;

    // Winner-takes-all OR top 50% split
    final winnersCount = (rankings.length * 0.5).ceil();

    if (winnersCount == 1) {
      // Winner takes all
      payouts[rankings[0].userId] = totalPool;
    } else {
      // Split among top performers
      final payoutPerWinner = totalPool ~/ winnersCount;

      for (int i = 0; i < winnersCount && i < rankings.length; i++) {
        payouts[rankings[i].userId] = payoutPerWinner;
      }
    }

    return payouts;
  }

  /// Calculate underdog bonus from team records
  /// Formula: (opponentWins - pickedWins) / 20
  /// Example: Picking 3-7 team over 8-2 team = (8 - 3) / 20 = 0.25 bonus
  static double calculateUnderdogBonus({
    required String pickedTeam,
    required String opponentTeam,
    required GameModel game,
  }) {
    // Determine which team was picked
    final pickedHome = pickedTeam == game.homeTeam;

    // Get team records (wins-losses)
    final pickedRecord = pickedHome ? game.homeTeamRecord : game.awayTeamRecord;
    final opponentRecord = pickedHome ? game.awayTeamRecord : game.homeTeamRecord;

    if (pickedRecord == null || opponentRecord == null) {
      return 0.0; // No record data available
    }

    // Parse records (e.g., "10-5" -> 10 wins, 5 losses)
    final pickedWins = _parseWins(pickedRecord);
    final opponentWins = _parseWins(opponentRecord);

    if (pickedWins == null || opponentWins == null) {
      return 0.0; // Couldn't parse records
    }

    // Underdog bonus formula: (opponentWins - pickedWins) / 20
    final bonus = (opponentWins - pickedWins) / 20.0;

    // Cap bonus at 0 (no penalty for picking favorite)
    return bonus > 0 ? bonus : 0.0;
  }

  /// Parse win count from record string (e.g., "10-5" -> 10)
  static int? _parseWins(String record) {
    try {
      final parts = record.split('-');
      if (parts.isEmpty) return null;
      return int.parse(parts[0].trim());
    } catch (e) {
      debugPrint('Error parsing record: $record');
      return null;
    }
  }
}

/// Represents a simple pick made by a user
class SimplePick {
  final String gameId;
  final String pickedTeam;
  final int? confidence; // 1-5 stars (optional)
  final DateTime pickedAt;

  SimplePick({
    required this.gameId,
    required this.pickedTeam,
    this.confidence,
    required this.pickedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'pickedTeam': pickedTeam,
      'confidence': confidence,
      'pickedAt': pickedAt.toIso8601String(),
    };
  }

  factory SimplePick.fromMap(Map<String, dynamic> map) {
    return SimplePick(
      gameId: map['gameId'] ?? '',
      pickedTeam: map['pickedTeam'] ?? '',
      confidence: map['confidence'],
      pickedAt: DateTime.parse(map['pickedAt']),
    );
  }
}

/// Represents the result of a game
class GameResult {
  final String gameId;
  final String? winningTeam;
  final bool isCompleted;
  final double? underdogBonus; // Bonus points for picking underdog (free tier)

  GameResult({
    required this.gameId,
    this.winningTeam,
    required this.isCompleted,
    this.underdogBonus,
  });

  factory GameResult.empty() => GameResult(
    gameId: '',
    isCompleted: false,
  );

  factory GameResult.fromGameModel(dynamic game, {String? pickedTeam}) {
    // Determine winner based on scores
    String? winner;
    if (game.homeScore != null && game.awayScore != null) {
      if (game.homeScore! > game.awayScore!) {
        winner = game.homeTeam;
      } else if (game.awayScore! > game.homeScore!) {
        winner = game.awayTeam;
      }
      // If tied, winner stays null
    }

    // Calculate underdog bonus if picked team is provided
    double? underdogBonus;
    if (pickedTeam != null && winner == pickedTeam && game is GameModel) {
      final opponentTeam = pickedTeam == game.homeTeam ? game.awayTeam : game.homeTeam;
      underdogBonus = SimplePickScoring.calculateUnderdogBonus(
        pickedTeam: pickedTeam,
        opponentTeam: opponentTeam,
        game: game,
      );
    }

    return GameResult(
      gameId: game.id,
      winningTeam: winner,
      isCompleted: game.status == 'final',
      underdogBonus: underdogBonus,
    );
  }
}

/// Represents a user's score in a simple pick pool
class UserScore {
  final String userId;
  final String username;
  final double score;
  final int correctPicks;
  final int totalPicks;
  final DateTime submittedAt; // For tiebreaker

  UserScore({
    required this.userId,
    required this.username,
    required this.score,
    required this.correctPicks,
    required this.totalPicks,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'score': score,
      'correctPicks': correctPicks,
      'totalPicks': totalPicks,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }

  factory UserScore.fromMap(Map<String, dynamic> map) {
    return UserScore(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      correctPicks: map['correctPicks'] ?? 0,
      totalPicks: map['totalPicks'] ?? 0,
      submittedAt: DateTime.parse(map['submittedAt']),
    );
  }
}
