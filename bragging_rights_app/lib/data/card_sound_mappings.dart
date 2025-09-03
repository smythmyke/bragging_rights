/// Sound mapping system for all cards in Bragging Rights
/// Maps each card to specific sounds for different interactions

class CardSoundMappings {
  // Sound file paths (to be copied to assets/sounds/)
  static const String soundsPath = 'assets/sounds/';
  
  /// Power Card Sound Mappings
  static const Map<String, CardSounds> powerCardSounds = {
    // OFFENSIVE CARDS
    'double_down': CardSounds(
      onSelect: 'dice-142528.mp3',  // Dice roll for gambling feel
      onPurchase: 'playful-casino-slot-machine-jackpot-3-183921.mp3',  // Jackpot sound
      onUse: 'magic-ascend-3-259526.mp3',  // Power up sound
    ),
    
    'mulligan': CardSounds(
      onSelect: 'riffle-card-shuffle-104313.mp3',  // Card shuffle
      onPurchase: 'ding-47489.mp3',
      onUse: 'time-freeze-tension-327055.mp3',  // Time manipulation
    ),
    
    'crystal_ball': CardSounds(
      onSelect: 'magic-03-278824.mp3',  // Mystical sound
      onPurchase: 'ding-47489.mp3',
      onUse: '080245_sfx-magic-84935.mp3',  // Magic reveal
    ),
    
    'copycat': CardSounds(
      onSelect: 'laugh-high-pitch-154516.mp3',  // Playful laugh
      onPurchase: 'ding-47489.mp3',
      onUse: '073702_quotwell-aren39t-you-smartquot-89646.mp3',  // Clever sound
    ),
    
    'hot_hand': CardSounds(
      onSelect: 'magic-ascend-3-259526.mp3',  // Fire/heat rising
      onPurchase: 'applause-01-253125.mp3',  // Success
      onUse: 'crowd-applause-113728.mp3',  // Crowd excitement
    ),
    
    'all_in': CardSounds(
      onSelect: 'dice-142528.mp3',  // High stakes
      onPurchase: 'playful-casino-slot-machine-jackpot-3-183921.mp3',
      onUse: 'applause-cheer-236786 (1).mp3',  // Big moment cheer
    ),
    
    // DEFENSIVE CARDS
    'insurance': CardSounds(
      onSelect: 'lock-sound-effect-247455.mp3',  // Security/lock
      onPurchase: 'ding-47489.mp3',
      onUse: '058216_quotcool-breezequot-sample-2wav-39360.mp3',  // Relief sound
    ),
    
    'shield': CardSounds(
      onSelect: 'lock-sound-effect-247455.mp3',  // Protection
      onPurchase: 'technology-inspiration-logo-10-sec-271912.mp3',
      onUse: 'iced-magic-1-378607.mp3',  // Ice shield forming
    ),
    
    'time_freeze': CardSounds(
      onSelect: 'time-freeze-tension-327055.mp3',  // Time stop
      onPurchase: 'ding-47489.mp3',
      onUse: 'time-freeze-tension-327055 (1).mp3',  // Extended freeze
    ),
    
    'split_bet': CardSounds(
      onSelect: 'cards-shuffling-87543.mp3',  // Splitting cards
      onPurchase: 'ding-47489.mp3',
      onUse: 'riffle-card-shuffle-104313.mp3',
    ),
    
    'second_chance': CardSounds(
      onSelect: 'gulp-37759 (1).mp3',  // Second wind
      onPurchase: 'applause-01-253125.mp3',
      onUse: 'magic-ascend-3-259526.mp3',  // Revival
    ),
    
    'hedge': CardSounds(
      onSelect: 'modern-digital-doorbell-sound-325250.mp3',  // Alert
      onPurchase: 'ding-47489.mp3',
      onUse: 'lock-sound-effect-247455.mp3',  // Locking in profits
    ),
    
    // SPECIAL CARDS
    'wildcard': CardSounds(
      onSelect: 'joker-laugh-2-98829.mp3',  // Joker/wildcard theme
      onPurchase: 'playful-casino-slot-machine-jackpot-3-183921.mp3',
      onUse: 'cards-shuffling-87543.mp3',  // Transform sound
    ),
    
    'lucky_charm': CardSounds(
      onSelect: 'magic-03-278824.mp3',  // Lucky magic
      onPurchase: 'applause-cheer-236786 (1).mp3',
      onUse: 'magic-descend-3-259525.mp3',  // Blessing descending
    ),
  };
  
