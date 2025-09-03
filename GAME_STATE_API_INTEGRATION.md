# Game State API Integration Plan

## Current State
We already receive basic game state from ESPN API:
- `period`: Current quarter/period/inning
- `timeRemaining`: Game clock
- `status`: live/final/scheduled

## Enhanced Game State Requirements

### Required Data Points
1. **Period/Quarter/Inning/Round**
   - Current period number
   - Period start/end events
   - Intermission/halftime status

2. **Time Information**
   - Game clock (minutes:seconds)
   - Shot clock (basketball)
   - Play clock (football)
   - Period end warnings

3. **Game Events**
   - Timeouts (team/TV)
   - Reviews/challenges
   - Injuries
   - Penalties/fouls

4. **Sport-Specific States**
   - **Football**: Possession, down & distance, red zone
   - **Basketball**: Bonus situation, possession arrow
   - **Baseball**: Inning top/bottom, outs, runners on base
   - **Hockey**: Power play, penalty kill
   - **Soccer**: Added time, penalty kicks
   - **MMA/Boxing**: Round breaks, fighter warnings
   - **Tennis**: Set/game score, serve, break points

## Recommended Solution: Hybrid Approach

### Primary: Enhanced ESPN Polling
```dart
class GameStateMonitor {
  // Poll every 30 seconds normally
  // Poll every 10 seconds in critical moments:
  // - Last 2 minutes of quarter/period
  // - Overtime
  // - Close games (within 10 points/runs)
  
  Timer? _gameStateTimer;
  
  void startMonitoring(String gameId) {
    _gameStateTimer = Timer.periodic(
      _getCriticalMoment() ? Duration(seconds: 10) : Duration(seconds: 30),
      (timer) => _fetchGameState(gameId),
    );
  }
}
```

### Secondary: The Odds API (Free Backup)
- Use for critical games when ESPN is slow
- 500 free requests/month
- Save for playoff/championship games

### Tertiary: WebSocket Stream (Future)
```dart
// Future enhancement - real-time updates
class GameStateWebSocket {
  late WebSocketChannel channel;
  
  void connect(String gameId) {
    channel = WebSocketChannel.connect(
      Uri.parse('wss://gamestate.braggingrights.com/$gameId'),
    );
    
    channel.stream.listen((message) {
      final state = GameState.fromJson(json.decode(message));
      _updateCardAvailability(state);
    });
  }
}
```

## Implementation Phases

### Phase 1: Enhance Current ESPN Integration (Week 1)
- [x] Parse period/quarter data from ESPN
- [ ] Add sport-specific period names
- [ ] Create GameState model class
- [ ] Add period change detection
- [ ] Implement adaptive polling rates

### Phase 2: Game State Controller (Week 2)
- [ ] Create `GameStateController` class
- [ ] Track period transitions
- [ ] Detect critical game moments
- [ ] Trigger card availability updates
- [ ] Store state history

### Phase 3: Card Rules Integration (Week 3)
- [ ] Link game states to card rules
- [ ] Auto-disable cards at period end
- [ ] Show countdown timers for card availability
- [ ] Send notifications for last chance to play cards

### Phase 4: Advanced Features (Week 4+)
- [ ] Add The Odds API as backup
- [ ] Implement caching layer
- [ ] Add predictive state changes
- [ ] Create state simulation for testing

## GameState Model

```dart
class GameState {
  final String gameId;
  final String sport;
  final String status; // pregame, live, halftime, final
  final int? period; // 1-4 for quarters, 1-9+ for innings
  final String? periodName; // "1st Quarter", "Bottom 5th"
  final String? clock; // "5:23", null for baseball
  final bool isIntermission;
  final bool isCriticalMoment; // Last 2 min, etc
  final Map<String, dynamic> sportSpecific;
  
  // Card-specific helpers
  bool get canPlayDoubleDown => 
    status == 'live' && period != null && period! < 3;
    
  bool get canPlayInsurance =>
    status == 'live' && period != null && period! < 4;
    
  bool get canPlayHedge =>
    status == 'live' && !isIntermission;
    
  Duration? get timeUntilPeriodEnd {
    if (clock == null) return null;
    // Parse clock and calculate
  }
}
```

## API Endpoints to Monitor

### ESPN Enhanced Endpoints
```
# Game Summary (current using)
https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard

# Game Detail (more frequent updates)
https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event={gameId}

# Play-by-Play (most detailed)
https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/playbyplay?gameId={gameId}
```

### The Odds API Endpoints
```
# Live Scores
https://api.the-odds-api.com/v4/sports/{sport}/scores/?apiKey={key}&daysFrom=1

# Live Odds (includes game state)
https://api.the-odds-api.com/v4/sports/{sport}/odds/?apiKey={key}&regions=us&markets=h2h,spreads,totals
```

## Database Schema Updates

```typescript
// Firestore structure
games/{gameId} {
  // Existing fields...
  
  gameState: {
    period: 2,
    periodName: "2nd Quarter",
    clock: "7:45",
    isIntermission: false,
    lastUpdated: Timestamp,
    
    sportSpecific: {
      possession: "home", // football/basketball
      inning: "top", // baseball
      powerPlay: true, // hockey
      // etc...
    }
  },
  
  stateHistory: [
    {
      timestamp: Timestamp,
      event: "period_end",
      details: { period: 1, finalScore: "28-24" }
    }
  ]
}
```

## Testing Strategy

1. **Mock Data Generator**
   - Simulate game progression
   - Test all period transitions
   - Verify card cutoff times

2. **Integration Tests**
   - Test with live ESPN data
   - Verify state changes
   - Check card rule enforcement

3. **Load Testing**
   - Multiple concurrent games
   - High-frequency polling
   - Cache performance

## Cost Analysis

| Service | Monthly Cost | Requests | Best For |
|---------|-------------|----------|----------|
| ESPN (current) | Free | Unlimited* | Primary source |
| The Odds API | Free | 500/month | Backup/critical |
| API-Football | $24 | 10,000/day | Future scale |
| SportRadar | $500+ | Unlimited | Enterprise |

*ESPN may rate limit - implement exponential backoff

## Next Steps

1. Enhance ESPN integration with period detection
2. Create GameStateController class
3. Update card rules to use game state
4. Add UI indicators for card availability windows
5. Implement state change notifications