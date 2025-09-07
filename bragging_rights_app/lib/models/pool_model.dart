import 'package:cloud_firestore/cloud_firestore.dart';

enum PoolType {
  quick,
  regional,
  private,
  tournament,
}

enum PoolStatus {
  open,
  closed,
  inProgress,
  completed,
}

enum PoolTier {
  beginner,
  standard,
  high,
  vip,
}

enum RegionalLevel {
  neighborhood,
  city,
  state,
  national,
}

class Pool {
  final String id;
  final String gameId;
  final String gameTitle;
  final String sport;
  final PoolType type;
  final PoolStatus status;
  final String name;
  final int buyIn;
  final int minPlayers;
  final int maxPlayers;
  final int currentPlayers;
  final List<String> playerIds;
  final DateTime startTime;
  final DateTime closeTime;
  final int prizePool;
  final Map<String, dynamic> prizeStructure;
  final String? code; // For private pools
  final RegionalLevel? regionalLevel;
  final String? region;
  final PoolTier? tier;
  final DateTime createdAt;
  final String? createdBy;
  final Map<String, dynamic>? metadata;

  Pool({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.type,
    required this.status,
    required this.name,
    required this.buyIn,
    required this.minPlayers,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.playerIds,
    required this.startTime,
    required this.closeTime,
    required this.prizePool,
    required this.prizeStructure,
    this.code,
    this.regionalLevel,
    this.region,
    this.tier,
    required this.createdAt,
    this.createdBy,
    this.metadata,
  });

  // Calculate fill percentage
  double get fillPercentage => currentPlayers / maxPlayers;
  
  // Check if pool is full
  bool get isFull => currentPlayers >= maxPlayers;
  
  // Check if pool can start
  bool get canStart => currentPlayers >= minPlayers;
  
  // Get formatted player count
  String get playerCountDisplay => '$currentPlayers/$maxPlayers players';
  
  // Get time until close
  Duration get timeUntilClose => closeTime.difference(DateTime.now());
  
  // Check if closing soon (less than 5 minutes)
  bool get isClosingSoon => timeUntilClose.inMinutes < 5;
  
