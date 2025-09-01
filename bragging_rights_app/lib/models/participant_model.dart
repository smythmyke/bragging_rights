/// Unified model for handling both teams and individual players
/// Used across all sports to maintain consistency

enum ParticipantType { team, individual, pair }

class Participant {
  final String id;
  final String name;
  final ParticipantType type;
  final String? logo;
  final Map<String, dynamic>? metadata;
  
  // For individual sports
  final int? ranking;
  final String? country;
  final int? seed;
  
  // For team sports
  final String? city;
  final String? abbreviation;
  final String? conference;
  
  Participant({
    required this.id,
    required this.name,
    required this.type,
    this.logo,
    this.metadata,
    this.ranking,
    this.country,
    this.seed,
    this.city,
    this.abbreviation,
    this.conference,
  });
  
  factory Participant.team({
    required String id,
    required String name,
    String? logo,
    String? city,
    String? abbreviation,
    String? conference,
    Map<String, dynamic>? metadata,
  }) {
    return Participant(
      id: id,
      name: name,
      type: ParticipantType.team,
      logo: logo,
      city: city,
      abbreviation: abbreviation,
      conference: conference,
      metadata: metadata,
    );
  }
  
  factory Participant.individual({
    required String id,
    required String name,
    int? ranking,
    String? country,
    int? seed,
    String? logo,
    Map<String, dynamic>? metadata,
  }) {
    return Participant(
      id: id,
      name: name,
      type: ParticipantType.individual,
      ranking: ranking,
      country: country,
      seed: seed,
      logo: logo,
      metadata: metadata,
    );
  }
  
  factory Participant.pair({
    required String id,
    required String name,
    String? logo,
    Map<String, dynamic>? metadata,
  }) {
    return Participant(
      id: id,
      name: name,
      type: ParticipantType.pair,
      logo: logo,
      metadata: metadata,
    );
  }
  
  /// Get display name based on type
  String get displayName {
    switch (type) {
      case ParticipantType.team:
        return city != null ? '$city $name' : name;
      case ParticipantType.individual:
        return seed != null ? '($seed) $name' : name;
      case ParticipantType.pair:
        return name;
    }
  }
  
  /// Get short name for compact display
  String get shortName {
    switch (type) {
      case ParticipantType.team:
        return abbreviation ?? name.substring(0, 3).toUpperCase();
      case ParticipantType.individual:
        // Last name for individuals
        final parts = name.split(' ');
        return parts.isNotEmpty ? parts.last : name;
      case ParticipantType.pair:
        // First initials for pairs
        final names = name.split('/');
        if (names.length == 2) {
          return '${names[0].trim()[0]}.${names[1].trim()[0]}.';
        }
        return name.substring(0, 3).toUpperCase();
    }
  }
  
  /// Check if this is a team sport
  bool get isTeamSport => type == ParticipantType.team;
  
  /// Check if this is an individual sport
  bool get isIndividualSport => type == ParticipantType.individual;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'logo': logo,
      'metadata': metadata,
      'ranking': ranking,
      'country': country,
      'seed': seed,
      'city': city,
      'abbreviation': abbreviation,
      'conference': conference,
    };
  }
  
  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: ParticipantType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => ParticipantType.team,
      ),
      logo: map['logo'],
      metadata: map['metadata'],
      ranking: map['ranking'],
      country: map['country'],
      seed: map['seed'],
      city: map['city'],
      abbreviation: map['abbreviation'],
      conference: map['conference'],
    );
  }
}

/// Extension to help identify sport type
extension SportParticipantType on String {
  ParticipantType get participantType {
    switch (toLowerCase()) {
      // Individual sports
      case 'tennis':
      case 'golf':
      case 'boxing':
      case 'mma':
      case 'ufc':
        return ParticipantType.individual;
      
      // Pair sports (doubles tennis, etc)
      case 'doubles':
        return ParticipantType.pair;
      
      // Team sports
      case 'nba':
      case 'nfl':
      case 'nhl':
      case 'mlb':
      case 'soccer':
      case 'ncaab':
      case 'ncaaf':
      default:
        return ParticipantType.team;
    }
  }
  
  /// Get appropriate label for participants
  String get participantLabel {
    final type = participantType;
    switch (type) {
      case ParticipantType.individual:
        return 'Player';
      case ParticipantType.pair:
        return 'Pair';
      case ParticipantType.team:
        return 'Team';
    }
  }
  
  /// Get versus text
  String get versusText {
    return participantType == ParticipantType.individual ? 'vs' : '@';
  }
}

/// Helper class for match participants
class MatchParticipants {
  final Participant home;
  final Participant away;
  final String sport;
  
  MatchParticipants({
    required this.home,
    required this.away,
    required this.sport,
  });
  
  /// Get display format for betting screens
  String getBettingDisplay() {
    if (sport.participantType == ParticipantType.individual) {
      // For individual sports, show rankings if available
      final homeRank = home.ranking != null ? '#${home.ranking} ' : '';
      final awayRank = away.ranking != null ? '#${away.ranking} ' : '';
      return '$homeRank${home.name} vs $awayRank${away.name}';
    } else {
      // For team sports, show traditional format
      return '${away.displayName} @ ${home.displayName}';
    }
  }
  
  /// Get compact display for lists
  String getCompactDisplay() {
    return '${home.shortName} vs ${away.shortName}';
  }
  
  /// Check if favorites can be determined
  bool canDetermineFavorite() {
    if (sport.participantType == ParticipantType.individual) {
      return home.ranking != null && away.ranking != null;
    }
    return true; // Teams always have odds/spreads
  }
  
  /// Get the favorite based on rankings (for individual sports)
  Participant? getFavoriteByRanking() {
    if (sport.participantType != ParticipantType.individual) return null;
    
    if (home.ranking == null || away.ranking == null) return null;
    
    // Lower ranking number = better player
    return home.ranking! < away.ranking! ? home : away;
  }
}