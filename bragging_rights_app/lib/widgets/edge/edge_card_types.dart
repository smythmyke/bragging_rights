import 'package:flutter/material.dart';

/// Enum defining all Edge Intelligence card categories
enum EdgeCardCategory {
  injury,
  weather,
  social,
  matchup,
  breaking,
  betting,
  insider,
  clutch,
}

/// Configuration for each card category
class EdgeCardConfig {
  final EdgeCardCategory category;
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final String previewText;
  final int baseCost;
  final EdgeCardPriority priority;
  final EdgeCardRarity defaultRarity;

  const EdgeCardConfig({
    required this.category,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.previewText,
    required this.baseCost,
    required this.priority,
    required this.defaultRarity,
  });
}

/// Priority levels for card ordering
enum EdgeCardPriority {
  highest,
  high,
  medium,
  low,
}

/// Rarity tiers for gamification
enum EdgeCardRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

/// Badge types for card indicators
enum EdgeCardBadge {
  newItem,
  hot,
  exclusive,
  verified,
  breaking,
  trending,
  views,
}

/// Card configurations map
class EdgeCardConfigs {
  static const Map<EdgeCardCategory, EdgeCardConfig> configs = {
    EdgeCardCategory.injury: EdgeCardConfig(
      category: EdgeCardCategory.injury,
      title: 'Injury Intelligence',
      icon: Icons.local_hospital,
      gradientColors: [Color(0xFFFF6B6B), Color(0xFFFFA502)],
      previewText: 'Injury Concern Detected',
      baseCost: 15,
      priority: EdgeCardPriority.high,
      defaultRarity: EdgeCardRarity.rare,
    ),
    EdgeCardCategory.weather: EdgeCardConfig(
      category: EdgeCardCategory.weather,
      title: 'Weather Impact',
      icon: Icons.cloud,
      gradientColors: [Color(0xFF4834D4), Color(0xFF95A5A6)],
      previewText: 'Weather Alert - Game Impact',
      baseCost: 10,
      priority: EdgeCardPriority.medium,
      defaultRarity: EdgeCardRarity.uncommon,
    ),
    EdgeCardCategory.social: EdgeCardConfig(
      category: EdgeCardCategory.social,
      title: 'Social Sentiment',
      icon: Icons.trending_up,
      gradientColors: [Color(0xFFFF4500), Color(0xFF1DA1F2)],
      previewText: 'Fan Buzz Detected',
      baseCost: 5,
      priority: EdgeCardPriority.low,
      defaultRarity: EdgeCardRarity.common,
    ),
    EdgeCardCategory.matchup: EdgeCardConfig(
      category: EdgeCardCategory.matchup,
      title: 'Matchup Analysis',
      icon: Icons.compare_arrows,
      gradientColors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
      previewText: 'Critical Matchup Intel',
      baseCost: 10,
      priority: EdgeCardPriority.medium,
      defaultRarity: EdgeCardRarity.uncommon,
    ),
    EdgeCardCategory.breaking: EdgeCardConfig(
      category: EdgeCardCategory.breaking,
      title: 'Breaking News',
      icon: Icons.bolt,
      gradientColors: [Color(0xFFFFC107), Color(0xFFFFD700)],
      previewText: 'Breaking:',
      baseCost: 20,
      priority: EdgeCardPriority.highest,
      defaultRarity: EdgeCardRarity.epic,
    ),
    EdgeCardCategory.betting: EdgeCardConfig(
      category: EdgeCardCategory.betting,
      title: 'Betting Movement',
      icon: Icons.show_chart,
      gradientColors: [Color(0xFF00B894), Color(0xFF00D2D3)],
      previewText: 'Sharp Money Alert',
      baseCost: 15,
      priority: EdgeCardPriority.high,
      defaultRarity: EdgeCardRarity.rare,
    ),
    EdgeCardCategory.insider: EdgeCardConfig(
      category: EdgeCardCategory.insider,
      title: 'Insider/Camp',
      icon: Icons.fitness_center,
      gradientColors: [Color(0xFF2C3E50), Color(0xFF34495E)],
      previewText: 'Training Camp Intel',
      baseCost: 15,
      priority: EdgeCardPriority.high,
      defaultRarity: EdgeCardRarity.rare,
    ),
    EdgeCardCategory.clutch: EdgeCardConfig(
      category: EdgeCardCategory.clutch,
      title: 'Clutch Performance',
      icon: Icons.timer,
      gradientColors: [Color(0xFFFFD700), Color(0xFFB8860B)],
      previewText: 'Clutch Factor Analysis',
      baseCost: 10,
      priority: EdgeCardPriority.medium,
      defaultRarity: EdgeCardRarity.uncommon,
    ),
  };

  /// Get configuration for a category
  static EdgeCardConfig getConfig(EdgeCardCategory category) {
    return configs[category]!;
  }
  
  /// Get generic teaser text for a category (non-revealing)
  static String getGenericTeaser(EdgeCardCategory category) {
    switch (category) {
      case EdgeCardCategory.injury:
        return 'Player health intelligence detected';
      case EdgeCardCategory.weather:
        return 'Environmental factors may impact game';
      case EdgeCardCategory.social:
        return 'Fan sentiment data available';
      case EdgeCardCategory.matchup:
        return 'Historical pattern identified';
      case EdgeCardCategory.breaking:
        return 'Time-sensitive information available';
      case EdgeCardCategory.betting:
        return 'Market movement detected';
      case EdgeCardCategory.insider:
        return 'Exclusive source intelligence';
      case EdgeCardCategory.clutch:
        return 'Critical moment analysis available';
    }
  }
  
