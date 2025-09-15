import 'package:cloud_firestore/cloud_firestore.dart';

/// Model to track user's bet status for a specific game
class UserBetStatus {
  final String gameId;
  final String userId;
  final DateTime betPlacedAt;
  final List<String> poolIds;
  final double totalAmount;
  final bool isActive;
  final String sport;
  final DateTime gameDate;
  final DateTime lastUpdated;

  UserBetStatus({
    required this.gameId,
    required this.userId,
    required this.betPlacedAt,
    required this.poolIds,
    required this.totalAmount,
    this.isActive = true,
    required this.sport,
    required this.gameDate,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Create from Firestore document
  factory UserBetStatus.fromMap(Map<String, dynamic> map, String gameId) {
    return UserBetStatus(
      gameId: gameId,
      userId: map['userId'] ?? '',
      betPlacedAt: (map['betPlacedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      poolIds: List<String>.from(map['poolIds'] ?? []),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      sport: map['sport'] ?? '',
      gameDate: (map['gameDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create from JSON (for SharedPreferences)
  factory UserBetStatus.fromJson(Map<String, dynamic> json) {
    return UserBetStatus(
      gameId: json['gameId'] ?? '',
      userId: json['userId'] ?? '',
      betPlacedAt: DateTime.parse(json['betPlacedAt'] ?? DateTime.now().toIso8601String()),
      poolIds: List<String>.from(json['poolIds'] ?? []),
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? true,
      sport: json['sport'] ?? '',
      gameDate: DateTime.parse(json['gameDate'] ?? DateTime.now().toIso8601String()),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'betPlacedAt': Timestamp.fromDate(betPlacedAt),
      'poolIds': poolIds,
      'totalAmount': totalAmount,
      'isActive': isActive,
      'sport': sport,
      'gameDate': Timestamp.fromDate(gameDate),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Convert to JSON (for SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'userId': userId,
      'betPlacedAt': betPlacedAt.toIso8601String(),
      'poolIds': poolIds,
      'totalAmount': totalAmount,
      'isActive': isActive,
      'sport': sport,
      'gameDate': gameDate.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Check if the bet is still relevant (game hasn't passed by more than 7 days)
  bool get isRelevant {
    final now = DateTime.now();
    final daysSinceGame = now.difference(gameDate).inDays;
    return daysSinceGame < 7;
  }

  /// Create a copy with updated fields
  UserBetStatus copyWith({
    String? gameId,
    String? userId,
    DateTime? betPlacedAt,
    List<String>? poolIds,
    double? totalAmount,
    bool? isActive,
    String? sport,
    DateTime? gameDate,
    DateTime? lastUpdated,
  }) {
    return UserBetStatus(
      gameId: gameId ?? this.gameId,
      userId: userId ?? this.userId,
      betPlacedAt: betPlacedAt ?? this.betPlacedAt,
      poolIds: poolIds ?? this.poolIds,
      totalAmount: totalAmount ?? this.totalAmount,
      isActive: isActive ?? this.isActive,
      sport: sport ?? this.sport,
      gameDate: gameDate ?? this.gameDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}