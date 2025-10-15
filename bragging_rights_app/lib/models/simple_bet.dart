import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple betting system - Binary yes/no predictions without odds
/// Used for all sports except NFL (which uses odds-based betting)
class SimpleBet {
  final String id;
  final String betType;          // 'winner', 'team_score_threshold', 'total_score_threshold', 'margin', etc.
  final String description;      // Display text: "Lakers score 110+ points"
  final bool selection;          // User's selection: true = yes, false = no
  final int basePoints;          // 1, 2, or 3 points
  final int confidence;          // 1-5 stars
  final double multiplier;       // Confidence multiplier (1.0, 1.5, 2.0, 2.5, 3.0)
  final String? team;            // 'home', 'away', or null for game-wide bets
  final double? threshold;       // Numeric threshold (110 points, 10 margin, etc.)
  final String? statType;        // For team stat bets: 'threes', 'assists', 'rebounds', etc.
  final bool isRequired;         // True for winner pick (mandatory)
  final bool? result;            // null before settlement, true/false after
  final double? pointsEarned;    // Calculated after settlement

  SimpleBet({
    required this.id,
    required this.betType,
    required this.description,
    required this.selection,
    required this.basePoints,
    required this.confidence,
    required this.multiplier,
    this.team,
    this.threshold,
    this.statType,
    this.isRequired = false,
    this.result,
    this.pointsEarned,
  });

  /// Calculate potential points (base × multiplier)
  double get potentialPoints => basePoints * multiplier;

  /// Convert confidence (1-5) to multiplier
  static double getMultiplier(int confidence) {
    switch (confidence) {
      case 1: return 1.0;
      case 2: return 1.5;
      case 3: return 2.0;
      case 4: return 2.5;
      case 5: return 3.0;
      default: return 1.0;
    }
  }

  /// Create a copy with updated fields
  SimpleBet copyWith({
    String? id,
    String? betType,
    String? description,
    bool? selection,
    int? basePoints,
    int? confidence,
    double? multiplier,
    String? team,
    double? threshold,
    String? statType,
    bool? isRequired,
    bool? result,
    double? pointsEarned,
  }) {
    return SimpleBet(
      id: id ?? this.id,
      betType: betType ?? this.betType,
      description: description ?? this.description,
      selection: selection ?? this.selection,
      basePoints: basePoints ?? this.basePoints,
      confidence: confidence ?? this.confidence,
      multiplier: multiplier ?? this.multiplier,
      team: team ?? this.team,
      threshold: threshold ?? this.threshold,
      statType: statType ?? this.statType,
      isRequired: isRequired ?? this.isRequired,
      result: result ?? this.result,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'betType': betType,
      'description': description,
      'selection': selection,
      'basePoints': basePoints,
      'confidence': confidence,
      'multiplier': multiplier,
      'team': team,
      'threshold': threshold,
      'statType': statType,
      'isRequired': isRequired,
      'result': result,
      'pointsEarned': pointsEarned,
    };
  }

  /// Create from Firestore map
  factory SimpleBet.fromMap(Map<String, dynamic> map) {
    return SimpleBet(
      id: map['id'] ?? '',
      betType: map['betType'] ?? '',
      description: map['description'] ?? '',
      selection: map['selection'] ?? false,
      basePoints: map['basePoints'] ?? 1,
      confidence: map['confidence'] ?? 1,
      multiplier: (map['multiplier'] ?? 1.0).toDouble(),
      team: map['team'],
      threshold: map['threshold']?.toDouble(),
      statType: map['statType'],
      isRequired: map['isRequired'] ?? false,
      result: map['result'],
      pointsEarned: map['pointsEarned']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'SimpleBet(id: $id, description: $description, basePoints: $basePoints, confidence: $confidence, potentialPoints: $potentialPoints)';
  }
}

/// Template for creating simple bets (before user selection)
class SimpleBetTemplate {
  final String betType;
  final String descriptionTemplate;  // Use {home} and {away} placeholders
  final int basePoints;
  final String? team;
  final double? threshold;
  final String? statType;
  final bool isRequired;

  SimpleBetTemplate({
    required this.betType,
    required this.descriptionTemplate,
    required this.basePoints,
    this.team,
    this.threshold,
    this.statType,
    this.isRequired = false,
  });

  /// Create a SimpleBet instance from this template
  SimpleBet createBet({
    required String id,
    required String homeTeam,
    required String awayTeam,
    int confidence = 1,
  }) {
    // Replace placeholders in description
    final description = descriptionTemplate
        .replaceAll('{home}', homeTeam)
        .replaceAll('{away}', awayTeam);

    return SimpleBet(
      id: id,
      betType: betType,
      description: description,
      selection: false,
      basePoints: basePoints,
      confidence: confidence,
      multiplier: SimpleBet.getMultiplier(confidence),
      team: team,
      threshold: threshold,
      statType: statType,
      isRequired: isRequired,
    );
  }
}

/// Configuration for a tab of bets
class BetTabConfig {
  final String name;
  final dynamic icon;  // IconData
  final List<SimpleBetTemplate> bets;
  final String? description;  // Optional tab description

  BetTabConfig({
    required this.name,
    required this.icon,
    required this.bets,
    this.description,
  });

  /// Check if this tab has the required winner bet
  bool get hasRequiredBet => bets.any((b) => b.isRequired);
}
