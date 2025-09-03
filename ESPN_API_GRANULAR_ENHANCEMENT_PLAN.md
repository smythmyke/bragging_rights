# ESPN API Granular Enhancement Plan

## Executive Summary
Comprehensive plan to enhance ESPN API integration for real-time game state monitoring, individual fight tracking for MMA/UFC events, and sport-specific card play windows.

## Core Requirements

### 1. Individual Fight Pools (MMA/UFC)
- Each fight within a UFC event gets its own pool
- Users can bet on individual fights OR entire events
- Fight-by-fight tracking with round-level granularity

### 2. Settlement Rules
- **Winners**: Paid immediately after official result
- **Retirements/Walkovers**: Treated as cancelled, BR returned to wallet
- **Suspended Games**: Polled every 10 minutes until resumed or cancelled
- **Cancellations**: BR returned to wallet (never cash refunds)

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│          ESPN API Gateway Service           │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────┐  ┌──────────────┐        │
│  │   Polling   │  │   Response   │        │
│  │   Manager   │  │   Parser     │        │
│  └─────────────┘  └──────────────┘        │
│                                             │
├─────────────────────────────────────────────┤
│          Sport-Specific Monitors            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │   Team   │ │  Combat  │ │  Tennis  │  │
│  │  Sports  │ │  Sports  │ │  Monitor │  │
│  └──────────┘ └──────────┘ └──────────┘  │
│                                             │
├─────────────────────────────────────────────┤
│          State Management Layer             │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │  State   │ │  Event   │ │   Card   │  │
│  │  Differ  │ │  Emitter │ │  Rules   │  │
│  └──────────┘ └──────────┘ └──────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## Implementation Phases

## Phase 1: Core Infrastructure (Week 1-2)

### 1.1 Enhanced ESPN Service
```dart
class EnhancedESPNService {
  // Polling configuration per sport
  static const Map<String, PollConfig> pollConfigs = {
    'NFL': PollConfig(normal: 30000, critical: 10000, suspended: 600000),
    'NBA': PollConfig(normal: 30000, critical: 10000, suspended: 600000),
    'UFC': PollConfig(normal: 15000, critical: 5000, suspended: 300000),
    'TENNIS': PollConfig(normal: 45000, critical: 15000, suspended: 600000),
    'MLB': PollConfig(normal: 30000, critical: 15000, suspended: 600000),
  };
  
  // Endpoint templates
  static const endpoints = {
    'scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard',
    'summary': 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event={eventId}',
    'competitions': 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/competitions/{eventId}',
  };
}
```

### 1.2 Game State Model
```dart
class GameState {
  final String gameId;
  final String sport;
  final GameStatus status; // scheduled, live, halftime, suspended, final, cancelled
  final int? period;
  final String? periodName; // "1st Quarter", "Round 3", "Set 2"
  final String? clock;
  final Map<String, dynamic> sportSpecific;
  final List<String> availableCards;
  final bool isCriticalMoment;
  final DateTime lastUpdate;
  
  // Sport-specific helpers
  bool get isHalftime => sport == 'NFL' && period == 2 && status == GameStatus.halftime;
  bool get isBetweenRounds => sport == 'UFC' && status == GameStatus.roundBreak;
  bool get isSetBreak => sport == 'TENNIS' && status == GameStatus.setBreak;
  
  // Card window calculations
  bool canPlayCard(String cardId) {
    switch(cardId) {
      case 'double_down':
        return status == GameStatus.live && period != null && period! < 3;
      case 'insurance':
        return status == GameStatus.live && period != null && period! < 4;
      case 'mulligan':
        return status == GameStatus.scheduled;
      case 'hedge':
        return status == GameStatus.live && !isIntermission;
      default:
        return false;
    }
  }
}
```

## Phase 2: MMA/UFC Fight Tracking (Week 2-3)

### 2.1 UFC Event Parser
```dart
class UFCEventParser {
  // Parse UFC event into individual fights
  static UFCEvent parseEvent(Map<String, dynamic> espnData) {
    final competitions = espnData['competitions'] ?? [];
    final fights = <Fight>[];
    
    for (final comp in competitions) {
      fights.add(Fight(
        id: comp['id'],
        fighters: _extractFighters(comp),
        weightClass: comp['notes']?[0]?['headline'] ?? '',
        isMainEvent: comp['conferenceCompetition'] ?? false,
        isTitleFight: comp['neutralSite'] ?? false,
        scheduledRounds: _getScheduledRounds(comp),
        currentRound: comp['status']?['period'] ?? 0,
        roundTime: comp['status']?['displayClock'] ?? '',
        status: _mapStatus(comp['status']),
      ));
    }
    
    return UFCEvent(
      id: espnData['id'],
      name: espnData['name'],
      date: DateTime.parse(espnData['date']),
      fights: fights,
      venue: espnData['venue']?['fullName'],
    );
  }
}
```

