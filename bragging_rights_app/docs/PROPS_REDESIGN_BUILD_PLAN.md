# Props Tab Redesign - Implementation Build Plan

## Overview
Complete redesign of the props betting interface to use a player-first selection approach with efficient API usage and Firestore caching.

## Architecture Principles
1. **Single API Call**: Fetch all props data once when props tab is opened
2. **Firestore Caching**: Store parsed props data with timestamp for session reuse
3. **Player-Centric Navigation**: Two-screen flow (Player Selection → Player Props)
4. **Position-Based Organization**: Group players by their field position
5. **Lazy Loading**: Load player photos asynchronously

## Data Flow

### 1. API Integration Strategy
```dart
// Single API call on props tab initialization
Future<PropsData> fetchPropsData(String eventId) {
  // 1. Check Firestore cache first (5-minute TTL)
  // 2. If stale/missing, fetch from Odds API
  // 3. Parse and organize by player/position
  // 4. Cache to Firestore with timestamp
  // 5. Return organized data
}
```

### 2. Firestore Cache Structure
```
firestore/
├── props_cache/
│   └── {eventId}/
│       ├── metadata
│       │   ├── timestamp: DateTime
│       │   ├── homeTeam: String
│       │   ├── awayTeam: String
│       │   └── sportType: String
│       ├── players/
│       │   └── {playerName}/
│       │       ├── team: String
│       │       ├── position: String
│       │       ├── isStar: Boolean
│       │       ├── photoUrl: String (if available)
│       │       └── props: Array<PropData>
│       └── positions/
│           ├── pitchers: Array<String> (player names)
│           ├── infielders: Array<String>
│           └── outfielders: Array<String>
```

### 3. Cache Management
- **TTL**: 5 minutes for live games, 30 minutes for future games
- **Invalidation**: Clear cache on app refresh or manual pull-to-refresh
- **Storage Limit**: Max 50 events cached, LRU eviction

## Screen Implementations

### Screen 1: Player Selection Grid

#### Layout Structure
```
PropsPlayerSelectionScreen
├── Team Toggle (Home/Away)
├── ScrollView
│   ├── Position Section (PITCHERS)
│   │   ├── GridView (2 columns)
│   │   │   ├── PlayerCard (star players first)
│   │   │   └── ... (up to 5 cards)
│   │   └── Show All Button (if > 5 players)
│   ├── Position Section (INFIELDERS)
│   │   └── ... (same structure)
│   └── Position Section (OUTFIELDERS)
│       └── ... (same structure)
└── Loading/Error States
```

#### Player Card Component
```dart
PlayerCard {
  - photoUrl: String? (null = show placeholder)
  - playerName: String
  - position: String (e.g., "SP", "3B")
  - isStar: Boolean (shows star icon)
  - propCount: int (for display if needed)
  - onTap: () => navigateToPlayerProps()
}
```

#### Data Requirements
- Player name
- Position abbreviation
- Team affiliation
- Star player status
- Photo URL (optional, from ESPN API or stored assets)

### Screen 2: Individual Player Props

#### Layout Structure
```
PlayerPropsScreen
├── App Bar
│   ├── Back Button
│   ├── Player Name
│   └── Position & Team
├── Filter Chips
│   ├── All
│   ├── Hitting
│   ├── Bases
│   └── ... (dynamic based on available props)
├── Props List (Grouped by Category)
│   ├── Category Header (e.g., "HITTING")
│   ├── PropCard
│   │   ├── Prop Description
│   │   ├── Over Button (odds)
│   │   └── Under Button (odds)
│   └── ... (more props)
└── Empty State (if no props available)
```

#### Prop Card Component
```dart
PropCard {
  - propType: String (e.g., "Hits O/U")
  - line: double (e.g., 1.5)
  - overOdds: int (e.g., -110)
  - underOdds: int (e.g., -110)
  - onOverSelected: () => addToBetSlip()
  - onUnderSelected: () => addToBetSlip()
  - isSelected: Boolean (visual feedback)
}
```

## Implementation Phases

### Phase 1: Data Layer (2 hours)
1. **Update PropsParser**
   - Enhanced player name extraction
   - Position inference from prop types
   - Star player identification (5+ props or specific positions)

2. **Firestore Integration**
   ```dart
   class PropsCache {
     static Future<PropsData?> getCached(String eventId);
     static Future<void> cache(String eventId, PropsData data);
     static bool isValid(DateTime timestamp);
     static Future<void> clearOldCache();
   }
   ```

3. **Data Models**
   ```dart
   class PlayerSelectionData {
     final Map<String, List<PlayerInfo>> playersByPosition;
     final Set<String> starPlayers;
     final String homeTeam;
     final String awayTeam;
   }
   
   class PlayerInfo {
     final String name;
     final String position;
     final String team;
     final bool isStar;
     final int propCount;
     final String? photoUrl;
   }
   ```

### Phase 2: Player Selection Screen (2 hours)
1. **Grid Layout Implementation**
   - 2-column GridView with aspect ratio 3:4
   - Position section headers
   - Expandable sections for > 5 players

2. **Player Cards**
   - Photo placeholder handling
   - Star indicator overlay
   - Tap navigation to props screen

3. **Team Toggle**
   - Filter players by selected team
   - Maintain scroll position on toggle

