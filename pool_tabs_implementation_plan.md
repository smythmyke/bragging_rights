# Bragging Rights Pool Tabs Implementation Plan

## Overview
This document outlines the implementation strategy for the Quick Play, Regional, and Tournament tabs in the pool selection screen. Currently, only the Private tab is functional, while the other tabs show empty states when accessing events like the upcoming McMillen vs. Mgoyan fight.

## Current State Analysis

### Working Components
- **PoolSelectionScreenV2**: Tab structure and navigation
- **BetSelectionScreen**: Betting interface with picks and wagers
- **Private Tab**: Fully functional with join codes and friend pools
- **Pool Models**: Templates and structures for different pool types
- **Services**: Pool, Bet, and Sports API services

### Missing Components
- Quick Play content generation and matchmaking
- Regional pool creation and location-based grouping
- Tournament bracket system and scoring
- Connection between pool selection and betting screen for non-private pools

## Implementation Plan

### Phase 1: Quick Play Tab
**Goal**: Enable instant betting with automatic matchmaking

#### 1.1 Pool Auto-Generation
- Create pools automatically when users access Quick Play
- Generate 4 tiers: Beginner ($5-10), Standard ($25-50), High Stakes ($100-250), VIP ($500+)
- Set pool sizes: Small (10-20), Medium (50-100), Large (100-500) players
- Auto-close pools 15 minutes before event start

#### 1.2 Instant Matchmaking Logic
```
- User selects tier → System finds or creates appropriate pool
- If pool near capacity → Create new pool of same tier
- Match users by:
  - Similar balance levels
  - Win rate brackets
  - Recent activity
```

#### 1.3 Simplified Betting Interface
For MMA/UFC:
- **Primary Pick**: Fighter to win (mandatory)
- **Quick Props** (optional):
  - Method of victory (KO/TKO, Submission, Decision)
  - Round betting (Early finish R1-2, Late finish R3-5, Goes distance)
  - Single prop: Fight to have knockdown (Yes/No)

#### 1.4 Implementation Steps
1. Create `QuickPlayPoolGenerator` service
2. Add auto-population logic to `pool_selection_screen_v2.dart`
3. Create simplified bet flow in `BetSelectionScreen`
4. Add real-time pool filling animations
5. Implement countdown timers for pool closure

### Phase 2: Regional Tab
**Goal**: Location-based competitive pools

#### 2.1 Location Hierarchy
```
Neighborhood → Zip Code (5-20 players)
City → City-wide (50-200 players)  
State → State-level (200-1000 players)
National → Country-wide (1000+ players)
```

#### 2.2 Regional Pool Features
- **Automatic Location Detection**: Use device location or user profile
- **Regional Statistics**: Show pick percentages by region
- **Local Leaderboards**: Track top predictors in each region
- **Regional Chat**: Pre-fight trash talk by location

#### 2.3 Pool Generation Strategy
```dart
// Generate pools for each regional level
for (level in [neighborhood, city, state, national]) {
  if (userCount >= minThreshold) {
    createRegionalPool(level, event);
  }
}
```

#### 2.4 Implementation Steps
1. Add location permission handling
2. Create `RegionalPoolService` with geo-grouping
3. Implement regional statistics aggregation
4. Add regional leaderboard widget
5. Create regional pool cards with location badges

### Phase 3: Tournament Tab
**Goal**: Structured competition formats

#### 3.1 Tournament Types

**Single Event Tournaments**
- **Survivor Pool**: Pick correctly or eliminate
- **Bracket Challenge**: Head-to-head elimination
- **Prediction Contest**: Points for correct outcomes
  - Winner: 10 points
  - Method: 5 points  
  - Round: 3 points

**Multi-Event Tournaments** (Fight Cards)
- **Card Parlay**: Build best multi-fight combination
- **Fantasy MMA**: Draft fighters, score points
- **Progressive Elimination**: Advance through rounds

#### 3.2 Tournament Structure
```
Entry Tiers:
- Bronze: $10-25 (Top 30% paid)
- Silver: $50-100 (Top 20% paid)
- Gold: $250+ (Top 10% paid)

Formats:
- Single Elimination: 8, 16, 32, 64 players
- Swiss System: Flexible player count
- Round Robin: Small groups (4-8)
```