### 2.2 Fight State Tracker
```dart
class FightStateTracker {
  final String eventId;
  final String fightId;
  Timer? _pollTimer;
  FightState? _lastState;
  
  // Track round-by-round
  void startTracking() {
    _pollTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      final newState = await _fetchFightState();
      
      if (_hasStateChanged(newState)) {
        _emitStateChange(newState);
        _checkCardWindows(newState);
        _updateDatabase(newState);
      }
      
      _lastState = newState;
    });
  }
  
  // Detect round transitions
  bool _hasStateChanged(FightState newState) {
    if (_lastState == null) return true;
    
    // Round changed
    if (_lastState!.round != newState.round) {
      _onRoundChange(_lastState!.round, newState.round);
      return true;
    }
    
    // Fight ended
    if (_lastState!.status != newState.status && 
        newState.status == FightStatus.final) {
      _onFightEnd(newState);
      return true;
    }
    
    return false;
  }
  
  // Handle round breaks (60-second card window)
  void _onRoundChange(int oldRound, int newRound) {
    if (newRound > oldRound) {
      // Round ended - start 60-second break timer
      notifyCardWindow('round_break', Duration(seconds: 60));
    }
  }
}
```

### 2.3 UFC Pool Structure
```dart
class UFCPoolManager {
  // Create pools for entire event
  Future<String> createEventPool(UFCEvent event) async {
    return await poolService.createPool(
      gameId: event.id,
      gameTitle: event.name,
      sport: 'UFC',
      type: PoolType.event,
      name: '${event.name} - Full Card',
    );
  }
  
  // Create individual fight pools
  Future<List<String>> createFightPools(UFCEvent event) async {
    final poolIds = <String>[];
    
    for (final fight in event.fights) {
      final poolId = await poolService.createPool(
        gameId: '${event.id}_${fight.id}',
        gameTitle: fight.fighterNames,
        sport: 'UFC',
        type: PoolType.fight,
        name: '${fight.fighters[0]} vs ${fight.fighters[1]}',
        metadata: {
          'eventId': event.id,
          'fightId': fight.id,
          'isMainEvent': fight.isMainEvent,
          'weightClass': fight.weightClass,
        }
      );
      poolIds.add(poolId);
    }
    
    return poolIds;
  }
}
```

## Phase 3: Tennis Match Monitoring (Week 3-4)

### 3.1 Tennis State Model
```dart
class TennisMatchState {
  final String matchId;
  final List<String> players;
  final MatchFormat format; // best_of_3, best_of_5
  final List<SetScore> sets;
  final GameScore currentGame;
  final String server;
  final bool isSetPoint;
  final bool isMatchPoint;
  final bool isTiebreak;
  
  // Card windows based on tennis flow
  List<String> getAvailableCards() {
    final cards = <String>[];
    
    if (status == MatchStatus.scheduled) {
      cards.add('mulligan');
    }
    
    if (status == MatchStatus.live) {
      cards.add('hedge');
      
      if (isSetPoint || isMatchPoint) {
        cards.add('insurance');
      }
      
      if (isBetweenSets) {
        cards.add('double_down'); // 120-second window
      }
    }
    
    return cards;
  }
}
```

### 3.2 Tennis Event Handlers
```dart
class TennisEventHandlers {
  // Set transitions
  void onSetEnd(int setNumber, SetScore score) {
    // 120-second break between sets
    startCardWindow('set_break', Duration(seconds: 120));
    
    // Check if match is decided
    if (isMatchDecided(score)) {
      settlePools(matchId, winner);
    }
  }
  
  // Handle retirements
  void onRetirement(String player, String reason) {
    // Cancel all pools and return BR
    cancelPools(matchId, 'Player retirement: $reason');
    refundBR(matchId);
  }
  
  // Handle walkovers
  void onWalkover(String winner, String reason) {
    // Cancel pools before first serve
    if (matchNotStarted) {
      cancelPools(matchId, 'Walkover: $reason');
      refundBR(matchId);
    } else {
      // If match started, settle normally
      settlePools(matchId, winner);
    }
  }
}
```

