import 'package:flutter/foundation.dart';

/// Simple pick scoring system for games without odds
/// Similar to MMA fight card scoring but adapted for team sports
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

  GameResult({
    required this.gameId,
    this.winningTeam,
    required this.isCompleted,
  });

  factory GameResult.empty() => GameResult(
    gameId: '',
    isCompleted: false,
  );

  factory GameResult.fromGameModel(dynamic game) {
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

    return GameResult(
      gameId: game.id,
      winningTeam: winner,
      isCompleted: game.status == 'final',
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
