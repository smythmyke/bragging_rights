import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/fight_card_model.dart';
import '../models/fight_pool_rules.dart';
import '../models/fight_card_scoring.dart';
import 'fight_odds_service.dart';
import 'pool_auto_generator.dart';

/// Service for managing fight card events and picks
class FightCardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FightOddsService _oddsService = FightOddsService();
  final PoolAutoGenerator _poolGenerator = PoolAutoGenerator();
  
  /// Get upcoming fight card events
  Future<List<FightCardEventModel>> getUpcomingEvents({
    String? promotion,
    int limit = 20,
  }) async {
    try {
      var query = _firestore
          .collection('events')
          .where('sport', isEqualTo: 'MMA')
          .where('gameTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('gameTime');
      
      if (promotion != null) {
        query = query.where('promotion', isEqualTo: promotion);
      }
      
      final results = await query.limit(limit).get();
      
      final events = results.docs
          .map((doc) => FightCardEventModel.fromFirestore(doc))
          .toList();
      
      // Auto-generate pools for events without them
      for (final event in events) {
        await _poolGenerator.generateFightCardPools(event: event);
      }
      
      return events;
    } catch (e) {
      debugPrint('Error getting upcoming events: $e');
      return [];
    }
  }
  
  /// Get a specific fight card event
  Future<FightCardEventModel?> getEvent(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      
      if (doc.exists) {
        return FightCardEventModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }
  
  /// Get live fight card events
  Future<List<FightCardEventModel>> getLiveEvents() async {
    try {
      final now = DateTime.now();
      final threeHoursAgo = now.subtract(const Duration(hours: 3));
      
      final results = await _firestore
          .collection('events')
          .where('sport', isEqualTo: 'MMA')
          .where('gameTime', isGreaterThan: Timestamp.fromDate(threeHoursAgo))
          .where('gameTime', isLessThan: Timestamp.fromDate(now))
          .where('status', isEqualTo: 'live')
          .get();
      
      return results.docs
          .map((doc) => FightCardEventModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting live events: $e');
      return [];
    }
  }
  
  /// Submit user picks for a fight card pool
  Future<void> submitPicks({
    required String userId,
    required String poolId,
    required String eventId,
    required List<FightPick> picks,
  }) async {
    try {
      // Validate event exists
      final event = await getEvent(eventId);
      if (event == null) {
        throw Exception('Event not found');
      }
      
      // Get pool rules
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();
      if (!poolDoc.exists) {
        throw Exception('Pool not found');
      }
      
      final poolData = poolDoc.data()!;
      final rules = FightPoolRules(
        requireAllFights: poolData['requireAllFights'] ?? false,
        allowSkipPrelims: poolData['allowSkipPrelims'] ?? true,
        allowLatePicks: poolData['allowLatePicks'] ?? false,
        allowMethodBetting: poolData['allowMethodBetting'] ?? true,
        allowRoundBetting: poolData['allowRoundBetting'] ?? true,
        confidenceEnabled: poolData['confidenceEnabled'] ?? true,
        maxConfidenceStars: poolData['maxConfidenceStars'] ?? 5,
      );
      
      // Validate picks meet requirements
      final validationResult = rules.validatePicks(
        picks: picks,
        fights: event.fights,
        submissionTime: DateTime.now(),
        eventTime: event.gameTime,
      );
      
      if (!validationResult.isValid) {
        throw Exception(validationResult.errors.join(', '));
      }
      
      // Save picks to Firestore
      final batch = _firestore.batch();
      
      for (final pick in picks) {
        final pickDoc = _firestore.collection('fight_picks').doc();
        batch.set(pickDoc, pick.copyWith(id: pickDoc.id).toFirestore());
      }
      
      // Update user's pool entry
      batch.update(
        _firestore.collection('pool_entries').doc('${poolId}_$userId'),
        {
          'picksSubmitted': true,
          'submittedAt': Timestamp.fromDate(DateTime.now()),
          'pickIds': picks.map((p) => p.id).toList(),
        },
      );
      
      await batch.commit();
      
      debugPrint('Picks submitted for user $userId in pool $poolId');
    } catch (e) {
      debugPrint('Error submitting picks: $e');
      rethrow;
    }
  }
  
  /// Get user's picks for a pool
  Future<List<FightPick>> getUserPicks({
    required String userId,
    required String poolId,
  }) async {
    try {
      final results = await _firestore
          .collection('fight_picks')
          .where('userId', isEqualTo: userId)
          .where('poolId', isEqualTo: poolId)
          .get();
      
      return results.docs
          .map((doc) => FightPick.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user picks: $e');
      return [];
    }
  }
  
  /// Update fight results (admin function)
  Future<void> updateFightResult({
    required String eventId,
    required String fightId,
    required String winnerId,
    String? method,
    int? winRound,
  }) async {
    try {
      // Get the event
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }
      
      final event = FightCardEventModel.fromFirestore(eventDoc);
      
      // Find and update the fight
      final updatedFights = event.fights.map((fight) {
        if (fight.id == fightId) {
          return fight.copyWith(
            winnerId: winnerId,
            method: method,
            winRound: winRound,
            status: 'completed',
          );
        }
        return fight;
      }).toList();
      
      // Update event with new fight data
      await _firestore.collection('events').doc(eventId).update({
        'fights': updatedFights.map((f) => f.toFirestore()).toList(),
      });
      
      // Check if all fights are complete
      final allComplete = updatedFights.every((f) => f.status == 'completed');
      
      if (allComplete) {
        await _processEventCompletion(eventId);
      }
      
      debugPrint('Fight result updated: $fightId');
    } catch (e) {
      debugPrint('Error updating fight result: $e');
      rethrow;
    }
  }
  
  /// Process event completion and calculate payouts
  Future<void> _processEventCompletion(String eventId) async {
    try {
      // Get the completed event
      final event = await getEvent(eventId);
      if (event == null) return;
      
      // Get all pools for this event
      final poolsQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: eventId)
          .get();
      
      // Get odds for scoring
      final odds = await _oddsService.getFightCardOdds(event: event);
      
      for (final poolDoc in poolsQuery.docs) {
        await _processPoolResults(
          poolId: poolDoc.id,
          event: event,
          odds: odds,
        );
      }
      
      // Update event status
      await _firestore.collection('events').doc(eventId).update({
        'status': 'completed',
        'completedAt': Timestamp.fromDate(DateTime.now()),
      });
      
    } catch (e) {
      debugPrint('Error processing event completion: $e');
    }
  }
  
  /// Process results for a specific pool
  Future<void> _processPoolResults({
    required String poolId,
    required FightCardEventModel event,
    required Map<String, FightOdds> odds,
  }) async {
    try {
      // Get all entries for this pool
      final entriesQuery = await _firestore
          .collection('pool_entries')
          .where('poolId', isEqualTo: poolId)
          .where('picksSubmitted', isEqualTo: true)
          .get();
      
      final userScores = <UserScore>[];
      
      // Calculate scores for each user
      for (final entryDoc in entriesQuery.docs) {
        final entryData = entryDoc.data();
        final userId = entryData['userId'] as String;
        final username = entryData['username'] as String;
        final pickIds = List<String>.from(entryData['pickIds'] ?? []);
        
        // Get user's picks
        final picks = <FightPick>[];
        for (final pickId in pickIds) {
          final pickDoc = await _firestore
              .collection('fight_picks')
              .doc(pickId)
              .get();
          
          if (pickDoc.exists) {
            picks.add(FightPick.fromFirestore(pickDoc));
          }
        }
        
        // Calculate score
        final score = FightCardScoring.calculateUserScore(
          picks: picks,
          results: event.fights,
          odds: odds,
        );
        
        // Count correct picks and underdog wins
        int correctPicks = 0;
        int underdogWins = 0;
        
        for (final pick in picks) {
          final fight = event.fights.firstWhere(
            (f) => f.id == pick.fightId,
            orElse: () => event.fights.first,
          );
          
          if (pick.winnerId == fight.winnerId) {
            correctPicks++;
            
            // Check if underdog
            final fightOdds = odds[fight.id];
            if (fightOdds != null) {
              final pickedOdds = pick.winnerId == fight.fighter1Id
                  ? fightOdds.fighter1Odds
                  : fightOdds.fighter2Odds;
              
              if (pickedOdds > 0) {
                underdogWins++;
              }
            }
          }
        }
        
        userScores.add(UserScore(
          userId: userId,
          username: username,
          score: score,
          correctPicks: correctPicks,
          totalPicks: picks.length,
          underdogWins: underdogWins,
        ));
      }
      
      // Sort by score
      userScores.sort((a, b) => b.score.compareTo(a.score));
      
      // Get pool data
      final poolDoc = await _firestore.collection('pools').doc(poolId).get();
      final poolData = poolDoc.data()!;
      final totalPool = poolData['prizePool'] as int;
      
      // Determine payout structure
      final structure = _getPayoutStructure(poolData['type'] as String);
      
      // Calculate payouts (100% distribution, no house cut)
      final payouts = FightCardScoring.distributePrizePool(
        rankings: userScores,
        totalPool: totalPool,
        structure: structure,
      );
      
      // Save results and pay out winners
      final batch = _firestore.batch();
      
      // Create pool result document
      batch.set(
        _firestore.collection('pool_results').doc(poolId),
        {
          'poolId': poolId,
          'eventId': event.id,
          'eventName': event.eventName,
          'completedAt': Timestamp.fromDate(DateTime.now()),
          'totalPool': totalPool,
          'totalPlayers': userScores.length,
          'rankings': userScores.map((s) => {
            'userId': s.userId,
            'username': s.username,
            'score': s.score,
            'correctPicks': s.correctPicks,
            'totalPicks': s.totalPicks,
            'underdogWins': s.underdogWins,
            'payout': payouts[s.userId] ?? 0,
          }).toList(),
        },
      );
      
      // Update user balances
      payouts.forEach((userId, amount) {
        // This would update user's BR balance
        debugPrint('Paying $amount BR to user $userId');
      });
      
      // Update pool status
      batch.update(
        _firestore.collection('pools').doc(poolId),
        {
          'status': 'completed',
          'completedAt': Timestamp.fromDate(DateTime.now()),
        },
      );
      
      await batch.commit();
      
      debugPrint('Pool $poolId results processed');
    } catch (e) {
      debugPrint('Error processing pool results: $e');
    }
  }
  
  /// Get payout structure based on pool type
  PoolPayoutStructure _getPayoutStructure(String poolType) {
    switch (poolType) {
      case 'quick':
        return PoolPayoutStructure.quickPlay;
      case 'tournament':
        return PoolPayoutStructure.tournament;
      case 'winner_take_all':
        return PoolPayoutStructure.winnerTakeAll;
      case 'top3':
        return PoolPayoutStructure.top3;
      default:
        return PoolPayoutStructure.quickPlay;
    }
  }
  
  /// Get pool leaderboard
  Future<List<UserScore>> getPoolLeaderboard({
    required String poolId,
    required String eventId,
  }) async {
    try {
      // Check if results exist
      final resultDoc = await _firestore
          .collection('pool_results')
          .doc(poolId)
          .get();
      
      if (resultDoc.exists) {
        // Return completed results
        final data = resultDoc.data()!;
        final rankings = List<Map<String, dynamic>>.from(data['rankings'] ?? []);
        
        return rankings.map((r) => UserScore(
          userId: r['userId'],
          username: r['username'],
          score: (r['score'] as num).toDouble(),
          correctPicks: r['correctPicks'],
          totalPicks: r['totalPicks'],
          underdogWins: r['underdogWins'],
        )).toList();
      }
      
      // Calculate live leaderboard
      final event = await getEvent(eventId);
      if (event == null) return [];
      
      final odds = await _oddsService.getFightCardOdds(event: event);
      
      // Get all entries
      final entriesQuery = await _firestore
          .collection('pool_entries')
          .where('poolId', isEqualTo: poolId)
          .where('picksSubmitted', isEqualTo: true)
          .get();
      
      final userScores = <UserScore>[];
      
      for (final entryDoc in entriesQuery.docs) {
        // Similar scoring logic as _processPoolResults
        // ... (implementation similar to above)
      }
      
      userScores.sort((a, b) => b.score.compareTo(a.score));
      return userScores;
      
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }
  
  /// Stream live updates for an event
  Stream<FightCardEventModel?> streamEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((snap) {
          if (snap.exists) {
            return FightCardEventModel.fromFirestore(snap);
          }
          return null;
        });
  }
  
  /// Get user's fight card history
  Future<List<Map<String, dynamic>>> getUserFightHistory({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final results = await _firestore
          .collection('pool_entries')
          .where('userId', isEqualTo: userId)
          .where('picksSubmitted', isEqualTo: true)
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get();
      
      final history = <Map<String, dynamic>>[];
      
      for (final doc in results.docs) {
        final data = doc.data();
        
        // Get pool info
        final poolDoc = await _firestore
            .collection('pools')
            .doc(data['poolId'])
            .get();
        
        if (poolDoc.exists) {
          final poolData = poolDoc.data()!;
          
          // Check for results
          final resultDoc = await _firestore
              .collection('pool_results')
              .doc(data['poolId'])
              .get();
          
          Map<String, dynamic>? result;
          if (resultDoc.exists) {
            final resultData = resultDoc.data()!;
            final rankings = List<Map<String, dynamic>>.from(
              resultData['rankings'] ?? [],
            );
            
            // Find user's result
            final userResult = rankings.firstWhere(
              (r) => r['userId'] == userId,
              orElse: () => {},
            );
            
            if (userResult.isNotEmpty) {
              result = {
                'position': rankings.indexOf(userResult) + 1,
                'totalPlayers': rankings.length,
                'score': userResult['score'],
                'payout': userResult['payout'],
                'correctPicks': userResult['correctPicks'],
                'totalPicks': userResult['totalPicks'],
              };
            }
          }
          
          history.add({
            'poolId': data['poolId'],
            'poolName': poolData['name'],
            'eventName': poolData['gameTitle'],
            'entryFee': poolData['buyIn'],
            'submittedAt': (data['submittedAt'] as Timestamp).toDate(),
            'result': result,
          });
        }
      }
      
      return history;
    } catch (e) {
      debugPrint('Error getting user history: $e');
      return [];
    }
  }
}