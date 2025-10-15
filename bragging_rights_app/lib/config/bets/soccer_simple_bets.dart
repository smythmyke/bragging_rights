import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// Soccer Simple Betting Configuration
/// 6 tabs based on ESPN final game data (goals, possession, shots, corners, fouls)
class SoccerSimpleBets {

  /// Get all bet tabs for Soccer
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTotalGoalsTab(),
      _getTeamGoalsTab(),
      _getSpecialOutcomesTab(),
      _getTeamStatsTab(),
      _getMatchEventsTab(),
    ];
  }

  /// Tab 1: Winner (REQUIRED) - Includes Draw option
  static BetTabConfig _getWinnerTab() {
    return BetTabConfig(
      name: 'Winner',
      icon: Icons.emoji_events,
      description: 'Pick winner or draw',
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
          descriptionTemplate: 'Draw',
          basePoints: 1,
          team: 'draw',
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
      icon: Icons.sports_soccer,
      description: 'Predict combined goals',
      bets: [
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 2+ total goals',
          basePoints: 1,
          threshold: 2,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 3+ total goals',
          basePoints: 1,
          threshold: 3,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 4+ total goals',
          basePoints: 2,
          threshold: 4,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 5+ total goals',
          basePoints: 3,
          threshold: 5,
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
          descriptionTemplate: '{home} scores 1+ goals',
          basePoints: 1,
          team: 'home',
          threshold: 1,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 2+ goals',
          basePoints: 2,
          team: 'home',
          threshold: 2,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 3+ goals',
          basePoints: 2,
          team: 'home',
          threshold: 3,
        ),
        // Away team goals
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 1+ goals',
          basePoints: 1,
          team: 'away',
          threshold: 1,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 2+ goals',
          basePoints: 2,
          team: 'away',
          threshold: 2,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 3+ goals',
          basePoints: 2,
          team: 'away',
          threshold: 3,
        ),
      ],
    );
  }

  /// Tab 4: Special Outcomes
  static BetTabConfig _getSpecialOutcomesTab() {
    return BetTabConfig(
      name: 'Special Outcomes',
      icon: Icons.star,
      description: 'Predict special match outcomes',
      bets: [
        SimpleBetTemplate(
          betType: 'both_teams_score',
          descriptionTemplate: 'Both teams score',
          basePoints: 2,
          statType: 'bothScore',
        ),
        SimpleBetTemplate(
          betType: 'clean_sheet',
          descriptionTemplate: 'Either team clean sheet',
          basePoints: 2,
          statType: 'cleanSheet',
        ),
        SimpleBetTemplate(
          betType: 'exact_score',
          descriptionTemplate: 'Game ends 0-0',
          basePoints: 3,
          statType: 'exactScore_0_0',
        ),
        SimpleBetTemplate(
          betType: 'exact_score',
          descriptionTemplate: 'Game ends 1-0',
          basePoints: 3,
          statType: 'exactScore_1_0',
        ),
        SimpleBetTemplate(
          betType: 'exact_score',
          descriptionTemplate: 'Game ends 1-1',
          basePoints: 2,
          statType: 'exactScore_1_1',
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
        // Possession
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner has 55%+ possession',
          basePoints: 2,
          threshold: 55,
          statType: 'possessionPct',
        ),
        SimpleBetTemplate(
          betType: 'winner_stat_threshold',
          descriptionTemplate: 'Winner has 60%+ possession',
          basePoints: 3,
          threshold: 60,
          statType: 'possessionPct',
        ),
        // Home team shots on target
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} has 5+ shots on target',
          basePoints: 2,
          team: 'home',
          threshold: 5,
          statType: 'shotsOnTarget',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} has 7+ shots on target',
          basePoints: 2,
          team: 'home',
          threshold: 7,
          statType: 'shotsOnTarget',
        ),
        // Away team shots on target
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} has 5+ shots on target',
          basePoints: 2,
          team: 'away',
          threshold: 5,
          statType: 'shotsOnTarget',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} has 7+ shots on target',
          basePoints: 2,
          team: 'away',
          threshold: 7,
          statType: 'shotsOnTarget',
        ),
      ],
    );
  }

  /// Tab 6: Match Events
  static BetTabConfig _getMatchEventsTab() {
    return BetTabConfig(
      name: 'Match Events',
      icon: Icons.event,
      description: 'Predict match events',
      bets: [
        // Corner kicks
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Game has 10+ corners',
          basePoints: 2,
          threshold: 10,
          statType: 'wonCorners',
        ),
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Game has 12+ corners',
          basePoints: 2,
          threshold: 12,
          statType: 'wonCorners',
        ),
        // Fouls
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Game has 20+ fouls',
          basePoints: 1,
          threshold: 20,
          statType: 'foulsCommitted',
        ),
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Game has 30+ fouls',
          basePoints: 2,
          threshold: 30,
          statType: 'foulsCommitted',
        ),
      ],
    );
  }
}
