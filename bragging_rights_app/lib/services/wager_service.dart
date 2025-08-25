import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wallet_service.dart';
import '../models/betting_models.dart';

/// Complete wagering engine that handles bet placement, pool management, and validation
class WagerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WalletService _walletService = WalletService();

  String? get _userId => _auth.currentUser?.uid;

  /// Place a wager in a specific pool
  Future<WagerResult> placeWager({
    required String poolId,
    required String gameId,
    required String gameTitle,
    required String sport,
    required List<WagerSelection> selections,
    required int wagerAmount,
    String? poolName,
  }) async {
    if (_userId == null) {
      return WagerResult(
        success: false,
        error: 'User not logged in',
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        // 1. Validate pool and user eligibility
        final poolDoc = await transaction.get(
          _firestore.collection('pools').doc(poolId),
        );

        if (!poolDoc.exists) {
          throw WagerException('Pool not found');
        }

        final poolData = poolDoc.data()!;
        
        // Check if user is in the pool
        final playerIds = List<String>.from(poolData['playerIds'] ?? []);
        if (!playerIds.contains(_userId)) {
          throw WagerException('You must join the pool first');
        }

        // Check if pool is still open for betting
        if (poolData['status'] != 'open') {
          throw WagerException('Pool is no longer accepting bets');
        }

        // Check cutoff time
        final closeTime = (poolData['closeTime'] as Timestamp).toDate();
        if (DateTime.now().isAfter(closeTime)) {
          throw WagerException('Betting window has closed');
        }

        // 2. Check if user already has a wager in this pool
        final existingWagerQuery = await _firestore
            .collection('wagers')
            .where('userId', isEqualTo: _userId)
            .where('poolId', isEqualTo: poolId)
            .where('gameId', isEqualTo: gameId)
            .get();

        if (existingWagerQuery.docs.isNotEmpty) {
          throw WagerException('You already have a wager in this pool');
        }

        // 3. Validate wager amount against pool rules
        final minWager = poolData['minWager'] ?? 10;
        final maxWager = poolData['maxWager'] ?? 1000;
        
        if (wagerAmount < minWager) {
          throw WagerException('Wager must be at least $minWager BR');
        }
        
        if (wagerAmount > maxWager) {
          throw WagerException('Wager cannot exceed $maxWager BR');
        }

        // 4. Check user's balance
        final balance = await _walletService.getBalance(_userId!);
        if (balance < wagerAmount) {
          throw WagerException('Insufficient BR balance');
        }

        // 5. Calculate odds and potential payout
        final oddsCalculation = _calculateOdds(selections);
        final potentialPayout = (wagerAmount * oddsCalculation.multiplier).round();

        // 6. Create wager document
        final wagerId = _firestore.collection('wagers').doc().id;
        final wagerData = {
          'id': wagerId,
          'userId': _userId,
          'poolId': poolId,
          'gameId': gameId,
          'gameTitle': gameTitle,
          'sport': sport,
          'selections': selections.map((s) => s.toMap()).toList(),
          'wagerAmount': wagerAmount,
          'odds': oddsCalculation.toMap(),
          'potentialPayout': potentialPayout,
          'status': 'pending', // pending, won, lost, push, cancelled
          'placedAt': FieldValue.serverTimestamp(),
          'poolName': poolName ?? poolData['name'],
          'isParlay': selections.length > 1,
        };

        // 7. Deduct from wallet (within transaction)
        final walletDoc = await transaction.get(
          _firestore.collection('wallets').doc(_userId),
        );

        if (!walletDoc.exists) {
          throw WagerException('Wallet not found');
        }

        final currentBalance = walletDoc.data()!['balance'] ?? 0;
        if (currentBalance < wagerAmount) {
          throw WagerException('Insufficient balance during transaction');
        }

        // Update wallet balance
        transaction.update(walletDoc.reference, {
          'balance': FieldValue.increment(-wagerAmount),
        });

        // Create transaction record
        final transactionId = _firestore.collection('transactions').doc().id;
        transaction.set(
          _firestore.collection('transactions').doc(transactionId),
          {
            'id': transactionId,
            'userId': _userId,
            'type': 'wager',
            'amount': -wagerAmount,
            'description': 'Wager placed: $gameTitle',
            'balanceBefore': currentBalance,
            'balanceAfter': currentBalance - wagerAmount,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'wagerId': wagerId,
              'poolId': poolId,
              'gameId': gameId,
            },
          },
        );

        // 8. Create the wager
        transaction.set(
          _firestore.collection('wagers').doc(wagerId),
          wagerData,
        );

        // 9. Update pool statistics
        transaction.update(poolDoc.reference, {
          'totalWagers': FieldValue.increment(1),
          'totalWagered': FieldValue.increment(wagerAmount),
        });

        // 10. Create user wager reference
        transaction.set(
          _firestore
              .collection('users')
              .doc(_userId)
              .collection('wagers')
              .doc(wagerId),
          {
            'wagerId': wagerId,
            'poolId': poolId,
            'gameId': gameId,
            'placedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          },
        );

        return WagerResult(
          success: true,
          wagerId: wagerId,
          potentialPayout: potentialPayout,
          odds: oddsCalculation.displayOdds,
        );
      });
    } on WagerException catch (e) {
      return WagerResult(
        success: false,
        error: e.message,
      );
    } catch (e) {
      return WagerResult(
        success: false,
        error: 'Failed to place wager: ${e.toString()}',
      );
    }
  }

  /// Get user's wagers for a specific pool
  Stream<List<Wager>> getPoolWagers(String poolId) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('wagers')
        .where('userId', isEqualTo: _userId)
        .where('poolId', isEqualTo: poolId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Wager.fromFirestore(doc))
            .toList());
  }

  /// Get all user's active wagers
  Stream<List<Wager>> getActiveWagers() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('wagers')
        .where('userId', isEqualTo: _userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Wager.fromFirestore(doc))
            .toList());
  }

  /// Get wager history
  Future<List<Wager>> getWagerHistory({
    int limit = 50,
    String? status,
  }) async {
    if (_userId == null) return [];

    Query query = _firestore
        .collection('wagers')
        .where('userId', isEqualTo: _userId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query
        .orderBy('placedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Wager.fromFirestore(doc)).toList();
  }

  /// Cancel a pending wager (if allowed by pool rules)
  Future<bool> cancelWager(String wagerId) async {
    if (_userId == null) return false;

    try {
      return await _firestore.runTransaction((transaction) async {
        // Get wager document
        final wagerDoc = await transaction.get(
          _firestore.collection('wagers').doc(wagerId),
        );

        if (!wagerDoc.exists) {
          throw WagerException('Wager not found');
        }

        final wagerData = wagerDoc.data()!;
        
        // Verify ownership
        if (wagerData['userId'] != _userId) {
          throw WagerException('Unauthorized to cancel this wager');
        }

        // Check status
        if (wagerData['status'] != 'pending') {
          throw WagerException('Can only cancel pending wagers');
        }

        // Check pool cancellation rules
        final poolDoc = await transaction.get(
          _firestore.collection('pools').doc(wagerData['poolId']),
        );

        if (poolDoc.exists) {
          final poolData = poolDoc.data()!;
          final allowCancellation = poolData['allowCancellation'] ?? false;
          
          if (!allowCancellation) {
            throw WagerException('This pool does not allow wager cancellation');
          }

          // Check cancellation deadline
          final closeTime = (poolData['closeTime'] as Timestamp).toDate();
          final cancellationDeadline = closeTime.subtract(const Duration(minutes: 5));
          
          if (DateTime.now().isAfter(cancellationDeadline)) {
            throw WagerException('Cancellation deadline has passed');
          }
        }

        // Refund the wager amount
        final walletDoc = await transaction.get(
          _firestore.collection('wallets').doc(_userId),
        );

        final currentBalance = walletDoc.data()!['balance'] ?? 0;
        final wagerAmount = wagerData['wagerAmount'];

        // Update wallet
        transaction.update(walletDoc.reference, {
          'balance': FieldValue.increment(wagerAmount),
        });

        // Create refund transaction
        final transactionId = _firestore.collection('transactions').doc().id;
        transaction.set(
          _firestore.collection('transactions').doc(transactionId),
          {
            'id': transactionId,
            'userId': _userId,
            'type': 'refund',
            'amount': wagerAmount,
            'description': 'Wager cancelled: ${wagerData['gameTitle']}',
            'balanceBefore': currentBalance,
            'balanceAfter': currentBalance + wagerAmount,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'wagerId': wagerId,
              'poolId': wagerData['poolId'],
              'gameId': wagerData['gameId'],
            },
          },
        );

        // Update wager status
        transaction.update(wagerDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // Update pool statistics
        if (poolDoc.exists) {
          transaction.update(poolDoc.reference, {
            'totalWagers': FieldValue.increment(-1),
            'totalWagered': FieldValue.increment(-wagerAmount),
          });
        }

        return true;
      });
    } catch (e) {
      print('Error cancelling wager: $e');
      return false;
    }
  }

  /// Calculate combined odds for selections
  OddsCalculation _calculateOdds(List<WagerSelection> selections) {
    if (selections.isEmpty) {
      return OddsCalculation(
        multiplier: 0,
        displayOdds: '+0',
        impliedProbability: 0,
      );
    }

    double combinedMultiplier = 1.0;
    double combinedProbability = 1.0;

    for (final selection in selections) {
      final odds = selection.odds;
      double multiplier;
      double probability;

      if (odds > 0) {
        multiplier = (odds / 100) + 1;
        probability = 100 / (odds + 100);
      } else {
        multiplier = (100 / -odds) + 1;
        probability = -odds / (-odds + 100);
      }

      combinedMultiplier *= multiplier;
      combinedProbability *= probability;
    }

    // Convert back to American odds format
    int displayOdds;
    if (combinedMultiplier >= 2) {
      displayOdds = ((combinedMultiplier - 1) * 100).round();
    } else {
      displayOdds = (-100 / (combinedMultiplier - 1)).round();
    }

    return OddsCalculation(
      multiplier: combinedMultiplier,
      displayOdds: displayOdds > 0 ? '+$displayOdds' : '$displayOdds',
      impliedProbability: combinedProbability * 100,
    );
  }

  /// Get wager statistics for user
  Future<WagerStats> getWagerStats() async {
    if (_userId == null) {
      return WagerStats.empty();
    }

    final wagers = await _firestore
        .collection('wagers')
        .where('userId', isEqualTo: _userId)
        .get();

    int totalWagers = wagers.docs.length;
    int wins = 0;
    int losses = 0;
    int pending = 0;
    int totalWagered = 0;
    int totalWon = 0;

    for (final doc in wagers.docs) {
      final data = doc.data();
      final status = data['status'];
      final amount = data['wagerAmount'] ?? 0;

      totalWagered += amount;

      switch (status) {
        case 'won':
          wins++;
          totalWon += (data['potentialPayout'] ?? 0) as int;
          break;
        case 'lost':
          losses++;
          break;
        case 'pending':
          pending++;
          break;
      }
    }

    return WagerStats(
      totalWagers: totalWagers,
      wins: wins,
      losses: losses,
      pending: pending,
      totalWagered: totalWagered,
      totalWon: totalWon,
      winRate: totalWagers > 0 ? (wins / (wins + losses)) * 100 : 0,
      roi: totalWagered > 0 ? ((totalWon - totalWagered) / totalWagered) * 100 : 0,
    );
  }
}

/// Wager selection model
class WagerSelection {
  final String type; // winner, spread, total, prop
  final String selection; // team name, over/under, player name
  final int odds; // American odds format
  final String? line; // For spread/totals
  final String description;

  WagerSelection({
    required this.type,
    required this.selection,
    required this.odds,
    this.line,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'selection': selection,
      'odds': odds,
      'line': line,
      'description': description,
    };
  }

  factory WagerSelection.fromMap(Map<String, dynamic> map) {
    return WagerSelection(
      type: map['type'],
      selection: map['selection'],
      odds: map['odds'],
      line: map['line'],
      description: map['description'],
    );
  }
}

/// Wager model
class Wager {
  final String id;
  final String userId;
  final String poolId;
  final String gameId;
  final String gameTitle;
  final String sport;
  final List<WagerSelection> selections;
  final int wagerAmount;
  final int potentialPayout;
  final String status;
  final DateTime placedAt;
  final String poolName;
  final bool isParlay;

  Wager({
    required this.id,
    required this.userId,
    required this.poolId,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.selections,
    required this.wagerAmount,
    required this.potentialPayout,
    required this.status,
    required this.placedAt,
    required this.poolName,
    required this.isParlay,
  });

  factory Wager.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Wager(
      id: doc.id,
      userId: data['userId'],
      poolId: data['poolId'],
      gameId: data['gameId'],
      gameTitle: data['gameTitle'],
      sport: data['sport'],
      selections: (data['selections'] as List)
          .map((s) => WagerSelection.fromMap(s))
          .toList(),
      wagerAmount: data['wagerAmount'],
      potentialPayout: data['potentialPayout'],
      status: data['status'],
      placedAt: (data['placedAt'] as Timestamp).toDate(),
      poolName: data['poolName'],
      isParlay: data['isParlay'] ?? false,
    );
  }
}

