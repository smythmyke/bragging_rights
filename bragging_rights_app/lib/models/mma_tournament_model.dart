import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentStatus {
  upcoming,
  registrationOpen,
  registrationClosed,
  prelims,
  mainCard,
  mainEvent,
  completed,
  cancelled
}

enum BracketType { preliminary, mainCard, mainEvent }

enum BracketStatus { pending, active, scoring, completed }

class MMATournamentModel {
  final String id;
  final String eventId;
  final String eventName;
  final String promotion; // UFC, Bellator, PFL
  final DateTime eventDate;
  final int entryFeeVC;
  final Map<String, dynamic> cashPrizes;
  final TournamentStatus status;
  final List<TournamentBracket> brackets;
  final int maxParticipants;
  final int currentParticipants;
  final String? eventImageUrl;
  final DateTime createdAt;
  final DateTime? registrationCloses;
  final DateTime? startedAt;
  final DateTime? completedAt;

  MMATournamentModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.promotion,
    required this.eventDate,
    required this.entryFeeVC,
    required this.cashPrizes,
    required this.status,
    required this.brackets,
    required this.maxParticipants,
    required this.currentParticipants,
    this.eventImageUrl,
    required this.createdAt,
    this.registrationCloses,
    this.startedAt,
    this.completedAt,
  });

  factory MMATournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MMATournamentModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      promotion: data['promotion'] ?? 'UFC',
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      entryFeeVC: data['entryFeeVC'] ?? 100,
      cashPrizes: data['cashPrizes'] ?? {},
      status: TournamentStatus.values.firstWhere(
        (e) => e.toString() == 'TournamentStatus.${data['status']}',
        orElse: () => TournamentStatus.upcoming,
      ),
      brackets: (data['brackets'] as List<dynamic>?)
              ?.map((b) => TournamentBracket.fromMap(b))
              .toList() ??
          [],
      maxParticipants: data['maxParticipants'] ?? 1000,
      currentParticipants: data['currentParticipants'] ?? 0,
      eventImageUrl: data['eventImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      registrationCloses: data['registrationCloses'] != null
          ? (data['registrationCloses'] as Timestamp).toDate()
          : null,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'promotion': promotion,
      'eventDate': Timestamp.fromDate(eventDate),
      'entryFeeVC': entryFeeVC,
      'cashPrizes': cashPrizes,
      'status': status.toString().split('.').last,
      'brackets': brackets.map((b) => b.toMap()).toList(),
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'eventImageUrl': eventImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'registrationCloses': registrationCloses != null
          ? Timestamp.fromDate(registrationCloses!)
          : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  double get fillRate => currentParticipants / maxParticipants;
  bool get isFull => currentParticipants >= maxParticipants;
  bool get canRegister => status == TournamentStatus.registrationOpen && !isFull;

  int get totalPrizePool {
    return cashPrizes.values
        .where((v) => v is int)
        .fold(0, (sum, prize) => sum + (prize as int));
  }

  static Map<String, dynamic> getDefaultPrizeStructure(String tier) {
    switch (tier) {
      case 'bronze':
        return {
          '1st': 15,
          '2nd': 10,
          '3rd': 7,
          '4th-10th': 2,
          '11th-20th': 0.50,
        };
      case 'silver':
        return {
          '1st': 100,
          '2nd': 50,
          '3rd': 25,
          '4th': 15,
          '5th': 10,
        };
      case 'gold':
        return {
          '1st': 300,
          '2nd': 150,
          '3rd': 50,
        };
      default:
        return {'1st': 50};
    }
  }
}

class TournamentBracket {
  final String bracketId;
  final BracketType type;
  final double eliminationPercentage;
  final List<String> fightIds;
  final BracketStatus status;
  final List<String> qualifiedParticipantIds;
  final int prizePoolPercentage;

  TournamentBracket({
    required this.bracketId,
    required this.type,
    required this.eliminationPercentage,
    required this.fightIds,
    required this.status,
    required this.qualifiedParticipantIds,
    required this.prizePoolPercentage,
  });

  factory TournamentBracket.fromMap(Map<String, dynamic> map) {
    return TournamentBracket(
      bracketId: map['bracketId'] ?? '',
      type: BracketType.values.firstWhere(
        (e) => e.toString() == 'BracketType.${map['type']}',
        orElse: () => BracketType.preliminary,
      ),
      eliminationPercentage: (map['eliminationPercentage'] ?? 0).toDouble(),
      fightIds: List<String>.from(map['fightIds'] ?? []),
      status: BracketStatus.values.firstWhere(
        (e) => e.toString() == 'BracketStatus.${map['status']}',
        orElse: () => BracketStatus.pending,
      ),
      qualifiedParticipantIds:
          List<String>.from(map['qualifiedParticipantIds'] ?? []),
      prizePoolPercentage: map['prizePoolPercentage'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bracketId': bracketId,
      'type': type.toString().split('.').last,
      'eliminationPercentage': eliminationPercentage,
      'fightIds': fightIds,
      'status': status.toString().split('.').last,
      'qualifiedParticipantIds': qualifiedParticipantIds,
      'prizePoolPercentage': prizePoolPercentage,
    };
  }

  static List<TournamentBracket> createDefaultBrackets() {
    return [
      TournamentBracket(
        bracketId: 'prelims',
        type: BracketType.preliminary,
        eliminationPercentage: 0.50, // Eliminate bottom 50%
        fightIds: [],
        status: BracketStatus.pending,
        qualifiedParticipantIds: [],
        prizePoolPercentage: 20,
      ),
      TournamentBracket(
        bracketId: 'mainCard',
        type: BracketType.mainCard,
        eliminationPercentage: 0.95, // Keep only top 5%
        fightIds: [],
        status: BracketStatus.pending,
        qualifiedParticipantIds: [],
        prizePoolPercentage: 35,
      ),
      TournamentBracket(
        bracketId: 'mainEvent',
        type: BracketType.mainEvent,
        eliminationPercentage: 0, // Winner takes all
        fightIds: [],
        status: BracketStatus.pending,
        qualifiedParticipantIds: [],
        prizePoolPercentage: 45,
      ),
    ];
  }
}