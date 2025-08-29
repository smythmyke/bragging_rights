import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wallet_service.dart';
import 'wager_service.dart';

/// Automated settlement system for processing game results and distributing winnings
class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();

  /// Process game settlement for all pools and wagers
  Future<SettlementResult> settleGame({
    required String gameId,
    required GameResult gameResult,
  }) async {
    try {
      // Use batch writes for atomic operations
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();
      
      int totalPoolsSettled = 0;
      int totalWagersSettled = 0;
      int totalPayouts = 0;

      // 1. Get all pools for this game
      final poolsSnapshot = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'open')
          .get();

      for (final poolDoc in poolsSnapshot.docs) {
        final poolData = poolDoc.data();
        final poolId = poolDoc.id;

        // 2. Get all wagers in this pool
        final wagersSnapshot = await _firestore
            .collection('wagers')
            .where('poolId', isEqualTo: poolId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (wagersSnapshot.docs.isEmpty) {
          // No wagers in pool, just close it
          batch.update(poolDoc.reference, {
            'status': 'completed',
            'completedAt': timestamp,
            'settlementData': {
              'noWagers': true,
              'refunded': true,
            },
          });
          totalPoolsSettled++;
          continue;
        }

        // 3. Evaluate each wager
        List<WagerEvaluation> evaluations = [];
        for (final wagerDoc in wagersSnapshot.docs) {
          final evaluation = _evaluateWager(
            wagerDoc.data(),
            gameResult,
          );
          evaluations.add(evaluation);
        }

        // 4. Calculate pool distribution
        final poolDistribution = _calculatePoolDistribution(
          poolData: poolData,
          evaluations: evaluations,
        );

        // 5. Process payouts
        for (final evaluation in evaluations) {
          final wagerId = evaluation.wagerId;
          final userId = evaluation.userId;
          
          // Update wager status
          batch.update(
            _firestore.collection('wagers').doc(wagerId),
            {
              'status': evaluation.status,
              'settledAt': timestamp,
              'actualPayout': evaluation.payout,
              'settlementData': evaluation.toMap(),
            },
          );

          // Process payout if won
          if (evaluation.status == 'won' && evaluation.payout > 0) {
            // Add winnings to wallet
            final transactionId = _firestore.collection('transactions').doc().id;
            batch.set(
              _firestore.collection('transactions').doc(transactionId),
              {
                'id': transactionId,
                'userId': userId,
                'type': 'winnings',
                'amount': evaluation.payout,
                'description': 'Winnings from ${poolData['name']}',
                'timestamp': timestamp,
                'metadata': {
                  'wagerId': wagerId,
                  'poolId': poolId,
                  'gameId': gameId,
                  'poolName': poolData['name'],
                },
              },
            );

            // Update wallet balance
            batch.update(
              _firestore.collection('wallets').doc(userId),
              {
                'balance': FieldValue.increment(evaluation.payout),
                'totalWinnings': FieldValue.increment(evaluation.payout),
              },
            );

            totalPayouts += evaluation.payout;
          }

          totalWagersSettled++;
        }

        // 6. Update pool status
        batch.update(poolDoc.reference, {
          'status': 'completed',
          'completedAt': timestamp,
          'settlementData': {
            'winners': poolDistribution.winners,
            'totalPayout': poolDistribution.totalPayout,
            'wagersSettled': evaluations.length,
            'gameResult': gameResult.toMap(),
          },
        });

        totalPoolsSettled++;
      }

      // 7. Update game status
      batch.set(
        _firestore.collection('settlements').doc(gameId),
        {
          'gameId': gameId,
          'settledAt': timestamp,
          'gameResult': gameResult.toMap(),
          'poolsSettled': totalPoolsSettled,
          'wagersSettled': totalWagersSettled,
          'totalPayouts': totalPayouts,
        },
      );

      // Commit all changes
      await batch.commit();

      // 8. Send notifications (would be implemented as Cloud Function)
      await _sendSettlementNotifications(gameId);

      return SettlementResult(
        success: true,
        poolsSettled: totalPoolsSettled,
        wagersSettled: totalWagersSettled,
        totalPayouts: totalPayouts,
      );
    } catch (e) {
      print('Settlement error: $e');
      return SettlementResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Evaluate a wager against game results
  WagerEvaluation _evaluateWager(
    Map<String, dynamic> wagerData,
    GameResult gameResult,
  ) {
    final wagerId = wagerData['id'];
    final userId = wagerData['userId'];
    final selections = (wagerData['selections'] as List)
        .map((s) => WagerSelection.fromMap(s))
        .toList();
    final wagerAmount = wagerData['wagerAmount'];
    final potentialPayout = wagerData['potentialPayout'];

    bool allCorrect = true;
    List<SelectionResult> selectionResults = [];

    for (final selection in selections) {
      bool isCorrect = false;
      
      switch (selection.type) {
        case 'winner':
          isCorrect = selection.selection == gameResult.winner;
          break;
        
        case 'spread':
          final spread = double.parse(selection.line ?? '0');
          if (selection.selection == gameResult.homeTeam) {
            isCorrect = (gameResult.homeScore - gameResult.awayScore) > spread;
          } else {
            isCorrect = (gameResult.awayScore - gameResult.homeScore) > -spread;
          }
          break;
        
        case 'total':
          final totalLine = double.parse(selection.line ?? '0');
          final actualTotal = gameResult.homeScore + gameResult.awayScore;
          if (selection.selection == 'over') {
            isCorrect = actualTotal > totalLine;
          } else {
            isCorrect = actualTotal < totalLine;
          }
          break;
        
        case 'prop':
          // Props would need specific evaluation based on prop type
          // For now, using mock evaluation
          isCorrect = _evaluateProp(selection, gameResult);
          break;
      }

      selectionResults.add(SelectionResult(
        selection: selection,
        isCorrect: isCorrect,
      ));

      if (!isCorrect) {
        allCorrect = false;
      }
    }

    // Determine final status and payout
    String status;
    int payout = 0;

    if (allCorrect) {
      status = 'won';
      payout = potentialPayout;
    } else {
      status = 'lost';
      payout = 0;
    }

    return WagerEvaluation(
      wagerId: wagerId,
      userId: userId,
      status: status,
      payout: payout,
      wagerAmount: wagerAmount,
      selectionResults: selectionResults,
    );
  }

  /// Evaluate prop bets (simplified for now)
  bool _evaluateProp(WagerSelection selection, GameResult gameResult) {
    // This would connect to actual prop bet results
    // For now, using mock logic
    final random = DateTime.now().millisecondsSinceEpoch % 2;
    return random == 0;
  }

  /// Calculate pool prize distribution
  PoolDistribution _calculatePoolDistribution({
    required Map<String, dynamic> poolData,
    required List<WagerEvaluation> evaluations,
  }) {
    final prizeStructure = poolData['prizeStructure'] as Map<String, dynamic>?;
    final prizePool = poolData['prizePool'] ?? 0;
    
    // Find winners
    final winners = evaluations.where((e) => e.status == 'won').toList();
    
    if (winners.isEmpty) {
      // No winners - could refund or carry over
      // For now, pool keeps the money
      return PoolDistribution(
        winners: 0,
        totalPayout: 0,
      );
    }

    // Sort winners by wager amount (tiebreaker)
    winners.sort((a, b) => b.wagerAmount.compareTo(a.wagerAmount));

    int totalPayout = 0;
    
    if (prizeStructure != null) {
      // Structured payout (1st, 2nd, 3rd place)
      for (int i = 0; i < winners.length && i < 3; i++) {
        final position = '${i + 1}';
        final prize = prizeStructure[position] ?? 0;
        winners[i].payout = prize.toInt();
        totalPayout += prize.toInt();
      }
    } else {
      // Equal distribution among winners
      final prizePerWinner = (prizePool / winners.length).round();
      for (final winner in winners) {
        winner.payout = prizePerWinner;
        totalPayout += prizePerWinner;
      }
    }

    return PoolDistribution(
      winners: winners.length,
      totalPayout: totalPayout,
    );
  }

  /// Send settlement notifications
  Future<void> _sendSettlementNotifications(String gameId) async {
    // This would be implemented as a Cloud Function
    // to send push notifications to affected users
    print('Sending settlement notifications for game: $gameId');
  }

  /// Rollback a settlement (admin function)
  Future<bool> rollbackSettlement(String gameId) async {
    try {
      // Get settlement record
      final settlementDoc = await _firestore
          .collection('settlements')
          .doc(gameId)
          .get();

      if (!settlementDoc.exists) {
        throw Exception('Settlement not found');
      }

      final settlementData = settlementDoc.data()!;
      
      // Start transaction for rollback
      return await _firestore.runTransaction((transaction) async {
        // 1. Get all settled wagers for this game
        final wagersSnapshot = await _firestore
            .collection('wagers')
            .where('gameId', isEqualTo: gameId)
            .where('status', whereIn: ['won', 'lost'])
            .get();

        // 2. Reverse each wager
        for (final wagerDoc in wagersSnapshot.docs) {
          final wagerData = wagerDoc.data();
          
          // Reset wager to pending
          transaction.update(wagerDoc.reference, {
            'status': 'pending',
            'settledAt': FieldValue.delete(),
            'actualPayout': FieldValue.delete(),
            'settlementData': FieldValue.delete(),
          });

          // If there was a payout, reverse it
          if (wagerData['status'] == 'won' && wagerData['actualPayout'] != null) {
            final userId = wagerData['userId'];
            final payout = wagerData['actualPayout'];

            // Deduct from wallet
            transaction.update(
              _firestore.collection('wallets').doc(userId),
              {
                'balance': FieldValue.increment(-payout),
                'totalWinnings': FieldValue.increment(-payout),
              },
            );

            // Create reversal transaction
            final transactionId = _firestore.collection('transactions').doc().id;
            transaction.set(
              _firestore.collection('transactions').doc(transactionId),
              {
                'id': transactionId,
                'userId': userId,
                'type': 'rollback',
                'amount': -payout,
                'description': 'Settlement rollback for game $gameId',
                'timestamp': FieldValue.serverTimestamp(),
                'metadata': {
                  'wagerId': wagerDoc.id,
                  'gameId': gameId,
                  'originalPayout': payout,
                },
              },
            );
          }
        }

        // 3. Reset pools
        final poolsSnapshot = await _firestore
            .collection('pools')
            .where('gameId', isEqualTo: gameId)
            .where('status', isEqualTo: 'completed')
            .get();

        for (final poolDoc in poolsSnapshot.docs) {
          transaction.update(poolDoc.reference, {
            'status': 'open',
            'completedAt': FieldValue.delete(),
            'settlementData': FieldValue.delete(),
          });
        }

        // 4. Delete settlement record
        transaction.delete(settlementDoc.reference);

        return true;
      });
    } catch (e) {
      print('Rollback error: $e');
      return false;
    }
  }

  /// Get settlement history
  Stream<List<Settlement>> getSettlementHistory({int limit = 50}) {
    return _firestore
        .collection('settlements')
        .orderBy('settledAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromFirestore(doc))
            .toList());
  }

  /// Verify settlement integrity
  Future<SettlementVerification> verifySettlement(String gameId) async {
    try {
      final settlementDoc = await _firestore
          .collection('settlements')
          .doc(gameId)
          .get();

      if (!settlementDoc.exists) {
        return SettlementVerification(
          isValid: false,
          error: 'Settlement not found',
        );
      }

      final settlementData = settlementDoc.data()!;
      int expectedPayouts = settlementData['totalPayouts'];
      int actualPayouts = 0;

      // Verify all wager payouts
      final wagersSnapshot = await _firestore
          .collection('wagers')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'won')
          .get();

      for (final wagerDoc in wagersSnapshot.docs) {
        final payout = wagerDoc.data()['actualPayout'] ?? 0;
        actualPayouts += payout as int;
      }

      final isValid = expectedPayouts == actualPayouts;

      return SettlementVerification(
        isValid: isValid,
        expectedPayouts: expectedPayouts,
        actualPayouts: actualPayouts,
        error: isValid ? null : 'Payout mismatch',
      );
    } catch (e) {
      return SettlementVerification(
        isValid: false,
        error: e.toString(),
      );
    }
  }
}