## Phase 4: Suspended Game Handling (Week 4)

### 4.1 Suspension Monitor
```dart
class SuspensionMonitor {
  final Map<String, Timer> _suspendedGames = {};
  
  void monitorSuspendedGame(String gameId, String sport) {
    // Poll every 10 minutes for status change
    _suspendedGames[gameId] = Timer.periodic(
      Duration(minutes: 10),
      (_) async {
        final status = await checkGameStatus(gameId);
        
        switch(status) {
          case GameStatus.resumed:
            resumeNormalPolling(gameId);
            notifyUsers(gameId, 'Game resumed!');
            break;
            
          case GameStatus.cancelled:
            handleCancellation(gameId);
            _suspendedGames[gameId]?.cancel();
            break;
            
          case GameStatus.postponed:
            handlePostponement(gameId);
            _suspendedGames[gameId]?.cancel();
            break;
            
          default:
            // Still suspended, continue monitoring
            break;
        }
      }
    );
  }
  
  void handleCancellation(String gameId) {
    // Return BR to all participants
    final pools = getPoolsForGame(gameId);
    for (final pool in pools) {
      refundAllParticipants(pool.id, 'Game cancelled');
    }
  }
}
```

## Phase 5: Card Window Management (Week 5)

### 5.1 Card Window Controller
```dart
class CardWindowController {
  final Map<String, CardWindow> activeWindows = {};
  
  // Open card play window
  void openWindow(String gameId, String cardType, Duration duration) {
    final window = CardWindow(
      gameId: gameId,
      cardType: cardType,
      opensAt: DateTime.now(),
      closesAt: DateTime.now().add(duration),
    );
    
    activeWindows[cardType] = window;
    
    // Notify users
    sendNotification(
      'Card window open for $cardType! ${duration.inSeconds} seconds remaining'
    );
    
    // Auto-close after duration
    Timer(duration, () => closeWindow(cardType));
  }
  
  // Sport-specific windows
  void configureSportWindows(String sport, GameState state) {
    switch(sport) {
      case 'UFC':
        if (state.isBetweenRounds) {
          openWindow(state.gameId, 'all_cards', Duration(seconds: 60));
        }
        break;
        
      case 'NFL':
        if (state.isHalftime) {
          openWindow(state.gameId, 'halftime_cards', Duration(minutes: 12));
        } else if (state.isTwoMinuteWarning) {
          openWindow(state.gameId, 'clutch_cards', Duration(minutes: 2));
        }
        break;
        
      case 'TENNIS':
        if (state.isSetBreak) {
          openWindow(state.gameId, 'set_cards', Duration(seconds: 120));
        }
        break;
    }
  }
}
```

## Phase 6: Fallback Systems (Week 5-6)

### 6.1 ESPN API Failure Handling
```dart
class ESPNFallbackHandler {
  int failureCount = 0;
  DateTime? lastFailure;
  
  Future<GameState?> fetchWithFallback(String gameId) async {
    try {
      // Primary: ESPN Summary endpoint
      return await fetchESPNSummary(gameId);
    } catch (e) {
      failureCount++;
      lastFailure = DateTime.now();
      
      // Fallback 1: ESPN Scoreboard endpoint
      try {
        return await fetchESPNScoreboard(gameId);
      } catch (e) {
        // Fallback 2: Cached data
        final cached = await getCachedState(gameId);
        if (cached != null && 
            cached.lastUpdate.difference(DateTime.now()).inMinutes < 5) {
          return cached;
        }
        
        // Fallback 3: Manual update mode
        enableManualMode(gameId);
        notifyAdmins('ESPN API failure for game $gameId');
        
        return null;
      }
    }
  }
}
```

### 6.2 Manual Update Interface
```dart
class ManualGameUpdater {
  // Admin interface for manual updates
  Future<void> updateGameState(String gameId, ManualUpdate update) async {
    // Validate admin permissions
    if (!isAdmin(currentUser)) {
      throw Exception('Unauthorized');
    }
    
    // Apply manual update
    final state = GameState(
      gameId: gameId,
      period: update.period,
      clock: update.clock,
      score: update.score,
      status: update.status,
      lastUpdate: DateTime.now(),
      isManualUpdate: true,
    );
    
    // Broadcast to all clients
    broadcastStateUpdate(state);
    
    // Log for audit
    logManualUpdate(gameId, currentUser, update);
  }
}
```

