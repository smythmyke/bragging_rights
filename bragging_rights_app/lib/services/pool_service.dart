import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pool_model.dart';
import 'wallet_service.dart';
import 'location_service.dart' as location;
import 'pool_cleanup_service.dart';

class PoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WalletService _walletService = WalletService();
  final location.LocationService _locationService = location.LocationService();
  
  // 75% minimum player rule
  static const double MINIMUM_PLAYER_PERCENTAGE = 0.75;

  // Get pools for a specific game
  Stream<List<Pool>> getPoolsForGame(String gameId) {
    return _firestore
        .collection('pools')
        .where('gameId', isEqualTo: gameId)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Pool.fromFirestore(doc)).toList();
    });
  }

  // Get pools by type
  Stream<List<Pool>> getPoolsByType(String gameId, PoolType type) {
    // Simplified query - get all pools for the game and filter in memory
    // This avoids the compound index requirement
    return _firestore
        .collection('pools')
        .where('gameId', isEqualTo: gameId)
        .snapshots()
        .map((snapshot) {
      final typeString = type.toString().split('.').last;
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['type'] == typeString && data['status'] == 'open';
          })
          .map((doc) => Pool.fromFirestore(doc))
          .toList();
    });
  }

  // Get regional pools
  Stream<List<Pool>> getRegionalPools(String gameId, String region) {
    return _firestore
        .collection('pools')
        .where('gameId', isEqualTo: gameId)
        .where('type', isEqualTo: 'regional')
        .where('region', isEqualTo: region)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Pool.fromFirestore(doc)).toList();
    });
  }

  // Get private pools for user's friends
  Stream<List<Pool>> getFriendPools(String gameId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('pools')
        .where('gameId', isEqualTo: gameId)
        .where('type', isEqualTo: 'private')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Pool.fromFirestore(doc)).toList();
    });
  }

  // Get tournament pools
  Stream<List<Pool>> getTournamentPools(String gameId) {
    return _firestore
        .collection('pools')
        .where('gameId', isEqualTo: gameId)
        .where('type', isEqualTo: 'tournament')
        .where('status', isEqualTo: 'open')
        .orderBy('prizePool', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Pool.fromFirestore(doc)).toList();
    });
  }

  // Join a pool - returns result with success and message
  Future<Map<String, dynamic>> joinPoolWithResult(String poolId, int buyIn) async {
    print('[POOL_SERVICE] joinPoolWithResult called - poolId: $poolId, buyIn: $buyIn');

    final userId = _auth.currentUser?.uid;
    print('[POOL_SERVICE] Current user ID: $userId');

    if (userId == null) {
      return {'success': false, 'message': 'User not logged in', 'code': 'NOT_LOGGED_IN'};
    }

    try {
      // First, check pool conditions outside of transaction
      print('[POOL_SERVICE] Fetching pool document...');
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();

      if (!poolDoc.exists) {
        print('[POOL_SERVICE] Pool document does not exist!');
        return {'success': false, 'message': 'Pool not found', 'code': 'POOL_NOT_FOUND'};
      }

      print('[POOL_SERVICE] Pool document found, converting to Pool model...');
      print('[POOL_SERVICE] Pool doc data keys: ${poolDoc.data()?.keys.toList()}');

      final pool = Pool.fromFirestore(poolDoc);
      print('[POOL_SERVICE] Pool model created - name: ${pool.name}, gameId: ${pool.gameId}, espnEventId: ${pool.espnEventId}');

      // Check if user is already in pool
      if (pool.playerIds.contains(userId)) {
        return {'success': false, 'message': 'You are already in this pool', 'code': 'ALREADY_IN_POOL'};
      }

      // Check if pool is full
      if (pool.isFull) {
        return {'success': false, 'message': 'Pool is full', 'code': 'POOL_FULL'};
      }

      // Check if pool is still open
      if (pool.status != PoolStatus.open) {
        return {'success': false, 'message': 'Pool is no longer open for entry', 'code': 'POOL_CLOSED'};
      }

      // Check user's balance
      final balance = await _walletService.getBalance(userId);
      if (balance < buyIn) {
        return {'success': false, 'message': 'Insufficient BR balance', 'code': 'INSUFFICIENT_BALANCE'};
      }

      // Deduct buy-in from wallet (this has its own transaction)
      bool walletSuccess = false;
      try {
        print('[POOL_SERVICE] Attempting to deduct $buyIn from wallet...');
        print('[POOL_SERVICE] Pool metadata - poolId: $poolId, poolName: ${pool.name}, gameId: ${pool.gameId}');

        walletSuccess = await _walletService.deductFromWallet(
          userId,
          buyIn,
          'Pool entry: ${pool.name}',
          metadata: {
            'poolId': poolId,
            'poolName': pool.name,
            'gameId': pool.gameId,
          },
        );

        print('[POOL_SERVICE] Wallet deduction result: $walletSuccess');
      } catch (e) {
        print('[POOL_SERVICE] Error during wallet deduction: $e');
        print('[POOL_SERVICE] Error type: ${e.runtimeType}');
        print('[POOL_SERVICE] Stack trace: ${StackTrace.current}');

        if (e.toString().contains('Insufficient')) {
          return {'success': false, 'message': 'Insufficient BR balance', 'code': 'INSUFFICIENT_BALANCE'};
        }
        return {'success': false, 'message': 'Payment failed', 'code': 'PAYMENT_FAILED'};
      }

      if (!walletSuccess) {
        return {'success': false, 'message': 'Payment failed', 'code': 'PAYMENT_FAILED'};
      }

      // Now update the pool in a transaction
      try {
        final success = await _firestore.runTransaction((transaction) async {
          // Re-fetch pool document to ensure current state
          final currentPoolDoc = await transaction.get(
            _firestore.collection('pools').doc(poolId),
          );

          if (!currentPoolDoc.exists) {
            throw Exception('POOL_NOT_FOUND');
          }

          final currentPool = Pool.fromFirestore(currentPoolDoc);

          // Double-check conditions haven't changed
          if (currentPool.playerIds.contains(userId)) {
            throw Exception('ALREADY_IN_POOL');
          }

          if (currentPool.isFull) {
            throw Exception('POOL_FULL');
          }

          if (currentPool.status != PoolStatus.open) {
            throw Exception('POOL_CLOSED');
          }

          // Update pool with new player
          transaction.update(currentPoolDoc.reference, {
            'currentPlayers': FieldValue.increment(1),
            'playerIds': FieldValue.arrayUnion([userId]),
            'prizePool': FieldValue.increment(buyIn),
          });

          // Create pool entry record for user
          transaction.set(
            _firestore.collection('user_pools').doc('${userId}_$poolId'),
            {
              'userId': userId,
              'poolId': poolId,
              'gameId': currentPool.gameId,
              'buyIn': buyIn,
              'joinedAt': FieldValue.serverTimestamp(),
              'poolName': currentPool.name,
              'poolType': currentPool.type.toString().split('.').last,
            },
          );

          return true;
        });

        return {'success': true, 'message': 'Successfully joined pool', 'code': 'SUCCESS'};
      } catch (e) {
        // If pool update fails, refund the wallet
        await _walletService.addToWallet(
          userId,
          buyIn,
          'Refund: Failed to join pool',
          metadata: {'poolId': poolId, 'error': e.toString()},
        );

        if (e.toString().contains('ALREADY_IN_POOL')) {
          return {'success': false, 'message': 'You are already in this pool', 'code': 'ALREADY_IN_POOL'};
        } else if (e.toString().contains('POOL_FULL')) {
          return {'success': false, 'message': 'Pool became full', 'code': 'POOL_FULL'};
        } else if (e.toString().contains('POOL_CLOSED')) {
          return {'success': false, 'message': 'Pool closed before you could join', 'code': 'POOL_CLOSED'};
        } else if (e.toString().contains('POOL_NOT_FOUND')) {
          return {'success': false, 'message': 'Pool no longer exists', 'code': 'POOL_NOT_FOUND'};
        }
        throw e; // Re-throw to be caught by outer catch
      }
    } catch (e) {
      print('Error joining pool: $e');
      String message = 'Failed to join pool';
      String code = 'UNKNOWN_ERROR';
      
      if (e.toString().contains('ALREADY_IN_POOL')) {
        message = 'You are already in this pool';
        code = 'ALREADY_IN_POOL';
      } else if (e.toString().contains('POOL_FULL')) {
        message = 'This pool is already full';
        code = 'POOL_FULL';
      } else if (e.toString().contains('POOL_CLOSED')) {
        message = 'This pool has already started';
        code = 'POOL_CLOSED';
      } else if (e.toString().contains('INSUFFICIENT_BALANCE')) {
        message = 'Insufficient BR balance';
        code = 'INSUFFICIENT_BALANCE';
      } else if (e.toString().contains('PAYMENT_FAILED')) {
        message = 'Payment processing failed';
        code = 'PAYMENT_FAILED';
      } else if (e.toString().contains('POOL_NOT_FOUND')) {
        message = 'Pool not found';
        code = 'POOL_NOT_FOUND';
      }
      
      return {'success': false, 'message': message, 'code': code};
    }
  }
  
  // Original joinPool method for backward compatibility
  Future<bool> joinPool(String poolId, int buyIn) async {
    final result = await joinPoolWithResult(poolId, buyIn);
    return result['success'] as bool;
  }

  // Leave a pool (before it starts)
  Future<bool> leavePool(String poolId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // First get pool information
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();

      if (!poolDoc.exists) {
        throw Exception('Pool not found');
      }

      final pool = Pool.fromFirestore(poolDoc);

      // Check if pool has started
      if (pool.status != PoolStatus.open) {
        throw Exception('Cannot leave pool after it has started');
      }

      // Check if user is in pool
      if (!pool.playerIds.contains(userId)) {
        throw Exception('Not in this pool');
      }

      // Update pool in a transaction first
      await _firestore.runTransaction((transaction) async {
        // Re-fetch to ensure current state
        final currentPoolDoc = await transaction.get(
          _firestore.collection('pools').doc(poolId),
        );

        if (!currentPoolDoc.exists) {
          throw Exception('Pool not found');
        }

        final currentPool = Pool.fromFirestore(currentPoolDoc);

        // Re-check conditions
        if (currentPool.status != PoolStatus.open) {
          throw Exception('Cannot leave pool after it has started');
        }

        if (!currentPool.playerIds.contains(userId)) {
          throw Exception('Not in this pool');
        }

        // Update pool
        transaction.update(currentPoolDoc.reference, {
          'currentPlayers': FieldValue.increment(-1),
          'playerIds': FieldValue.arrayRemove([userId]),
          'prizePool': FieldValue.increment(-currentPool.buyIn),
        });

        // Delete pool entry record
        transaction.delete(
          _firestore.collection('user_pools').doc('${userId}_$poolId'),
        );
      });

      // After successfully updating pool, refund the buy-in
      await _walletService.addToWallet(
        userId,
        pool.buyIn,
        'Pool refund: ${pool.name}',
        metadata: {
          'poolId': poolId,
          'poolName': pool.name,
          'gameId': pool.gameId,
        },
      );

      return true;
    } catch (e) {
      print('Error leaving pool: $e');
      return false;
    }
  }

  // Create a private pool
  Future<String?> createPrivatePool({
    required String gameId,
    required String gameTitle,
    required String sport,
    required String name,
    required int buyIn,
    required int maxPlayers,
    int minPlayers = 2,
    Map<String, dynamic>? prizeStructure,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      // Check user's current pool creation count
      final userPoolsQuery = await _firestore
          .collection('pools')
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .get();
      
      if (userPoolsQuery.docs.length >= 5) {
        throw Exception('You can only create up to 5 active pools at a time. Please wait for some pools to complete or delete existing ones.');
      }

      final now = DateTime.now();
      final code = _generatePoolCode();

      // Calculate default prize structure if not provided
      final prizes = prizeStructure ??
          _calculatePrizeStructure(buyIn * maxPlayers);

      final pool = Pool(
        id: '',
        gameId: gameId,
        gameTitle: gameTitle,
        sport: sport,
        type: PoolType.private,
        status: PoolStatus.open,
        name: name,
        buyIn: buyIn,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        currentPlayers: 1, // Creator auto-joins
        playerIds: [userId],
        startTime: now.add(const Duration(hours: 1)),
        closeTime: now.add(const Duration(minutes: 45)),
        prizePool: buyIn, // Creator's buy-in
        prizeStructure: prizes,
        code: code,
        createdAt: now,
        createdBy: userId,
        metadata: {
          'isPrivate': true,
          'inviteOnly': false,
        },
      );

      // Deduct buy-in from creator
      final walletSuccess = await _walletService.deductFromWallet(
        userId,
        buyIn,
        'Created pool: $name',
        metadata: {
          'poolName': name,
          'gameId': gameId,
        },
      );

      if (!walletSuccess) {
        throw Exception('Failed to process payment');
      }

      // Create pool document
      final docRef = await _firestore.collection('pools').add(pool.toFirestore());

      // Create pool entry for creator
      await _firestore.collection('user_pools').doc('${userId}_${docRef.id}').set({
        'userId': userId,
        'poolId': docRef.id,
        'gameId': gameId,
        'buyIn': buyIn,
        'joinedAt': FieldValue.serverTimestamp(),
        'poolName': name,
        'poolType': 'private',
        'isCreator': true,
      });

      return docRef.id;
    } catch (e) {
      print('Error creating private pool: $e');
      return null;
    }
  }

  // Generic method to create any type of pool
  Future<String?> createPool({
    required String gameId,
    required String gameTitle,
    required String sport,
    required PoolType type,
    required String name,
    required int buyIn,
    required int maxPlayers,
    int minPlayers = 2,
    Map<String, dynamic>? prizeStructure,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      // Check user's balance
      final balance = await _walletService.getCurrentBalance();
      if (balance < buyIn) {
        throw Exception('Insufficient balance. You need $buyIn BR to create this pool.');
      }

      final now = DateTime.now();
      final code = type == PoolType.private ? _generatePoolCode() : null;

      // Calculate default prize structure if not provided
      final prizes = prizeStructure ??
          _calculatePrizeStructure(buyIn * maxPlayers);

      // Determine tier based on buy-in
      PoolTier tier = PoolTier.standard;
      if (buyIn <= 10) {
        tier = PoolTier.beginner;
      } else if (buyIn <= 25) {
        tier = PoolTier.standard;
      } else if (buyIn <= 50) {
        tier = PoolTier.high;
      } else {
        tier = PoolTier.vip;
      }

      final pool = Pool(
        id: '',
        gameId: gameId,
        gameTitle: gameTitle,
        sport: sport,
        type: type,
        status: PoolStatus.open,
        name: name,
        buyIn: buyIn,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        currentPlayers: 1, // Creator auto-joins
        playerIds: [userId],
        startTime: now.add(const Duration(hours: 1)),
        closeTime: now.add(const Duration(minutes: 45)),
        prizePool: buyIn, // Creator's buy-in
        prizeStructure: prizes,
        tier: tier,
        code: code,
        createdAt: now,
        createdBy: userId,
        metadata: {
          'userCreated': true,
          'autoGenerated': false,
        },
      );

      // Deduct buy-in from creator
      final walletSuccess = await _walletService.deductFromWallet(
        userId,
        buyIn,
        'Created pool: $name',
        metadata: {
          'poolName': name,
          'gameId': gameId,
          'poolType': type.toString(),
        },
      );

      if (!walletSuccess) {
        throw Exception('Failed to process payment');
      }

      // Create pool document
      final docRef = await _firestore.collection('pools').add(pool.toFirestore());

      // Create pool entry for creator
      await _firestore.collection('user_pools').doc('${userId}_${docRef.id}').set({
        'userId': userId,
        'poolId': docRef.id,
        'gameId': gameId,
        'buyIn': buyIn,
        'joinedAt': FieldValue.serverTimestamp(),
        'poolName': name,
        'poolType': type.toString().split('.').last,
        'isCreator': true,
      });

      return docRef.id;
    } catch (e) {
      print('Error creating pool: $e');
      return null;
    }
  }

  // Join pool with code
  Future<bool> joinPoolWithCode(String code) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // Find pool with code
      final querySnapshot = await _firestore
          .collection('pools')
          .where('code', isEqualTo: code.toUpperCase())
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid pool code');
      }

      final poolDoc = querySnapshot.docs.first;
      final pool = Pool.fromFirestore(poolDoc);

      // Join the pool
      return await joinPool(poolDoc.id, pool.buyIn);
    } catch (e) {
      print('Error joining pool with code: $e');
      return false;
    }
  }

  // Check if user is already in a specific pool
  Future<bool> isUserInPool(String poolId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final doc = await _firestore
          .collection('user_pools')
          .doc('${userId}_$poolId')
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user in pool: $e');
      return false;
    }
  }

  // Check if user has submitted picks for a pool
  Future<bool> hasUserSubmittedPicks(String poolId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // Check if user has any bets for this pool
      final betsQuery = await _firestore
          .collection('bets')
          .where('userId', isEqualTo: userId)
          .where('poolId', isEqualTo: poolId)
          .where('status', isEqualTo: 'locked')
          .limit(1)
          .get();
      
      return betsQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user picks: $e');
      return false;
    }
  }

  // Get user's active pools
  Stream<List<Pool>> getUserPools() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('user_pools')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final poolIds = snapshot.docs.map((doc) => doc.data()['poolId'] as String).toList();
      
      if (poolIds.isEmpty) return [];

      final poolDocs = await Future.wait(
        poolIds.map((id) => _firestore.collection('pools').doc(id).get()),
      );

      return poolDocs
          .where((doc) => doc.exists)
          .map((doc) => Pool.fromFirestore(doc))
          .toList();
    });
  }

  // Generate pool statistics
  Future<Map<String, dynamic>> getPoolStats(String poolId) async {
    try {
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();
      if (!poolDoc.exists) return {};

      final pool = Pool.fromFirestore(poolDoc);

      return {
        'fillPercentage': pool.fillPercentage,
        'spotsRemaining': pool.maxPlayers - pool.currentPlayers,
        'timeUntilClose': pool.timeUntilClose.inMinutes,
        'isClosingSoon': pool.isClosingSoon,
        'canStart': pool.canStart,
        'averageBuyIn': pool.prizePool / pool.currentPlayers,
        'maxPrize': pool.getPrizeForPosition(1),
      };
    } catch (e) {
      print('Error getting pool stats: $e');
      return {};
    }
  }

  // Helper: Generate unique pool code
  String _generatePoolCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i * 7) % chars.length];
    }
    return code;
  }

  // Helper: Calculate prize structure
  Map<String, dynamic> _calculatePrizeStructure(int totalPrize) {
    return {
      '1': (totalPrize * 0.5).round(),  // 50% to first
      '2': (totalPrize * 0.3).round(),  // 30% to second
      '3': (totalPrize * 0.2).round(),  // 20% to third
    };
  }
  
  // Get user's created pool count
  Future<int> getUserCreatedPoolCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;
    
    try {
      final query = await _firestore
          .collection('pools')
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .get();
      
      return query.docs.length;
    } catch (e) {
      print('Error getting user pool count: $e');
      return 0;
    }
  }
  
  // Delete a pool (only by creator, before it starts)
  Future<bool> deletePool(String poolId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // First get pool information
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();

      if (!poolDoc.exists) {
        throw Exception('Pool not found');
      }

      final pool = Pool.fromFirestore(poolDoc);

      // Check if user is the creator
      if (pool.createdBy != userId) {
        throw Exception('Only the pool creator can delete this pool');
      }

      // Check if pool has started
      if (pool.status != PoolStatus.open) {
        throw Exception('Cannot delete pool after it has started');
      }

      // Check if there are other players (besides creator)
      if (pool.currentPlayers > 1) {
        throw Exception('Cannot delete pool with other players. They must leave first.');
      }

      // Delete the pool in a transaction
      await _firestore.runTransaction((transaction) async {
        // Re-fetch to ensure current state
        final currentPoolDoc = await transaction.get(
          _firestore.collection('pools').doc(poolId),
        );

        if (!currentPoolDoc.exists) {
          throw Exception('Pool not found');
        }

        final currentPool = Pool.fromFirestore(currentPoolDoc);

        // Re-check conditions
        if (currentPool.createdBy != userId) {
          throw Exception('Only the pool creator can delete this pool');
        }

        if (currentPool.status != PoolStatus.open) {
          throw Exception('Cannot delete pool after it has started');
        }

        if (currentPool.currentPlayers > 1) {
          throw Exception('Cannot delete pool with other players. They must leave first.');
        }
        
        // Delete the pool document
        transaction.delete(currentPoolDoc.reference);

        // Delete user pool entry
        transaction.delete(
          _firestore.collection('user_pools').doc('${userId}_$poolId'),
        );
      });

      // After successfully deleting pool, refund creator's buy-in
      await _walletService.addToWallet(
        userId,
        pool.buyIn,
        'Pool deleted: ${pool.name}',
        metadata: {
          'poolId': poolId,
          'poolName': pool.name,
        },
      );

      return true;
    } catch (e) {
      print('Error deleting pool: $e');
      return false;
    }
  }

  // Check and activate pools that meet minimum requirements
  Future<void> checkPoolActivation(String poolId) async {
    try {
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();
      if (!poolDoc.exists) return;

      final pool = Pool.fromFirestore(poolDoc);
      final now = DateTime.now();

      // Check if it's time to activate or cancel the pool
      if (pool.status == PoolStatus.open && now.isAfter(pool.closeTime)) {
        // Calculate 75% of max players as minimum requirement
        final minimumRequired = (pool.maxPlayers * MINIMUM_PLAYER_PERCENTAGE).ceil();
        
        if (pool.currentPlayers >= minimumRequired) {
          // Activate the pool
          await _activatePool(poolId, pool);
        } else {
          // Cancel the pool and refund players
          await _cancelPool(poolId, pool);
        }
      }
    } catch (e) {
      print('Error checking pool activation: $e');
    }
  }

  // Activate a pool when minimum players are met
  Future<void> _activatePool(String poolId, Pool pool) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Calculate final prize structure
        final prizeStructure = _calculatePrizeStructure(pool.prizePool);

        // Update pool status to active
        transaction.update(_firestore.collection('pools').doc(poolId), {
          'status': 'active',
          'activatedAt': FieldValue.serverTimestamp(),
          'finalPlayerCount': pool.currentPlayers,
          'finalPrizePool': pool.prizePool,
          'prizeStructure': prizeStructure,
        });

        // Notify all players that the pool is active
        // This would trigger push notifications in production
        print('Pool $poolId activated with ${pool.currentPlayers} players');
      });
    } catch (e) {
      print('Error activating pool: $e');
    }
  }

  // Cancel a pool when minimum players are not met
  Future<void> _cancelPool(String poolId, Pool pool) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // FIRST: Do all reads
        final Map<String, DocumentSnapshot> userEntries = {};
        for (final playerId in pool.playerIds) {
          // Get the user's pool entry to know how much to refund
          final entryDoc = await transaction.get(
            _firestore.collection('user_pools').doc('${playerId}_$poolId'),
          );
          if (entryDoc.exists) {
            userEntries[playerId] = entryDoc;
          }
        }

        // SECOND: Do all writes
        // Update pool status to cancelled
        transaction.update(_firestore.collection('pools').doc(poolId), {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationReason': 'Minimum players not met',
        });

        // Delete all user pool entries
        for (final entry in userEntries.values) {
          transaction.delete(entry.reference);
        }

        // Process refunds outside the transaction
        // (Wallet operations should not be in Firestore transactions)
        for (final playerId in userEntries.keys) {
          final entryData = userEntries[playerId]!.data() as Map<String, dynamic>;
          final buyIn = entryData['buyIn'] ?? pool.buyIn;

          // Refund the buy-in (this will be done after transaction completes)
          _walletService.addToWallet(
            playerId,
            buyIn,
            'Pool cancelled refund: ${pool.name}',
            metadata: {
              'poolId': poolId,
              'poolName': pool.name,
              'reason': 'Minimum players not met',
            },
          );
        }

        print('Pool $poolId cancelled and ${userEntries.length} players refunded');
      });
    } catch (e) {
      print('Error cancelling pool: $e');
    }
  }

  // Check all open pools for activation or cancellation
  Future<void> checkAllPoolsForActivation() async {
    // Check if user is authenticated
    if (_auth.currentUser == null) {
      print('Skipping pool activation check - user not authenticated');
      return;
    }
    
    try {
      final now = DateTime.now();
      
      // Get all open pools that have passed their close time
      // Exclude already processed pools
      final poolsQuery = await _firestore
          .collection('pools')
          .where('status', isEqualTo: 'open')
          .get();

      int processedCount = 0;
      for (final poolDoc in poolsQuery.docs) {
        final data = poolDoc.data();
        
        // Skip if already processed
        if (data['processedAt'] != null) {
          continue;
        }
        
        final pool = Pool.fromFirestore(poolDoc);
        if (now.isAfter(pool.closeTime)) {
          await checkPoolActivation(poolDoc.id);
          processedCount++;
        }
      }
      
      if (processedCount > 0) {
        print('Processed $processedCount pools for activation/cancellation');
        
        // Run cleanup after processing
        final cleanupService = PoolCleanupService();
        final deletedCount = await cleanupService.cleanupExpiredPools();
        if (deletedCount > 0) {
          print('Cleaned up $deletedCount expired/empty pools');
        }
      }
    } catch (e) {
      print('Error checking pools for activation: $e');
    }
  }

  // Automatically generate pools based on demand
  Future<void> generatePoolsForGame({
    required String gameId,
    required String gameTitle,
    required String sport,
    required DateTime gameStartTime,
  }) async {
    // Check if user is authenticated
    if (_auth.currentUser == null) {
      print('Skipping pool generation - user not authenticated');
      return;
    }
    
    try {
      // Check existing pools for this game
      final existingPoolsQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'open')
          .get();

      final existingPools = existingPoolsQuery.docs
          .map((doc) => Pool.fromFirestore(doc))
          .toList();

      // Generate Quick Play pools if none exist
      if (existingPools.where((p) => p.type == PoolType.quick).isEmpty) {
        await _generateQuickPlayPools(gameId, gameTitle, sport, gameStartTime);
      }

      // Generate Regional pools based on user location
      // This would use user's location in production
      if (existingPools.where((p) => p.type == PoolType.regional).isEmpty) {
        await _generateRegionalPools(gameId, gameTitle, sport, gameStartTime);
      }
    } catch (e) {
      print('Error generating pools: $e');
    }
  }

  // Generate Quick Play pools with different buy-in levels
  Future<void> _generateQuickPlayPools(
    String gameId,
    String gameTitle,
    String sport,
    DateTime gameStartTime,
  ) async {
    final templates = [
      QuickPlayPoolTemplate.beginner(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.standard(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.highStakes(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.vip(gameId: gameId, gameTitle: gameTitle, sport: sport),
    ];

    for (final template in templates) {
      // Calculate 75% minimum for each pool
      final minimumRequired = (template.maxPlayers * MINIMUM_PLAYER_PERCENTAGE).ceil();
      
      // Set proper timing based on game start time and update minimum
      final pool = template.copyWith(
        startTime: gameStartTime,
        closeTime: gameStartTime.subtract(const Duration(minutes: 15)),
        minPlayers: minimumRequired,
      );

      await _firestore.collection('pools').add(pool.toFirestore());
    }

    print('Generated ${templates.length} Quick Play pools for game $gameId with 75% minimum rule');
  }

  // Generate Regional pools for different geographic levels
  Future<void> _generateRegionalPools(
    String gameId,
    String gameTitle,
    String sport,
    DateTime gameStartTime,
  ) async {
    // Detect user's region
    final regionInfo = await _locationService.detectRegion();
    
    // Pool configurations for each regional level
    final poolConfigs = [
      {
        'level': location.RegionalLevel.neighborhood,
        'name': '${regionInfo.city} Neighborhood',
        'buyIn': 25,
        'maxPlayers': 20,
        'region': '${regionInfo.city}-neighborhood',
      },
      {
        'level': location.RegionalLevel.city,
        'name': '${regionInfo.city} Metro',
        'buyIn': 50,
        'maxPlayers': 50,
        'region': regionInfo.city,
      },
      {
        'level': location.RegionalLevel.state,
        'name': regionInfo.state,
        'buyIn': 100,
        'maxPlayers': 100,
        'region': regionInfo.state,
      },
      {
        'level': location.RegionalLevel.national,
        'name': '${regionInfo.country} National',
        'buyIn': 200,
        'maxPlayers': 200,
        'region': regionInfo.country,
      },
    ];

    for (final config in poolConfigs) {
      final maxPlayers = config['maxPlayers'] as int;
      final minimumRequired = (maxPlayers * MINIMUM_PLAYER_PERCENTAGE).ceil();
      
      final pool = Pool(
        id: '',
        gameId: gameId,
        gameTitle: gameTitle,
        sport: sport,
        type: PoolType.regional,
        status: PoolStatus.open,
        name: '${config['name']} Pool - $gameTitle',
        buyIn: config['buyIn'] as int,
        minPlayers: minimumRequired,  // Use 75% rule
        maxPlayers: maxPlayers,
        currentPlayers: 0,
        playerIds: [],
        startTime: gameStartTime,
        closeTime: gameStartTime.subtract(const Duration(minutes: 30)),
        prizePool: 0,
        prizeStructure: {},
        region: config['region'] as String,
        createdAt: DateTime.now(),
        metadata: {
          'autoGenerated': true,
          'region': config['region'],
          'regionalLevel': config['level'].toString().split('.').last,
          'minimumRequired': minimumRequired,
        },
      );

      await _firestore.collection('pools').add(pool.toFirestore());
    }

    print('Generated ${poolConfigs.length} Regional pools for game $gameId in ${regionInfo.city}, ${regionInfo.state}');
  }

  // Monitor pool fill rates and generate additional pools if needed
  Future<void> monitorAndGeneratePoolsByDemand(String gameId) async {
    try {
      final poolsQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'open')
          .where('type', isEqualTo: 'quick')
          .get();

      for (final poolDoc in poolsQuery.docs) {
        final pool = Pool.fromFirestore(poolDoc);
        
        // If a pool is more than 80% full, create another similar pool
        if (pool.fillPercentage > 80) {
          final newPool = pool.copyWith(
            id: '',
            currentPlayers: 0,
            playerIds: [],
            prizePool: 0,
            createdAt: DateTime.now(),
          );

          await _firestore.collection('pools').add(newPool.toFirestore());
          print('Generated additional pool due to high demand for ${pool.name}');
        }
      }
    } catch (e) {
      print('Error monitoring pool demand: $e');
    }
  }

  // Create mock pools for testing
  Future<void> createMockPools(String gameId, String gameTitle, String sport) async {
    final templates = [
      QuickPlayPoolTemplate.beginner(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.standard(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.highStakes(gameId: gameId, gameTitle: gameTitle, sport: sport),
      QuickPlayPoolTemplate.vip(gameId: gameId, gameTitle: gameTitle, sport: sport),
    ];

    for (final template in templates) {
      // Simulate some players already in pool
      final mockPlayers = (template.maxPlayers * 0.3 + DateTime.now().millisecond % 20).round();
      final poolWithPlayers = template.copyWith(
        currentPlayers: mockPlayers,
        prizePool: template.buyIn * mockPlayers,
      );

      await _firestore.collection('pools').add(poolWithPlayers.toFirestore());
    }
  }
}