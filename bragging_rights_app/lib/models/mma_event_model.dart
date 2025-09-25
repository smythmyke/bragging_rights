import 'mma_fighter_model.dart';

/// MMA Event Model (UFC, Bellator, PFL, ONE Championship)
class MMAEvent {
  final String id;
  final String? espnId; // ESPN event ID for direct API access
  final String name; // "UFC 311: Makhachev vs. Moicano"
  final String? shortName; // "UFC 311"
  final DateTime date;
  final String? promotion; // "UFC", "Bellator", "PFL", "ONE"
  final String? promotionLogoUrl;

  // Venue
  final String? venue;
  final String? venueName;
  final String? venueCity;
  final String? venueState;
  final String? venueCountry;
  final bool? isIndoor;

  // Fights
  final List<MMAFight> fights;
  final MMAFight? mainEvent;
  final MMAFight? coMainEvent;

  // Broadcast
  final List<String>? broadcasters; // ["ESPN+ PPV", "ESPN", "UFC Fight Pass"]
  final String? broadcastDetails;
  final Map<String, String>? broadcastByCard; // {'main': 'DAZN PPV', 'prelim': 'DAZN'}

  // Status
  final String? status; // "Scheduled", "In Progress", "Final"
  final bool isLive;
  final bool isComplete;

  // ESPN specific (legacy - keeping for compatibility)
  final String? espnEventId;
  final String? espnUrl;

  // Cache info
  final DateTime? lastUpdated;

  MMAEvent({
    required this.id,
    this.espnId,
    required this.name,
    this.shortName,
    required this.date,
    this.promotion,
    this.promotionLogoUrl,
    this.venue,
    this.venueName,
    this.venueCity,
    this.venueState,
    this.venueCountry,
    this.isIndoor,
    required this.fights,
    this.mainEvent,
    this.coMainEvent,
    this.broadcasters,
    this.broadcastDetails,
    this.broadcastByCard,
    this.status,
    this.isLive = false,
    this.isComplete = false,
    this.espnEventId,
    this.espnUrl,
    this.lastUpdated,
  });

