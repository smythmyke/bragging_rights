/// Model for TheSportsDB Team data
class SportsDBTeam {
  final String idTeam;
  final String strTeam;
  final String? strTeamShort;
  final String? strAlternate;
  final String? strSport;
  final String? strLeague;
  final String? idLeague;
  final String? strStadium;
  final String? strStadiumLocation;
  final String? intStadiumCapacity;
  final String? strWebsite;
  final String? strTeamBadge; // Primary logo (usually best quality)
  final String? strTeamLogo;   // Alternative logo
  final String? strTeamJersey; // Jersey image
  final String? strTeamBanner; // Banner image
  final String? strLogo;       // Another logo option
  final String? strDescriptionEN;
  final String? strCountry;
  final String? intFormedYear;

  SportsDBTeam({
    required this.idTeam,
    required this.strTeam,
    this.strTeamShort,
    this.strAlternate,
    this.strSport,
    this.strLeague,
    this.idLeague,
    this.strStadium,
    this.strStadiumLocation,
    this.intStadiumCapacity,
    this.strWebsite,
    this.strTeamBadge,
    this.strTeamLogo,
    this.strTeamJersey,
    this.strTeamBanner,
    this.strLogo,
    this.strDescriptionEN,
    this.strCountry,
    this.intFormedYear,
  });

  factory SportsDBTeam.fromJson(Map<String, dynamic> json) {
    return SportsDBTeam(
      idTeam: json['idTeam'] ?? '',
      strTeam: json['strTeam'] ?? '',
      strTeamShort: json['strTeamShort'],
      strAlternate: json['strAlternate'],
      strSport: json['strSport'],
      strLeague: json['strLeague'],
      idLeague: json['idLeague'],
      strStadium: json['strStadium'],
      strStadiumLocation: json['strStadiumLocation'],
      intStadiumCapacity: json['intStadiumCapacity'],
      strWebsite: json['strWebsite'],
      strTeamBadge: json['strTeamBadge'],
      strTeamLogo: json['strTeamLogo'],
      strTeamJersey: json['strTeamJersey'],
      strTeamBanner: json['strTeamBanner'],
      strLogo: json['strLogo'],
      strDescriptionEN: json['strDescriptionEN'],
      strCountry: json['strCountry'],
      intFormedYear: json['intFormedYear'],
    );
  }

  /// Get the best available logo URL
  String? get bestLogoUrl {
    // Priority order for logos
    return strTeamBadge ?? 
           strLogo ?? 
           strTeamLogo;
  }

  /// Get team display name
  String get displayName {
    return strTeam;
  }

  /// Get short name for compact displays
  String get shortName {
    return strTeamShort ?? strTeam.split(' ').last;
  }

  Map<String, dynamic> toJson() {
    return {
      'idTeam': idTeam,
      'strTeam': strTeam,
      'strTeamShort': strTeamShort,
      'strAlternate': strAlternate,
      'strSport': strSport,
      'strLeague': strLeague,
      'idLeague': idLeague,
      'strStadium': strStadium,
      'strStadiumLocation': strStadiumLocation,
      'intStadiumCapacity': intStadiumCapacity,
      'strWebsite': strWebsite,
      'strTeamBadge': strTeamBadge,
      'strTeamLogo': strTeamLogo,
      'strTeamJersey': strTeamJersey,
      'strTeamBanner': strTeamBanner,
      'strLogo': strLogo,
      'strDescriptionEN': strDescriptionEN,
      'strCountry': strCountry,
      'intFormedYear': intFormedYear,
    };
  }
}

/// League IDs for major sports
class SportsDBLeagues {
  // Basketball
  static const String NBA = '4387';
  static const String WNBA = '4510';
  static const String EUROLEAGUE = '4388';
  
  // American Football
  static const String NFL = '4391';
  static const String NCAA_FOOTBALL = '4479';
  static const String CFL = '4392';
  
  // Baseball
  static const String MLB = '4424';
  static const String MLB_NL = '4425'; // National League
  static const String MLB_AL = '4426'; // American League
  
  // Ice Hockey  
  static const String NHL = '4380';
  static const String KHL = '4466';
  
  // Soccer (if needed later)
  static const String MLS = '4346';
  static const String PREMIER_LEAGUE = '4328';
  static const String LA_LIGA = '4335';
  static const String SERIE_A = '4332';
  static const String BUNDESLIGA = '4331';
  
  /// Get league ID by sport code
  static String? getLeagueId(String sportCode) {
    switch (sportCode.toLowerCase()) {
      case 'nba':
        return NBA;
      case 'nfl':
        return NFL;
      case 'mlb':
        return MLB;
      case 'nhl':
        return NHL;
      case 'mls':
        return MLS;
      default:
        return null;
    }
  }
  
  /// Get all teams endpoint
  static String getAllTeamsEndpoint(String leagueId) {
    return 'lookup_all_teams.php?id=$leagueId';
  }
  
  /// Search teams endpoint
  static String getSearchTeamsEndpoint(String teamName) {
    return 'searchteams.php?t=${Uri.encodeComponent(teamName)}';
  }
  
  /// Get team details endpoint
  static String getTeamDetailsEndpoint(String teamId) {
    return 'lookupteam.php?id=$teamId';
  }
}