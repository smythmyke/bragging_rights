class IntelProduct {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String detailedDescription;
  final int price;
  final String imagePath;
  
  const IntelProduct({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.detailedDescription,
    required this.price,
    required this.imagePath,
  });
}

class IntelProducts {
  static final List<IntelProduct> all = [
    IntelProduct(
      id: 'live_game_intel',
      name: 'Live Game Intel',
      icon: '⚡',
      description: 'Real-time insights',
      detailedDescription: 'Get real-time data feeds, momentum shifts, and critical game moments as they happen. Updated every 30 seconds during live games.',
      price: 250,
      imagePath: 'assets/images/cards/live_game_intel.png',
    ),
    IntelProduct(
      id: 'pre_game_analysis',
      name: 'Pre-Game Analysis',
      icon: '📊',
      description: 'Statistical breakdown',
      detailedDescription: 'Comprehensive pre-game statistics, head-to-head history, recent form analysis, and key player matchups.',
      price: 150,
      imagePath: 'assets/images/cards/pre_game_analysis.png',
    ),
    IntelProduct(
      id: 'expert_picks',
      name: 'Expert Picks',
      icon: '🎯',
      description: 'Pro predictions',
      detailedDescription: 'Access predictions from verified sports analysts with 70%+ accuracy. See consensus picks and contrarian plays.',
      price: 300,
      imagePath: 'assets/images/cards/expert_picks.png',
    ),
    IntelProduct(
      id: 'injury_reports',
      name: 'Injury Reports',
      icon: '🏥',
      description: 'Latest updates',
      detailedDescription: 'Real-time injury updates, player availability status, and impact analysis on game outcomes.',
      price: 100,
      imagePath: 'assets/images/cards/injury_reports.png',
    ),
  ];
}