### Phase 3: Player Props Screen (1.5 hours)
1. **Props Display**
   - Group by category (HITTING, BASES, etc.)
   - Clear Over/Under selection buttons
   - Selected state visualization

2. **Filter Implementation**
   - Dynamic filter chips based on available props
   - Instant filtering without API calls

3. **Navigation**
   - Back button to player selection
   - Maintain bet selections when navigating

### Phase 4: Integration & Polish (1.5 hours)
1. **Bet Slip Integration**
   - Add props to existing bet slip
   - Show selection count indicator

2. **Loading States**
   - Skeleton screens while loading
   - Error handling with retry

3. **Performance Optimization**
   - Image caching for player photos
   - Smooth transitions between screens

## API Efficiency Strategies

### 1. Request Optimization
```dart
// Single request with all needed markets
final markets = [
  'batter_home_runs',
  'batter_hits', 
  'batter_rbis',
  'batter_runs_scored',
  'batter_total_bases',
  'pitcher_strikeouts',
  'pitcher_hits_allowed',
  // ... all prop markets
];

final response = await oddsApi.getEventOdds(
  eventId: gameId,
  markets: markets.join(','),
);
```

### 2. Response Parsing
```dart
Map<String, PlayerInfo> parsePropsResponse(dynamic response) {
  // 1. Extract all unique player names
  // 2. Infer positions from prop types
  // 3. Count props per player
  // 4. Identify star players (most props)
  // 5. Group by position
  // 6. Sort stars first, then alphabetically
}
```

### 3. Caching Strategy
- **Memory Cache**: Current session data
- **Firestore Cache**: Cross-session persistence
- **Cache Key**: `${eventId}_${homeTeam}_${awayTeam}`
- **Invalidation**: TTL-based + manual refresh

## Player Photo Integration

### Option 1: ESPN API Integration
```dart
Future<String?> fetchPlayerPhoto(String playerName, String team) {
  // Query ESPN API for player headshot
  // Cache URL in Firestore
  // Return null if not found
}
```

### Option 2: Asset Bundles
```
assets/
└── player_photos/
    └── mlb/
        ├── manny_machado.jpg
        ├── fernando_tatis.jpg
        └── ... (top 50 players)
```

### Option 3: Placeholder System
- Generic position-based placeholders
- Team color backgrounds
- Player initials overlay

## Position Mapping

### Baseball (MLB)
```dart
const MLB_POSITIONS = {
  'pitchers': ['SP', 'RP', 'CP'],
  'catchers': ['C'],
  'infielders': ['1B', '2B', '3B', 'SS'],
  'outfielders': ['LF', 'CF', 'RF'],
  'designated': ['DH']
};
```

### Position Inference Rules
```dart
String inferPosition(List<String> propTypes) {
  if (propTypes.any((p) => p.contains('pitcher'))) {
    return propTypes.any((p) => p.contains('saves')) ? 'CP' : 'SP';
  }
  if (propTypes.any((p) => p.contains('batter'))) {
    // Additional logic based on common props
    if (propTypes.length > 6) return 'INF'; // Star infielder
    if (propTypes.contains('stolen_bases')) return 'OF'; // Likely outfielder
    return 'DH'; // Default for batters
  }
}
```

## Error Handling

### API Failures
```dart
try {
  final props = await fetchPropsData(eventId);
} catch (e) {
  // 1. Check Firestore cache (even if stale)
  // 2. Show cached data with stale indicator
  // 3. Offer manual refresh option
  // 4. Log error to analytics
}
```

### Empty States
- No props available: "No player props available for this game"
- No players in position: Hide that position section
- API error: "Unable to load props. Tap to retry."

## Testing Checklist

### Unit Tests
- [ ] Props parser correctly extracts player names
- [ ] Position inference accuracy
- [ ] Star player identification
- [ ] Cache TTL validation

### Widget Tests
- [ ] Player grid layout renders correctly
- [ ] Team toggle filters players
- [ ] Props grouped by category
- [ ] Filter chips work correctly

### Integration Tests
- [ ] Full flow: Select player → View props → Add to bet slip
- [ ] Cache hit/miss scenarios
- [ ] Error recovery flows
- [ ] Navigation state preservation

## Performance Targets
- **Initial Load**: < 2 seconds (with cache)
- **Player Selection**: Instant (pre-parsed data)
- **Props Display**: < 500ms transition
- **Image Loading**: Progressive with placeholders
- **Memory Usage**: < 50MB for props data

## Future Enhancements
1. **Player Stats Integration**: Show recent performance
2. **Prop Trends**: Historical hit rates
3. **Popular Parlays**: Pre-built prop combinations
4. **Live Updates**: Real-time odds changes
5. **Search**: Find players quickly
6. **Favorites**: Pin favorite players

## Dependencies
- `cached_network_image`: Player photo caching
- `shimmer`: Loading skeletons
- Existing: Firebase, http, provider/riverpod

## Delivery Timeline
- Phase 1: 2 hours (Data Layer)
- Phase 2: 2 hours (Player Selection)
- Phase 3: 1.5 hours (Player Props)
- Phase 4: 1.5 hours (Integration)
- **Total: 7 hours**

## Success Metrics
- ✅ Single API call per game
- ✅ < 2 second load time
- ✅ Intuitive player selection
- ✅ Clear prop organization
- ✅ Smooth navigation
- ✅ Efficient caching