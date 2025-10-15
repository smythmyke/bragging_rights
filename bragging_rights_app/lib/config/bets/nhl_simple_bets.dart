import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// NHL Simple Betting Configuration
/// 5 tabs - Limited options due to ESPN providing minimal NHL stats
class NhlSimpleBets {

  /// Get all bet tabs for NHL
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTotalGoalsTab(),
      _getTeamGoalsTab(),
      _getSpecialEventsTab(),
      _getPlayerPerformanceTab(),
    ];
  }

  /// Tab 1: Winner (REQUIRED)
  static BetTabConfig _getWinnerTab() {
    return BetTabConfig(
      name: 'Winner',
      icon: Icons.emoji_events,
      description: 'Pick the winning team',
      bets: [
        SimpleBetTemplate(
          betType: 'winner',
          descriptionTemplate: '{home} to Win',
          basePoints: 1,
          team: 'home',
          isRequired: true,
        ),
        SimpleBetTemplate(
          betType: 'winner',
          descriptionTemplate: '{away} to Win',
          basePoints: 1,
          team: 'away',
          isRequired: true,
        ),
      ],
    );
  }

  /// Tab 2: Total Goals
  static BetTabConfig _getTotalGoalsTab() {
    return BetTabConfig(
      name: 'Total Goals',
      icon: Icons.sports_hockey,
      description: 'Predict combined goals',
      bets: [
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 4+ total goals',
          basePoints: 1,
          threshold: 4,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 5+ total goals',
          basePoints: 1,
          threshold: 5,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 6+ total goals',
          basePoints: 2,
          threshold: 6,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 7+ total goals',
          basePoints: 2,
          threshold: 7,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 8+ total goals',
          basePoints: 3,
          threshold: 8,
        ),
      ],
    );
  }

  /// Tab 3: Team Goals
  static BetTabConfig _getTeamGoalsTab() {
    return BetTabConfig(
      name: 'Team Goals',
      icon: Icons.score,
      description: 'Predict team goal totals',
      bets: [
        // Home team goals
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 3+ goals',
          basePoints: 1,
          team: 'home',
          threshold: 3,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 4+ goals',
          basePoints: 2,
          team: 'home',
          threshold: 4,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 5+ goals',
          basePoints: 2,
          team: 'home',
          threshold: 5,
        ),
        // Away team goals
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 3+ goals',
          basePoints: 1,
          team: 'away',
          threshold: 3,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 4+ goals',
          basePoints: 2,
          team: 'away',
          threshold: 4,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 5+ goals',
          basePoints: 2,
          team: 'away',
          threshold: 5,
        ),
      ],
    );
  }

  /// Tab 4: Special Events
  static BetTabConfig _getSpecialEventsTab() {
    return BetTabConfig(
      name: 'Special Events',
      icon: Icons.star,
      description: 'Predict special game outcomes',
      bets: [
        SimpleBetTemplate(
          betType: 'shutout',
          descriptionTemplate: 'Either team shut out',
          basePoints: 3,
          statType: 'shutout',
        ),
        SimpleBetTemplate(
          betType: 'overtime',
          descriptionTemplate: 'Game goes to overtime',
          basePoints: 2,
          statType: 'overtime',
        ),
        SimpleBetTemplate(
          betType: 'shootout',
          descriptionTemplate: 'Game goes to shootout',
          basePoints: 3,
          statType: 'shootout',
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 1 goal',
          basePoints: 2,
          threshold: 1,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 2+ goals',
          basePoints: 2,
          threshold: 2,
        ),
      ],
    );
  }

  /// Tab 5: Player Performance
  static BetTabConfig _getPlayerPerformanceTab() {
    return BetTabConfig(
      name: 'Player Performance',
      icon: Icons.person,
      description: 'Predict top scorer points',
      bets: [
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Top scorer has 1+ points',
          basePoints: 1,
          threshold: 1,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Top scorer has 2+ points',
          basePoints: 2,
          threshold: 2,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Top scorer has 3+ points',
          basePoints: 3,
          threshold: 3,
          statType: 'points',
        ),
      ],
    );
  }
}