  /// Intel Card Sound Mappings
  static const Map<String, CardSounds> intelCardSounds = {
    'live_game_intel': CardSounds(
      onSelect: 'modern-digital-doorbell-sound-325250.mp3',  // Digital alert
      onPurchase: 'technology-inspiration-logo-10-sec-271912.mp3',
      onUse: 'ding-47489.mp3',  // Data received
    ),
    
    'pre_game_analysis': CardSounds(
      onSelect: 'technology-inspiration-logo-10-sec-271912.mp3',  // Tech sound
      onPurchase: 'ding-47489.mp3',
      onUse: '080245_sfx-magic-84935.mp3',  // Analysis complete
    ),
    
    'expert_picks': CardSounds(
      onSelect: '073702_quotwell-aren39t-you-smartquot-89646.mp3',  // Expert advice
      onPurchase: 'applause-01-253125.mp3',
      onUse: 'crowd-applause-113728.mp3',  // Expert consensus
    ),
    
    'injury_reports': CardSounds(
      onSelect: 'gasp-6253.mp3',  // Surprise/concern
      onPurchase: 'ding-47489.mp3',
      onUse: 'gulp-37759 (1).mp3',  // Concerning news
    ),
    
    'weather_report': CardSounds(
      onSelect: '058216_quotcool-breezequot-sample-2wav-39360.mp3',  // Weather
      onPurchase: 'ding-47489.mp3',
      onUse: 'modern-digital-doorbell-sound-325250.mp3',
    ),
    
    'referee_stats': CardSounds(
      onSelect: 'modern-digital-doorbell-sound-325250.mp3',
      onPurchase: 'ding-47489.mp3',
      onUse: 'technology-inspiration-logo-10-sec-271912.mp3',
    ),
    
    'live_sentiment': CardSounds(
      onSelect: 'crowd-applause-113728.mp3',  // Crowd reaction
      onPurchase: 'ding-47489.mp3',
      onUse: 'applause-cheer-236786 (1).mp3',
    ),
    
    'head_to_head': CardSounds(
      onSelect: 'dice-142528.mp3',  // Competition
      onPurchase: 'ding-47489.mp3',
      onUse: 'technology-inspiration-logo-10-sec-271912.mp3',
    ),
    
    'insider_tips': CardSounds(
      onSelect: 'joker-laugh-2-98829.mp3',  // Secret knowledge
      onPurchase: 'applause-01-253125.mp3',
      onUse: '073702_quotwell-aren39t-you-smartquot-89646.mp3',
    ),
    
    // Duplicate for comprehensive coverage
    'odds_movement': CardSounds(
      onSelect: 'magic-descend-3-259525.mp3',
      onPurchase: 'ding-47489.mp3',
      onUse: 'magic-ascend-3-259526.mp3',
    ),
  };
  
  /// Generic sounds for common actions
  static const CommonSounds commonSounds = CommonSounds(
    insufficientFunds: 'gasp-6253.mp3',  // Can't afford
    navigateToBuyBR: 'modern-digital-doorbell-sound-325250.mp3',  // Redirect alert
    cardActivated: 'magic-03-278824.mp3',  // Card triggers in game
    cardExpired: 'gulp-37759 (1).mp3',  // Card window missed
    strategyLocked: 'lock-sound-effect-247455.mp3',  // Strategy confirmed
  );
  
  /// Get sounds for a specific card
  static CardSounds? getSoundsForCard(String cardId) {
    // Check power cards first
    if (powerCardSounds.containsKey(cardId)) {
      return powerCardSounds[cardId];
    }
    // Then check intel cards
    if (intelCardSounds.containsKey(cardId)) {
      return intelCardSounds[cardId];
    }
    // Return default sounds if not found
    return const CardSounds(
      onSelect: 'ding-47489.mp3',
      onPurchase: 'applause-01-253125.mp3',
      onUse: 'magic-03-278824.mp3',
    );
  }
}

/// Individual card sound configuration
class CardSounds {
  final String onSelect;    // When viewing/selecting in shop
  final String onPurchase;  // When successfully purchased
  final String onUse;       // When card is activated/used
  
  const CardSounds({
    required this.onSelect,
    required this.onPurchase,
    required this.onUse,
  });
  
  String get selectPath => '${CardSoundMappings.soundsPath}$onSelect';
  String get purchasePath => '${CardSoundMappings.soundsPath}$onPurchase';
  String get usePath => '${CardSoundMappings.soundsPath}$onUse';
}

/// Common sounds used across the app
class CommonSounds {
  final String insufficientFunds;
  final String navigateToBuyBR;
  final String cardActivated;
  final String cardExpired;
  final String strategyLocked;
  
  const CommonSounds({
    required this.insufficientFunds,
    required this.navigateToBuyBR,
    required this.cardActivated,
    required this.cardExpired,
    required this.strategyLocked,
  });
  
  String get insufficientPath => '${CardSoundMappings.soundsPath}$insufficientFunds';
  String get navigatePath => '${CardSoundMappings.soundsPath}$navigateToBuyBR';
  String get activatedPath => '${CardSoundMappings.soundsPath}$cardActivated';
  String get expiredPath => '${CardSoundMappings.soundsPath}$cardExpired';
  String get lockedPath => '${CardSoundMappings.soundsPath}$strategyLocked';
}