  // Get prize for position
  int getPrizeForPosition(int position) {
    final positionKey = position.toString();
    if (prizeStructure.containsKey(positionKey)) {
      return prizeStructure[positionKey] as int;
    }
    return 0;
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'gameId': gameId,
      'gameTitle': gameTitle,
      'sport': sport,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'name': name,
      'buyIn': buyIn,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'playerIds': playerIds,
      'startTime': Timestamp.fromDate(startTime),
      'closeTime': Timestamp.fromDate(closeTime),
      'prizePool': prizePool,
      'prizeStructure': prizeStructure,
      'code': code,
      'regionalLevel': regionalLevel?.toString().split('.').last,
      'region': region,
      'tier': tier?.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  // Create from Firestore document
  factory Pool.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    if (rawData == null) {
      throw Exception('Pool document has no data');
    }
    final data = rawData as Map<String, dynamic>;
    return Pool(
      id: doc.id,
      gameId: data['gameId'] ?? '',
      gameTitle: data['gameTitle'] ?? '',
      sport: data['sport'] ?? '',
      type: PoolType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => PoolType.quick,
      ),
      status: PoolStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => PoolStatus.open,
      ),
      name: data['name'] ?? '',
      buyIn: data['buyIn'] ?? 0,
      minPlayers: data['minPlayers'] ?? 2,
      maxPlayers: data['maxPlayers'] ?? 100,
      currentPlayers: data['currentPlayers'] ?? 0,
      playerIds: List<String>.from(data['playerIds'] ?? []),
      startTime: data['startTime'] != null 
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 1)),
      closeTime: data['closeTime'] != null
          ? (data['closeTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 2)),
      prizePool: data['prizePool'] ?? 0,
      prizeStructure: data['prizeStructure'] ?? {},
      code: data['code'],
      regionalLevel: data['regionalLevel'] != null
          ? RegionalLevel.values.firstWhere(
              (e) => e.toString().split('.').last == data['regionalLevel'],
              orElse: () => RegionalLevel.neighborhood,
            )
          : null,
      region: data['region'],
      tier: data['tier'] != null
          ? PoolTier.values.firstWhere(
              (e) => e.toString().split('.').last == data['tier'],
              orElse: () => PoolTier.standard,
            )
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: data['createdBy'],
      metadata: data['metadata'],
    );
  }

  // Create a copy with updated fields
  Pool copyWith({
    String? id,
    String? gameId,
    String? gameTitle,
    String? sport,
    PoolType? type,
    PoolStatus? status,
    String? name,
    int? buyIn,
    int? minPlayers,
    int? maxPlayers,
    int? currentPlayers,
    List<String>? playerIds,
    DateTime? startTime,
    DateTime? closeTime,
    int? prizePool,
    Map<String, dynamic>? prizeStructure,
    String? code,
    RegionalLevel? regionalLevel,
    String? region,
    PoolTier? tier,
    DateTime? createdAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return Pool(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      gameTitle: gameTitle ?? this.gameTitle,
      sport: sport ?? this.sport,
      type: type ?? this.type,
      status: status ?? this.status,
      name: name ?? this.name,
      buyIn: buyIn ?? this.buyIn,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      playerIds: playerIds ?? this.playerIds,
      startTime: startTime ?? this.startTime,
      closeTime: closeTime ?? this.closeTime,
      prizePool: prizePool ?? this.prizePool,
      prizeStructure: prizeStructure ?? this.prizeStructure,
      code: code ?? this.code,
      regionalLevel: regionalLevel ?? this.regionalLevel,
      region: region ?? this.region,
      tier: tier ?? this.tier,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }
}

// Quick Play Pool Templates
class QuickPlayPoolTemplate {
  static Pool beginner({
    required String gameId,
    required String gameTitle,
    required String sport,
  }) {
    final now = DateTime.now();
    return Pool(
      id: '',
      gameId: gameId,
      gameTitle: gameTitle,
      sport: sport,
      type: PoolType.quick,
      status: PoolStatus.open,
      name: 'Beginner Pool',
      buyIn: 10,
      minPlayers: 10,
      maxPlayers: 50,
      currentPlayers: 0,
      playerIds: [],
      startTime: now.add(const Duration(minutes: 30)),
      closeTime: now.add(const Duration(minutes: 15)),
      prizePool: 500,
      prizeStructure: {
        '1': 250,
        '2': 150,
        '3': 100,
      },
      tier: PoolTier.beginner,
      createdAt: now,
      metadata: {
        'autoMatch': true,
        'skillLevel': 'beginner',
      },
    );
  }

  static Pool standard({
    required String gameId,
    required String gameTitle,
    required String sport,
  }) {
    final now = DateTime.now();
    return Pool(
      id: '',
      gameId: gameId,
      gameTitle: gameTitle,
      sport: sport,
      type: PoolType.quick,
      status: PoolStatus.open,
      name: 'Standard Pool',
      buyIn: 50,
      minPlayers: 20,
      maxPlayers: 100,
      currentPlayers: 0,
      playerIds: [],
      startTime: now.add(const Duration(minutes: 30)),
      closeTime: now.add(const Duration(minutes: 15)),
      prizePool: 5000,
      prizeStructure: {
        '1': 2000,
        '2': 1500,
        '3': 1000,
        '4': 500,
      },
      tier: PoolTier.standard,
      createdAt: now,
      metadata: {
        'autoMatch': true,
        'skillLevel': 'intermediate',
      },
    );
  }

  static Pool highStakes({
    required String gameId,
    required String gameTitle,
    required String sport,
  }) {
    final now = DateTime.now();
    return Pool(
      id: '',
      gameId: gameId,
      gameTitle: gameTitle,
      sport: sport,
      type: PoolType.quick,
      status: PoolStatus.open,
      name: 'High Stakes',
      buyIn: 200,
      minPlayers: 10,
      maxPlayers: 50,
      currentPlayers: 0,
      playerIds: [],
      startTime: now.add(const Duration(minutes: 30)),
      closeTime: now.add(const Duration(minutes: 15)),
      prizePool: 10000,
      prizeStructure: {
        '1': 5000,
        '2': 3000,
        '3': 1500,
        '4': 500,
      },
      tier: PoolTier.high,
      createdAt: now,
      metadata: {
        'autoMatch': true,
        'skillLevel': 'advanced',
      },
    );
  }

  static Pool vip({
    required String gameId,
    required String gameTitle,
    required String sport,
  }) {
    final now = DateTime.now();
    return Pool(
      id: '',
      gameId: gameId,
      gameTitle: gameTitle,
      sport: sport,
      type: PoolType.quick,
      status: PoolStatus.open,
      name: 'VIP Pool',
      buyIn: 500,
      minPlayers: 5,
      maxPlayers: 20,
      currentPlayers: 0,
      playerIds: [],
      startTime: now.add(const Duration(minutes: 30)),
      closeTime: now.add(const Duration(minutes: 15)),
      prizePool: 10000,
      prizeStructure: {
        '1': 6000,
        '2': 3000,
        '3': 1000,
      },
      tier: PoolTier.vip,
      createdAt: now,
      metadata: {
        'autoMatch': false,
        'skillLevel': 'expert',
        'vipOnly': true,
      },
    );
  }
}