import 'fight_card_model.dart';

/// Rules for a fight card pool
class FightPoolRules {
  final String poolId;
  final bool requireAllFights;         // Must pick every fight?
  final bool allowSkipPrelims;         // Can skip early/prelims?
  final bool allowLatePicks;           // Join after event starts?
  final bool requireAdvancedPicks;     // Method, round required?
  final int minimumPicks;              // Minimum fights to pick
  final bool allowPartialEntry;        // Can enter with incomplete picks?
  final ScoringSystem scoringSystem;
  final DateTime? lockTime;            // When picks lock (null = at fight time)
  
  const FightPoolRules({
    required this.poolId,
    required this.requireAllFights,
    required this.allowSkipPrelims,
    required this.allowLatePicks,
    required this.requireAdvancedPicks,
    required this.minimumPicks,
    required this.allowPartialEntry,
    required this.scoringSystem,
    this.lockTime,
  });
  
  /// Validate if user's picks meet pool requirements
  bool validatePicks(List<Fight> allFights, Map<String, FightPick> picks) {
    // Check if we have minimum required picks
    if (picks.length < minimumPicks) return false;
    
    // If all fights required, check we have them all
    if (requireAllFights) {
      return picks.length == allFights.length;
    }
    
    // If prelims can be skipped, only require main card
    if (allowSkipPrelims) {
      final mainCardFights = allFights.where((f) => f.isMainCard).toList();
      final mainCardPicks = picks.values.where((p) {
        return mainCardFights.any((f) => f.id == p.fightId);
      }).toList();
      
      return mainCardPicks.length == mainCardFights.length;
    }
    
    return true;
  }
  
  /// Get list of required fights based on rules
  List<Fight> getRequiredFights(List<Fight> allFights) {
    if (requireAllFights) {
      return allFights;
    }
    
    if (allowSkipPrelims) {
      return allFights.where((f) => f.isMainCard).toList();
    }
    
    // Return at least the minimum required
    return allFights.take(minimumPicks).toList();
  }
  
  /// Check if a specific fight is required
  bool isFightRequired(Fight fight) {
    if (requireAllFights) return true;
    
    if (allowSkipPrelims && !fight.isMainCard) {
      return false; // Prelims optional
    }
    
    // Main card fights always required when skipPrelims is true
    if (allowSkipPrelims && fight.isMainCard) {
      return true;
    }
    
    return true; // Default to required
  }
  
  /// Calculate adjusted entry fee for late entries
  int calculateLateEntryFee(
    int originalFee,
    List<Fight> allFights,
    DateTime currentTime,
  ) {
    if (!allowLatePicks) return originalFee;
    
    // Count remaining fights
    final remainingFights = allFights.where((f) {
      return f.scheduledTime?.isAfter(currentTime) ?? true;
    }).toList();
    
    // If less than minimum picks available, can't enter
    if (remainingFights.length < minimumPicks) {
      return -1; // Indicates pool closed
    }
    
    // Pro-rate fee based on remaining fights
    final requiredFights = getRequiredFights(allFights);
    final percentage = remainingFights.length / requiredFights.length;
    
    // Round to nearest 5
    final adjustedFee = (originalFee * percentage / 5).round() * 5;
    
    // Minimum fee is 25% of original
    return adjustedFee < originalFee * 0.25 
        ? (originalFee * 0.25).round() 
        : adjustedFee;
  }
  
  // Predefined rule sets for different pool types
  static FightPoolRules quickPlay(String poolId) => FightPoolRules(
    poolId: poolId,
    requireAllFights: false,
    allowSkipPrelims: true,
    allowLatePicks: true,
    requireAdvancedPicks: false,
    minimumPicks: 5, // Main card only
    allowPartialEntry: false,
    scoringSystem: ScoringSystem.simple,
  );
  
  static FightPoolRules regional(String poolId) => FightPoolRules(
    poolId: poolId,
    requireAllFights: false,
    allowSkipPrelims: true,
    allowLatePicks: true,
    requireAdvancedPicks: false,
    minimumPicks: 5,
    allowPartialEntry: false,
    scoringSystem: ScoringSystem.standard,
  );
  
  static FightPoolRules tournament(String poolId) => FightPoolRules(
    poolId: poolId,
    requireAllFights: true,
    allowSkipPrelims: false,
    allowLatePicks: false,
    requireAdvancedPicks: true,
    minimumPicks: 10,
    allowPartialEntry: false,
    scoringSystem: ScoringSystem.tournament,
  );
  
  static FightPoolRules private(
    String poolId, {
    bool requireAll = false,
    bool skipPrelims = true,
    int minPicks = 5,
    ScoringSystem? scoring,
  }) => FightPoolRules(
    poolId: poolId,
    requireAllFights: requireAll,
    allowSkipPrelims: skipPrelims,
    allowLatePicks: true,
    requireAdvancedPicks: false,
    minimumPicks: minPicks,
    allowPartialEntry: true,
    scoringSystem: scoring ?? ScoringSystem.standard,
  );
  
