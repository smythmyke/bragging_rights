/// Betting models for Bragging Rights app
/// Supports various bet types with American odds display

enum BetType {
  moneyline,
  spread,
  total,
  playerProp,
  gameProp,
  parlay,
}

enum Sport {
  nba,
  nfl,
  mlb,
  nhl,
  soccer,
  tennis,
  golf,
  mma,
}

class BettingOption {
  final String id;
  final String gameId;
  final BetType type;
  final String description;
  final Map<String, dynamic> options;
  final DateTime? expiresAt;
  final bool isLive;
  final Sport sport;

  BettingOption({
    required this.id,
    required this.gameId,
    required this.type,
    required this.description,
    required this.options,
    this.expiresAt,
    this.isLive = false,
    required this.sport,
  });

  factory BettingOption.fromJson(Map<String, dynamic> json) {
    return BettingOption(
      id: json['id'],
      gameId: json['gameId'],
      type: BetType.values.firstWhere((e) => e.name == json['type']),
      description: json['description'],
      options: json['options'],
      expiresAt: json['expiresAt'] != null 
        ? DateTime.parse(json['expiresAt']) 
        : null,
      isLive: json['isLive'] ?? false,
      sport: Sport.values.firstWhere((e) => e.name == json['sport']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'type': type.name,
    'description': description,
    'options': options,
    'expiresAt': expiresAt?.toIso8601String(),
    'isLive': isLive,
    'sport': sport.name,
  };
}

class AmericanOdds {
  final int value;
  final double impliedProbability;
  final double payout;

  AmericanOdds({
    required this.value,
    required this.impliedProbability,
    required this.payout,
  });

  static AmericanOdds fromValue(int odds) {
    double probability;
    double payoutMultiplier;
    
    if (odds > 0) {
      probability = 100 / (odds + 100);
      payoutMultiplier = (odds / 100) + 1;
    } else {
      probability = -odds / (-odds + 100);
      payoutMultiplier = (100 / -odds) + 1;
    }
    
    return AmericanOdds(
      value: odds,
      impliedProbability: probability,
      payout: payoutMultiplier,
    );
  }

  String get displayValue {
    return value > 0 ? '+$value' : '$value';
  }

  double calculatePayout(double wager) {
    return wager * payout;
  }

  double calculateProfit(double wager) {
    return calculatePayout(wager) - wager;
  }
}

class BetSlip {
  final List<BetSlipItem> items;
  final double totalWager;
  final double potentialPayout;
  final bool isParlay;
  final int maxParlayLegs = 8;

  BetSlip({
    required this.items,
    required this.totalWager,
    required this.potentialPayout,
    this.isParlay = false,
  });

  bool canAddToParlay() {
    return isParlay && items.length < maxParlayLegs;
  }

  double calculateParlayOdds() {
    if (!isParlay || items.isEmpty) return 0;
    
    double combinedOdds = 1;
    for (var item in items) {
      combinedOdds *= item.odds.payout;
    }
    return combinedOdds;
  }

  double calculateParlayPayout(double wager) {
    return wager * calculateParlayOdds();
  }
}

class BetSlipItem {
  final String id;
  final BettingOption option;
  final String selection;
  final AmericanOdds odds;
  final double wager;

  BetSlipItem({
    required this.id,
    required this.option,
    required this.selection,
    required this.odds,
    required this.wager,
  });

  double get potentialPayout => odds.calculatePayout(wager);
  double get potentialProfit => odds.calculateProfit(wager);
}

class GameOdds {
  final String gameId;
  final String homeTeam;
  final String awayTeam;
  final DateTime gameTime;
  final Sport sport;
  final Map<String, dynamic> moneyline;
  final Map<String, dynamic>? spread;
  final Map<String, dynamic>? total;
  final List<BettingOption> propBets;
  final bool isLive;

  GameOdds({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.gameTime,
    required this.sport,
    required this.moneyline,
    this.spread,
    this.total,
    this.propBets = const [],
    this.isLive = false,
  });

  List<BettingOption> getAllBettingOptions() {
    List<BettingOption> options = [];
    
    // Moneyline
    options.add(BettingOption(
      id: '${gameId}_ml',
      gameId: gameId,
      type: BetType.moneyline,
      description: 'Moneyline',
      options: moneyline,
      sport: sport,
      isLive: isLive,
    ));
    
    // Spread
    if (spread != null) {
      options.add(BettingOption(
        id: '${gameId}_spread',
        gameId: gameId,
        type: BetType.spread,
        description: 'Point Spread',
        options: spread!,
        sport: sport,
        isLive: isLive,
      ));
    }
    
    // Total
    if (total != null) {
      options.add(BettingOption(
        id: '${gameId}_total',
        gameId: gameId,
        type: BetType.total,
        description: 'Total Points',
        options: total!,
        sport: sport,
        isLive: isLive,
      ));
    }
    
    // Props
    options.addAll(propBets);
    
    return options;
  }
}

// Predefined BR amounts
enum BRAmount {
  ten(10),
  twentyFive(25),
  fifty(50),
  hundred(100),
  custom(0);

  final int value;
  const BRAmount(this.value);
}