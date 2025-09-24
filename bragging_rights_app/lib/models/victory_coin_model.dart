import 'package:cloud_firestore/cloud_firestore.dart';

class VictoryCoinModel {
  final String userId;
  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime lastEarned;
  final DateTime? lastSpent;
  final int dailyEarned;
  final int weeklyEarned;
  final int monthlyEarned;
  final DateTime lastResetDaily;
  final DateTime lastResetWeekly;
  final DateTime lastResetMonthly;
  final Map<String, dynamic> earningHistory;

  static const int DAILY_CAP = 500;
  static const int WEEKLY_CAP = 2500;
  static const int MONTHLY_CAP = 8000;

  VictoryCoinModel({
    required this.userId,
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.lastEarned,
    this.lastSpent,
    required this.dailyEarned,
    required this.weeklyEarned,
    required this.monthlyEarned,
    required this.lastResetDaily,
    required this.lastResetWeekly,
    required this.lastResetMonthly,
    required this.earningHistory,
  });

  factory VictoryCoinModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VictoryCoinModel(
      userId: doc.id,
      balance: data['balance'] ?? 0,
      lifetimeEarned: data['lifetimeEarned'] ?? 0,
      lifetimeSpent: data['lifetimeSpent'] ?? 0,
      lastEarned: (data['lastEarned'] as Timestamp).toDate(),
      lastSpent: data['lastSpent'] != null
          ? (data['lastSpent'] as Timestamp).toDate()
          : null,
      dailyEarned: data['dailyEarned'] ?? 0,
      weeklyEarned: data['weeklyEarned'] ?? 0,
      monthlyEarned: data['monthlyEarned'] ?? 0,
      lastResetDaily: (data['lastResetDaily'] as Timestamp).toDate(),
      lastResetWeekly: (data['lastResetWeekly'] as Timestamp).toDate(),
      lastResetMonthly: (data['lastResetMonthly'] as Timestamp).toDate(),
      earningHistory: data['earningHistory'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'balance': balance,
      'lifetimeEarned': lifetimeEarned,
      'lifetimeSpent': lifetimeSpent,
      'lastEarned': Timestamp.fromDate(lastEarned),
      'lastSpent': lastSpent != null ? Timestamp.fromDate(lastSpent!) : null,
      'dailyEarned': dailyEarned,
      'weeklyEarned': weeklyEarned,
      'monthlyEarned': monthlyEarned,
      'lastResetDaily': Timestamp.fromDate(lastResetDaily),
      'lastResetWeekly': Timestamp.fromDate(lastResetWeekly),
      'lastResetMonthly': Timestamp.fromDate(lastResetMonthly),
      'earningHistory': earningHistory,
    };
  }

  int get remainingDailyCap => DAILY_CAP - dailyEarned;
  int get remainingWeeklyCap => WEEKLY_CAP - weeklyEarned;
  int get remainingMonthlyCap => MONTHLY_CAP - monthlyEarned;

  bool canEarnMore() {
    return remainingDailyCap > 0 &&
           remainingWeeklyCap > 0 &&
           remainingMonthlyCap > 0;
  }

  int getMaxEarnable() {
    return [
      remainingDailyCap,
      remainingWeeklyCap,
      remainingMonthlyCap
    ].reduce((a, b) => a < b ? a : b);
  }

  VictoryCoinModel copyWith({
    int? balance,
    int? lifetimeEarned,
    int? lifetimeSpent,
    DateTime? lastEarned,
    DateTime? lastSpent,
    int? dailyEarned,
    int? weeklyEarned,
    int? monthlyEarned,
    DateTime? lastResetDaily,
    DateTime? lastResetWeekly,
    DateTime? lastResetMonthly,
    Map<String, dynamic>? earningHistory,
  }) {
    return VictoryCoinModel(
      userId: userId,
      balance: balance ?? this.balance,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      lastEarned: lastEarned ?? this.lastEarned,
      lastSpent: lastSpent ?? this.lastSpent,
      dailyEarned: dailyEarned ?? this.dailyEarned,
      weeklyEarned: weeklyEarned ?? this.weeklyEarned,
      monthlyEarned: monthlyEarned ?? this.monthlyEarned,
      lastResetDaily: lastResetDaily ?? this.lastResetDaily,
      lastResetWeekly: lastResetWeekly ?? this.lastResetWeekly,
      lastResetMonthly: lastResetMonthly ?? this.lastResetMonthly,
      earningHistory: earningHistory ?? this.earningHistory,
    );
  }
}

class VCTransaction {
  final String id;
  final String userId;
  final String type; // 'earned', 'spent', 'bonus'
  final int amount;
  final String source; // 'bet_win', 'tournament_entry', 'tournament_prize'
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  VCTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.source,
    required this.metadata,
    required this.timestamp,
  });

  factory VCTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VCTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      amount: data['amount'] ?? 0,
      source: data['source'] ?? '',
      metadata: data['metadata'] ?? {},
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'source': source,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}