/// Game result model
class GameResult {
  final String gameId;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String winner;
  final DateTime completedAt;
  final Map<String, dynamic>? additionalData;

  GameResult({
    required this.gameId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.winner,
    required this.completedAt,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'winner': winner,
      'completedAt': completedAt.toIso8601String(),
      'additionalData': additionalData,
    };
  }
}

/// Wager evaluation result
class WagerEvaluation {
  final String wagerId;
  final String userId;
  String status;
  int payout;
  final int wagerAmount;
  final List<SelectionResult> selectionResults;

  WagerEvaluation({
    required this.wagerId,
    required this.userId,
    required this.status,
    required this.payout,
    required this.wagerAmount,
    required this.selectionResults,
  });

  Map<String, dynamic> toMap() {
    return {
      'wagerId': wagerId,
      'userId': userId,
      'status': status,
      'payout': payout,
      'wagerAmount': wagerAmount,
      'selectionResults': selectionResults.map((s) => s.toMap()).toList(),
    };
  }
}

/// Selection result
class SelectionResult {
  final WagerSelection selection;
  final bool isCorrect;

  SelectionResult({
    required this.selection,
    required this.isCorrect,
  });

  Map<String, dynamic> toMap() {
    return {
      'selection': selection.toMap(),
      'isCorrect': isCorrect,
    };
  }
}