  /// Get obfuscated title for a category (non-revealing)
  static String getObfuscatedTitle(EdgeCardCategory category, String teamName) {
    switch (category) {
      case EdgeCardCategory.injury:
        return '$teamName - Health Intel';
      case EdgeCardCategory.weather:
        return 'Game Environment Alert';
      case EdgeCardCategory.social:
        return '$teamName - Sentiment Data';
      case EdgeCardCategory.matchup:
        return 'Matchup Intelligence';
      case EdgeCardCategory.breaking:
        return 'Breaking Intel - $teamName';
      case EdgeCardCategory.betting:
        return 'Market Alert';
      case EdgeCardCategory.insider:
        return '$teamName - Inside Info';
      case EdgeCardCategory.clutch:
        return 'Performance Metrics';
    }
  }

  /// Get rarity color
  static Color getRarityColor(EdgeCardRarity rarity) {
    switch (rarity) {
      case EdgeCardRarity.common:
        return Colors.grey;
      case EdgeCardRarity.uncommon:
        return Colors.green;
      case EdgeCardRarity.rare:
        return Colors.blue;
      case EdgeCardRarity.epic:
        return Colors.purple;
      case EdgeCardRarity.legendary:
        return Colors.orange;
    }
  }

  /// Get rarity glow color (for effects)
  static Color getRarityGlowColor(EdgeCardRarity rarity) {
    switch (rarity) {
      case EdgeCardRarity.common:
        return Colors.grey.withOpacity(0.3);
      case EdgeCardRarity.uncommon:
        return Colors.green.withOpacity(0.4);
      case EdgeCardRarity.rare:
        return Colors.blue.withOpacity(0.5);
      case EdgeCardRarity.epic:
        return Colors.purple.withOpacity(0.6);
      case EdgeCardRarity.legendary:
        return Colors.orange.withOpacity(0.7);
    }
  }

  /// Get badge icon
  static IconData getBadgeIcon(EdgeCardBadge badge) {
    switch (badge) {
      case EdgeCardBadge.newItem:
        return Icons.fiber_new;
      case EdgeCardBadge.hot:
        return Icons.local_fire_department;
      case EdgeCardBadge.exclusive:
        return Icons.lock_outline;
      case EdgeCardBadge.verified:
        return Icons.verified;
      case EdgeCardBadge.breaking:
        return Icons.bolt;
      case EdgeCardBadge.trending:
        return Icons.trending_up;
      case EdgeCardBadge.views:
        return Icons.remove_red_eye;
    }
  }

  /// Get badge color
  static Color getBadgeColor(EdgeCardBadge badge) {
    switch (badge) {
      case EdgeCardBadge.newItem:
        return Colors.blue;
      case EdgeCardBadge.hot:
        return Colors.red;
      case EdgeCardBadge.exclusive:
        return Colors.purple;
      case EdgeCardBadge.verified:
        return Colors.green;
      case EdgeCardBadge.breaking:
        return Colors.orange;
      case EdgeCardBadge.trending:
        return Colors.teal;
      case EdgeCardBadge.views:
        return Colors.grey;
    }
  }
}

/// Model for Edge Card data
class EdgeCardData {
  final String id;
  final EdgeCardCategory category;
  final String title;
  final String teaserText;
  final String fullContent;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final EdgeCardRarity rarity;
  final List<EdgeCardBadge> badges;
  final int currentCost;
  final double confidence;
  final String? impactText;
  final bool isLocked;
  final int? viewCount;
  final DateTime? expiresAt;

  EdgeCardData({
    required this.id,
    required this.category,
    required this.title,
    required this.teaserText,
    required this.fullContent,
    required this.metadata,
    required this.timestamp,
    required this.rarity,
    this.badges = const [],
    required this.currentCost,
    required this.confidence,
    this.impactText,
    this.isLocked = true,
    this.viewCount,
    this.expiresAt,
  });

  /// Check if card is fresh (less than 2 hours old)
  bool get isFresh => DateTime.now().difference(timestamp).inHours < 2;

  /// Check if card is expiring soon (less than 15 minutes)
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return expiresAt!.difference(DateTime.now()).inMinutes < 15;
  }

  /// Get age text
  String get ageText {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Calculate dynamic price based on modifiers
  int calculateDynamicPrice(DateTime gameTime) {
    final config = EdgeCardConfigs.getConfig(category);
    int price = currentCost;

    // Freshness modifier
    if (isFresh) price += 5;

    // Game proximity modifier
    final timeToGame = gameTime.difference(DateTime.now());
    if (timeToGame.inMinutes < 30) {
      price = (price * 1.5).round();
    } else if (timeToGame.inMinutes < 60) {
      price = (price * 1.3).round();
    } else if (timeToGame.inHours < 3) {
      price = (price * 1.1).round();
    } else if (timeToGame.inHours > 24) {
      price = (price * 0.8).round();
    }

    // Rarity modifier
    switch (rarity) {
      case EdgeCardRarity.legendary:
        price += 10;
        break;
      case EdgeCardRarity.epic:
        price += 5;
        break;
      case EdgeCardRarity.rare:
        price += 3;
        break;
      default:
        break;
    }

    return price;
  }

  /// Copy with lock status
  EdgeCardData copyWithLockStatus(bool isLocked) {
    return EdgeCardData(
      id: id,
      category: category,
      title: title,
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: metadata,
      timestamp: timestamp,
      rarity: rarity,
      badges: badges,
      currentCost: currentCost,
      confidence: confidence,
      impactText: impactText,
      isLocked: isLocked,
      viewCount: viewCount,
      expiresAt: expiresAt,
    );
  }
}