/// Wager result
class WagerResult {
  final bool success;
  final String? wagerId;
  final String? error;
  final int? potentialPayout;
  final String? odds;

  WagerResult({
    required this.success,
    this.wagerId,
    this.error,
    this.potentialPayout,
    this.odds,
  });
}

/// Odds calculation
class OddsCalculation {
  final double multiplier;
  final String displayOdds;
  final double impliedProbability;

  OddsCalculation({
    required this.multiplier,
    required this.displayOdds,
    required this.impliedProbability,
  });

  Map<String, dynamic> toMap() {
    return {
      'multiplier': multiplier,
      'displayOdds': displayOdds,
      'impliedProbability': impliedProbability,
    };
  }
}

/// Wager statistics
class WagerStats {
  final int totalWagers;
  final int wins;
  final int losses;
  final int pending;
  final int totalWagered;
  final int totalWon;
  final double winRate;
  final double roi;

  WagerStats({
    required this.totalWagers,
    required this.wins,
    required this.losses,
    required this.pending,
    required this.totalWagered,
    required this.totalWon,
    required this.winRate,
    required this.roi,
  });

  factory WagerStats.empty() {
    return WagerStats(
      totalWagers: 0,
      wins: 0,
      losses: 0,
      pending: 0,
      totalWagered: 0,
      totalWon: 0,
      winRate: 0,
      roi: 0,
    );
  }
}

/// Custom exception for wager errors
class WagerException implements Exception {
  final String message;
  WagerException(this.message);
}