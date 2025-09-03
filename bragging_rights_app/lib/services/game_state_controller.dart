import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_state_model.dart';
import '../services/enhanced_espn_service.dart';
import '../services/card_service.dart';
import '../services/pool_service.dart';

class CardWindow {
  final String gameId;
  final List<String> cardTypes;
  final DateTime opensAt;
  final DateTime closesAt;
  final String trigger;
  final SportType sport;

  CardWindow({
    required this.gameId,
    required this.cardTypes,
    required this.opensAt,
    required this.closesAt,
    required this.trigger,
    required this.sport,
  });

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(closesAt)) {
      return Duration.zero;
    }
    return closesAt.difference(now);
  }

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(opensAt) && now.isBefore(closesAt);
  }
}

class GameStateController {
  static GameStateController? _instance;
  factory GameStateController() {
    _instance ??= GameStateController._internal();
    return _instance!;
  }
  GameStateController._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EnhancedESPNService _espnService = EnhancedESPNService();
  final CardService _cardService = CardService();
  final PoolService _poolService = PoolService();

  // Active game subscriptions
  final Map<String, StreamSubscription<GameState>> _subscriptions = {};
  final Map<String, StreamController<GameState>> _stateStreams = {};
  
  // Card windows
  final Map<String, CardWindow> _activeWindows = {};
  final Map<String, Timer> _windowTimers = {};
  
  // State change listeners
  final List<Function(String gameId, GameState state)> _stateListeners = [];
  final List<Function(String gameId, CardWindow window)> _windowListeners = [];

  // Start monitoring a game
  Stream<GameState> startMonitoring(String gameId, SportType sport) {
    // Stop existing monitoring if any
    stopMonitoring(gameId);

    // Create broadcast stream for this game
    final controller = StreamController<GameState>.broadcast();
    _stateStreams[gameId] = controller;

    // Subscribe to ESPN updates
    final subscription = _espnService.monitorGame(gameId, sport).listen(
      (state) {
        // Process state update
        _processStateUpdate(gameId, state);
        
        // Forward to listeners
        controller.add(state);
        
        // Save to Firestore
        _saveStateToFirestore(gameId, state);
      },
      onError: (error) {
        print('Error monitoring game $gameId: $error');
      },
    );

    _subscriptions[gameId] = subscription;
    
    return controller.stream;
  }

  // Stop monitoring a game
  void stopMonitoring(String gameId) {
    _subscriptions[gameId]?.cancel();
    _subscriptions.remove(gameId);
    
    _stateStreams[gameId]?.close();
    _stateStreams.remove(gameId);
    
    _espnService.stopMonitoring(gameId);
    
    // Cancel any active card windows
    _activeWindows.remove(gameId);
    _windowTimers[gameId]?.cancel();
    _windowTimers.remove(gameId);
  }

  // Process state updates
  void _processStateUpdate(String gameId, GameState state) {
    // Check for card window triggers
    _checkCardWindows(gameId, state);
    
    // Notify listeners
    for (final listener in _stateListeners) {
      listener(gameId, state);
    }
    
    // Handle special state transitions
    _handleStateTransitions(gameId, state);
  }

  // Check and open card windows
  void _checkCardWindows(String gameId, GameState state) {
    // Halftime window (team sports)
    if (state.status == GameStatus.halftime) {
      _openCardWindow(
        gameId: gameId,
        cardTypes: ['double_down', 'insurance', 'hedge', 'split_bet'],
        duration: const Duration(minutes: 12),
        trigger: 'halftime',
        sport: state.sport,
      );
    }
    
    // Round break window (UFC)
    if (state.status == GameStatus.roundBreak && state.sport == SportType.ufc) {
      _openCardWindow(
        gameId: gameId,
        cardTypes: ['all'], // All cards available
        duration: const Duration(seconds: 60),
        trigger: 'round_break',
        sport: state.sport,
      );
    }
    
    // Set break window (Tennis)
    if (state.status == GameStatus.setBreak && state.sport == SportType.tennis) {
      _openCardWindow(
        gameId: gameId,
        cardTypes: ['double_down', 'insurance', 'hedge'],
        duration: const Duration(seconds: 120),
        trigger: 'set_break',
        sport: state.sport,
      );
    }
    
    // Two-minute warning (NFL)
    if (state.sport == SportType.nfl && 
        state.status == GameStatus.live && 
        state.clock != null &&
        _parseClockToSeconds(state.clock!) == 120) {
      _openCardWindow(
        gameId: gameId,
        cardTypes: ['insurance', 'hedge'],
        duration: const Duration(minutes: 2),
        trigger: 'two_minute_warning',
        sport: state.sport,
      );
    }
    
    // 7th inning stretch (MLB)
    if (state.sport == SportType.mlb && 
        state.period == 7 &&
        state.sportSpecific['isTop'] == false) {
      _openCardWindow(
        gameId: gameId,
        cardTypes: ['insurance', 'hedge', 'lucky_charm'],
        duration: const Duration(minutes: 5),
        trigger: 'seventh_inning_stretch',
        sport: state.sport,
      );
    }
  }

