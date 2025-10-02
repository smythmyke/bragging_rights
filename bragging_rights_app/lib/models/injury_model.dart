class Injury {
  final String id;
  final String athleteId;
  final String athleteName;
  final String? athletePosition;
  final String status; // "Out", "Questionable", "Doubtful", "Day-to-Day"
  final String shortComment;
  final String longComment;
  final DateTime date;
  final InjuryDetails? details;
  final InjuryType type;

  Injury({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    this.athletePosition,
    required this.status,
    required this.shortComment,
    required this.longComment,
    required this.date,
    this.details,
    required this.type,
  });

  factory Injury.fromESPN(Map<String, dynamic> json) {
    return Injury(
      id: json['id']?.toString() ?? '',
      athleteId: json['athlete']?['\$ref']?.split('/').last ?? '',
      athleteName: json['athlete']?['displayName'] ?? 'Unknown Player',
      athletePosition: json['athlete']?['position']?['abbreviation'],
      status: json['status'] ?? 'Unknown',
      shortComment: json['shortComment'] ?? '',
      longComment: json['longComment'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      details: json['details'] != null
          ? InjuryDetails.fromJSON(json['details'])
          : null,
      type: InjuryType.fromJSON(json['type'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'athleteId': athleteId,
      'athleteName': athleteName,
      'athletePosition': athletePosition,
      'status': status,
      'shortComment': shortComment,
      'longComment': longComment,
      'date': date.toIso8601String(),
      'details': details?.toJson(),
      'type': type.toJson(),
    };
  }

  // Severity based on status
  InjurySeverity get severity {
    switch (status.toLowerCase()) {
      case 'out':
        return InjurySeverity.out;
      case 'doubtful':
        return InjurySeverity.doubtful;
      case 'questionable':
        return InjurySeverity.questionable;
      default:
        return InjurySeverity.dayToDay;
    }
  }

  // Impact score for betting analysis
  double get impactScore {
    switch (severity) {
      case InjurySeverity.out:
        return 10.0;
      case InjurySeverity.doubtful:
        return 7.0;
      case InjurySeverity.questionable:
        return 4.0;
      case InjurySeverity.dayToDay:
        return 1.0;
    }
  }
}

class InjuryDetails {
  final String? type; // "Knee", "Ankle", etc.
  final String? location; // "Leg", "Arm", etc.
  final String? detail; // "Surgery", "Sprain", etc.
  final String? side; // "Left", "Right"
  final DateTime? returnDate;
  final FantasyStatus? fantasyStatus;

  InjuryDetails({
    this.type,
    this.location,
    this.detail,
    this.side,
    this.returnDate,
    this.fantasyStatus,
  });

  factory InjuryDetails.fromJSON(Map<String, dynamic> json) {
    return InjuryDetails(
      type: json['type'],
      location: json['location'],
      detail: json['detail'],
      side: json['side'],
      returnDate: json['returnDate'] != null
          ? DateTime.parse(json['returnDate'])
          : null,
      fantasyStatus: json['fantasyStatus'] != null
          ? FantasyStatus.fromJSON(json['fantasyStatus'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'location': location,
      'detail': detail,
      'side': side,
      'returnDate': returnDate?.toIso8601String(),
      'fantasyStatus': fantasyStatus?.toJson(),
    };
  }

  String get injuryDescription {
    final parts = <String>[];
    if (side != null) parts.add(side!);
    if (type != null) parts.add(type!);
    if (detail != null && detail != type) parts.add('($detail)');
    return parts.isNotEmpty ? parts.join(' ') : 'Injury';
  }
}

class InjuryType {
  final String name; // "INJURY_STATUS_OUT"
  final String description; // "out"
  final String abbreviation; // "O"

  InjuryType({
    required this.name,
    required this.description,
    required this.abbreviation,
  });

  factory InjuryType.fromJSON(Map<String, dynamic> json) {
    return InjuryType(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'abbreviation': abbreviation,
    };
  }
}

class FantasyStatus {
  final String description; // "OUT"
  final String abbreviation; // "OUT"

  FantasyStatus({
    required this.description,
    required this.abbreviation,
  });

  factory FantasyStatus.fromJSON(Map<String, dynamic> json) {
    return FantasyStatus(
      description: json['description'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'abbreviation': abbreviation,
    };
  }
}

enum InjurySeverity {
  out, // Definitely not playing
  doubtful, // <25% chance of playing
  questionable, // 50/50 chance
  dayToDay, // Minor, game-time decision
}

class GameInjuryReport {
  final String homeTeamId;
  final String homeTeamName;
  final String? homeTeamLogo;
  final String awayTeamId;
  final String awayTeamName;
  final String? awayTeamLogo;
  final List<Injury> homeInjuries;
  final List<Injury> awayInjuries;
  final DateTime fetchedAt;

  GameInjuryReport({
    required this.homeTeamId,
    required this.homeTeamName,
    this.homeTeamLogo,
    required this.awayTeamId,
    required this.awayTeamName,
    this.awayTeamLogo,
    required this.homeInjuries,
    required this.awayInjuries,
    required this.fetchedAt,
  });

  factory GameInjuryReport.fromJson(Map<String, dynamic> json) {
    return GameInjuryReport(
      homeTeamId: json['homeTeamId'],
      homeTeamName: json['homeTeamName'],
      homeTeamLogo: json['homeTeamLogo'],
      awayTeamId: json['awayTeamId'],
      awayTeamName: json['awayTeamName'],
      awayTeamLogo: json['awayTeamLogo'],
      homeInjuries: (json['homeInjuries'] as List)
          .map((i) => Injury.fromESPN(i))
          .toList(),
      awayInjuries: (json['awayInjuries'] as List)
          .map((i) => Injury.fromESPN(i))
          .toList(),
      fetchedAt: DateTime.parse(json['fetchedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'homeTeamId': homeTeamId,
      'homeTeamName': homeTeamName,
      'homeTeamLogo': homeTeamLogo,
      'awayTeamId': awayTeamId,
      'awayTeamName': awayTeamName,
      'awayTeamLogo': awayTeamLogo,
      'homeInjuries': homeInjuries.map((i) => i.toJson()).toList(),
      'awayInjuries': awayInjuries.map((i) => i.toJson()).toList(),
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  // Calculate impact score for betting
  double get homeImpactScore {
    return homeInjuries.fold(0.0, (sum, injury) => sum + injury.impactScore);
  }

  double get awayImpactScore {
    return awayInjuries.fold(0.0, (sum, injury) => sum + injury.impactScore);
  }

  // Which team is more affected by injuries?
  String get advantageTeam {
    if (homeImpactScore > awayImpactScore + 5) {
      return awayTeamName; // Away team has advantage
    } else if (awayImpactScore > homeImpactScore + 5) {
      return homeTeamName; // Home team has advantage
    }
    return 'Even'; // Injuries cancel out
  }

  // Injury insight for betting recommendations
  String get insightText {
    if (advantageTeam == 'Even') {
      return 'Both teams similarly affected by injuries. Injury factor is neutral in this matchup.';
    }

    final advantagedTeam = advantageTeam;
    final disadvantagedTeam =
        advantageTeam == homeTeamName ? awayTeamName : homeTeamName;

    return '$advantagedTeam has the health advantage over $disadvantagedTeam. Consider this in your betting decision.';
  }

  bool get hasSignificantInjuries {
    return homeImpactScore > 5 || awayImpactScore > 5;
  }

  int get totalInjuries {
    return homeInjuries.length + awayInjuries.length;
  }
}
