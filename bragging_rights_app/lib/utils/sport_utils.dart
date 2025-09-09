/// Utility class for sport detection and classification
class SportUtils {
  
  /// Combat sports
  static const List<String> combatSportNames = [
    'MMA',      // Mixed Martial Arts (the sport)
    'BOXING',   // Boxing (the sport)
    'FIGHT',    // Generic fight term
  ];
  
  /// MMA promotions (all fall under MMA sport)
  static const List<String> mmaPromotions = [
    'UFC',      // Ultimate Fighting Championship
    'BELLATOR', // Bellator MMA
    'PFL',      // Professional Fighters League
    'INVICTA',  // Invicta FC
    'ONE',      // ONE Championship
    'BKFC',     // Bare Knuckle Fighting Championship
  ];
  
  /// All supported team sports
  static const List<String> teamSports = [
    'NFL',
    'NBA', 
    'NHL',
    'MLB',
    'FOOTBALL',
    'BASKETBALL',
    'HOCKEY',
    'BASEBALL',
  ];
  
  /// All supported individual sports
  static const List<String> individualSports = [
    'TENNIS',
    'GOLF',
  ];
  
  /// Check if a sport is a combat sport (uses fight card grid)
  /// This includes both combat sports (MMA, Boxing) and MMA promotions (UFC, PFL, etc.)
  static bool isCombatSport(String sport) {
    final sportUpper = sport.toUpperCase().trim();
    
    // Check if it's a combat sport name (MMA, Boxing)
    final isCombatSportName = combatSportNames.any((combatSport) => 
        sportUpper.contains(combatSport) || 
        combatSport.contains(sportUpper)
    );
    
    // Check if it's an MMA promotion (UFC, Bellator, etc.) - these are all MMA
    final isMmaPromotion = mmaPromotions.any((promotion) => 
        sportUpper.contains(promotion) || 
        promotion.contains(sportUpper)
    );
    
    return isCombatSportName || isMmaPromotion;
  }
  
  /// Check if a sport is a team sport (uses standard bet selection)
  static bool isTeamSport(String sport) {
    final sportUpper = sport.toUpperCase().trim();
    
    return teamSports.any((teamSport) => 
        sportUpper.contains(teamSport) || 
        teamSport.contains(sportUpper)
    );
  }
  
  /// Check if a sport is an individual sport
  static bool isIndividualSport(String sport) {
    final sportUpper = sport.toUpperCase().trim();
    
    return individualSports.any((individualSport) => 
        sportUpper.contains(individualSport) || 
        individualSport.contains(sportUpper)
    );
  }
  
  /// Get the appropriate navigation route for a sport
  static String getNavigationRoute(String sport) {
    if (isCombatSport(sport)) {
      return '/fight-card-grid';
    }
    return '/bet-selection';
  }
  
  /// Get display name for live betting message
  static String getLiveBettingEventType(String sport) {
    if (isCombatSport(sport)) {
      return 'Fight';
    }
    return 'Game';
  }
  
  /// Check if sport supports props tab
  static bool supportsProps(String sport) {
    // Combat sports typically don't have props tabs (they use method of victory instead)
    // Team sports have player props
    return isTeamSport(sport) || isIndividualSport(sport);
  }
  
  /// Get sport category for debugging/logging
  static String getSportCategory(String sport) {
    if (isCombatSport(sport)) return 'Combat Sport';
    if (isTeamSport(sport)) return 'Team Sport';
    if (isIndividualSport(sport)) return 'Individual Sport';
    return 'Unknown Sport';
  }
  
  /// Get the actual sport name for API calls
  /// Converts MMA promotions (UFC, Bellator, etc.) to 'mma'
  static String getApiSportName(String sport) {
    final sportUpper = sport.toUpperCase().trim();
    
    // If it's an MMA promotion, return 'mma' for API calls
    if (mmaPromotions.any((promotion) => 
        sportUpper.contains(promotion) || 
        promotion.contains(sportUpper))) {
      return 'mma';
    }
    
    // If it's already a sport name, return it in lowercase
    if (combatSportNames.contains(sportUpper)) {
      return sportUpper.toLowerCase();
    }
    
    // For team sports, return as-is in lowercase
    return sport.toLowerCase();
  }
  
  /// Check if this is specifically an MMA promotion (not boxing)
  static bool isMmaPromotion(String sport) {
    final sportUpper = sport.toUpperCase().trim();
    return mmaPromotions.any((promotion) => 
        sportUpper.contains(promotion) || 
        promotion.contains(sportUpper)
    );
  }
}