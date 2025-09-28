import 'package:cloud_firestore/cloud_firestore.dart';

enum FightStatus { upcoming, live, completed, cancelled }

class BoxingFight {
  final String id;
  final String title;
  final String eventId;
  final Map<String, BoxingFighterInfo> fighters;
  final String division;
  final int scheduledRounds;
  final List<String> titles;
  final int cardPosition;
  final FightStatus status;
  final String? result;
  final String? method;
  final int? endingRound;
  final DateTime? date;

  BoxingFight({
    required this.id,
    required this.title,
    required this.eventId,
    required this.fighters,
    required this.division,
    required this.scheduledRounds,
    required this.titles,
    required this.cardPosition,
    required this.status,
    this.result,
    this.method,
    this.endingRound,
    this.date,
    this.odds,  // Add odds field
  });

  final Map<String, dynamic>? odds;  // Betting odds from Odds API

  bool get isMainEvent => cardPosition == 1;
  bool get isTitleFight => titles.isNotEmpty;
  bool get isChampionshipFight => titles.any((t) =>
    t.toLowerCase().contains('world') ||
    t.toLowerCase().contains('championship')
  );

  factory BoxingFight.fromBoxingData(Map<String, dynamic> data) {
    final fightersData = data['fighters'] as Map<String, dynamic>? ?? {};

    return BoxingFight(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      eventId: data['event']?['id'] ?? data['eventId'] ?? '',
      fighters: {
        'fighter1': BoxingFighterInfo.fromBoxingData(fightersData['fighter_1'] ?? {}),
        'fighter2': BoxingFighterInfo.fromBoxingData(fightersData['fighter_2'] ?? {}),
      },
      division: data['division']?['name'] ?? data['division'] ?? '',
      scheduledRounds: data['scheduled_rounds'] ?? 12,
      titles: List<String>.from(
        data['titles']?.map((t) => t['name'] ?? t.toString()) ?? []
      ),
      cardPosition: data['cardPosition'] ?? 99,
      status: _parseStatus(data['status']),
      result: data['result'],
      method: data['method'],
      endingRound: data['ending_round'],
      date: data['date'] != null ? DateTime.parse(data['date']) : null,
    );
  }

  factory BoxingFight.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return BoxingFight.fromBoxingData(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'eventId': eventId,
      'fighters': {
        'fighter_1': fighters['fighter1']?.toMap(),
        'fighter_2': fighters['fighter2']?.toMap(),
      },
      'division': division,
      'scheduled_rounds': scheduledRounds,
      'titles': titles,
      'cardPosition': cardPosition,
      'status': status.toString(),
      'result': result,
      'method': method,
      'ending_round': endingRound,
      'date': date?.toIso8601String(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  static FightStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'live':
      case 'in_progress':
        return FightStatus.live;
      case 'completed':
      case 'finished':
        return FightStatus.completed;
      case 'cancelled':
      case 'canceled':
        return FightStatus.cancelled;
      default:
        return FightStatus.upcoming;
    }
  }
}

class BoxingFighterInfo {
  final String id;
  final String name;
  final String fullName;
  final String? record;
  final String? nationality;
  final bool? isWinner;
  final String? imageUrl;  // From Boxing Data API cache
  final bool? isChampion;  // From Boxing Data API cache
  final String? ranking;    // From Boxing Data API cache (e.g., "#3")

  BoxingFighterInfo({
    required this.id,
    required this.name,
    required this.fullName,
    this.record,
    this.nationality,
    this.isWinner,
    this.imageUrl,
    this.isChampion,
    this.ranking,
  });

  factory BoxingFighterInfo.fromBoxingData(Map<String, dynamic> data) {
    return BoxingFighterInfo(
      id: data['fighter_id'] ?? data['id'] ?? '',
      name: data['name'] ?? '',
      fullName: data['full_name'] ?? data['name'] ?? '',
      record: data['record'],
      nationality: data['nationality'],
      isWinner: data['is_winner'],
      imageUrl: data['image_url'] ?? data['imageUrl'],
      isChampion: data['is_champion'] ?? data['isChampion'],
      ranking: data['ranking'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fighter_id': id,
      'name': name,
      'full_name': fullName,
      'record': record,
      'nationality': nationality,
      'is_winner': isWinner,
      'image_url': imageUrl,
      'is_champion': isChampion,
      'ranking': ranking,
    };
  }
}