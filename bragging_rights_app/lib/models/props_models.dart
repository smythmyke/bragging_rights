/// Models for player props betting functionality
class PropsTabData {
  final String homeTeam;
  final String awayTeam;
  final Map<String, PlayerProps> playersByName;
  final List<String> starPlayers;
  final Map<String, List<String>> playersByPosition;
  final Map<String, List<String>> playersByTeam;
  final DateTime cacheTime;
  final String eventId;
  
  PropsTabData({
    required this.homeTeam,
    required this.awayTeam,
    required this.playersByName,
    required this.starPlayers,
    required this.playersByPosition,
    required this.playersByTeam,
    required this.cacheTime,
    required this.eventId,
  });
  
  /// Check if cache is still valid (5 minutes)
  bool get isCacheValid {
    return DateTime.now().difference(cacheTime).inMinutes < 5;
  }
  
  /// Get players for a specific team
  List<PlayerProps> getTeamPlayers(bool isHomeTeam) {
    final team = isHomeTeam ? homeTeam : awayTeam;
    final playerNames = playersByTeam[team] ?? [];
    return playerNames
        .map((name) => playersByName[name])
        .where((player) => player != null)
        .cast<PlayerProps>()
        .toList();
  }
  
  /// Search players by name
  List<PlayerProps> searchPlayers(String query) {
    final lowerQuery = query.toLowerCase();
    return playersByName.values
        .where((player) => player.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

class PlayerProps {
  final String name;
  final String team;
  final String position;
  final bool isStar;
  final List<PropOption> props;
  
  PlayerProps({
    required this.name,
    required this.team,
    required this.position,
    required this.isStar,
    required this.props,
  });
  
  /// Get display name with position
  String get displayName => '$position $name';
  
  /// Get prop count for sorting
  int get propCount => props.length;
}

class PropOption {
  final String marketKey; // e.g., 'player_pass_yds'
  final String type; // e.g., 'Passing Yards'
  final String displayName; // e.g., 'Pass Yards O/U'
  final double? line; // e.g., 275.5
  final int? overOdds; // e.g., -110
  final int? underOdds; // e.g., -110
  final int? straightOdds; // For props without O/U (like Anytime TD)
  final String bookmaker;
  final String description; // e.g., 'Over 275.5 yards'
  
  PropOption({
    required this.marketKey,
    required this.type,
    required this.displayName,
    this.line,
    this.overOdds,
    this.underOdds,
    this.straightOdds,
    required this.bookmaker,
    required this.description,
  });
  
  /// Check if this is an over/under prop
  bool get isOverUnder => line != null;
  
  /// Get formatted line display
  String get formattedLine {
    if (line == null) return '';
    return line!.toStringAsFixed(line! % 1 == 0 ? 0 : 1);
  }
  
  /// Format odds for display
  String formatOdds(int? odds) {
    if (odds == null) return '';
    return odds > 0 ? '+$odds' : '$odds';
  }
  
  /// Get display text for the prop
  String get displayText {
    if (isOverUnder) {
      return '$displayName $formattedLine';
    }
    return displayName;
  }
}

/// Helper class to parse props from API response
class PropsParser {
  /// Market key to display name mapping
  static const Map<String, String> marketDisplayNames = {
    'player_pass_yds': 'Passing Yards',
    'player_pass_tds': 'Passing TDs',
    'player_pass_attempts': 'Pass Attempts',
    'player_pass_completions': 'Completions',
    'player_pass_interceptions': 'Interceptions',
    'player_rush_yds': 'Rushing Yards',
    'player_rush_tds': 'Rushing TDs',
    'player_rush_attempts': 'Rush Attempts',
    'player_reception_yds': 'Receiving Yards',
    'player_receptions': 'Receptions',
    'player_reception_tds': 'Receiving TDs',
    'player_anytime_td': 'Anytime TD Scorer',
    'player_first_td': 'First TD Scorer',
    'player_points': 'Points',
    'player_rebounds': 'Rebounds',
    'player_assists': 'Assists',
    'player_threes': '3-Pointers Made',
    'player_blocks': 'Blocks',
    'player_steals': 'Steals',
    'player_points_rebounds_assists': 'Points + Reb + Ast',
    'player_double_double': 'Double-Double',
    'player_triple_double': 'Triple-Double',
    'batter_home_runs': 'Home Runs',
    'batter_hits': 'Hits',
    'batter_rbis': 'RBIs',
    'batter_runs_scored': 'Runs Scored',
    'batter_total_bases': 'Total Bases',
    'pitcher_strikeouts': 'Strikeouts',
    'pitcher_hits_allowed': 'Hits Allowed',
    'pitcher_earned_runs': 'Earned Runs',
    'player_goals': 'Goals',
    'player_shots_on_goal': 'Shots on Goal',
    'player_blocked_shots': 'Blocked Shots',
    'player_power_play_points': 'Power Play Points',
  };
  
  /// Infer position from prop types
  static String inferPosition(List<String> propTypes) {
    // NFL positions
    if (propTypes.any((t) => t.contains('pass_yds') || t.contains('pass_tds'))) {
      return 'QB';
    }
    if (propTypes.any((t) => t.contains('rush_yds') || t.contains('rush_attempts'))) {
      // Could be RB or QB - check if they also have passing props
      if (!propTypes.any((t) => t.contains('pass'))) {
        return 'RB';
      }
    }
    if (propTypes.any((t) => t.contains('reception') || t.contains('receptions'))) {
      // Could be WR, TE, or RB - use prop count as hint
      if (propTypes.length > 3) {
        return 'WR';
      }
      return 'WR/TE';
    }
    
    // NBA positions (generic)
    if (propTypes.any((t) => t.contains('points') || t.contains('rebounds'))) {
      return 'Player';
    }
    
    // MLB positions
    if (propTypes.any((t) => t.contains('pitcher'))) {
      return 'P';
    }
    if (propTypes.any((t) => t.contains('batter') || t.contains('home_runs'))) {
      return 'Batter';
    }
    
    // NHL positions
    if (propTypes.any((t) => t.contains('goals') || t.contains('shots'))) {
      return 'Player';
    }
    
    return 'Player';
  }
  
  /// Extract player name from outcome text
  static String extractPlayerName(String outcomeText) {
    // Remove common prop indicators
    final cleanText = outcomeText
        .replaceAll(RegExp(r'Over\s+[\d.]+'), '')
        .replaceAll(RegExp(r'Under\s+[\d.]+'), '')
        .replaceAll(RegExp(r'[+-]\d+'), '')
        .replaceAll(RegExp(r'\s+Anytime.*'), '')
        .replaceAll(RegExp(r'\s+First.*'), '')
        .replaceAll(RegExp(r'\s+to\s+.*'), '')
        .trim();
    
    return cleanText;
  }
  
  /// Determine if player is a star based on prop count and types
  static bool isStarPlayer(List<PropOption> props) {
    // 5+ props usually indicates a star
    if (props.length >= 5) return true;
    
    // QB with passing props is usually a starter
    if (props.any((p) => p.marketKey.contains('pass_yds'))) return true;
    
    // Premium prop types indicate stars
    if (props.any((p) => 
        p.marketKey.contains('anytime_td') || 
        p.marketKey.contains('first_td'))) {
      return props.length >= 3;
    }
    
    return false;
  }
  
  /// Get market display name
  static String getMarketDisplayName(String marketKey) {
    return marketDisplayNames[marketKey] ?? marketKey
        .replaceAll('player_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}