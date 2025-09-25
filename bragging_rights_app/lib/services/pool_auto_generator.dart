import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pool_model.dart';
import '../models/fight_card_model.dart';
import '../models/game_model.dart';

/// Service to auto-generate pools for events
class PoolAutoGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Clean up old NFL pools that were incorrectly created as separate bet type pools
  Future<void> cleanupOldNFLPools() async {
    try {
      debugPrint('🧹 Starting NFL pool cleanup...');

      // Get all NFL pools
      final nflPoolsQuery = await _firestore
          .collection('pools')
          .where('sport', isEqualTo: 'NFL')
          .where('status', isEqualTo: 'open')
          .get();

      debugPrint('Found ${nflPoolsQuery.docs.length} open NFL pools');

      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in nflPoolsQuery.docs) {
        final poolData = doc.data();
        final poolName = poolData['name'] ?? '';

        // Delete old-style pools with bet type names
        if (poolName.contains('Against Spread') ||
            poolName.contains('Over/Under') ||
            poolName.contains('Pick Winner')) {

          // Only delete if no players have joined
          final currentPlayers = poolData['currentPlayers'] ?? 0;
          if (currentPlayers == 0) {
            batch.delete(doc.reference);
            deleteCount++;
            debugPrint('  - Deleting: $poolName (ID: ${doc.id})');
          } else {
            debugPrint('  - Keeping: $poolName (has $currentPlayers players)');
          }
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('✅ Deleted $deleteCount old NFL pools');
      } else {
        debugPrint('✅ No old NFL pools to delete');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up NFL pools: $e');
    }
  }

  /// Clean up old MLB pools that were incorrectly created as separate bet type pools
  Future<void> cleanupOldMLBPools() async {
    try {
      debugPrint('🧹 Starting MLB pool cleanup...');

      // Get all MLB pools
      final mlbPoolsQuery = await _firestore
          .collection('pools')
          .where('sport', isEqualTo: 'MLB')
          .where('status', isEqualTo: 'open')
          .get();

      debugPrint('Found ${mlbPoolsQuery.docs.length} open MLB pools');

      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in mlbPoolsQuery.docs) {
        final poolData = doc.data();
        final poolName = poolData['name'] ?? '';

        // Delete old-style pools with bet type names
        if (poolName.contains('Against Spread') ||
            poolName.contains('Over/Under') ||
            poolName.contains('Pick Winner')) {

          // Only delete if no players have joined
          final currentPlayers = poolData['currentPlayers'] ?? 0;
          if (currentPlayers == 0) {
            batch.delete(doc.reference);
            deleteCount++;
            debugPrint('  - Deleting: $poolName (ID: ${doc.id})');
          } else {
            debugPrint('  - Keeping: $poolName (has $currentPlayers players)');
          }
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('✅ Deleted $deleteCount old MLB pools');
      } else {
        debugPrint('✅ No old MLB pools to delete');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up MLB pools: $e');
    }
  }

  /// Generate pools for a fight card event
  Future<void> generateFightCardPools({
    required FightCardEventModel event,
  }) async {
    try {
      // Check if pools already exist
      final existingPools = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: event.id)
          .limit(1)
          .get();
      
      if (existingPools.docs.isNotEmpty) {
        debugPrint('Pools already exist for ${event.eventName}');
        return;
      }
      
      debugPrint('Generating pools for ${event.eventName}');
      
      // Generate Quick Play pools (different buy-ins)
      await _generateQuickPlayPools(event);
      
      // Generate Regional pools (if location available)
      await _generateRegionalPools(event);
      
      // Generate Tournament pools
      await _generateTournamentPools(event);
      
      debugPrint('Successfully generated pools for ${event.eventName}');
    } catch (e) {
      debugPrint('Error generating pools: $e');
    }
  }
  
  /// Generate Quick Play pools with different buy-ins
  Future<void> _generateQuickPlayPools(FightCardEventModel event) async {
    final batch = _firestore.batch();
    
    // Different tiers
    final tiers = [
      {'name': 'Casual', 'buyIn': 10, 'min': 10, 'max': 100},
      {'name': 'Standard', 'buyIn': 25, 'min': 10, 'max': 50},
      {'name': 'Competitive', 'buyIn': 50, 'min': 10, 'max': 30},
      {'name': 'High Stakes', 'buyIn': 100, 'min': 5, 'max': 20},
    ];
    
    for (final tier in tiers) {
      final pool = Pool(
        id: '',  // Auto-generated
        gameId: event.id,
        gameTitle: event.eventName,
        sport: 'MMA',
        type: PoolType.quick,
        status: PoolStatus.open,
        name: '${tier['name']} - Quick Play',
        buyIn: tier['buyIn'] as int,
        minPlayers: tier['min'] as int,
        maxPlayers: tier['max'] as int,
        currentPlayers: 0,
        playerIds: [],
        startTime: event.gameTime,
        closeTime: event.gameTime.subtract(const Duration(minutes: 30)),
        prizePool: 0,  // Will update as players join
        prizeStructure: _getQuickPlayPrizeStructure(tier['max'] as int),
        tier: _getTierFromBuyIn(tier['buyIn'] as int),
        createdAt: DateTime.now(),
        metadata: {
          'eventName': event.eventName,
          'mainEvent': event.mainEventTitle,
          'totalFights': event.totalFights,
          'autoGenerated': true,
        },
      );
      
      final docRef = _firestore.collection('pools').doc();
      batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
    }
    
    await batch.commit();
  }
  
  /// Generate Regional pools
  Future<void> _generateRegionalPools(FightCardEventModel event) async {
    final batch = _firestore.batch();
    
    // Generate for major regions
    final regions = [
      {'level': 'national', 'region': 'USA', 'buyIn': 50},
      {'level': 'state', 'region': 'California', 'buyIn': 25},
      {'level': 'state', 'region': 'New York', 'buyIn': 25},
      {'level': 'state', 'region': 'Texas', 'buyIn': 25},
      {'level': 'state', 'region': 'Florida', 'buyIn': 25},
    ];
    
    for (final regionData in regions) {
      final pool = Pool(
        id: '',
        gameId: event.id,
        gameTitle: event.eventName,
        sport: 'MMA',
        type: PoolType.regional,
        status: PoolStatus.open,
        name: '${regionData['region']} Championship',
        buyIn: regionData['buyIn'] as int,
        minPlayers: 10,
        maxPlayers: 100,
        currentPlayers: 0,
        playerIds: [],
        startTime: event.gameTime,
        closeTime: event.gameTime.subtract(const Duration(minutes: 30)),
        prizePool: 0,
        prizeStructure: _getRegionalPrizeStructure(),
        regionalLevel: _getRegionalLevel(regionData['level'] as String),
        region: regionData['region'] as String,
        createdAt: DateTime.now(),
        metadata: {
          'eventName': event.eventName,
          'autoGenerated': true,
        },
      );
      
      final docRef = _firestore.collection('pools').doc();
      batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
    }
    
    await batch.commit();
  }
  
  /// Generate Tournament pools
  Future<void> _generateTournamentPools(FightCardEventModel event) async {
    final batch = _firestore.batch();
    
    // Tournament tiers
    final tournaments = [
      {'name': 'Bronze Tournament', 'buyIn': 50, 'max': 64},
      {'name': 'Silver Tournament', 'buyIn': 100, 'max': 32},
      {'name': 'Gold Tournament', 'buyIn': 250, 'max': 16},
    ];
    
    for (final tourney in tournaments) {
      final pool = Pool(
        id: '',
        gameId: event.id,
        gameTitle: event.eventName,
        sport: 'MMA',
        type: PoolType.tournament,
        status: PoolStatus.open,
        name: tourney['name'] as String,
        buyIn: tourney['buyIn'] as int,
        minPlayers: 8,
        maxPlayers: tourney['max'] as int,
        currentPlayers: 0,
        playerIds: [],
        startTime: event.gameTime,
        closeTime: event.gameTime.subtract(const Duration(hours: 1)),
        prizePool: 0,
        prizeStructure: _getTournamentPrizeStructure(),
        createdAt: DateTime.now(),
        metadata: {
          'eventName': event.eventName,
          'requiresFullCard': true,
          'autoGenerated': true,
        },
      );
      
      final docRef = _firestore.collection('pools').doc();
      batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
    }
    
    await batch.commit();
  }
  
  /// Generate pools for regular sports games
  Future<void> generateGamePools({
    required GameModel game,
  }) async {
    try {
      // Check if pools already exist
      final existingPools = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: game.id)
          .limit(1)
          .get();
      
      if (existingPools.docs.isNotEmpty) {
        return;
      }
      
      // Check what odds are available for this game
      final gameDoc = await _firestore
          .collection('games')
          .doc(game.id)
          .get();
      
      final oddsAvailable = gameDoc.data()?['oddsAvailable'] ?? {
        'moneyline': false,
        'spread': false,
        'total': false,
      };
      
      // Skip pool generation if no odds are available
      if (!oddsAvailable['moneyline'] && 
          !oddsAvailable['spread'] && 
          !oddsAvailable['total']) {
        debugPrint('⚠️ No odds available for ${game.gameTitle} - skipping pool generation');
        return;
      }
      
      debugPrint('🎰 Auto-generating pools for ${game.gameTitle}');
      debugPrint('   Available odds: ML=${oddsAvailable['moneyline']}, Spread=${oddsAvailable['spread']}, Total=${oddsAvailable['total']}');
      
      final batch = _firestore.batch();
      
      // Quick Play pools - create ONE pool per buy-in that allows multiple bet types
      final quickPlayBuyIns = [10, 25, 50, 100];

      // Only create pools if we have at least one type of odds available
      final hasAnyOdds = oddsAvailable['moneyline'] == true ||
                         oddsAvailable['spread'] == true ||
                         oddsAvailable['total'] == true;

      if (!hasAnyOdds) {
        debugPrint('   No odds available for ${game.gameTitle}, skipping pool generation');
        return;
      }

      for (final buyIn in quickPlayBuyIns) {
        // For MLB and NFL, create a single pool that allows all available bet types
        if (game.sport.toUpperCase() == 'MLB' || game.sport.toUpperCase() == 'NFL') {
          // Determine max players based on buy-in
          final maxPlayers = buyIn <= 25 ? 50 : (buyIn <= 50 ? 30 : 20);

          final pool = Pool(
            id: '',
            gameId: game.id,
            gameTitle: game.gameTitle,
            sport: game.sport,
            type: PoolType.quick,
            status: PoolStatus.open,
            name: 'Quick Play - $buyIn BR',
            buyIn: buyIn,
            minPlayers: 2,
            maxPlayers: maxPlayers,
            currentPlayers: 0,
            playerIds: [],
            startTime: game.gameTime,
            closeTime: game.gameTime.subtract(const Duration(minutes: 15)),
            prizePool: 0,
            prizeStructure: _getQuickPlayPrizeStructure(maxPlayers),
            tier: _getTierFromBuyIn(buyIn),
            createdAt: DateTime.now(),
            metadata: {
              'autoGenerated': true,
              'availableBetTypes': {
                'moneyline': oddsAvailable['moneyline'] ?? false,
                'spread': oddsAvailable['spread'] ?? false,
                'total': oddsAvailable['total'] ?? false,
              },
              'requiresOdds': true,
            },
          );

          final docRef = _firestore.collection('pools').doc();
          batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
        } else {
          // Keep old behavior for other sports temporarily
          // Create Moneyline pool if odds available
          if (oddsAvailable['moneyline'] == true) {
            final pool = Pool(
              id: '',
              gameId: game.id,
              gameTitle: game.gameTitle,
              sport: game.sport,
              type: PoolType.quick,
              status: PoolStatus.open,
              name: 'Pick Winner - $buyIn BR',
              buyIn: buyIn,
              minPlayers: 2,
              maxPlayers: buyIn <= 25 ? 50 : 20,
              currentPlayers: 0,
              playerIds: [],
              startTime: game.gameTime,
              closeTime: game.gameTime.subtract(const Duration(minutes: 15)),
              prizePool: 0,
              prizeStructure: _getQuickPlayPrizeStructure(20),
              tier: _getTierFromBuyIn(buyIn),
              createdAt: DateTime.now(),
              metadata: {
                'autoGenerated': true,
                'betType': 'moneyline',
                'requiresOdds': 'moneyline',
              },
            );

            final docRef = _firestore.collection('pools').doc();
            batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
          }

          // Create Spread pool if odds available
          if (oddsAvailable['spread'] == true) {
            final pool = Pool(
              id: '',
              gameId: game.id,
              gameTitle: game.gameTitle,
              sport: game.sport,
              type: PoolType.quick,
              status: PoolStatus.open,
              name: 'Against Spread - $buyIn BR',
              buyIn: buyIn,
              minPlayers: 2,
              maxPlayers: buyIn <= 25 ? 40 : 15,
              currentPlayers: 0,
              playerIds: [],
              startTime: game.gameTime,
              closeTime: game.gameTime.subtract(const Duration(minutes: 15)),
              prizePool: 0,
              prizeStructure: _getQuickPlayPrizeStructure(15),
              tier: _getTierFromBuyIn(buyIn),
              createdAt: DateTime.now(),
              metadata: {
                'autoGenerated': true,
                'betType': 'spread',
                'requiresOdds': 'spread',
              },
            );

            final docRef = _firestore.collection('pools').doc();
            batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
          }

          // Create Over/Under pool if odds available
          if (oddsAvailable['total'] == true && buyIn <= 50) { // Limit O/U pools to lower stakes
            final pool = Pool(
              id: '',
              gameId: game.id,
              gameTitle: game.gameTitle,
              sport: game.sport,
              type: PoolType.quick,
              status: PoolStatus.open,
              name: 'Over/Under - $buyIn BR',
              buyIn: buyIn,
              minPlayers: 2,
              maxPlayers: 30,
              currentPlayers: 0,
              playerIds: [],
              startTime: game.gameTime,
              closeTime: game.gameTime.subtract(const Duration(minutes: 15)),
              prizePool: 0,
              prizeStructure: _getQuickPlayPrizeStructure(30),
              tier: _getTierFromBuyIn(buyIn),
              createdAt: DateTime.now(),
              metadata: {
                'autoGenerated': true,
                'betType': 'total',
                'requiresOdds': 'total',
              },
            );

            final docRef = _firestore.collection('pools').doc();
            batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
          }
        } // End else (other sports)
      } // End for loop
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error generating game pools: $e');
    }
  }
  
  /// Get prize structure for Quick Play (100% payout)
  Map<String, int> _getQuickPlayPrizeStructure(int maxPlayers) {
    if (maxPlayers <= 10) {
      return {
        '1': 50,  // 50% to 1st
        '2': 30,  // 30% to 2nd
        '3': 20,  // 20% to 3rd
      };
    } else if (maxPlayers <= 30) {
      return {
        '1': 35,
        '2': 25,
        '3': 15,
        '4': 10,
        '5': 8,
        '6': 7,
      };
    } else {
      return {
        '1': 30,
        '2': 20,
        '3': 15,
        '4': 10,
        '5': 8,
        '6': 6,
        '7': 5,
        '8': 3,
        '9': 2,
        '10': 1,
      };
    }
  }
  
  /// Get prize structure for Regional pools
  Map<String, int> _getRegionalPrizeStructure() {
    return {
      '1': 40,
      '2': 25,
      '3': 15,
      '4': 10,
      '5': 10,
    };
  }
  
  /// Get prize structure for Tournament pools
  Map<String, int> _getTournamentPrizeStructure() {
    return {
      '1': 50,
      '2': 30,
      '3': 20,
    };
  }
  
  /// Get tier from buy-in amount
  PoolTier _getTierFromBuyIn(int buyIn) {
    if (buyIn <= 10) return PoolTier.beginner;
    if (buyIn <= 25) return PoolTier.standard;
    if (buyIn <= 50) return PoolTier.high;
    return PoolTier.vip;
  }
  
  /// Get regional level from string
  RegionalLevel _getRegionalLevel(String level) {
    switch (level) {
      case 'neighborhood':
        return RegionalLevel.neighborhood;
      case 'city':
        return RegionalLevel.city;
      case 'state':
        return RegionalLevel.state;
      case 'national':
        return RegionalLevel.national;
      default:
        return RegionalLevel.city;
    }
  }
  
  /// Check and generate pools for upcoming events
  Future<void> checkAndGenerateUpcomingPools() async {
    try {
      // Get events in next 3 weeks without pools
      final now = DateTime.now();
      final threeWeeksFromNow = now.add(const Duration(days: 21));
      
      // Check UFC/MMA events
      final mmaEvents = await _firestore
          .collection('events')
          .where('sport', isEqualTo: 'MMA')
          .where('gameTime', isGreaterThan: Timestamp.fromDate(now))
          .where('gameTime', isLessThan: Timestamp.fromDate(threeWeeksFromNow))
          .get();
      
      for (final doc in mmaEvents.docs) {
        final event = FightCardEventModel.fromFirestore(doc);
        await generateFightCardPools(event: event);
      }
      
      // Check regular games
      final games = await _firestore
          .collection('games')
          .where('gameTime', isGreaterThan: Timestamp.fromDate(now))
          .where('gameTime', isLessThan: Timestamp.fromDate(threeWeeksFromNow))
          .limit(100)  // Increased limit for 3 weeks of games
          .get();
      
      for (final doc in games.docs) {
        final game = GameModel.fromFirestore(doc);
        await generateGamePools(game: game);
      }
      
    } catch (e) {
      debugPrint('Error checking upcoming events: $e');
    }
  }
}

/// Pool seeding service for testing
class PoolSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Add mock players to pools for testing
  Future<void> seedPoolWithMockPlayers({
    required String poolId,
    required int playerCount,
  }) async {
    try {
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();
      if (!poolDoc.exists) return;
      
      final pool = Pool.fromFirestore(poolDoc);
      
      // Generate mock player IDs
      final mockPlayerIds = List.generate(
        playerCount,
        (i) => 'mock_player_${i + 1}',
      );
      
      // Update pool
      await _firestore.collection('pools').doc(poolId).update({
        'currentPlayers': playerCount,
        'playerIds': mockPlayerIds,
        'prizePool': pool.buyIn * playerCount,
      });
      
      debugPrint('Seeded pool $poolId with $playerCount mock players');
    } catch (e) {
      debugPrint('Error seeding pool: $e');
    }
  }
}