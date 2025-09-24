import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state_model.dart';
import 'event_splitter_service.dart';
import 'enhanced_espn_service.dart';
import 'game_state_controller.dart';
import 'pool_service.dart';
import 'wallet_service.dart';

// Monitors multiple competitions within a single event
class MultiCompetitionMonitor {
  static MultiCompetitionMonitor? _instance;
  factory MultiCompetitionMonitor() {
    _instance ??= MultiCompetitionMonitor._internal();
    return _instance!;
  }
  MultiCompetitionMonitor._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventSplitterService _splitter = EventSplitterService();
  final EnhancedESPNService _espnService = EnhancedESPNService();
  final GameStateController _stateController = GameStateController();
  final PoolService _poolService = PoolService();
  final WalletService _walletService = WalletService();

  // Active event monitors
  final Map<String, Timer> _eventMonitors = {};
  final Map<String, List<Competition>> _eventCompetitions = {};
  final Map<String, StreamController<List<Competition>>> _eventStreams = {};

  // Monitor a UFC event with all its fights
  Stream<List<UFCFight>> monitorUFCEvent(String eventId) async* {
    print('Starting UFC event monitoring for: $eventId');
    
    // Initial fetch
    final fights = await _splitter.parseUFCEvent(eventId);
    yield fights;
    
    // Create pools for each fight if they don't exist
    await _createFightPools(eventId, fights);
    
    // Set up periodic monitoring
    final controller = StreamController<List<UFCFight>>.broadcast();
    
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final updatedFights = await _splitter.parseUFCEvent(eventId);
        
        // Check for changes
        if (_hasChanges(fights, updatedFights)) {
          controller.add(updatedFights);
          
          // Process individual fight updates
          for (final fight in updatedFights) {
            await _processFightUpdate(fight);
          }
        }
      } catch (e) {
        print('Error monitoring UFC event $eventId: $e');
      }
    });
    
    _eventMonitors[eventId] = timer;
    
    // Yield stream updates
    yield* controller.stream;
  }

  // Monitor a tennis tournament with all its matches
  Stream<List<TennisMatch>> monitorTennisTournament(String tournamentId) async* {
    print('Starting tennis tournament monitoring for: $tournamentId');
    
    // Initial fetch
    final matches = await _splitter.parseTennisTournament(tournamentId);
    yield matches;
    
    // Create pools for each match if they don't exist
    await _createMatchPools(tournamentId, matches);
    
    // Set up periodic monitoring
    final controller = StreamController<List<TennisMatch>>.broadcast();
    
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        final updatedMatches = await _splitter.parseTennisTournament(tournamentId);
        
        // Check for changes
        if (_hasChanges(matches, updatedMatches)) {
          controller.add(updatedMatches);
          
          // Process individual match updates
          for (final match in updatedMatches) {
            await _processMatchUpdate(match);
          }
        }
      } catch (e) {
        print('Error monitoring tennis tournament $tournamentId: $e');
      }
    });
    
    _eventMonitors[tournamentId] = timer;
    
    // Yield stream updates
    yield* controller.stream;
  }

  // Create pools for UFC fights
  Future<void> _createFightPools(String eventId, List<UFCFight> fights) async {
    for (final fight in fights) {
      // Check if pool already exists
      final existingPool = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: fight.id)
          .limit(1)
          .get();
      
      if (existingPool.docs.isEmpty) {
        // Create pool for this fight
        await _createFightPool(eventId, fight);
      }
    }
  }

  // Create individual fight pool
  Future<String?> _createFightPool(String eventId, UFCFight fight) async {
    try {
      // Determine buy-in based on fight importance
      int buyIn = 25; // Default
      if (fight.isMainEvent) {
        buyIn = 100;
      } else if (fight.isTitleFight) {
        buyIn = 75;
      }
      
      // Create the pool
      final poolId = await _poolService.createPool(
        gameId: fight.id,
        gameTitle: fight.title,
        sport: 'UFC',
        type: PoolType.quick,
        name: '${fight.title} - ${fight.weightClass}',
        buyIn: buyIn,
        maxPlayers: fight.isMainEvent ? 100 : 50,
        minPlayers: 2,
        prizeStructure: _calculateFightPrizeStructure(buyIn, fight.isMainEvent),
      );
      
      if (poolId != null) {
        // Save fight details to database
        await _firestore
            .collection('ufc_events')
            .doc(eventId)
            .collection('fights')
            .doc(fight.id)
            .set({
          'eventId': eventId,
          'fightId': fight.id,
          'fighter1': fight.fighter1,
          'fighter2': fight.fighter2,
          'weightClass': fight.weightClass,
          'scheduledRounds': fight.scheduledRounds,
          'isMainEvent': fight.isMainEvent,
          'isTitleFight': fight.isTitleFight,
          'poolId': poolId,
          'startTime': Timestamp.fromDate(fight.startTime),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('Created pool for fight: ${fight.title} (Pool ID: $poolId)');
      }
      
      return poolId;
    } catch (e) {
      print('Error creating fight pool: $e');
      return null;
    }
  }

  // Create pools for tennis matches
  Future<void> _createMatchPools(String tournamentId, List<TennisMatch> matches) async {
    for (final match in matches) {
      // Check if pool already exists
      final existingPool = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: match.id)
          .limit(1)
          .get();
      
      if (existingPool.docs.isEmpty) {
        // Create pool for this match
        await _createMatchPool(tournamentId, match);
      }
    }
  }

  // Create individual tennis match pool
  Future<String?> _createMatchPool(String tournamentId, TennisMatch match) async {
    try {
      // Determine buy-in based on round
      int buyIn = 25; // Default
      if (match.round.contains('Final')) {
        buyIn = 100;
      } else if (match.round.contains('Semi')) {
        buyIn = 75;
      } else if (match.round.contains('Quarter')) {
        buyIn = 50;
      }
      
      // Create the pool
      final poolId = await _poolService.createPool(
        gameId: match.id,
        gameTitle: match.title,
        sport: 'Tennis',
        type: PoolType.quick,
        name: '${match.title} - ${match.round}',
        buyIn: buyIn,
        maxPlayers: 50,
        minPlayers: 2,
      );
      
      if (poolId != null) {
        // Save match details to database
        await _firestore
            .collection('tennis_tournaments')
            .doc(tournamentId)
            .collection('matches')
            .doc(match.id)
            .set({
          'tournamentId': tournamentId,
          'matchId': match.id,
          'player1': match.player1,
          'player2': match.player2,
          'round': match.round,
          'surface': match.surface,
          'setsToWin': match.setsToWin,
          'poolId': poolId,
          'startTime': Timestamp.fromDate(match.startTime),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('Created pool for match: ${match.title} (Pool ID: $poolId)');
      }
      
      return poolId;
    } catch (e) {
      print('Error creating match pool: $e');
      return null;
    }
  }

  // Process UFC fight update
  Future<void> _processFightUpdate(UFCFight fight) async {
    try {
      // Convert to game state
      final state = _convertFightToGameState(fight);
      
      // Save state to Firestore
      await _firestore
          .collection('games')
          .doc(fight.id)
          .collection('states')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set(state.toFirestore());
      
      // Check for round transitions
      if (fight.status == CompetitionStatus.live && fight.currentRound != null) {
        // Check if we're between rounds
        if (fight.roundTime == '0:00' || fight.roundTime == '5:00') {
          print('Round break detected for ${fight.title}');
          // Trigger 60-second card window
          _triggerRoundBreakWindow(fight);
        }
      }
      
      // Check for fight completion
      if (fight.status == CompetitionStatus.final && fight.result != null) {
        print('Fight completed: ${fight.title}');
        print('Winner: ${fight.result!.winner} by ${fight.result!.method}');
        await _settleFightPool(fight);
      }
    } catch (e) {
      print('Error processing fight update: $e');
    }
  }

  // Process tennis match update
  Future<void> _processMatchUpdate(TennisMatch match) async {
    try {
      // Convert to game state
      final state = _convertMatchToGameState(match);
      
      // Save state to Firestore
      await _firestore
          .collection('games')
          .doc(match.id)
          .collection('states')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set(state.toFirestore());
      
      // Check for set breaks
      if (match.status == CompetitionStatus.live && match.sets != null) {
        // Check if we're between sets
        final lastSet = match.sets!.lastOrNull;
        if (lastSet != null && lastSet.isComplete) {
          print('Set break detected for ${match.title}');
          // Trigger 120-second card window
          _triggerSetBreakWindow(match);
        }
      }
      
      // Check for match completion
      if (match.status == CompetitionStatus.final && match.result != null) {
        print('Match completed: ${match.title}');
        print('Winner: ${match.result!.winner} - ${match.result!.score}');
        
        // Handle retirements/walkovers
        if (match.result!.isRetirement || match.result!.isWalkover) {
          await _refundMatchPool(match, 'Match ended by retirement/walkover');
        } else {
          await _settleMatchPool(match);
        }
      }
    } catch (e) {
      print('Error processing match update: $e');
    }
  }

  // Convert UFC fight to game state
  GameState _convertFightToGameState(UFCFight fight) {
    return UFCFightState(
      gameId: fight.id,
      status: _mapCompetitionStatus(fight.status),
      eventId: fight.eventId,
      fightId: fight.id,
      fighters: [fight.fighter1, fight.fighter2],
      weightClass: fight.weightClass,
      isMainEvent: fight.isMainEvent,
      scheduledRounds: fight.scheduledRounds,
      round: fight.currentRound,
      roundTime: fight.roundTime,
      score: {
        'fighter1': 0, // TODO: Get actual scores from judges
        'fighter2': 0,
      },
      lastUpdate: DateTime.now(),
    );
  }

  // Convert tennis match to game state
  GameState _convertMatchToGameState(TennisMatch match) {
    return TennisMatchState(
      gameId: match.id,
      status: _mapCompetitionStatus(match.status),
      players: [match.player1, match.player2],
      setsToWin: match.setsToWin,
      sets: match.sets ?? [],
      server: match.currentServer,
      isSetPoint: false, // TODO: Calculate from game score
      isMatchPoint: false, // TODO: Calculate from set score
      isTiebreak: false, // TODO: Determine from game score
      lastUpdate: DateTime.now(),
    );
  }

  // Map competition status to game status
  GameStatus _mapCompetitionStatus(CompetitionStatus status) {
    switch (status) {
      case CompetitionStatus.scheduled:
        return GameStatus.scheduled;
      case CompetitionStatus.live:
        return GameStatus.live;
      case CompetitionStatus.final:
        return GameStatus.final;
      case CompetitionStatus.cancelled:
        return GameStatus.cancelled;
    }
  }

  // Trigger round break card window
  void _triggerRoundBreakWindow(UFCFight fight) {
    // Use the game state controller to open a card window
    // This would trigger the 60-second window for cards
    print('Opening 60-second card window for round break: ${fight.title}');
  }

  // Trigger set break card window
  void _triggerSetBreakWindow(TennisMatch match) {
    // Use the game state controller to open a card window
    // This would trigger the 120-second window for cards
    print('Opening 120-second card window for set break: ${match.title}');
  }

  // Settle fight pool
  Future<void> _settleFightPool(UFCFight fight) async {
    if (fight.result == null) return;
    
    try {
      // Get pool for this fight
      final poolQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: fight.id)
          .limit(1)
          .get();
      
      if (poolQuery.docs.isEmpty) return;
      
      final poolId = poolQuery.docs.first.id;
      
      // Get all bets for this pool
      final betsQuery = await _firestore
          .collection('wagers')
          .where('poolId', isEqualTo: poolId)
          .get();
      
      // Determine winners (those who picked the winning fighter)
      final winners = <String>[];
      final losers = <String>[];
      
      for (final betDoc in betsQuery.docs) {
        final bet = betDoc.data();
        if (bet['selection'] == fight.result!.winner) {
          winners.add(bet['userId']);
        } else {
          losers.add(bet['userId']);
        }
      }
      
      // Calculate and distribute winnings
      if (winners.isNotEmpty) {
        final pool = poolQuery.docs.first.data();
        final totalPot = pool['prizePool'] ?? 0;
        final buyIn = pool['buyIn'] ?? 0;
        final winnerShare = totalPot ~/ winners.length;

        for (final winnerId in winners) {
          // Add BR winnings to wallet
          await _walletService.addToWallet(
            winnerId,
            winnerShare,
            'Fight pool winnings: ${fight.title}',
            metadata: {
              'poolId': poolId,
              'fightId': fight.id,
              'fightTitle': fight.title,
            },
          );

          // Process Victory Coins for MMA picks
          // For fight pools, award VC based on winning
          await _walletService.processMMAPicks(
            brWagered: buyIn,
            correctPicks: 1,  // They picked the winner
            totalFights: 1,    // Single fight pool
            eventId: fight.id,
            eventName: fight.title,
          );

          print('Paid out $winnerShare BR + Victory Coins to winner: $winnerId');
        }
      }
      
      // Update pool status
      await poolQuery.docs.first.reference.update({
        'status': 'settled',
        'settledAt': FieldValue.serverTimestamp(),
        'result': {
          'winner': fight.result!.winner,
          'method': fight.result!.method,
          'round': fight.result!.round,
          'time': fight.result!.time,
        },
      });
      
      print('Pool settled for fight: ${fight.title}');
    } catch (e) {
      print('Error settling fight pool: $e');
    }
  }

  // Settle tennis match pool
  Future<void> _settleMatchPool(TennisMatch match) async {
    if (match.result == null) return;
    
    try {
      // Similar to fight pool settlement
      // Get pool, determine winners, distribute prizes
      print('Settling pool for match: ${match.title}');
    } catch (e) {
      print('Error settling match pool: $e');
    }
  }

  // Refund match pool (for retirements/walkovers)
  Future<void> _refundMatchPool(TennisMatch match, String reason) async {
    try {
      // Get pool for this match
      final poolQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: match.id)
          .limit(1)
          .get();
      
      if (poolQuery.docs.isEmpty) return;
      
      final poolId = poolQuery.docs.first.id;
      final pool = poolQuery.docs.first.data();
      
      // Get all participants
      final participants = List<String>.from(pool['playerIds'] ?? []);
      final buyIn = pool['buyIn'] ?? 0;
      
      // Refund all participants
      for (final userId in participants) {
        // Refund BR to wallet (no VC since no win occurred)
        await _walletService.addToWallet(
          userId,
          buyIn,
          'Pool refund: $reason',
          metadata: {
            'poolId': poolId,
            'matchId': match.id,
            'reason': reason,
          },
        );
        print('Refunded $buyIn BR to user: $userId (Reason: $reason)');
      }
      
      // Update pool status
      await poolQuery.docs.first.reference.update({
        'status': 'refunded',
        'refundedAt': FieldValue.serverTimestamp(),
        'refundReason': reason,
      });
      
      print('Pool refunded for match: ${match.title}');
    } catch (e) {
      print('Error refunding match pool: $e');
    }
  }

  // Calculate prize structure for fights
  Map<String, dynamic> _calculateFightPrizeStructure(int buyIn, bool isMainEvent) {
    final totalPot = buyIn * (isMainEvent ? 100 : 50); // Estimated max players
    
    if (isMainEvent) {
      // Main event: 60/25/15 split
      return {
        '1st': (totalPot * 0.6).round(),
        '2nd': (totalPot * 0.25).round(),
        '3rd': (totalPot * 0.15).round(),
      };
    } else {
      // Regular fight: 70/30 split
      return {
        '1st': (totalPot * 0.7).round(),
        '2nd': (totalPot * 0.3).round(),
      };
    }
  }

  // Check if competitions have changed
  bool _hasChanges(List<Competition> old, List<Competition> updated) {
    if (old.length != updated.length) return true;
    
    for (int i = 0; i < old.length; i++) {
      if (old[i].status != updated[i].status) return true;
      
      // Check specific changes for each type
      if (old[i] is UFCFight && updated[i] is UFCFight) {
        final oldFight = old[i] as UFCFight;
        final newFight = updated[i] as UFCFight;
        if (oldFight.currentRound != newFight.currentRound ||
            oldFight.roundTime != newFight.roundTime ||
            oldFight.result != newFight.result) {
          return true;
        }
      }
      
      if (old[i] is TennisMatch && updated[i] is TennisMatch) {
        final oldMatch = old[i] as TennisMatch;
        final newMatch = updated[i] as TennisMatch;
        if (oldMatch.sets?.length != newMatch.sets?.length ||
            oldMatch.result != newMatch.result) {
          return true;
        }
      }
    }
    
    return false;
  }

  // Stop monitoring an event
  void stopMonitoring(String eventId) {
    _eventMonitors[eventId]?.cancel();
    _eventMonitors.remove(eventId);
    _eventStreams[eventId]?.close();
    _eventStreams.remove(eventId);
    _eventCompetitions.remove(eventId);
  }

  // Dispose all monitors
  void dispose() {
    for (final timer in _eventMonitors.values) {
      timer.cancel();
    }
    _eventMonitors.clear();
    
    for (final stream in _eventStreams.values) {
      stream.close();
    }
    _eventStreams.clear();
    
    _eventCompetitions.clear();
  }
}