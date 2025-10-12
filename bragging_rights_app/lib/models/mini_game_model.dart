import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a mini-game available in the app
class MiniGameModel {
  final String id;
  final String name;
  final String embedUrl;
  final String platform; // 'html5_free', 'gamedistribution', 'native'
  final int weekNumber;
  final bool active;
  final String icon;
  final String sportType;
  final String description;
  final int maxScore;

  MiniGameModel({
    required this.id,
    required this.name,
    required this.embedUrl,
    required this.platform,
    required this.weekNumber,
    required this.active,
    required this.icon,
    required this.sportType,
    required this.description,
    required this.maxScore,
  });

  factory MiniGameModel.fromMap(Map<String, dynamic> map) {
    return MiniGameModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      embedUrl: map['embedUrl'] ?? '',
      platform: map['platform'] ?? 'html5_free',
      weekNumber: map['weekNumber'] ?? 1,
      active: map['active'] ?? true,
      icon: map['icon'] ?? 'gameController',
      sportType: map['sportType'] ?? 'general',
      description: map['description'] ?? '',
      maxScore: map['maxScore'] ?? 10000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'embedUrl': embedUrl,
      'platform': platform,
      'weekNumber': weekNumber,
      'active': active,
      'icon': icon,
      'sportType': sportType,
      'description': description,
      'maxScore': maxScore,
    };
  }
}

/// Represents a leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String username;
  final int score;
  final DateTime timestamp;
  final String? avatarUrl;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.score,
    required this.timestamp,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      score: map['score'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      avatarUrl: map['avatarUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'score': score,
      'timestamp': Timestamp.fromDate(timestamp),
      'avatarUrl': avatarUrl,
    };
  }
}

/// Represents a weekly leaderboard for a specific game
class GameLeaderboard {
  final String id;
  final String gameId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<LeaderboardEntry> scores;
  final bool active;

  GameLeaderboard({
    required this.id,
    required this.gameId,
    required this.weekStart,
    required this.weekEnd,
    required this.scores,
    required this.active,
  });

  factory GameLeaderboard.fromMap(Map<String, dynamic> map) {
    final scoresList = (map['scores'] as List<dynamic>?)?.map((scoreMap) {
      return LeaderboardEntry.fromMap(scoreMap as Map<String, dynamic>);
    }).toList() ?? [];

    return GameLeaderboard(
      id: map['id'] ?? '',
      gameId: map['gameId'] ?? '',
      weekStart: (map['weekStart'] as Timestamp).toDate(),
      weekEnd: (map['weekEnd'] as Timestamp).toDate(),
      scores: scoresList,
      active: map['active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'scores': scores.map((entry) => entry.toMap()).toList(),
      'active': active,
    };
  }

  /// Get sorted leaderboard (highest scores first)
  List<LeaderboardEntry> getSortedScores() {
    final sortedScores = List<LeaderboardEntry>.from(scores);
    sortedScores.sort((a, b) => b.score.compareTo(a.score));
    return sortedScores;
  }

  /// Get top N players
  List<LeaderboardEntry> getTopPlayers(int n) {
    final sorted = getSortedScores();
    return sorted.take(n).toList();
  }
}

/// Represents user statistics for a specific game
class UserGameStats {
  final String userId;
  final String gameId;
  final int attempts;
  final int bestScore;
  final int brSpent;
  final DateTime? lastPlayed;

  UserGameStats({
    required this.userId,
    required this.gameId,
    required this.attempts,
    required this.bestScore,
    required this.brSpent,
    this.lastPlayed,
  });

  factory UserGameStats.fromMap(Map<String, dynamic> map) {
    return UserGameStats(
      userId: map['userId'] ?? '',
      gameId: map['gameId'] ?? '',
      attempts: map['attempts'] ?? 0,
      bestScore: map['bestScore'] ?? 0,
      brSpent: map['brSpent'] ?? 0,
      lastPlayed: map['lastPlayed'] != null
          ? (map['lastPlayed'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'gameId': gameId,
      'attempts': attempts,
      'bestScore': bestScore,
      'brSpent': brSpent,
      'lastPlayed': lastPlayed != null ? Timestamp.fromDate(lastPlayed!) : null,
    };
  }
}
