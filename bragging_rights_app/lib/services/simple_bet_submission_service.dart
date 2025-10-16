import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/simple_bet.dart';
import 'wallet_service.dart';

/// Service for submitting simple betting bet slips to Firestore
/// Handles validation, wallet integration, and duplicate prevention
class SimpleBetSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();

  // Singleton pattern
  static final SimpleBetSubmissionService _instance = SimpleBetSubmissionService._internal();
  factory SimpleBetSubmissionService() => _instance;
  SimpleBetSubmissionService._internal();

  /// Submit a simple bet slip to Firestore
  ///
  /// Returns bet slip ID on success, null on failure
  ///
  /// Process:
  /// 1. Validates inputs (winner bet present, wager > 0)
  /// 2. Checks user has sufficient balance
  /// 3. Checks for duplicate pending bets on this game
  /// 4. Generates unique bet slip ID
  /// 5. Calculates total potential points
  /// 6. Saves bet slip to Firestore
  /// 7. Deducts wager from user's wallet
  /// 8. Logs transaction
  ///
  /// Rollback: If wallet deduction fails, deletes bet slip from Firestore
  Future<String?> submitBetSlip({
    required String userId,
    required String gameId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime gameTime,
    required SimpleBet winnerBet,
    required List<SimpleBet> optionalBets,
    required int wagerAmount,
  }) async {
    try {
      debugPrint('\n╔════════════════════════════════════════════════════════════╗');
      debugPrint('║     💰 BET SUBMISSION SERVICE                             ║');
      debugPrint('╚════════════════════════════════════════════════════════════╝');
      debugPrint('📍 User ID: $userId');
      debugPrint('📍 Game ID: $gameId');
      debugPrint('📍 Sport: $sport');
      debugPrint('📍 Matchup: $awayTeam @ $homeTeam');
      debugPrint('📍 Wager: $wagerAmount BR');

      // 1. Validate inputs
      if (!_validateBetSlip(winnerBet: winnerBet, wagerAmount: wagerAmount)) {
        debugPrint('❌ [BetSubmission] Validation failed');
        return null;
      }

      debugPrint('✅ Validation passed');

      // 2. Get current balance
      final balance = await _walletService.getUserBalance(userId);
      debugPrint('💵 Current balance: $balance BR');

      if (balance < wagerAmount) {
        debugPrint('❌ [BetSubmission] Insufficient balance: $balance < $wagerAmount');
        return null;
      }

      debugPrint('✅ Sufficient balance');

      // 3. Check for duplicate bet slips
      final existingBets = await _firestore
          .collection('simple_bet_slips')
          .where('userId', isEqualTo: userId)
          .where('gameId', isEqualTo: gameId)
          .where('settled', isEqualTo: false)
          .get();

      if (existingBets.docs.isNotEmpty) {
        debugPrint('⚠️ [BetSubmission] User already has a pending bet for this game');
        return null;
      }

      debugPrint('✅ No duplicate bets found');

      // 4. Generate unique bet slip ID
      final betSlipId = _firestore.collection('simple_bet_slips').doc().id;
      debugPrint('🎫 Generated bet slip ID: $betSlipId');

      // 5. Calculate total potential points
      double totalPotentialPoints = winnerBet.basePoints * winnerBet.multiplier;
      for (var bet in optionalBets) {
        totalPotentialPoints += bet.basePoints * bet.multiplier;
      }

      debugPrint('📊 Total potential points: ${totalPotentialPoints.toStringAsFixed(1)}');
      debugPrint('   - Winner bet: ${winnerBet.description} (${winnerBet.basePoints} × ${winnerBet.multiplier}x = ${(winnerBet.basePoints * winnerBet.multiplier).toStringAsFixed(1)} pts)');
      for (var bet in optionalBets) {
        debugPrint('   - ${bet.description} (${bet.basePoints} × ${bet.multiplier}x = ${(bet.basePoints * bet.multiplier).toStringAsFixed(1)} pts)');
      }

      // 6. Create bet slip data
      final betSlipData = {
        'id': betSlipId,
        'gameId': gameId,
        'userId': userId,
        'sport': sport,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'gameTime': Timestamp.fromDate(gameTime),
        'winnerBet': winnerBet.toMap(),
        'optionalBets': optionalBets.map((b) => b.toMap()).toList(),
        'wagerAmount': wagerAmount,
        'totalPotentialPoints': totalPotentialPoints,
        'totalEarnedPoints': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'settled': false,
        'settledAt': null,
        'status': 'pending',
      };

      debugPrint('💾 Saving bet slip to Firestore...');

      // 7. Save to Firestore first
      await _firestore.collection('simple_bet_slips').doc(betSlipId).set(betSlipData);

      debugPrint('✅ Bet slip saved to Firestore');
      debugPrint('💰 Deducting $wagerAmount BR from wallet...');

      // 8. Deduct wager from wallet
      final success = await _walletService.deductBalance(
        userId,
        wagerAmount,
        'Bet on $sport: $awayTeam @ $homeTeam',
      );

      if (!success) {
        // Rollback: delete bet slip
        debugPrint('❌ [BetSubmission] Failed to deduct balance, rolling back...');
        await _firestore.collection('simple_bet_slips').doc(betSlipId).delete();
        debugPrint('🔄 Bet slip rolled back');
        return null;
      }

      debugPrint('✅ Wallet deduction successful');
      debugPrint('📝 Logging transaction...');

      // 9. Log transaction
      await _walletService.addTransaction(
        userId,
        -wagerAmount,
        'bet_placed',
        'Bet #$betSlipId: $awayTeam @ $homeTeam',
      );

      debugPrint('✅ Transaction logged');
      debugPrint('\n╔════════════════════════════════════════════════════════════╗');
      debugPrint('║     ✅ BET SUBMISSION SUCCESSFUL                          ║');
      debugPrint('╚════════════════════════════════════════════════════════════╝');
      debugPrint('🎫 Bet Slip ID: $betSlipId');
      debugPrint('💰 Wager: $wagerAmount BR');
      debugPrint('📊 Potential Points: ${totalPotentialPoints.toStringAsFixed(1)}');
      debugPrint('═══════════════════════════════════════════════════════════\n');

      return betSlipId;

    } catch (e, stackTrace) {
      debugPrint('❌ [BetSubmission] Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Validates bet slip inputs
  ///
  /// Checks:
  /// - Winner bet is required
  /// - Wager amount is positive
  bool _validateBetSlip({
    required SimpleBet winnerBet,
    required int wagerAmount,
  }) {
    if (!winnerBet.isRequired) {
      debugPrint('❌ [Validation] Winner bet is not marked as required');
      return false;
    }

    if (wagerAmount <= 0) {
      debugPrint('❌ [Validation] Invalid wager amount: $wagerAmount');
      return false;
    }

    return true;
  }
}
