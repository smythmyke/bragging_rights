import 'package:collection/collection.dart';

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

  // Fighting statistics
  final double? sigStrikesPerMinute;
  final double? strikeAccuracy;
  final double? strikeDefense;
  final double? takedownAverage;
  final double? takedownAccuracy;
  final double? takedownDefense;
  final double? submissionAverage;

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
    this.sigStrikesPerMinute,
    this.strikeAccuracy,
    this.strikeDefense,
    this.takedownAverage,
    this.takedownAccuracy,
    this.takedownDefense,
    this.submissionAverage,
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

    // Parse physical attributes
    double? heightValue;
    String? heightDisplay;
    double? weightValue;
    String? weightDisplay;
    double? reachValue;
    String? reachDisplay;

    // Height parsing
    if (json['height'] != null) {
      if (json['height'] is Map) {
        heightValue = json['height']['value']?.toDouble();
        heightDisplay = json['height']['display'];
      } else {
        heightValue = json['height'].toDouble();
      }
    }
    if (heightDisplay == null && json['displayHeight'] != null) {
      heightDisplay = json['displayHeight'];
    }

    // Weight parsing
    if (json['weight'] != null) {
      if (json['weight'] is Map) {
        weightValue = json['weight']['value']?.toDouble();
        weightDisplay = json['weight']['display'];
      } else {
        weightValue = json['weight'].toDouble();
      }
    }
    if (weightDisplay == null && json['displayWeight'] != null) {
      weightDisplay = json['displayWeight'];
    }

    // Reach parsing
    if (json['reach'] != null) {
      if (json['reach'] is Map) {
        reachValue = json['reach']['value']?.toDouble();
        reachDisplay = json['reach']['display'];
      } else {
        reachValue = json['reach'].toDouble();
      }
    }
    if (reachDisplay == null && json['displayReach'] != null) {
      reachDisplay = json['displayReach'];
    }

    // Parse age from dateOfBirth if age is not provided
    int? age = json['age'];
    if (age == null && json['dateOfBirth'] != null) {
      final dob = DateTime.tryParse(json['dateOfBirth']);
      if (dob != null) {
        age = DateTime.now().year - dob.year;
        if (DateTime.now().month < dob.month ||
            (DateTime.now().month == dob.month && DateTime.now().day < dob.day)) {
          age--;
        }
      }
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
      height: heightValue,
      displayHeight: heightDisplay,
      weight: weightValue,
      displayWeight: weightDisplay,
      reach: reachValue,
      displayReach: reachDisplay,
      stance: json['stance']?['text'] ?? json['stance'],
      age: age,
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
          ?.cast<Map<String, dynamic>>()
          .where((img) => img['rel']?.toString().contains('leftStance') ?? false)
          .firstOrNull?['href'],
      rightStanceUrl: (json['images'] as List?)
          ?.cast<Map<String, dynamic>>()
          .where((img) => img['rel']?.toString().contains('rightStance') ?? false)
          .firstOrNull?['href'],
      recentForm: recentForm,
      sigStrikesPerMinute: json['sigStrikesPerMinute']?.toDouble(),
      strikeAccuracy: json['strikeAccuracy']?.toDouble(),
      strikeDefense: json['strikeDefense']?.toDouble(),
      takedownAverage: json['takedownAverage']?.toDouble(),
      takedownAccuracy: json['takedownAccuracy']?.toDouble(),
      takedownDefense: json['takedownDefense']?.toDouble(),
      submissionAverage: json['submissionAverage']?.toDouble(),
      espnId: json['id']?.toString(),
      espnUrl: json['links'] != null
          ? (json['links'] as List).firstWhere(
              (link) => link['rel']?.contains('overview') ?? false,
              orElse: () => <String, dynamic>{},
            )['href']
          : null,
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
      'sigStrikesPerMinute': sigStrikesPerMinute,
      'strikeAccuracy': strikeAccuracy,
      'strikeDefense': strikeDefense,
      'takedownAverage': takedownAverage,
      'takedownAccuracy': takedownAccuracy,
      'takedownDefense': takedownDefense,
      'submissionAverage': submissionAverage,
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
      sigStrikesPerMinute: json['sigStrikesPerMinute']?.toDouble(),
      strikeAccuracy: json['strikeAccuracy']?.toDouble(),
      strikeDefense: json['strikeDefense']?.toDouble(),
      takedownAverage: json['takedownAverage']?.toDouble(),
      takedownAccuracy: json['takedownAccuracy']?.toDouble(),
      takedownDefense: json['takedownDefense']?.toDouble(),
      submissionAverage: json['submissionAverage']?.toDouble(),
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