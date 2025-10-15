import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// MLB Simple Betting Configuration
/// 7 tabs based on ESPN final game data (runs, hits, errors)
class MlbSimpleBets {

  /// Get all bet tabs for MLB
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTotalRunsTab(),
      _getTeamRunsTab(),
      _getHittingTab(),
      _getHomeRunsTab(),
      _getDefenseTab(),
      _getSpecialEventsTab(),
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

  /// Tab 2: Total Runs
  static BetTabConfig _getTotalRunsTab() {
    return BetTabConfig(
      name: 'Total Runs',
      icon: Icons.sports_baseball,
      description: 'Predict combined runs',
      bets: [
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 6+ total runs',
          basePoints: 1,
          threshold: 6,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 8+ total runs',
          basePoints: 1,
          threshold: 8,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 10+ total runs',
          basePoints: 2,
          threshold: 10,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 12+ total runs',
          basePoints: 2,
          threshold: 12,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Game has 15+ total runs',
          basePoints: 3,
          threshold: 15,
        ),
      ],
    );
  }

  /// Tab 3: Team Runs
  static BetTabConfig _getTeamRunsTab() {
    return BetTabConfig(
      name: 'Team Runs',
      icon: Icons.score,
      description: 'Predict team run totals',
      bets: [
        // Home team runs
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 3+ runs',
          basePoints: 1,
          team: 'home',
          threshold: 3,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 5+ runs',
          basePoints: 1,
          team: 'home',
          threshold: 5,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 7+ runs',
          basePoints: 2,
          team: 'home',
          threshold: 7,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 10+ runs',
          basePoints: 3,
          team: 'home',
          threshold: 10,
        ),
        // Away team runs
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 3+ runs',
          basePoints: 1,
          team: 'away',
          threshold: 3,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 5+ runs',
          basePoints: 1,
          team: 'away',
          threshold: 5,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 7+ runs',
          basePoints: 2,
          team: 'away',
          threshold: 7,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 10+ runs',
          basePoints: 3,
          team: 'away',
          threshold: 10,
        ),
      ],
    );
  }

  /// Tab 4: Hitting
  static BetTabConfig _getHittingTab() {
    return BetTabConfig(
      name: 'Hitting',
      icon: Icons.sports_cricket,
      description: 'Predict hit totals',
      bets: [
        // Home team hits
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 8+ hits',
          basePoints: 1,
          team: 'home',
          threshold: 8,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 10+ hits',
          basePoints: 2,
          team: 'home',
          threshold: 10,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{home} records 12+ hits',
          basePoints: 2,
          team: 'home',
          threshold: 12,
          statType: 'hits',
        ),
        // Away team hits
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 8+ hits',
          basePoints: 1,
          team: 'away',
          threshold: 8,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 10+ hits',
          basePoints: 2,
          team: 'away',
          threshold: 10,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_threshold',
          descriptionTemplate: '{away} records 12+ hits',
          basePoints: 2,
          team: 'away',
          threshold: 12,
          statType: 'hits',
        ),
        // Combined hits
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Combined hits 15+',
          basePoints: 1,
          threshold: 15,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Combined hits 18+',
          basePoints: 2,
          threshold: 18,
          statType: 'hits',
        ),
        SimpleBetTemplate(
          betType: 'total_stat_threshold',
          descriptionTemplate: 'Combined hits 20+',
          basePoints: 2,
          threshold: 20,
          statType: 'hits',
        ),
      ],
    );
  }

  /// Tab 5: Home Runs
  static BetTabConfig _getHomeRunsTab() {
    return BetTabConfig(
      name: 'Home Runs',
      icon: Icons.gps_fixed,
      description: 'Predict home runs',
      bets: [
        SimpleBetTemplate(
          betType: 'game_event',
          descriptionTemplate: 'Home run hit in game',
          basePoints: 1,
          statType: 'homeRun',
        ),
        SimpleBetTemplate(
          betType: 'game_event_threshold',
          descriptionTemplate: '2+ home runs in game',
          basePoints: 2,
          threshold: 2,
          statType: 'homeRun',
        ),
        SimpleBetTemplate(
          betType: 'game_event_threshold',
          descriptionTemplate: '3+ home runs in game',
          basePoints: 2,
          threshold: 3,
          statType: 'homeRun',
        ),
        SimpleBetTemplate(
          betType: 'team_event',
          descriptionTemplate: '{home} hits a home run',
          basePoints: 1,
          team: 'home',
          statType: 'homeRun',
        ),
        SimpleBetTemplate(
          betType: 'team_event',
          descriptionTemplate: '{away} hits a home run',
          basePoints: 1,
          team: 'away',
          statType: 'homeRun',
        ),
      ],
    );
  }

  /// Tab 6: Defense
  static BetTabConfig _getDefenseTab() {
    return BetTabConfig(
      name: 'Defense',
      icon: Icons.shield,
      description: 'Predict defensive performance',
      bets: [
        SimpleBetTemplate(
          betType: 'team_stat_exact',
          descriptionTemplate: '{home} plays error-free',
          basePoints: 2,
          team: 'home',
          threshold: 0,
          statType: 'errors',
        ),
        SimpleBetTemplate(
          betType: 'team_stat_exact',
          descriptionTemplate: '{away} plays error-free',
          basePoints: 2,
          team: 'away',
          threshold: 0,
          statType: 'errors',
        ),
        SimpleBetTemplate(
          betType: 'game_stat_exact',
          descriptionTemplate: 'Both teams error-free',
          basePoints: 3,
          threshold: 0,
          statType: 'errors',
        ),
        SimpleBetTemplate(
          betType: 'shutout',
          descriptionTemplate: 'Either team shut out',
          basePoints: 3,
          statType: 'shutout',
        ),
      ],
    );
  }

  /// Tab 7: Special Events
  static BetTabConfig _getSpecialEventsTab() {
    return BetTabConfig(
      name: 'Special Events',
      icon: Icons.star,
      description: 'Predict special game outcomes',
      bets: [
        SimpleBetTemplate(
          betType: 'extra_innings',
          descriptionTemplate: 'Game goes to extra innings',
          basePoints: 2,
          statType: 'extraInnings',
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 1 run',
          basePoints: 2,
          threshold: 1,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 5+ runs',
          basePoints: 2,
          threshold: 5,
        ),
      ],
    );
  }
}