#### 3.3 Scoring System
```dart
class TournamentScoring {
  // MMA/UFC Scoring
  static const CORRECT_WINNER = 10;
  static const CORRECT_METHOD = 5;
  static const CORRECT_ROUND = 3;
  static const EXACT_ROUND_TIME = 10; // Within 30 seconds
  
  // Bonus multipliers
  static const UNDERDOG_BONUS = 1.5;
  static const PERFECT_CARD = 2.0;
}
```

#### 3.4 Implementation Steps
1. Create `TournamentService` with bracket generation
2. Implement scoring engine for different formats
3. Add tournament status tracking (rounds, eliminations)
4. Create bracket visualization widget
5. Add tournament history and statistics

### Phase 4: Sport-Specific Adaptations

#### 4.1 MMA/UFC Specific
- Fighter records and recent form display
- Method of victory statistics
- Round-by-round betting options
- Significant strikes prop bets

#### 4.2 NFL Specific
- Quarter-by-quarter scoring
- Player props (touchdowns, yards)
- Team statistics integration
- Live score updates

#### 4.3 NBA Specific
- Player points/rebounds/assists
- Quarter winners
- Team totals
- Live play-by-play integration

#### 4.4 MLB Specific
- Inning-by-inning scoring
- Pitcher strikeouts
- Home runs props
- Weather impact notices

### Phase 5: Integration & Flow

#### 5.1 Navigation Flow
```
Event Selection → PoolSelectionScreenV2 → Tab Selection → Pool Join →
BetSelectionScreen → Pick Submission → Confirmation → Active Wagers
```

#### 5.2 Data Flow
```dart
// Pool selection to bet screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BetSelectionScreen(
      gameId: pool.gameId,
      gameTitle: pool.gameTitle,
      sport: pool.sport,
      poolName: pool.name,
      poolId: pool.id,
      poolType: pool.type, // Quick, Regional, Tournament
      betOptions: _getBetOptionsForPoolType(pool.type),
    ),
  ),
);
```

#### 5.3 State Management
- Pool selection state
- Active bets tracking
- Real-time pool updates
- Tournament progress tracking

## Technical Requirements

### Backend Requirements
1. **Firestore Collections**:
   - `quick_pools`: Auto-generated pools
   - `regional_pools`: Location-based pools
   - `tournament_pools`: Structured competitions
   - `pool_stats`: Regional statistics

2. **Cloud Functions**:
   - `generateQuickPools`: Auto-create pools for events
   - `matchUsersToPool`: Intelligent matchmaking
   - `calculateRegionalStats`: Aggregate regional picks
   - `processTournamentRound`: Handle eliminations/scoring

### Frontend Requirements
1. **New Widgets**:
   - `QuickPlayPoolCard`: Animated pool filling
   - `RegionalStatsWidget`: Pick percentages by location
   - `TournamentBracket`: Visual bracket display
   - `PoolCountdown`: Time until pool closes

2. **Services**:
   - `QuickPlayService`: Handle instant matchmaking
   - `RegionalService`: Location-based pool management
   - `TournamentService`: Bracket and scoring logic

## Implementation Timeline

### Week 1: Quick Play
- Day 1-2: Pool auto-generation
- Day 3-4: Matchmaking logic
- Day 5: Testing and refinement

### Week 2: Regional
- Day 1-2: Location services
- Day 3-4: Regional pool creation
- Day 5: Statistics and leaderboards

### Week 3: Tournament
- Day 1-2: Tournament structure
- Day 3-4: Scoring system
- Day 5: Bracket visualization

### Week 4: Integration
- Day 1-2: Connect all flows
- Day 3-4: Sport-specific features
- Day 5: Testing and polish

## Success Metrics
- **Quick Play**: 80% of pools fill before event start
- **Regional**: 60% user participation in regional pools
- **Tournament**: 40% completion rate for tournaments
- **Overall**: 50% increase in betting engagement

## Risk Mitigation
1. **Empty Pools**: Use AI bots for minimum liquidity
2. **Location Issues**: Fallback to IP-based location
3. **Tournament Dropouts**: Auto-advance system
4. **Technical Failures**: Offline bet caching

## Next Steps
1. Review and approve implementation plan
2. Prioritize sport-specific features
3. Design mockups for new UI components
4. Set up backend infrastructure
5. Begin Phase 1 implementation

---

*Document Version: 1.0*  
*Last Updated: Current Session*  
*Status: Pending Review*