/// Pool distribution
class PoolDistribution {
  final int winners;
  final int totalPayout;

  PoolDistribution({
    required this.winners,
    required this.totalPayout,
  });
}

/// Settlement result
class SettlementResult {
  final bool success;
  final int? poolsSettled;
  final int? wagersSettled;
  final int? totalPayouts;
  final String? error;

  SettlementResult({
    required this.success,
    this.poolsSettled,
    this.wagersSettled,
    this.totalPayouts,
    this.error,
  });
}

/// Settlement model
class Settlement {
  final String gameId;
  final DateTime settledAt;
  final GameResult gameResult;
  final int poolsSettled;
  final int wagersSettled;
  final int totalPayouts;

  Settlement({
    required this.gameId,
    required this.settledAt,
    required this.gameResult,
    required this.poolsSettled,
    required this.wagersSettled,
    required this.totalPayouts,
  });

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Settlement(
      gameId: doc.id,
      settledAt: (data['settledAt'] as Timestamp).toDate(),
      gameResult: GameResult(
        gameId: data['gameResult']['gameId'],
        homeTeam: data['gameResult']['homeTeam'],
        awayTeam: data['gameResult']['awayTeam'],
        homeScore: data['gameResult']['homeScore'],
        awayScore: data['gameResult']['awayScore'],
        winner: data['gameResult']['winner'],
        completedAt: DateTime.parse(data['gameResult']['completedAt']),
      ),
      poolsSettled: data['poolsSettled'],
      wagersSettled: data['wagersSettled'],
      totalPayouts: data['totalPayouts'],
    );
  }
}

/// Settlement verification
class SettlementVerification {
  final bool isValid;
  final int? expectedPayouts;
  final int? actualPayouts;
  final String? error;

  SettlementVerification({
    required this.isValid,
    this.expectedPayouts,
    this.actualPayouts,
    this.error,
  });
}