  factory MMAEvent.fromESPN(Map<String, dynamic> json, {List<MMAFight>? fights}) {
    // Parse venue
    Map<String, dynamic>? venue = json['venue'];

    // Parse fights and identify main/co-main
    List<MMAFight> allFights = fights ?? [];
    MMAFight? mainEvent;
    MMAFight? coMainEvent;

    if (allFights.isNotEmpty) {
      // Main event is usually the last fight or marked as main
      mainEvent = allFights.firstWhere(
        (MMAFight f) => f.isMainEvent,
        orElse: () => allFights.last,
      );

      // Co-main is the second to last or marked as co-main
      if (allFights.length > 1) {
        coMainEvent = allFights.firstWhere(
          (MMAFight f) => f.isCoMainEvent && f != mainEvent,
          orElse: () => allFights[allFights.length - 2],
        );
      }
    }

    // Parse broadcast info
    List<String>? broadcasters;
    if (json['competitions'] != null && json['competitions'].isNotEmpty) {
      var broadcasts = json['competitions'][0]['broadcasts'];
      if (broadcasts != null) {
        broadcasters = (broadcasts as List)
            .map((b) => b['names']?.first ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
            .cast<String>();
      }
    }

    return MMAEvent(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      shortName: json['shortName'],
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      promotion: _extractPromotion(json['name'] ?? ''),
      promotionLogoUrl: _getPromotionLogo(json['name'] ?? ''),
      venueName: venue?['fullName'],
      venueCity: venue?['address']?['city'],
      venueState: venue?['address']?['state'],
      venueCountry: venue?['address']?['country'],
      isIndoor: venue?['indoor'],
      fights: allFights,
      mainEvent: mainEvent,
      coMainEvent: coMainEvent,
      broadcasters: broadcasters,
      broadcastDetails: json['broadcastDetails'],
      status: json['status']?['type']?['description'],
      isLive: json['status']?['type']?['state'] == 'in',
      isComplete: json['status']?['type']?['completed'] ?? false,
      espnEventId: json['id']?.toString(),
      espnUrl: json['links']?.firstWhere(
        (link) => link['rel']?.contains('summary') ?? false,
        orElse: () => null,
      )?['href'],
      lastUpdated: DateTime.now(),
    );
  }

  static String? _extractPromotion(String eventName) {
    if (eventName.contains('UFC')) return 'UFC';
    if (eventName.contains('Bellator')) return 'Bellator';
    if (eventName.contains('PFL')) return 'PFL';
    if (eventName.contains('ONE')) return 'ONE';
    if (eventName.contains('Contender Series')) return 'DWCS';
    return null;
  }

  static String? _getPromotionLogo(String eventName) {
    final upperName = eventName.toUpperCase();

    if (upperName.contains('UFC')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/ufc.png';
    } else if (upperName.contains('PFL')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/pfl.png';
    } else if (upperName.contains('BELLATOR')) {
      // Bellator doesn't have an ESPN logo, use a placeholder or custom URL
      return 'https://www.bellator.com/themes/custom/bellator/assets/images/bellator-mma.svg';
    } else if (upperName.contains('ONE') && (upperName.contains('CHAMPIONSHIP') || upperName.contains('FC'))) {
      // ONE Championship logo
      return 'https://www.onefc.com/wp-content/themes/onefc/assets/images/logo.svg';
    }

    // Default to UFC logo for generic MMA events
    return 'https://a.espncdn.com/i/teamlogos/leagues/500/ufc.png';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'espnId': espnId,
      'name': name,
      'shortName': shortName,
      'date': date.toIso8601String(),
      'promotion': promotion,
      'promotionLogoUrl': promotionLogoUrl,
      'venue': venue,
      'venueName': venueName,
      'venueCity': venueCity,
      'venueState': venueState,
      'venueCountry': venueCountry,
      'isIndoor': isIndoor,
      'fights': fights.map((f) => f.toJson()).toList(),
      'mainEventId': mainEvent?.id,
      'coMainEventId': coMainEvent?.id,
      'broadcasters': broadcasters,
      'broadcastDetails': broadcastDetails,
      'status': status,
      'isLive': isLive,
      'isComplete': isComplete,
      'espnEventId': espnEventId,
      'espnUrl': espnUrl,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory MMAEvent.fromJson(Map<String, dynamic> json) {
    return MMAEvent(
      id: json['id'],
      espnId: json['espnId'],
      name: json['name'],
      shortName: json['shortName'],
      date: DateTime.parse(json['date']),
      promotion: json['promotion'],
      promotionLogoUrl: json['promotionLogoUrl'],
      venue: json['venue'],
      venueName: json['venueName'],
      venueCity: json['venueCity'],
      venueState: json['venueState'],
      venueCountry: json['venueCountry'],
      isIndoor: json['isIndoor'],
      fights: (json['fights'] as List?)
          ?.map((f) => MMAFight.fromJson(f))
          .toList() ?? [],
      broadcasters: (json['broadcasters'] as List?)?.cast<String>(),
      broadcastDetails: json['broadcastDetails'],
      status: json['status'],
      isLive: json['isLive'] ?? false,
      isComplete: json['isComplete'] ?? false,
      espnEventId: json['espnEventId'],
      espnUrl: json['espnUrl'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
    );
  }

  // Helper getters
  List<MMAFight> get mainCardFights {
    return fights.where((f) => f.cardPosition == 'main').toList();
  }

  List<MMAFight> get prelimFights {
    return fights.where((f) => f.cardPosition == 'prelim').toList();
  }

  List<MMAFight> get earlyPrelimFights {
    return fights.where((f) => f.cardPosition == 'early').toList();
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get venueLocation {
    List<String> parts = [];
    if (venueCity != null) parts.add(venueCity!);
    if (venueState != null) parts.add(venueState!);
    if (venueCountry != null && venueCountry != 'USA') parts.add(venueCountry!);
    return parts.join(', ');
  }
}

/// Individual MMA Fight/Bout
class MMAFight {
  final String id;
  final String? espnCompetitionId; // ESPN competition ID for this specific fight
  final String? fighter1EspnId; // ESPN athlete ID for fighter 1
  final String? fighter2EspnId; // ESPN athlete ID for fighter 2
  final MMAFighter? fighter1;
  final MMAFighter? fighter2;

  // Fight details
  final String? weightClass;
  final int rounds; // 3 or 5
  final bool isMainEvent;
  final bool isCoMainEvent;
  final bool isTitleFight;
  final String cardPosition; // "main", "prelim", "early"
  final int? fightOrder; // Position on card (1 = first fight)

  // Odds (if available)
  final double? fighter1Odds;
  final double? fighter2Odds;

  // Result (post-fight)
  final String? winnerId;
  final String? method; // "KO", "TKO", "Submission", "Decision"
  final String? methodDetails; // "Rear Naked Choke", "Unanimous Decision"
  final int? endRound;
  final String? endTime;

  // Status
  final String? status;
  final bool isComplete;
  final bool isCancelled;

  MMAFight({
    required this.id,
    this.espnCompetitionId,
    this.fighter1EspnId,
    this.fighter2EspnId,
    this.fighter1,
    this.fighter2,
    this.weightClass,
    this.rounds = 3,
    this.isMainEvent = false,
    this.isCoMainEvent = false,
    this.isTitleFight = false,
    this.cardPosition = 'main',
    this.fightOrder,
    this.fighter1Odds,
    this.fighter2Odds,
    this.winnerId,
    this.method,
    this.methodDetails,
    this.endRound,
    this.endTime,
    this.status,
    this.isComplete = false,
    this.isCancelled = false,
  });

  factory MMAFight.fromESPN(Map<String, dynamic> json, {
    MMAFighter? fighter1,
    MMAFighter? fighter2,
  }) {
    // Parse competition type for weight class
    String? weightClass = json['type']?['text'] ?? json['type']?['abbreviation'];

    // Determine card position based on order or other indicators
    String cardPosition = 'main'; // Default
    int? fightOrder = json['order'];

    // Check if title fight
    bool isTitleFight = json['description']?.toLowerCase().contains('title') ?? false;

    // Parse result if fight is complete
    String? winnerId;
    String? method;
    if (json['status']?['type']?['completed'] == true) {
      // Find winner
      var competitors = json['competitors'];
      if (competitors != null) {
        for (var comp in competitors) {
          if (comp['winner'] == true) {
            winnerId = comp['id']?.toString();
            break;
          }
        }
      }

      // Parse method from status or result
      method = json['status']?['result']?['method'];
    }

    return MMAFight(
      id: json['id']?.toString() ?? '',
      fighter1: fighter1,
      fighter2: fighter2,
      weightClass: weightClass,
      rounds: json['format']?['regulation']?['periods'] ?? 3,
      isMainEvent: json['isMainEvent'] ?? false,
      isCoMainEvent: json['isCoMainEvent'] ?? false,
      isTitleFight: isTitleFight,
      cardPosition: cardPosition,
      fightOrder: fightOrder,
      fighter1Odds: json['odds']?['fighter1']?.toDouble(),
      fighter2Odds: json['odds']?['fighter2']?.toDouble(),
      winnerId: winnerId,
      method: method,
      methodDetails: json['status']?['result']?['methodDetails'],
      endRound: json['status']?['result']?['round'],
      endTime: json['status']?['result']?['time'],
      status: json['status']?['type']?['description'],
      isComplete: json['status']?['type']?['completed'] ?? false,
      isCancelled: json['status']?['type']?['name'] == 'STATUS_CANCELED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'espnCompetitionId': espnCompetitionId,
      'fighter1EspnId': fighter1EspnId,
      'fighter2EspnId': fighter2EspnId,
      'fighter1': fighter1?.toJson(),
      'fighter2': fighter2?.toJson(),
      'weightClass': weightClass,
      'rounds': rounds,
      'isMainEvent': isMainEvent,
      'isCoMainEvent': isCoMainEvent,
      'isTitleFight': isTitleFight,
      'cardPosition': cardPosition,
      'fightOrder': fightOrder,
      'fighter1Odds': fighter1Odds,
      'fighter2Odds': fighter2Odds,
      'winnerId': winnerId,
      'method': method,
      'methodDetails': methodDetails,
      'endRound': endRound,
      'endTime': endTime,
      'status': status,
      'isComplete': isComplete,
      'isCancelled': isCancelled,
    };
  }

  factory MMAFight.fromJson(Map<String, dynamic> json) {
    return MMAFight(
      id: json['id'],
      espnCompetitionId: json['espnCompetitionId'],
      fighter1EspnId: json['fighter1EspnId'],
      fighter2EspnId: json['fighter2EspnId'],
      fighter1: json['fighter1'] != null
          ? MMAFighter.fromJson(json['fighter1'])
          : null,
      fighter2: json['fighter2'] != null
          ? MMAFighter.fromJson(json['fighter2'])
          : null,
      weightClass: json['weightClass'],
      rounds: json['rounds'] ?? 3,
      isMainEvent: json['isMainEvent'] ?? false,
      isCoMainEvent: json['isCoMainEvent'] ?? false,
      isTitleFight: json['isTitleFight'] ?? false,
      cardPosition: json['cardPosition'] ?? 'main',
      fightOrder: json['fightOrder'],
      fighter1Odds: json['fighter1Odds']?.toDouble(),
      fighter2Odds: json['fighter2Odds']?.toDouble(),
      winnerId: json['winnerId'],
      method: json['method'],
      methodDetails: json['methodDetails'],
      endRound: json['endRound'],
      endTime: json['endTime'],
      status: json['status'],
      isComplete: json['isComplete'] ?? false,
      isCancelled: json['isCancelled'] ?? false,
    );
  }

  // Helper getters
  String get fightDescription {
    String desc = weightClass ?? 'Catchweight';
    if (isTitleFight) desc += ' Title';
    desc += ' • $rounds Rounds';
    return desc;
  }

  String? get resultDescription {
    if (!isComplete || winnerId == null) return null;

    String winner = winnerId == fighter1?.id ? fighter1!.name : fighter2!.name;
    String result = '$winner wins';

    if (method != null) {
      result += ' via $method';
      if (endRound != null) {
        result += ' (R$endRound';
        if (endTime != null) result += ', $endTime';
        result += ')';
      }
    }

    return result;
  }

  MMAFighter? get winner {
    if (winnerId == null) return null;
    return winnerId == fighter1?.id ? fighter1 : fighter2;
  }

  MMAFighter? get loser {
    if (winnerId == null) return null;
    return winnerId == fighter1?.id ? fighter2 : fighter1;
  }

  // Create a copy with updated fields
  MMAFight copyWith({
    String? id,
    MMAFighter? fighter1,
    MMAFighter? fighter2,
    String? weightClass,
    int? rounds,
    bool? isMainEvent,
    bool? isCoMainEvent,
    bool? isTitleFight,
    String? cardPosition,
    int? fightOrder,
    double? fighter1Odds,
    double? fighter2Odds,
    String? winnerId,
    String? method,
    String? methodDetails,
    int? endRound,
    String? endTime,
    String? status,
    bool? isComplete,
    bool? isCancelled,
  }) {
    return MMAFight(
      id: id ?? this.id,
      fighter1: fighter1 ?? this.fighter1,
      fighter2: fighter2 ?? this.fighter2,
      weightClass: weightClass ?? this.weightClass,
      rounds: rounds ?? this.rounds,
      isMainEvent: isMainEvent ?? this.isMainEvent,
      isCoMainEvent: isCoMainEvent ?? this.isCoMainEvent,
      isTitleFight: isTitleFight ?? this.isTitleFight,
      cardPosition: cardPosition ?? this.cardPosition,
      fightOrder: fightOrder ?? this.fightOrder,
      fighter1Odds: fighter1Odds ?? this.fighter1Odds,
      fighter2Odds: fighter2Odds ?? this.fighter2Odds,
      winnerId: winnerId ?? this.winnerId,
      method: method ?? this.method,
      methodDetails: methodDetails ?? this.methodDetails,
      endRound: endRound ?? this.endRound,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}