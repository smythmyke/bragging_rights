enum CardType {
  offensive,
  defensive,
  special,
}

enum CardRarity {
  common,
  uncommon,
  rare,
  legendary,
}

class PowerCard {
  final String id;
  final String name;
  final String icon;
  final CardType type;
  final String whenToUse;
  final String effect;
  final String howToUse;
  final CardRarity rarity;
  int quantity;

  PowerCard({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.whenToUse,
    required this.effect,
    required this.howToUse,
    required this.rarity,
    this.quantity = 0,
  });

  PowerCard copyWith({int? quantity}) {
    return PowerCard(
      id: id,
      name: name,
      icon: icon,
      type: type,
      whenToUse: whenToUse,
      effect: effect,
      howToUse: howToUse,
      rarity: rarity,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CardDefinitions {
  static final Map<String, PowerCard> allCards = {
    // Offensive Cards
    'double_down': PowerCard(
      id: 'double_down',
      name: 'Double Down',
      icon: '🎯',
      type: CardType.offensive,
      whenToUse: 'Before halftime',
      effect: 'Double your winnings if your pick wins',
      howToUse: 'Tap card during live game before halftime. Risk doubles but so does reward.',
      rarity: CardRarity.common,
    ),
    'mulligan': PowerCard(
      id: 'mulligan',
      name: 'Mulligan',
      icon: '🔄',
      type: CardType.offensive,
      whenToUse: 'Before game starts',
      effect: 'Change your pick once after making it',
      howToUse: 'Use in pool details screen before the game locks. One-time use per pool.',
      rarity: CardRarity.common,
    ),
    'crystal_ball': PowerCard(
      id: 'crystal_ball',
      name: 'Crystal Ball',
      icon: '🔮',
      type: CardType.offensive,
      whenToUse: 'Before making pick',
      effect: 'See what percentage of players picked each team',
      howToUse: 'Activate before submitting your pick to see crowd sentiment.',
      rarity: CardRarity.uncommon,
    ),
    'copycat': PowerCard(
      id: 'copycat',
      name: 'Copycat',
      icon: '🐱',
      type: CardType.offensive,
      whenToUse: 'Before game starts',
      effect: 'Copy the pick of the current pool leader',
      howToUse: 'Automatically matches your pick to the top-ranked player in the pool.',
      rarity: CardRarity.uncommon,
    ),
    'hot_hand': PowerCard(
      id: 'hot_hand',
      name: 'Hot Hand',
      icon: '🔥',
      type: CardType.offensive,
      whenToUse: 'During win streak',
      effect: '1.5x multiplier when on a 3+ game win streak',
      howToUse: 'Auto-activates when you have won 3 or more pools in a row.',
      rarity: CardRarity.rare,
    ),
    'all_in': PowerCard(
      id: 'all_in',
      name: 'All In',
      icon: '💎',
      type: CardType.offensive,
      whenToUse: 'Before game starts',
      effect: 'Triple winnings but lose double if wrong',
      howToUse: 'High risk, high reward. Activate when extremely confident.',
      rarity: CardRarity.legendary,
    ),

    // Defensive Cards
    'insurance': PowerCard(
      id: 'insurance',
      name: 'Insurance',
      icon: '🛡️',
      type: CardType.defensive,
      whenToUse: 'Before 4th quarter',
      effect: 'Get 50% refund if you lose',
      howToUse: 'Activate before the 4th quarter starts to protect half your buy-in.',
      rarity: CardRarity.common,
    ),
    'shield': PowerCard(
      id: 'shield',
      name: 'Shield',
      icon: '🛡️',
      type: CardType.defensive,
      whenToUse: 'When targeted',
      effect: 'Block one offensive card used against you',
      howToUse: 'Auto-activates when an opponent uses a sabotage or steal card on you.',
      rarity: CardRarity.uncommon,
    ),
    'time_freeze': PowerCard(
      id: 'time_freeze',
      name: 'Time Freeze',
      icon: '⏰',
      type: CardType.defensive,
      whenToUse: 'Near pool closing',
      effect: 'Extend pick deadline by 15 minutes',
      howToUse: 'Use when you need more time to research before the pool locks.',
      rarity: CardRarity.uncommon,
    ),
    'split_bet': PowerCard(
      id: 'split_bet',
      name: 'Split Bet',
      icon: '↔️',
      type: CardType.defensive,
      whenToUse: 'Before halftime',
      effect: 'Bet on both teams for guaranteed small win',
      howToUse: 'Reduces risk by splitting your bet. Win less but never lose completely.',
      rarity: CardRarity.common,
    ),
    'second_chance': PowerCard(
      id: 'second_chance',
      name: 'Second Chance',
      icon: '♻️',
      type: CardType.defensive,
      whenToUse: 'After losing',
      effect: 'Re-enter the same pool once after elimination',
      howToUse: 'Only for elimination pools. Get back in after your first loss.',
      rarity: CardRarity.rare,
    ),
    'hedge': PowerCard(
      id: 'hedge',
      name: 'Hedge',
      icon: '⚖️',
      type: CardType.defensive,
      whenToUse: 'During game',
      effect: 'Lock in current winnings at reduced rate',
      howToUse: 'Cash out early for 60-80% of potential winnings based on game state.',
      rarity: CardRarity.uncommon,
    ),

    // Special Cards (Count as either offensive or defensive)
    'wildcard': PowerCard(
      id: 'wildcard',
      name: 'Wildcard',
      icon: '🃏',
      type: CardType.special,
      whenToUse: 'Anytime',
      effect: 'Acts as any common card of your choice',
      howToUse: 'Transform into any common offensive or defensive card when used.',
      rarity: CardRarity.rare,
    ),
    'lucky_charm': PowerCard(
      id: 'lucky_charm',
      name: 'Lucky Charm',
      icon: '🍀',
      type: CardType.special,
      whenToUse: 'Before picking',
      effect: '+15% win probability boost',
      howToUse: 'Mysterious boost to your chances. The algorithm favors you slightly.',
      rarity: CardRarity.legendary,
    ),
  };

  static List<PowerCard> getOffensiveCards() {
    return allCards.values
        .where((card) => card.type == CardType.offensive)
        .toList();
  }

  static List<PowerCard> getDefensiveCards() {
    return allCards.values
        .where((card) => card.type == CardType.defensive)
        .toList();
  }

  static List<PowerCard> getSpecialCards() {
    return allCards.values
        .where((card) => card.type == CardType.special)
        .toList();
  }

  static PowerCard? getCard(String id) {
    return allCards[id];
  }

  static String getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return '#808080'; // Gray
      case CardRarity.uncommon:
        return '#00FF00'; // Green
      case CardRarity.rare:
        return '#0080FF'; // Blue
      case CardRarity.legendary:
        return '#FF8000'; // Orange
    }
  }
}