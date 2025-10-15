import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// NCAAF Simple Betting Configuration
/// 4 tabs of prediction bets based on ESPN final game data
class NcaafSimpleBets {

  /// Get all bet tabs for NCAAF
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getTeamScoringTab(),
      _getGameTotalTab(),
      _getMarginTab(),
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
          descriptionTemplate: '{home} scores 14+ points',
          basePoints: 1,
          team: 'home',
          threshold: 14,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 21+ points',
          basePoints: 1,
          team: 'home',
          threshold: 21,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 28+ points',
          basePoints: 2,
          team: 'home',
          threshold: 28,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 35+ points',
          basePoints: 2,
          team: 'home',
          threshold: 35,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{home} scores 42+ points',
          basePoints: 3,
          team: 'home',
          threshold: 42,
        ),
        // Away team scoring
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 14+ points',
          basePoints: 1,
          team: 'away',
          threshold: 14,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 21+ points',
          basePoints: 1,
          team: 'away',
          threshold: 21,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 28+ points',
          basePoints: 2,
          team: 'away',
          threshold: 28,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 35+ points',
          basePoints: 2,
          team: 'away',
          threshold: 35,
        ),
        SimpleBetTemplate(
          betType: 'team_score_threshold',
          descriptionTemplate: '{away} scores 42+ points',
          basePoints: 3,
          team: 'away',
          threshold: 42,
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
          descriptionTemplate: 'Combined score over 45',
          basePoints: 1,
          threshold: 45,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 50',
          basePoints: 1,
          threshold: 50,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 55',
          basePoints: 2,
          threshold: 55,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 60',
          basePoints: 2,
          threshold: 60,
        ),
        SimpleBetTemplate(
          betType: 'total_score_threshold',
          descriptionTemplate: 'Combined score over 65',
          basePoints: 3,
          threshold: 65,
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
          descriptionTemplate: 'Game decided by 1-7 points',
          basePoints: 2,
          threshold: 7,
          statType: 'close',
        ),
        SimpleBetTemplate(
          betType: 'margin_range',
          descriptionTemplate: 'Game decided by 8-14 points',
          basePoints: 2,
          threshold: 14,
          statType: 'moderate',
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 15+ points',
          basePoints: 2,
          threshold: 15,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 21+ points',
          basePoints: 3,
          threshold: 21,
        ),
        SimpleBetTemplate(
          betType: 'margin_threshold',
          descriptionTemplate: 'Game decided by 28+ points',
          basePoints: 3,
          threshold: 28,
        ),
      ],
    );
  }
}