  // Open a card window
  void _openCardWindow({
    required String gameId,
    required List<String> cardTypes,
    required Duration duration,
    required String trigger,
    required SportType sport,
  }) {
    // Check if window already exists
    if (_activeWindows.containsKey('${gameId}_$trigger')) {
      return;
    }
    
    final window = CardWindow(
      gameId: gameId,
      cardTypes: cardTypes,
      opensAt: DateTime.now(),
      closesAt: DateTime.now().add(duration),
      trigger: trigger,
      sport: sport,
    );
    
    _activeWindows['${gameId}_$trigger'] = window;
    
    // Notify listeners
    for (final listener in _windowListeners) {
      listener(gameId, window);
    }
    
    // Send push notification
    _sendCardWindowNotification(window);
    
    // Set timer to close window
    _windowTimers['${gameId}_$trigger'] = Timer(duration, () {
      _closeCardWindow('${gameId}_$trigger');
    });
    
    // Save to Firestore
    _saveCardWindowToFirestore(window);
  }

  // Close a card window
  void _closeCardWindow(String windowId) {
    final window = _activeWindows[windowId];
    if (window != null) {
      _activeWindows.remove(windowId);
      _windowTimers[windowId]?.cancel();
      _windowTimers.remove(windowId);
      
      print('Card window closed for game ${window.gameId}: ${window.trigger}');
    }
  }

  // Handle special state transitions
  void _handleStateTransitions(String gameId, GameState state) {
    // Game finished - settle pools
    if (state.status == GameStatus.final) {
      _settlePools(gameId, state);
    }
    
    // Game cancelled - refund BR
    if (state.status == GameStatus.cancelled) {
      _refundPools(gameId, 'Game cancelled');
    }
    
    // Game suspended - switch to slow polling
    if (state.status == GameStatus.suspended) {
      print('Game $gameId suspended - switching to 10-minute polling');
    }
  }

