# Props Tab Implementation Build Plan

## Overview
Implement a sophisticated player props betting interface using a hybrid expandable approach that minimizes API calls while providing excellent UX for discovering and betting on player props.

## Architecture

### 1. API Strategy
- **Single API Call**: Fetch ALL props when Props tab is first opened
- **Cache Management**: Store parsed data for session duration
- **No Refetch**: Reuse cached data when switching tabs
- **Event-specific Endpoint**: Use `/events/{eventId}/odds` endpoint

### 2. Data Structure

```dart
class PropsTabData {
  final String homeTeam;
  final String awayTeam;
  final Map<String, PlayerProps> playersByName;
  final List<String> starPlayers; // Top 3-5 players
  final Map<String, List<String>> playersByPosition;
  final Map<String, List<String>> playersByTeam;
  DateTime cacheTime;
}

class PlayerProps {
  final String name;
  final String team; // home or away
  final String position; // inferred from prop types
  final bool isStar;
  final List<PropOption> props;
}

class PropOption {
  final String type; // pass_yds, rush_yds, etc.
  final String displayName; // "Passing Yards"
  final double line; // 275.5
  final int overOdds; // -110
  final int underOdds; // -110
  final String bookmaker;
}
```

### 3. UI Layout

```
Props Tab
├── Search Bar ["Search player name..."]
├── Team Toggle [Chiefs | Opponents]
├── Star Players Section (auto-expanded)
│   ├── ⭐ Patrick Mahomes ▼
│   │   ├── Pass Yards O/U 275.5
│   │   ├── Pass TDs O/U 2.5
│   │   └── Rush Yards O/U 25.5
│   └── ⭐ Travis Kelce ▼
│       ├── Receptions O/U 7.5
│       └── Anytime TD Scorer
├── Quarterbacks ▶
├── Running Backs ▶
├── Wide Receivers ▶
└── Tight Ends ▶
```

## Implementation Steps

### Phase 1: Data Layer
1. **Update OddsApiService** ✅ COMPLETED
   - Added `getEventOdds()` method
   - Added `getSportEvents()` method
   - Implemented `_processEventOdds()` parser

2. **Create Props Data Models**
   - `PlayerProps` class
   - `PropOption` class
   - `PropsTabData` container

3. **Build Props Parser**
   - Extract player names from outcomes
   - Infer positions from prop types
   - Identify star players
   - Group by team and position

### Phase 2: UI Components
1. **Props Tab Container**
   - Cache management
   - Loading states
   - Error handling

2. **Search Component**
   - Real-time filtering
   - Highlight matches
   - Auto-expand to results

3. **Team Toggle**
   - Switch between home/away
   - Filter existing data (no API call)

4. **Player Cards**
   - Expandable/collapsible
   - Star player indicators
   - Position badges

5. **Prop Betting Cards**
   - Over/Under display
   - Odds formatting
   - Add to bet slip functionality

### Phase 3: Business Logic

#### Player Name Extraction
```dart
String extractPlayerName(String outcome) {
  // "Patrick Mahomes Over 275.5" -> "Patrick Mahomes"
  // Remove Over/Under and numbers
  // Handle special cases
}
```

#### Position Inference
```dart
String inferPosition(List<String> propTypes) {
  if (propTypes.contains('player_pass_yds')) return 'QB';
  if (propTypes.contains('player_rush_yds')) return 'RB';
  if (propTypes.contains('player_reception_yds')) return 'WR/TE';
  // etc...
}
```

#### Star Player Detection
```dart
bool isStarPlayer(PlayerProps player) {
  // Has 5+ different prop types
  // OR is QB with passing props
  // OR has premium prop types
  return player.props.length >= 5;
}
```

### Phase 4: Optimizations

1. **Roster Limits**
   - Max 5 players per position shown
   - Prioritize by prop count
   - Show "View More" if needed

2. **Performance**
   - Lazy load position groups
   - Virtual scrolling for long lists
   - Debounced search

3. **Caching Strategy**
   - 5-minute cache for props
   - Refresh button available
   - Background refresh on stale data

## User Stories

### Story 1: Browse Star Players
```
GIVEN user opens Props tab
WHEN props load
THEN star players section shows expanded
AND other positions are collapsed
```

### Story 2: Search for Player
```
GIVEN user types in search box
WHEN entering "Mahomes"
THEN Patrick Mahomes card highlights
AND auto-expands to show props
```

### Story 3: Browse by Position
```
GIVEN user wants to see RB props
WHEN tapping "Running Backs"
THEN section expands
AND shows top 5 RBs with props
```

### Story 4: Switch Teams
```
GIVEN user viewing home team
WHEN toggling to away team
THEN props filter to away players
AND no new API call is made
```

## Success Metrics
- Single API call per game session
- < 2 seconds to load and parse props
- Find any player in < 3 interactions
- 90% of users find desired props without search

## Error Handling
- No props available message
- API failure fallback
- Empty search results
- Rate limit warnings

## Future Enhancements
1. Popular parlays section
2. Odds movement tracking
3. Player stats integration
4. Favorite players list
5. Prop betting trends

## Testing Requirements
1. Unit tests for parser functions
2. Widget tests for expandable cards
3. Integration test for full flow
4. Performance test with 100+ props

## Delivery Timeline
- Phase 1: Data Layer (30 min)
- Phase 2: UI Components (45 min)
- Phase 3: Business Logic (30 min)
- Phase 4: Optimizations (15 min)
- Testing & Polish (30 min)

Total: ~2.5 hours

## Dependencies
- Event ID from game selection
- Cached OddsApiService instance
- BetSlip integration
- Team/player name normalization

## Acceptance Criteria
✅ Props load with single API call
✅ Players grouped by position
✅ Star players prominently displayed
✅ Search works across all players
✅ Team toggle filters correctly
✅ Max 5 players per position shown
✅ Props can be added to bet slip
✅ Responsive and performant UI