## Database Schema Updates

### Game States Collection
```typescript
games/{gameId}/states/{timestamp} {
  period: number,
  periodName: string,
  clock: string,
  status: string,
  score: { home: number, away: number },
  possession: string?, // Team sports
  round: number?, // Combat sports
  set: number?, // Tennis
  sportSpecific: Map<string, any>,
  availableCards: string[],
  isCriticalMoment: boolean,
  lastUpdate: Timestamp,
  isManualUpdate: boolean
}
```

### UFC Events Structure
```typescript
ufc_events/{eventId} {
  name: string,
  date: Timestamp,
  venue: string,
  fights: [{
    id: string,
    fighters: string[],
    weightClass: string,
    isMainEvent: boolean,
    scheduledRounds: number,
    poolId: string
  }]
}

ufc_events/{eventId}/fights/{fightId}/states/{timestamp} {
  round: number,
  roundTime: string,
  status: string,
  fighterStats: Map<string, any>,
  lastUpdate: Timestamp
}
```

### Card Windows Collection
```typescript
card_windows/{windowId} {
  gameId: string,
  cardTypes: string[],
  opensAt: Timestamp,
  closesAt: Timestamp,
  sport: string,
  trigger: string, // 'halftime', 'round_break', 'set_break'
  playersNotified: string[]
}
```

## Monitoring & Alerts

### Real-time Notifications
1. **Pre-game**: "Game starting in 5 minutes - last chance for Mulligan!"
2. **Period transitions**: "3rd quarter starting - Insurance card expires soon!"
3. **UFC rounds**: "Round 2 ending - 60-second card window opening!"
4. **Tennis sets**: "Set point! Hedge and Insurance cards available!"
5. **Suspensions**: "Game suspended due to weather - monitoring for updates"

### Performance Metrics
- API response times
- State update latency
- Card window accuracy
- Settlement speed
- Fallback activation rate

## Testing Strategy

### 1. Unit Tests
- State extractors for each sport
- Card window calculations
- Settlement logic
- Refund scenarios

### 2. Integration Tests
- Full game simulations
- UFC event with multiple fights
- Tennis match with retirements
- Suspended game scenarios

### 3. Load Tests
- 100+ concurrent games
- 1000+ active pools
- Peak card play windows

### 4. Mock Data Generators
```dart
class MockGameGenerator {
  // Generate realistic game progressions
  Stream<GameState> generateNFLGame() async* {
    // Pre-game
    yield GameState(status: GameStatus.scheduled);
    
    // Quarters 1-4
    for (int q = 1; q <= 4; q++) {
      for (int minute = 15; minute >= 0; minute--) {
        yield GameState(
          period: q,
          clock: '$minute:00',
          status: GameStatus.live
        );
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    // Final
    yield GameState(status: GameStatus.final);
  }
}
```

## Success Metrics

1. **Accuracy**: 99.9% correct game state within 30 seconds
2. **Card Windows**: 100% of valid card plays accepted
3. **Settlement Speed**: < 5 seconds after official result
4. **Uptime**: 99.95% availability (excluding ESPN outages)
5. **User Satisfaction**: < 0.1% disputes on game results

## Timeline

- **Weeks 1-2**: Core infrastructure and enhanced ESPN integration
- **Weeks 2-3**: UFC fight-by-fight tracking
- **Weeks 3-4**: Tennis match monitoring
- **Week 4**: Suspended game handling
- **Weeks 5-6**: Card windows and fallback systems
- **Week 7**: Testing and optimization
- **Week 8**: Production deployment

## Risk Mitigation

1. **ESPN API Changes**: Monitor for schema changes, maintain adapters
2. **Rate Limiting**: Implement caching and request pooling
3. **Network Failures**: Local state management and reconciliation
4. **Disputed Results**: Admin override with audit trail
5. **Peak Load**: Auto-scaling and load balancing

## Next Steps

1. [ ] Set up development environment with ESPN API access
2. [ ] Create sport-specific state extractors
3. [ ] Implement UFC fight parser
4. [ ] Build card window controller
5. [ ] Develop fallback systems
6. [ ] Create comprehensive test suite
7. [ ] Deploy to staging environment
8. [ ] Production rollout with monitoring