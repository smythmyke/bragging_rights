import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// NBA Simple Betting Configuration
/// 7 tabs of prediction bets based on ESPN final game data
class NbaSimpleBets {

  /// Get all bet tabs for NBA
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTeamScoringTab(),
      _getGameTotalTab(),
      _getMarginTab(),
      _getPlayerPerformanceTab(),
      _getTeamStatsTab(),
      _getEfficiencyTab(),
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
          descriptionTemplate: '{home} scores 100+ points',
          basePoints: 1,
          team: 'home',
          threshold: 100,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 110+ points',
          basePoints: 1,
          team: 'home',
          threshold: 110,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 120+ points',
          basePoints: 2,
          team: 'home',
          threshold: 120,
        ),
        // Away team scoring
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 100+ points',
          basePoints: 1,
          team: 'away',
          threshold: 100,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 110+ points',
          basePoints: 1,
          team: 'away',
          threshold: 110,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 120+ points',
          basePoints: 2,
          team: 'away',
          threshold: 120,
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
          descriptionTemplate: 'Combined score over 200',
          basePoints: 1,
          threshold: 200,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 210',
          basePoints: 1,
          threshold: 210,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 220',
          basePoints: 2,
          threshold: 220,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 230',
          basePoints: 2,
          threshold: 230,
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

  /// Tab 5: Player Performance
  static BetTabConfig _getPlayerPerformanceTab() {
    return BetTabConfig(
      name: 'Player Performance',
      icon: Icons.person,
      description: 'Predict individual player stats',
      bets: [
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Any player scores 20+ points',
          basePoints: 1,
          threshold: 20,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Any player scores 25+ points',
          basePoints: 2,
          threshold: 25,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Any player scores 30+ points',
          basePoints: 3,
          threshold: 30,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Any player scores 35+ points',
          basePoints: 3,
          threshold: 35,
          statType: 'points',
        ),
        SimpleBetTemplate(
          betType: 'player_stat_threshold',
          descriptionTemplate: 'Any player scores 40+ points',
          basePoints: 3,
          threshold: 40,
          statType: 'points',
        ),
      ],
    );
  }

  /// Tab 6: Team Stats
  static BetTabConfig _getTeamStatsTab() {
    return BetTabConfig(
      name: 'Team Stats',
      icon: Icons.bar_chart,
      description: 'Predict team statistics',
      bets: [
        // Home team three-pointers
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 10+ threes',
          basePoints: 2,
          team: 'home',
          threshold: 10,
          statType: 'threePointFieldGoalsMade',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 12+ threes',
          basePoints: 2,
          team: 'home',
          threshold: 12,
          statType: 'threePointFieldGoalsMade',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} makes 15+ threes',
          basePoints: 3,
          team: 'home',
          threshold: 15,
          statType: 'threePointFieldGoalsMade',
        ),
        // Home team assists
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 25+ assists',
          basePoints: 2,
          team: 'home',
          threshold: 25,
          statType: 'assists',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 30+ assists',
          basePoints: 3,
          team: 'home',
          threshold: 30,
          statType: 'assists',
        ),
        // Home team rebounds
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} grabs 45+ rebounds',
          basePoints: 2,
          team: 'home',
          threshold: 45,
          statType: 'rebounds',
        ),
        // Away team three-pointers
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 10+ threes',
          basePoints: 2,
          team: 'away',
          threshold: 10,
          statType: 'threePointFieldGoalsMade',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 12+ threes',
          basePoints: 2,
          team: 'away',
          threshold: 12,
          statType: 'threePointFieldGoalsMade',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} makes 15+ threes',
          basePoints: 3,
          team: 'away',
          threshold: 15,
          statType: 'threePointFieldGoalsMade',
        ),
        // Away team assists
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 25+ assists',
          basePoints: 2,
          team: 'away',
          threshold: 25,
          statType: 'assists',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 30+ assists',
          basePoints: 3,
          team: 'away',
          threshold: 30,
          statType: 'assists',
        ),
        // Away team rebounds
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} grabs 45+ rebounds',
          basePoints: 2,
          team: 'away',
          threshold: 45,
          statType: 'rebounds',
        ),
      ],
    );
  }

  /// Tab 7: Efficiency
  static BetTabConfig _getEfficiencyTab() {
    return BetTabConfig(
      name: 'Efficiency',
      icon: Icons.trending_up,
      description: 'Predict shooting efficiency',
      bets: [
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner shoots 45%+ FG',
          basePoints: 2,
          threshold: 45,
          statType: 'fieldGoalPct',
        ),
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner shoots 48%+ FG',
          basePoints: 3,
          threshold: 48,
          statType: 'fieldGoalPct',
        ),
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner shoots 35%+ from 3PT',
          basePoints: 2,
          threshold: 35,
          statType: 'threePointPct',
        ),
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner shoots 80%+ FT',
          basePoints: 2,
          threshold: 80,
          statType: 'freeThrowPct',
        ),
      ],
    );
  }
}
