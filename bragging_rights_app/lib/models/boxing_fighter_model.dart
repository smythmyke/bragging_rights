import 'package:cloud_firestore/cloud_firestore.dart';
import 'boxing_event_model.dart' show DataSource;

class BoxingFighter {
  final String id;
  final String name;
  final String? nickname;
  final String nationality;
  final int? age;
  final BoxingStats stats;
  final PhysicalAttributes physical;
  final String? division;
  final List<String> titles;
  final DataSource source;
  final DateTime? lastUpdated;

  BoxingFighter({
    required this.id,
    required this.name,
    this.nickname,
    required this.nationality,
    this.age,
    required this.stats,
    required this.physical,
    this.division,
    required this.titles,
    required this.source,
    this.lastUpdated,
  });

  bool get isChampion => titles.isNotEmpty;
  double get koPercentage => stats.koPercentage;
  String get record => '${stats.wins}-${stats.losses}${stats.draws > 0 ? '-${stats.draws}' : ''}';

  factory BoxingFighter.fromBoxingData(Map<String, dynamic> data) {
    return BoxingFighter(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      nickname: data['nickname'],
      nationality: data['nationality'] ?? '',
      age: data['age'],
      stats: BoxingStats.fromMap(data['stats'] ?? {}),
      physical: PhysicalAttributes.fromMap(data),
      division: data['division']?['name'] ?? data['division'],
      titles: List<String>.from(
        data['titles']?.map((t) => t['name'] ?? t.toString()) ?? []
      ),
      source: DataSource.boxingData,
      lastUpdated: data['lastUpdated'] != null
        ? (data['lastUpdated'] as Timestamp).toDate()
        : null,
    );
  }

  factory BoxingFighter.fromESPN(Map<String, dynamic> data) {
    final record = data['record'] ?? '';
    final recordParts = record.split('-');

    return BoxingFighter(
      id: data['id'] ?? '',
      name: data['displayName'] ?? data['name'] ?? '',
      nickname: data['nickname'],
      nationality: data['birthCountry'] ?? '',
      age: data['age'],
      stats: BoxingStats(
        wins: int.tryParse(recordParts.isNotEmpty ? recordParts[0] : '0') ?? 0,
        losses: recordParts.length > 1 ? int.tryParse(recordParts[1]) ?? 0 : 0,
        draws: recordParts.length > 2 ? int.tryParse(recordParts[2]) ?? 0 : 0,
        kos: 0,
        totalBouts: 0,
      ),
      physical: PhysicalAttributes(
        height: data['height'] ?? '',
        reach: data['reach'] ?? '',
        stance: data['stance'] ?? '',
      ),
      division: data['weightClass'],
      titles: [],
      source: DataSource.espn,
    );
  }

  factory BoxingFighter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return BoxingFighter.fromBoxingData(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nickname': nickname,
      'nationality': nationality,
      'age': age,
      'stats': stats.toMap(),
      'height': physical.height,
      'reach': physical.reach,
      'stance': physical.stance,
      'division': division,
      'titles': titles,
      'source': source.toString(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class BoxingStats {
  final int wins;
  final int losses;
  final int draws;
  final int kos;
  final int totalBouts;

  BoxingStats({
    required this.wins,
    required this.losses,
    required this.draws,
    required this.kos,
    required this.totalBouts,
  });

  double get koPercentage => wins > 0 ? (kos / wins) * 100 : 0;
  double get winPercentage => totalBouts > 0 ? (wins / totalBouts) * 100 : 0;

  factory BoxingStats.fromMap(Map<String, dynamic> data) {
    final wins = data['wins'] ?? 0;
    final losses = data['losses'] ?? 0;
    final draws = data['draws'] ?? 0;

    return BoxingStats(
      wins: wins,
      losses: losses,
      draws: draws,
      kos: data['ko_wins'] ?? data['kos'] ?? 0,
      totalBouts: data['total_bouts'] ?? (wins + losses + draws),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'ko_wins': kos,
      'total_bouts': totalBouts,
      'ko_percentage': koPercentage,
    };
  }
}

class PhysicalAttributes {
  final String height;
  final String reach;
  final String stance;

  PhysicalAttributes({
    required this.height,
    required this.reach,
    required this.stance,
  });

  factory PhysicalAttributes.fromMap(Map<String, dynamic> data) {
    return PhysicalAttributes(
      height: data['height'] ?? '',
      reach: data['reach'] ?? '',
      stance: data['stance'] ?? '',
    );
  }
}