  Map<String, dynamic> toMap() {
    return {
      'poolId': poolId,
      'requireAllFights': requireAllFights,
      'allowSkipPrelims': allowSkipPrelims,
      'allowLatePicks': allowLatePicks,
      'requireAdvancedPicks': requireAdvancedPicks,
      'minimumPicks': minimumPicks,
      'allowPartialEntry': allowPartialEntry,
      'scoringSystem': scoringSystem.toMap(),
      'lockTime': lockTime?.toIso8601String(),
    };
  }
  
  factory FightPoolRules.fromMap(Map<String, dynamic> map, String poolId) {
    // Parse scoring system
    ScoringSystem scoring = ScoringSystem.standard;
    if (map['scoringSystem'] != null) {
      final scoringMap = map['scoringSystem'] as Map<String, dynamic>;
      final name = scoringMap['name'] ?? 'Standard';
      
      switch (name.toLowerCase()) {
        case 'simple':
          scoring = ScoringSystem.simple;
          break;
        case 'advanced':
          scoring = ScoringSystem.advanced;
          break;
        case 'tournament':
          scoring = ScoringSystem.tournament;
          break;
        default:
          scoring = ScoringSystem.standard;
      }
    }
    
    return FightPoolRules(
      poolId: poolId,
      requireAllFights: map['requireAllFights'] ?? false,
      allowSkipPrelims: map['allowSkipPrelims'] ?? true,
      allowLatePicks: map['allowLatePicks'] ?? true,
      requireAdvancedPicks: map['requireAdvancedPicks'] ?? false,
      minimumPicks: map['minimumPicks'] ?? 5,
      allowPartialEntry: map['allowPartialEntry'] ?? false,
      scoringSystem: scoring,
      lockTime: map['lockTime'] != null 
          ? DateTime.parse(map['lockTime'])
          : null,
    );
  }
}

/// Betting session for a fight card
class FightCardBettingSession {
  final String sessionId;
  final String userId;
  final String eventId;
  final String poolId;
  final FightPoolRules rules;
  final List<Fight> fights;
  final Map<String, FightPick> picks;
  final DateTime startedAt;
  DateTime? submittedAt;
  
  FightCardBettingSession({
    required this.sessionId,
    required this.userId,
    required this.eventId,
    required this.poolId,
    required this.rules,
    required this.fights,
    Map<String, FightPick>? picks,
    required this.startedAt,
    this.submittedAt,
  }) : picks = picks ?? {};
  
  // Progress tracking
  List<Fight> get requiredFights => rules.getRequiredFights(fights);
  
  int get requiredPicksCount => requiredFights.length;
  
  int get completedPicksCount => requiredFights
      .where((f) => picks.containsKey(f.id) && picks[f.id]!.isComplete)
      .length;
  
  double get progressPercent => requiredPicksCount > 0 
      ? completedPicksCount / requiredPicksCount 
      : 0.0;
  
  bool get isComplete => completedPicksCount == requiredPicksCount;
  
  // Validation
  bool get canSubmit => rules.validatePicks(fights, picks);
  
  String get statusMessage {
    if (isComplete) {
      return 'All required picks completed';
    }
    
    final remaining = requiredPicksCount - completedPicksCount;
    if (remaining == 1) {
      return '1 pick remaining';
    }
    
    return '$remaining picks remaining';
  }
  
  // Get next unpicked fight
  Fight? get nextUnpickedFight {
    for (final fight in requiredFights) {
      if (!picks.containsKey(fight.id) || !picks[fight.id]!.isComplete) {
        return fight;
      }
    }
    return null;
  }
  
  // Add or update a pick
  void addPick(FightPick pick) {
    picks[pick.fightId] = pick;
  }
  
  // Remove a pick
  void removePick(String fightId) {
    picks.remove(fightId);
  }
  
  // Check if fight has been picked
  bool hasPick(String fightId) {
    return picks.containsKey(fightId) && picks[fightId]!.isComplete;
  }
  
  // Get pick for a fight
  FightPick? getPick(String fightId) {
    return picks[fightId];
  }
  
  // Calculate total potential points
  int calculatePotentialPoints() {
    int total = 0;
    
    for (final pick in picks.values) {
      if (pick.isComplete) {
        // Base winner points
        int potential = rules.scoringSystem.winnerPoints;
        
        // Add method/round bonuses if picked
        if (pick.method != null) {
          potential += rules.scoringSystem.methodPoints;
        }
        if (pick.round != null) {
          potential += rules.scoringSystem.roundPoints;
        }
        
        // Apply confidence multiplier
        final multiplier = rules.scoringSystem.confidenceMultipliers[pick.confidence - 1];
        potential = (potential * multiplier).round();
        
        total += potential;
      }
    }
    
    // Add perfect card bonus potential
    if (picks.length == fights.length) {
      total += rules.scoringSystem.perfectCardBonus;
    } else if (picks.length == fights.where((f) => f.isMainCard).length) {
      total += rules.scoringSystem.perfectMainCardBonus;
    }
    
    return total;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'eventId': eventId,
      'poolId': poolId,
      'rules': rules.toMap(),
      'picks': picks.map((key, value) => MapEntry(key, value.toFirestore())),
      'startedAt': startedAt.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'progressPercent': progressPercent,
      'isComplete': isComplete,
      'canSubmit': canSubmit,
    };
  }
}