import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pool_service.dart';

class PoolManagementService {
  final PoolService _poolService = PoolService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Timer? _poolCheckTimer;
  Timer? _demandMonitorTimer;
  
  static final PoolManagementService _instance = PoolManagementService._internal();
  factory PoolManagementService() => _instance;
  PoolManagementService._internal();

  // Start the pool management background tasks
  void startPoolManagement() {
    // Check for pool activation every minute
    _poolCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkPoolsForActivation();
    });

    // Monitor demand and generate pools every 5 minutes
    _demandMonitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _monitorAndGeneratePools();
    });

    // Do an immediate check
    _checkPoolsForActivation();
    _monitorAndGeneratePools();
  }

  // Stop the pool management background tasks
  void stopPoolManagement() {
    _poolCheckTimer?.cancel();
    _demandMonitorTimer?.cancel();
  }

  // Check all pools for activation or cancellation
  Future<void> _checkPoolsForActivation() async {
    try {
      await _poolService.checkAllPoolsForActivation();
    } catch (e) {
      print('Error in pool activation check: $e');
    }
  }

  // Monitor pool demand and generate new pools
  Future<void> _monitorAndGeneratePools() async {
    try {
      // Get upcoming games (within next 24 hours)
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(hours: 24));
      
      final gamesQuery = await _firestore
          .collection('games')
          .where('gameTime', isGreaterThan: now)
          .where('gameTime', isLessThan: tomorrow)
          .get();

      for (final gameDoc in gamesQuery.docs) {
        final gameData = gameDoc.data();
        final gameId = gameDoc.id;
        final gameTitle = gameData['title'] ?? 'Unknown Game';
        final sport = gameData['sport'] ?? 'Unknown Sport';
        final gameTime = (gameData['gameTime'] as Timestamp).toDate();
        final espnEventId = gameData['espnId']?.toString();

        // Generate pools for this game if needed
        await _poolService.generatePoolsForGame(
          gameId: gameId,
          gameTitle: gameTitle,
          sport: sport,
          gameStartTime: gameTime,
          espnEventId: espnEventId,
        );

        // Monitor demand for existing pools
        await _poolService.monitorAndGeneratePoolsByDemand(gameId);
      }
    } catch (e) {
      print('Error in pool generation: $e');
    }
  }

  // Generate initial pools for a newly added game
  Future<void> generatePoolsForNewGame({
    required String gameId,
    required String gameTitle,
    required String sport,
    required DateTime gameStartTime,
    String? espnEventId,
  }) async {
    try {
      await _poolService.generatePoolsForGame(
        gameId: gameId,
        gameTitle: gameTitle,
        sport: sport,
        gameStartTime: gameStartTime,
        espnEventId: espnEventId,
      );
    } catch (e) {
      print('Error generating pools for new game: $e');
    }
  }

  // Clean up old/expired pools
  Future<void> cleanupExpiredPools() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      // Get completed or cancelled pools older than 7 days
      final oldPoolsQuery = await _firestore
          .collection('pools')
          .where('status', whereIn: ['completed', 'cancelled'])
          .where('createdAt', isLessThan: cutoffDate)
          .get();

      // Archive or delete old pools
      for (final poolDoc in oldPoolsQuery.docs) {
        // In production, you might want to archive instead of delete
        await poolDoc.reference.delete();
      }

      print('Cleaned up ${oldPoolsQuery.docs.length} expired pools');
    } catch (e) {
      print('Error cleaning up expired pools: $e');
    }
  }

  // Get pool statistics for analytics
  Future<Map<String, dynamic>> getPoolStatistics() async {
    try {
      final poolsQuery = await _firestore.collection('pools').get();
      
      int openPools = 0;
      int activePools = 0;
      int completedPools = 0;
      int cancelledPools = 0;
      int totalPlayers = 0;
      double totalPrizePool = 0;

      for (final poolDoc in poolsQuery.docs) {
        final data = poolDoc.data();
        final status = data['status'] ?? '';
        final players = data['currentPlayers'] ?? 0;
        final prize = (data['prizePool'] ?? 0).toDouble();

        switch (status) {
          case 'open':
            openPools++;
            break;
          case 'active':
            activePools++;
            break;
          case 'completed':
            completedPools++;
            break;
          case 'cancelled':
            cancelledPools++;
            break;
        }

        totalPlayers += players as int;
        totalPrizePool += prize;
      }

      return {
        'totalPools': poolsQuery.docs.length,
        'openPools': openPools,
        'activePools': activePools,
        'completedPools': completedPools,
        'cancelledPools': cancelledPools,
        'totalPlayers': totalPlayers,
        'totalPrizePool': totalPrizePool,
        'averagePlayersPerPool': poolsQuery.docs.isNotEmpty 
            ? (totalPlayers / poolsQuery.docs.length).toStringAsFixed(1)
            : '0',
      };
    } catch (e) {
      print('Error getting pool statistics: $e');
      return {};
    }
  }

  // Handle real-time pool updates
  Stream<List<Map<String, dynamic>>> getLivePoolUpdates() {
    return _firestore
        .collection('pools')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'poolId': doc.id,
          'name': data['name'],
          'currentPlayers': data['currentPlayers'],
          'maxPlayers': data['maxPlayers'],
          'prizePool': data['prizePool'],
          'gameId': data['gameId'],
        };
      }).toList();
    });
  }
}