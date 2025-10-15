import 'package:flutter/material.dart';
import '../../models/simple_bet.dart';

/// Tennis Simple Betting Configuration
/// 3 tabs - Very limited due to ESPN providing minimal tennis data
class TennisSimpleBets {

  /// Get all bet tabs for Tennis
  static List<BetTabConfig> getTabs() {
    return [
      _getWinnerTab(),
      _getMatchDurationTab(),
      _getSetResultsTab(),
    ];
  }

  /// Tab 1: Winner (REQUIRED)
  static BetTabConfig _getWinnerTab() {
    return BetTabConfig(
      name: 'Winner',
      icon: Icons.emoji_events,
      description: 'Pick the winning player',
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

  /// Tab 2: Match Duration
  static BetTabConfig _getMatchDurationTab() {
    return BetTabConfig(
      name: 'Match Duration',
      icon: Icons.timer,
      description: 'Predict number of sets',
      bets: [
        SimpleBetTemplate(
          betType: 'set_count',
          descriptionTemplate: 'Match goes to 3 sets',
          basePoints: 2,
          threshold: 3,
          statType: 'setCount',
        ),
        SimpleBetTemplate(
          betType: 'set_count',
          descriptionTemplate: 'Match ends in 2 sets',
          basePoints: 2,
          threshold: 2,
          statType: 'setCount',
        ),
      ],
    );
  }

  /// Tab 3: Set Results
  static BetTabConfig _getSetResultsTab() {
    return BetTabConfig(
      name: 'Set Results',
      icon: Icons.sports_tennis,
      description: 'Predict set outcomes',
      bets: [
        SimpleBetTemplate(
          betType: 'straight_sets',
          descriptionTemplate: 'Winner wins in straight sets',
          basePoints: 2,
          statType: 'straightSets',
        ),
        SimpleBetTemplate(
          betType: 'tiebreak',
          descriptionTemplate: 'Match has a tiebreak',
          basePoints: 2,
          statType: 'tiebreak',
        ),
      ],
    );
  }
}
