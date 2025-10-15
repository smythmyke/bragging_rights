import 'package:cloud_firestore/cloud_firestore.dart';
import 'simple_bet.dart';

/// Bet slip for simple betting system
/// Contains one required winner bet + optional additional bets
class SimpleBetSlip {
  final String id;
  final String gameId;
  final String userId;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final DateTime gameTime;
  final SimpleBet winnerBet;              // REQUIRED
  final List<SimpleBet> optionalBets;     // User's optional selections
  final int wagerAmount;                  // BR Coins
  final DateTime submittedAt;
  final bool settled;
  final DateTime? settledAt;

  SimpleBetSlip({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.gameTime,
    required this.winnerBet,
    required this.optionalBets,
    required this.wagerAmount,
    required this.submittedAt,
    this.settled = false,
    this.settledAt,
  });

  /// Calculate total potential points if all bets win
  double get totalPotentialPoints {
    double total = winnerBet.potentialPoints;
    for (var bet in optionalBets) {
      total += bet.potentialPoints;
    }
    return total;
  }

  /// Calculate total earned points after settlement
  double? get totalEarnedPoints {
    if (!settled) return null;

    double total = winnerBet.pointsEarned ?? 0;
    for (var bet in optionalBets) {
      total += bet.pointsEarned ?? 0;
    }
    return total;
  }

  /// Get all bets (winner + optional)
  List<SimpleBet> get allBets => [winnerBet, ...optionalBets];

  /// Count of winning bets
  int get winningBetsCount {
    if (!settled) return 0;
    return allBets.where((b) => b.result == true).length;
  }

  /// Count of losing bets
  int get losingBetsCount {
    if (!settled) return 0;
    return allBets.where((b) => b.result == false).length;
  }

  /// Total number of bets placed
  int get totalBetsCount => allBets.length;

  /// Win percentage (after settlement)
  double? get winPercentage {
    if (!settled || totalBetsCount == 0) return null;
    return (winningBetsCount / totalBetsCount) * 100;
  }

  /// Check if winner bet was correct
  bool? get wonWinnerBet => settled ? winnerBet.result : null;

  /// Create a copy with updated fields
  SimpleBetSlip copyWith({
    String? id,
    String? gameId,
    String? userId,
    String? sport,
    String? homeTeam,
    String? awayTeam,
    DateTime? gameTime,
    SimpleBet? winnerBet,
    List<SimpleBet>? optionalBets,
    int? wagerAmount,
    DateTime? submittedAt,
    bool? settled,
    DateTime? settledAt,
  }) {
    return SimpleBetSlip(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      userId: userId ?? this.userId,
      sport: sport ?? this.sport,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      gameTime: gameTime ?? this.gameTime,
      winnerBet: winnerBet ?? this.winnerBet,
      optionalBets: optionalBets ?? this.optionalBets,
      wagerAmount: wagerAmount ?? this.wagerAmount,
      submittedAt: submittedAt ?? this.submittedAt,
      settled: settled ?? this.settled,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'userId': userId,
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'gameTime': Timestamp.fromDate(gameTime),
      'winnerBet': winnerBet.toMap(),
      'optionalBets': optionalBets.map((b) => b.toMap()).toList(),
      'wagerAmount': wagerAmount,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'settled': settled,
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'totalPotentialPoints': totalPotentialPoints,
      'totalEarnedPoints': totalEarnedPoints,
    };
  }

  /// Create from Firestore map
  factory SimpleBetSlip.fromMap(Map<String, dynamic> map) {
    return SimpleBetSlip(
      id: map['id'] ?? '',
      gameId: map['gameId'] ?? '',
      userId: map['userId'] ?? '',
      sport: map['sport'] ?? '',
      homeTeam: map['homeTeam'] ?? '',
      awayTeam: map['awayTeam'] ?? '',
      gameTime: (map['gameTime'] as Timestamp).toDate(),
      winnerBet: SimpleBet.fromMap(map['winnerBet']),
      optionalBets: (map['optionalBets'] as List)
          .map((b) => SimpleBet.fromMap(b))
          .toList(),
      wagerAmount: map['wagerAmount'] ?? 0,
      submittedAt: (map['submittedAt'] as Timestamp).toDate(),
      settled: map['settled'] ?? false,
      settledAt: map['settledAt'] != null
          ? (map['settledAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create from Firestore document
  factory SimpleBetSlip.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SimpleBetSlip.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  @override
  String toString() {
    return 'SimpleBetSlip(gameId: $gameId, sport: $sport, totalBets: $totalBetsCount, potentialPoints: $totalPotentialPoints, settled: $settled)';
  }
}

/// Builder for creating a SimpleBetSlip
class SimpleBetSlipBuilder {
  String? gameId;
  String? userId;
  String? sport;
  String? homeTeam;
  String? awayTeam;
  DateTime? gameTime;
  SimpleBet? winnerBet;
  List<SimpleBet> optionalBets = [];
  int wagerAmount = 0;

  SimpleBetSlipBuilder();

  /// Add the winner bet (required)
  SimpleBetSlipBuilder setWinnerBet(SimpleBet bet) {
    winnerBet = bet;
    return this;
  }

  /// Add an optional bet
  SimpleBetSlipBuilder addOptionalBet(SimpleBet bet) {
    optionalBets.add(bet);
    return this;
  }

  /// Add multiple optional bets
  SimpleBetSlipBuilder addOptionalBets(List<SimpleBet> bets) {
    optionalBets.addAll(bets);
    return this;
  }

  /// Remove an optional bet
  SimpleBetSlipBuilder removeOptionalBet(String betId) {
    optionalBets.removeWhere((b) => b.id == betId);
    return this;
  }

  /// Clear all optional bets
  SimpleBetSlipBuilder clearOptionalBets() {
    optionalBets.clear();
    return this;
  }

  /// Set game info
  SimpleBetSlipBuilder setGameInfo({
    required String gameId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime gameTime,
  }) {
    this.gameId = gameId;
    this.sport = sport;
    this.homeTeam = homeTeam;
    this.awayTeam = awayTeam;
    this.gameTime = gameTime;
    return this;
  }

  /// Set user and wager
  SimpleBetSlipBuilder setUserAndWager({
    required String userId,
    required int wagerAmount,
  }) {
    this.userId = userId;
    this.wagerAmount = wagerAmount;
    return this;
  }

  /// Validate and build
  SimpleBetSlip build() {
    if (gameId == null) throw Exception('Game ID is required');
    if (userId == null) throw Exception('User ID is required');
    if (sport == null) throw Exception('Sport is required');
    if (homeTeam == null) throw Exception('Home team is required');
    if (awayTeam == null) throw Exception('Away team is required');
    if (gameTime == null) throw Exception('Game time is required');
    if (winnerBet == null) throw Exception('Winner bet is required');
    if (wagerAmount <= 0) throw Exception('Wager amount must be positive');

    return SimpleBetSlip(
      id: '', // Will be set by Firestore
      gameId: gameId!,
      userId: userId!,
      sport: sport!,
      homeTeam: homeTeam!,
      awayTeam: awayTeam!,
      gameTime: gameTime!,
      winnerBet: winnerBet!,
      optionalBets: optionalBets,
      wagerAmount: wagerAmount,
      submittedAt: DateTime.now(),
    );
  }
}
