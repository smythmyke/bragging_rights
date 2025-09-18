/// MMA Fighter Model with ESPN API data structure
class MMAFighter {
  final String id;
  final String name;
  final String? nickname;
  final String displayName;
  final String shortName;

  // Record
  final String record; // "25-3-0"
  final int? wins;
  final int? losses;
  final int? draws;
  final int? knockouts;
  final int? submissions;
  final int? decisions;

  // Physical attributes
  final double? height; // in inches
  final String? displayHeight; // "5'11\""
  final double? weight; // in pounds
  final String? displayWeight; // "155 lbs"
  final double? reach; // in inches
  final String? displayReach; // "72\""
  final String? stance; // "Orthodox", "Southpaw", "Switch"

  // Personal info
  final int? age;
  final DateTime? dateOfBirth;
  final String? gender;

  // Location
  final String? country;
  final String? countryCode;
  final String? flagUrl;

  // Fighting info
  final String? weightClass;
  final String? weightClassSlug;
  final String? camp; // Training camp/association
  final String? campLocation;
  final List<String>? fightingStyles; // ["Wrestling", "BJJ"]
  final int? ranking;
  final bool isChampion;

  // Images
  final String? headshotUrl;
  final String? leftStanceUrl;
  final String? rightStanceUrl;

  // Recent form
  final List<String>? recentForm; // ["W", "W", "L", "W", "W"]
  final List<RecentFight>? recentFights;

  // ESPN specific
  final String? espnId;
  final String? espnUrl;

  // Cache info
  final DateTime? lastUpdated;

  MMAFighter({
    required this.id,
    required this.name,
    this.nickname,
    required this.displayName,
    required this.shortName,
    required this.record,
    this.wins,
    this.losses,
    this.draws,
    this.knockouts,
    this.submissions,
    this.decisions,
    this.height,
    this.displayHeight,
    this.weight,
    this.displayWeight,
    this.reach,
    this.displayReach,
    this.stance,
    this.age,
    this.dateOfBirth,
    this.gender,
    this.country,
    this.countryCode,
    this.flagUrl,
    this.weightClass,
    this.weightClassSlug,
    this.camp,
    this.campLocation,
    this.fightingStyles,
    this.ranking,
    this.isChampion = false,
    this.headshotUrl,
    this.leftStanceUrl,
    this.rightStanceUrl,
    this.recentForm,
    this.recentFights,
    this.espnId,
    this.espnUrl,
    this.lastUpdated,
  });

