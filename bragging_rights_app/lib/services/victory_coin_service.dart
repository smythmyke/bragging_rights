import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/victory_coin_model.dart';
import 'dart:math' as math;

class VictoryCoinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, double> VC_CONVERSION_RATES = {
    'favorite_win': 0.15,      // 15% of BR wagered
    'even_odds_win': 0.25,     // 25% of BR wagered
    'underdog_win': 0.40,      // 40% of BR wagered
    'parlay_2_team': 0.35,     // 35% of BR wagered
    'parlay_3_team': 0.60,     // 60% of BR wagered
    'parlay_4_team': 1.00,     // 100% of BR wagered
    'parlay_5_plus': 1.50,     // 150% of BR wagered
    'mma_perfect_card': 1.50,  // 150% for perfect MMA picks
    'mma_high_accuracy': 0.80, // 80% for 80%+ correct
    'mma_good_accuracy': 0.40, // 40% for 60-79% correct
    'mma_fair_accuracy': 0.20, // 20% for 40-59% correct
  };

  Future<VictoryCoinModel?> getUserVC(String userId) async {
    try {
      final doc = await _firestore
          .collection('victory_coins')
          .doc(userId)
          .get();

      if (!doc.exists) {
        await _initializeUserVC(userId);
        return getUserVC(userId);
      }

      return VictoryCoinModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting user VC: $e');
      return null;
    }
  }

  Future<void> _initializeUserVC(String userId) async {
    final now = DateTime.now();
    final initialVC = VictoryCoinModel(
      userId: userId,
      balance: 0,
      lifetimeEarned: 0,
      lifetimeSpent: 0,
      lastEarned: now,
      dailyEarned: 0,
      weeklyEarned: 0,
      monthlyEarned: 0,
      lastResetDaily: now,
      lastResetWeekly: now,
      lastResetMonthly: now,
      earningHistory: {},
    );

    await _firestore
        .collection('victory_coins')
        .doc(userId)
        .set(initialVC.toFirestore());
  }

  Future<int> calculateVCForBet({
    required int brWagered,
    required double odds,
    required bool won,
    required String betType,
  }) async {
    if (!won) return 0;

    double conversionRate;

    if (betType == 'parlay') {
      return 0; // Handle separately with calculateVCForParlay
    }

    // Determine conversion rate based on odds
    if (odds < -200) {
      conversionRate = VC_CONVERSION_RATES['favorite_win']!;
    } else if (odds >= -110 && odds <= 110) {
      conversionRate = VC_CONVERSION_RATES['even_odds_win']!;
    } else {
      conversionRate = VC_CONVERSION_RATES['underdog_win']!;
    }

    return (brWagered * conversionRate).floor();
  }

  Future<int> calculateVCForParlay({
    required int brWagered,
    required int numTeams,
    required bool won,
  }) async {
    if (!won) return 0;

    double conversionRate;

    switch (numTeams) {
      case 2:
        conversionRate = VC_CONVERSION_RATES['parlay_2_team']!;
        break;
      case 3:
        conversionRate = VC_CONVERSION_RATES['parlay_3_team']!;
        break;
      case 4:
        conversionRate = VC_CONVERSION_RATES['parlay_4_team']!;
        break;
      default:
        conversionRate = VC_CONVERSION_RATES['parlay_5_plus']!;
    }

    return (brWagered * conversionRate).floor();
  }

  Future<int> calculateVCForMMACard({
    required int brWagered,
    required int correctPicks,
    required int totalFights,
  }) async {
    final accuracy = correctPicks / totalFights;
    double conversionRate;

    if (accuracy == 1.0) {
      conversionRate = VC_CONVERSION_RATES['mma_perfect_card']!;
    } else if (accuracy >= 0.8) {
      conversionRate = VC_CONVERSION_RATES['mma_high_accuracy']!;
    } else if (accuracy >= 0.6) {
      conversionRate = VC_CONVERSION_RATES['mma_good_accuracy']!;
    } else if (accuracy >= 0.4) {
      conversionRate = VC_CONVERSION_RATES['mma_fair_accuracy']!;
    } else {
      return 0; // Less than 40% correct gets no VC
    }

    return (brWagered * conversionRate).floor();
  }

  Future<bool> awardVC({
    required String userId,
    required int amount,
    required String source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get current VC balance and check caps
      final userVC = await getUserVC(userId);
      if (userVC == null) return false;

      // Check and reset caps if needed
      final updatedVC = await _checkAndResetCaps(userVC);

      // Calculate actual amount considering caps
      final actualAmount = math.min(amount, updatedVC.getMaxEarnable());

      if (actualAmount <= 0) {
        print('User has reached VC earning caps');
        return false;
      }

      // Update VC balance
      await _firestore.collection('victory_coins').doc(userId).update({
        'balance': FieldValue.increment(actualAmount),
        'lifetimeEarned': FieldValue.increment(actualAmount),
        'dailyEarned': FieldValue.increment(actualAmount),
        'weeklyEarned': FieldValue.increment(actualAmount),
        'monthlyEarned': FieldValue.increment(actualAmount),
        'lastEarned': FieldValue.serverTimestamp(),
        'earningHistory.$source': FieldValue.increment(actualAmount),
      });

      // Log transaction
      await _logVCTransaction(
        userId: userId,
        type: 'earned',
        amount: actualAmount,
        source: source,
        metadata: metadata ?? {},
      );

      return true;
    } catch (e) {
      print('Error awarding VC: $e');
      return false;
    }
  }

  Future<bool> spendVC({
    required String userId,
    required int amount,
    required String purpose,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userVC = await getUserVC(userId);
      if (userVC == null || userVC.balance < amount) {
        return false; // Insufficient balance
      }

      await _firestore.collection('victory_coins').doc(userId).update({
        'balance': FieldValue.increment(-amount),
        'lifetimeSpent': FieldValue.increment(amount),
        'lastSpent': FieldValue.serverTimestamp(),
      });

      await _logVCTransaction(
        userId: userId,
        type: 'spent',
        amount: amount,
        source: purpose,
        metadata: metadata ?? {},
      );

      return true;
    } catch (e) {
      print('Error spending VC: $e');
      return false;
    }
  }

  Future<VictoryCoinModel> _checkAndResetCaps(VictoryCoinModel vc) async {
    final now = DateTime.now();
    bool needsUpdate = false;
    var updated = vc;

    // Check daily reset (midnight)
    if (!_isSameDay(now, vc.lastResetDaily)) {
      updated = updated.copyWith(
        dailyEarned: 0,
        lastResetDaily: now,
      );
      needsUpdate = true;
    }

    // Check weekly reset (Monday)
    if (!_isSameWeek(now, vc.lastResetWeekly)) {
      updated = updated.copyWith(
        weeklyEarned: 0,
        lastResetWeekly: now,
      );
      needsUpdate = true;
    }

    // Check monthly reset (1st of month)
    if (!_isSameMonth(now, vc.lastResetMonthly)) {
      updated = updated.copyWith(
        monthlyEarned: 0,
        lastResetMonthly: now,
      );
      needsUpdate = true;
    }

    if (needsUpdate) {
      await _firestore
          .collection('victory_coins')
          .doc(vc.userId)
          .update(updated.toFirestore());
    }

    return updated;
  }

  Future<void> _logVCTransaction({
    required String userId,
    required String type,
    required int amount,
    required String source,
    required Map<String, dynamic> metadata,
  }) async {
    final transaction = VCTransaction(
      id: '',
      userId: userId,
      type: type,
      amount: amount,
      source: source,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('vc_transactions')
        .add(transaction.toFirestore());
  }

  Stream<VictoryCoinModel?> streamUserVC(String userId) {
    return _firestore
        .collection('victory_coins')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return VictoryCoinModel.fromFirestore(doc);
    });
  }

  Future<List<VCTransaction>> getUserTransactions(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final query = await _firestore
          .collection('vc_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => VCTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting VC transactions: $e');
      return [];
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isSameWeek(DateTime date1, DateTime date2) {
    final week1 = _weekNumber(date1);
    final week2 = _weekNumber(date2);
    return date1.year == date2.year && week1 == week2;
  }

  bool _isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }
}