  // Settle pools for finished game
  Future<void> _settlePools(String gameId, GameState state) async {
    try {
      print('Settling pools for game $gameId');
      
      // Get all pools for this game
      final poolsSnapshot = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'active')
          .get();
      
      for (final poolDoc in poolsSnapshot.docs) {
        final poolId = poolDoc.id;
        // TODO: Implement pool settlement logic based on game result
        print('Settling pool $poolId');
      }
    } catch (e) {
      print('Error settling pools for game $gameId: $e');
    }
  }

  // Refund pools for cancelled game
  Future<void> _refundPools(String gameId, String reason) async {
    try {
      print('Refunding pools for game $gameId: $reason');
      
      // Get all pools for this game
      final poolsSnapshot = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('status', whereIn: ['open', 'active'])
          .get();
      
      for (final poolDoc in poolsSnapshot.docs) {
        final poolId = poolDoc.id;
        final pool = poolDoc.data();
        
        // Refund all participants
        final participants = List<String>.from(pool['playerIds'] ?? []);
        final buyIn = pool['buyIn'] ?? 0;
        
        for (final userId in participants) {
          // TODO: Call wallet service to refund BR
          print('Refunding $buyIn BR to user $userId');
        }
        
        // Update pool status
        await poolDoc.reference.update({
          'status': 'cancelled',
          'cancellationReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error refunding pools for game $gameId: $e');
    }
  }

  // Save game state to Firestore
  Future<void> _saveStateToFirestore(String gameId, GameState state) async {
    try {
      final stateData = state.toFirestore();
      
      // Save to states subcollection with timestamp as ID
      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('states')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set(stateData);
      
      // Update latest state on game document
      await _firestore
          .collection('games')
          .doc(gameId)
          .update({
        'latestState': stateData,
        'lastStateUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving game state to Firestore: $e');
    }
  }

  // Save card window to Firestore
  Future<void> _saveCardWindowToFirestore(CardWindow window) async {
    try {
      await _firestore.collection('card_windows').add({
        'gameId': window.gameId,
        'cardTypes': window.cardTypes,
        'opensAt': Timestamp.fromDate(window.opensAt),
        'closesAt': Timestamp.fromDate(window.closesAt),
        'trigger': window.trigger,
        'sport': window.sport.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving card window to Firestore: $e');
    }
  }

  // Send push notification for card window
  void _sendCardWindowNotification(CardWindow window) {
    String message = '';
    
    switch (window.trigger) {
      case 'halftime':
        message = 'Halftime! Card window open for ${window.timeRemaining.inMinutes} minutes';
        break;
      case 'round_break':
        message = 'Round break! 60 seconds to play cards';
        break;
      case 'set_break':
        message = 'Set break! 2 minutes to play cards';
        break;
      case 'two_minute_warning':
        message = 'Two-minute warning! Last chance for Insurance';
        break;
      case 'seventh_inning_stretch':
        message = '7th inning stretch! Special cards available';
        break;
      default:
        message = 'Card window open!';
    }
    
    // TODO: Implement actual push notification
    print('NOTIFICATION: $message');
  }

  // Parse clock string to seconds
  int _parseClockToSeconds(String clock) {
    try {
      final parts = clock.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return (minutes * 60) + seconds;
      }
    } catch (e) {
      // Invalid format
    }
    return 0;
  }

  // Add state change listener
  void addStateListener(Function(String gameId, GameState state) listener) {
    _stateListeners.add(listener);
  }

  // Add card window listener
  void addWindowListener(Function(String gameId, CardWindow window) listener) {
    _windowListeners.add(listener);
  }

  // Remove listeners
  void removeStateListener(Function(String gameId, GameState state) listener) {
    _stateListeners.remove(listener);
  }

  void removeWindowListener(Function(String gameId, CardWindow window) listener) {
    _windowListeners.remove(listener);
  }

  // Get current state for a game
  Future<GameState?> getCurrentState(String gameId) async {
    try {
      final doc = await _firestore
          .collection('games')
          .doc(gameId)
          .get();
      
      if (doc.exists && doc.data()?['latestState'] != null) {
        return GameState.fromFirestore(doc.data()!['latestState']);
      }
    } catch (e) {
      print('Error getting current state for game $gameId: $e');
    }
    return null;
  }

  // Get active card windows for a game
  List<CardWindow> getActiveWindows(String gameId) {
    return _activeWindows.values
        .where((window) => window.gameId == gameId && window.isActive)
        .toList();
  }

  // Check if a card can be played
  bool canPlayCard(String gameId, String cardId) {
    // Check if there's an active window that allows this card
    final windows = getActiveWindows(gameId);
    for (final window in windows) {
      if (window.cardTypes.contains(cardId) || window.cardTypes.contains('all')) {
        return true;
      }
    }
    
    // Check based on current game state
    // This would need to be implemented based on the latest state
    return false;
  }

  // Play a card
  Future<bool> playCard({
    required String gameId,
    required String cardId,
    required String poolId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      // Check if card can be played
      if (!canPlayCard(gameId, cardId)) {
        print('Card $cardId cannot be played for game $gameId');
        return false;
      }
      
      // Use the card (decrements quantity)
      final success = await _cardService.useCard(cardId, poolId);
      if (!success) {
        print('Failed to use card $cardId');
        return false;
      }
      
      // Record card play
      await _firestore.collection('card_plays').add({
        'userId': userId,
        'gameId': gameId,
        'poolId': poolId,
        'cardId': cardId,
        'playedAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
      
      print('Card $cardId played successfully for game $gameId');
      return true;
    } catch (e) {
      print('Error playing card: $e');
      return false;
    }
  }

  // Dispose controller
  void dispose() {
    // Stop all monitoring
    for (final gameId in _subscriptions.keys.toList()) {
      stopMonitoring(gameId);
    }
    
    // Cancel all timers
    for (final timer in _windowTimers.values) {
      timer.cancel();
    }
    _windowTimers.clear();
    
    // Clear listeners
    _stateListeners.clear();
    _windowListeners.clear();
    
    // Dispose ESPN service
    _espnService.dispose();
  }
}