import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// NCAAB Simple Betting Configuration
/// 5 tabs of prediction bets based on ESPN final game data
class NcaabSimpleBets {

  /// Get all bet tabs for NCAAB
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTeamScoringTab(),
      _getGameTotalTab(),
      _getMarginTab(),
      _getTeamStatsTab(),
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

  /// Tab 2: Team Scoring
  static BetTabConfig _getTeamScoringTab() {
    return BetTabConfig(
      name: 'Team Scoring',
      icon: Icons.score,
      description: 'Predict team point totals',
      bets: [
        // Home team scoring
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 60+ points',
          basePoints: 1,
          team: 'home',
          threshold: 60,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 70+ points',
          basePoints: 1,
          team: 'home',
          threshold: 70,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 80+ points',
          basePoints: 2,
          team: 'home',
          threshold: 80,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 90+ points',
          basePoints: 3,
          team: 'home',
          threshold: 90,
        ),
        // Away team scoring
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 60+ points',
          basePoints: 1,
          team: 'away',
          threshold: 60,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 70+ points',
          basePoints: 1,
          team: 'away',
          threshold: 70,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 80+ points',
          basePoints: 2,
          team: 'away',
          threshold: 80,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 90+ points',
          basePoints: 3,
          team: 'away',
          threshold: 90,
        ),
      ],
    );
  }

  /// Tab 3: Game Total
  static BetTabConfig _getGameTotalTab() {
    return BetTabConfig(
      name: 'Game Total',
      icon: Icons.functions,
      description: 'Predict combined score',
      bets: [
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 120',
          basePoints: 1,
          threshold: 120,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 130',
          basePoints: 1,
          threshold: 130,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 140',
          basePoints: 2,
          threshold: 140,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 150',
          basePoints: 2,
          threshold: 150,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 160',
          basePoints: 3,
          threshold: 160,
        ),
      ],
    );
  }

  /// Tab 4: Margin
  static BetTabConfig _getMarginTab() {
    return BetTabConfig(
      name: 'Margin',
      icon: Icons.trending_up,
      description: 'Predict winning margin',
      bets: [
        SimpleBetTemplate(
          betType: 'margin_range',
          descriptionTemplate: 'Game decided by 1-5 points',
          basePoints: 2,
          threshold: 5,
          statType: 'close',
        ),
        SimpleBetTemplate(
          betType: 'margin_range',
          descriptionTemplate: 'Game decided by 6-10 points',
          basePoints: 2,
          threshold: 10,
          statType: 'moderate',
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 10+ points',
          basePoints: 2,
          threshold: 10,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 15+ points',
          basePoints: 2,
          threshold: 15,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 20+ points',
          basePoints: 3,
          threshold: 20,
        ),
      ],
    );
  }

  /// Tab 5: Team Stats
  static BetTabConfig _getTeamStatsTab() {
    return BetTabConfig(
      name: 'Team Stats',
      icon: Icons.bar_chart,
      description: 'Predict team statistics',
      bets: [
        // Home team threes
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 8+ threes',
          basePoints: 2,
          team: 'home',
          statType: 'threesMade',
          threshold: 8,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 10+ threes',
          basePoints: 2,
          team: 'home',
          statType: 'threesMade',
          threshold: 10,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 12+ threes',
          basePoints: 3,
          team: 'home',
          statType: 'threesMade',
          threshold: 12,
        ),
        // Home team assists
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 15+ assists',
          basePoints: 2,
          team: 'home',
          statType: 'assists',
          threshold: 15,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 20+ assists',
          basePoints: 3,
          team: 'home',
          statType: 'assists',
          threshold: 20,
        ),
        // Home team rebounds
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} grabs 35+ rebounds',
          basePoints: 2,
          team: 'home',
          statType: 'rebounds',
          threshold: 35,
        ),
        // Away team threes
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 8+ threes',
          basePoints: 2,
          team: 'away',
          statType: 'threesMade',
          threshold: 8,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 10+ threes',
          basePoints: 2,
          team: 'away',
          statType: 'threesMade',
          threshold: 10,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 12+ threes',
          basePoints: 3,
          team: 'away',
          statType: 'threesMade',
          threshold: 12,
        ),
        // Away team assists
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 15+ assists',
          basePoints: 2,
          team: 'away',
          statType: 'assists',
          threshold: 15,
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 20+ assists',
          basePoints: 3,
          team: 'away',
          statType: 'assists',
          threshold: 20,
        ),
        // Away team rebounds
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} grabs 35+ rebounds',
          basePoints: 2,
          team: 'away',
          statType: 'rebounds',
          threshold: 35,
        ),
      ],
    );
  }
}