  factory MMAFighter.fromESPN(Map<String, dynamic> json) {
    // Parse record string (e.g., "25-3-0" or "25-3")
    String? recordStr = json['records']?['overall']?['summary'];
    int? wins, losses, draws;
    if (recordStr != null) {
      List<String> parts = recordStr.split('-');
      if (parts.isNotEmpty) wins = int.tryParse(parts[0]);
      if (parts.length > 1) losses = int.tryParse(parts[1]);
      if (parts.length > 2) draws = int.tryParse(parts[2]);
    }

    // Parse fighting styles
    List<String>? styles;
    if (json['styles'] != null) {
      styles = (json['styles'] as List)
          .map((s) => s['text'] as String)
          .toList();
    }

    // Parse recent form from event log (would need separate API call)
    // For now, generate mock recent form based on record
    List<String>? recentForm;
    if (wins != null && losses != null) {
      recentForm = _generateMockRecentForm(wins, losses);
    }

    return MMAFighter(
      id: json['id']?.toString() ?? '',
      name: json['fullName'] ?? json['displayName'] ?? '',
      nickname: json['nickname'],
      displayName: json['displayName'] ?? '',
      shortName: json['shortName'] ?? '',
      record: recordStr ?? '0-0',
      wins: wins,
      losses: losses,
      draws: draws,
      knockouts: json['knockouts'],
      submissions: json['submissions'],
      decisions: json['decisions'],
      height: json['height']?.toDouble(),
      displayHeight: json['displayHeight'],
      weight: json['weight']?.toDouble(),
      displayWeight: json['displayWeight'],
      reach: json['reach']?.toDouble(),
      displayReach: json['displayReach'],
      stance: json['stance']?['text'],
      age: json['age'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      country: json['citizenship'] ?? json['citizenshipCountry']?['abbreviation'],
      countryCode: json['citizenshipCountry']?['abbreviation']?.toLowerCase(),
      flagUrl: json['flag']?['href'],
      weightClass: json['weightClass']?['text'],
      weightClassSlug: json['weightClass']?['slug'],
      camp: json['association']?['name'],
      campLocation: json['association']?['location']?['country'],
      fightingStyles: styles,
      ranking: json['ranking'],
      isChampion: json['isChampion'] ?? false,
      headshotUrl: json['headshot']?['href'],
      leftStanceUrl: (json['images'] as List?)
          ?.firstWhere((img) => img['rel']?.contains('leftStance') ?? false,
              orElse: () => null)?['href'],
      rightStanceUrl: (json['images'] as List?)
          ?.firstWhere((img) => img['rel']?.contains('rightStance') ?? false,
              orElse: () => null)?['href'],
      recentForm: recentForm,
      espnId: json['id']?.toString(),
      espnUrl: json['links']?.firstWhere(
          (link) => link['rel']?.contains('overview') ?? false,
          orElse: () => null)?['href'],
      lastUpdated: DateTime.now(),
    );
  }

  // Generate mock recent form based on win/loss ratio
  static List<String> _generateMockRecentForm(int wins, int losses) {
    List<String> form = [];
    double winRate = wins / (wins + losses);

    for (int i = 0; i < 5; i++) {
      // Use win rate to randomly generate realistic form
      form.add(DateTime.now().millisecond % 100 < (winRate * 100) ? 'W' : 'L');
    }

    return form;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'displayName': displayName,
      'shortName': shortName,
      'record': record,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'knockouts': knockouts,
      'submissions': submissions,
      'decisions': decisions,
      'height': height,
      'displayHeight': displayHeight,
      'weight': weight,
      'displayWeight': displayWeight,
      'reach': reach,
      'displayReach': displayReach,
      'stance': stance,
      'age': age,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'country': country,
      'countryCode': countryCode,
      'flagUrl': flagUrl,
      'weightClass': weightClass,
      'weightClassSlug': weightClassSlug,
      'camp': camp,
      'campLocation': campLocation,
      'fightingStyles': fightingStyles,
      'ranking': ranking,
      'isChampion': isChampion,
      'headshotUrl': headshotUrl,
      'leftStanceUrl': leftStanceUrl,
      'rightStanceUrl': rightStanceUrl,
      'recentForm': recentForm,
      'recentFights': recentFights?.map((f) => f.toJson()).toList(),
      'espnId': espnId,
      'espnUrl': espnUrl,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory MMAFighter.fromJson(Map<String, dynamic> json) {
    return MMAFighter(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nickname: json['nickname'],
      displayName: json['displayName'] ?? '',
      shortName: json['shortName'] ?? '',
      record: json['record'] ?? '0-0',
      wins: json['wins'],
      losses: json['losses'],
      draws: json['draws'],
      knockouts: json['knockouts'],
      submissions: json['submissions'],
      decisions: json['decisions'],
      height: json['height']?.toDouble(),
      displayHeight: json['displayHeight'],
      weight: json['weight']?.toDouble(),
      displayWeight: json['displayWeight'],
      reach: json['reach']?.toDouble(),
      displayReach: json['displayReach'],
      stance: json['stance'],
      age: json['age'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'])
          : null,
      gender: json['gender'],
      country: json['country'],
      countryCode: json['countryCode'],
      flagUrl: json['flagUrl'],
      weightClass: json['weightClass'],
      weightClassSlug: json['weightClassSlug'],
      camp: json['camp'],
      campLocation: json['campLocation'],
      fightingStyles: json['fightingStyles'] != null
          ? List<String>.from(json['fightingStyles'])
          : null,
      ranking: json['ranking'],
      isChampion: json['isChampion'] ?? false,
      headshotUrl: json['headshotUrl'],
      leftStanceUrl: json['leftStanceUrl'],
      rightStanceUrl: json['rightStanceUrl'],
      recentForm: json['recentForm'] != null
          ? List<String>.from(json['recentForm'])
          : null,
      recentFights: json['recentFights'] != null
          ? (json['recentFights'] as List)
              .map((f) => RecentFight.fromJson(f))
              .toList()
          : null,
      espnId: json['espnId'],
      espnUrl: json['espnUrl'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'])
          : null,
    );
  }

  // Helper getters
  double get winPercentage {
    if (wins == null || losses == null) return 0;
    int total = wins! + losses! + (draws ?? 0);
    if (total == 0) return 0;
    return (wins! / total) * 100;
  }

  double get finishRate {
    if (wins == null || wins == 0) return 0;
    int finishes = (knockouts ?? 0) + (submissions ?? 0);
    return (finishes / wins!) * 100;
  }

  String get heightFeetInches {
    if (displayHeight != null) return displayHeight!;
    if (height == null) return 'N/A';
    int feet = (height! / 12).floor();
    int inches = (height! % 12).round();
    return "$feet'$inches\"";
  }

  String get reachInches {
    if (displayReach != null) return displayReach!;
    if (reach == null) return 'N/A';
    return "${reach!.round()}\"";
  }
}

class RecentFight {
  final String? opponentName;
  final String? result; // "W", "L", "D", "NC"
  final String? method; // "KO", "TKO", "Submission", "Decision"
  final int? round;
  final String? time;
  final DateTime? date;
  final String? eventName;

  RecentFight({
    this.opponentName,
    this.result,
    this.method,
    this.round,
    this.time,
    this.date,
    this.eventName,
  });

  factory RecentFight.fromJson(Map<String, dynamic> json) {
    return RecentFight(
      opponentName: json['opponentName'],
      result: json['result'],
      method: json['method'],
      round: json['round'],
      time: json['time'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      eventName: json['eventName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opponentName': opponentName,
      'result': result,
      'method': method,
      'round': round,
      'time': time,
      'date': date?.toIso8601String(),
      'eventName': eventName,
    };
  }
}