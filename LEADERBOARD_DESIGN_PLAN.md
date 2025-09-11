# Leaderboard Design Plan

## Overview
Pool-based leaderboard system where each pool type maintains its own scoring and rankings for consistent cross-device display.

## Leaderboard Structure (4 Tabs)

### 1. Quick Play
**Daily Competition (Resets at Midnight Local Time)**
- Today's leaders only
- Real-time updates
- Casual, fast-moving competition

**Display Format:**
```
Rank | Username | Today's P/L | Streak
#1   | MikeW23  | +$145      | 🔥 5
#2   | Sarah_L  | +$89       | 🔥 3  
#3   | You      | +$67       | 🔥 2
```

### 2. Regional
**Permanent Geographic Rankings**
- Includes all regional pools user participates in
- Cumulative stats across all regional betting

**Filter Options:**
- My City (e.g., "San Francisco")
- My State (e.g., "California") 
- National (entire US)

**Display Format:**
```
Rank | Username | Total P/L | Win % | Change
#47  | You      | +$1,250  | 58%   | ↑ 3
#48  | JohnD    | +$1,240  | 56%   | ↓ 1
```

### 3. Private Pools
**User's Private Pool Memberships**

**Pool List View:**
```
Pool Name          | Your Rank | Members
NFL Degenerates    | 3rd/12    | 12
Office League      | 1st/8     | 8  
College Buddies    | 5th/20    | 20
```

**Inside Pool View (tap to expand):**
- Full member standings
- Pool statistics
- Historical performance
- Pool chat/activity feed
- Pool rules and settings

### 4. Tournament
**Active Tournament Participation Only**

**Display Format:**
```
Tournament         | Phase      | Your Rank | Points | Status
March Madness 2024 | Round of 16| 23rd/128  | 450    | Advancing
NFL Playoff Challenge | Week 2  | 5th/64    | 780    | Leader
```

**Tournament Details:**
- Bracket/advancement visualization
- Payout structure
- Entry requirements
- Time remaining in phase

## Data Architecture

### Scoring Isolation
Each pool maintains independent scoring:
```
firestore/
├── pools/
│   ├── quickplay/
│   │   └── daily_{date}/
│   │       └── leaderboard: [{userId, username, profitLoss, streak}]
│   ├── regional/
│   │   ├── state_{stateCode}/
│   │   │   └── leaderboard: [{userId, username, totalPL, winPct, prevRank}]
│   │   └── city_{cityId}/
│   │       └── leaderboard: [{userId, username, totalPL, winPct, prevRank}]
│   ├── private/
│   │   └── {poolId}/
│   │       ├── settings: {name, creator, rules}
│   │       └── leaderboard: [{userId, rank, stats}]
│   └── tournament/
│       └── {tournamentId}/
│           ├── settings: {name, phase, rules, prizes}
│           └── leaderboard: [{userId, points, advancement}]
```

### Real-time Updates
- Firestore listeners for each active pool
- Updates trigger on bet settlement
- Rank calculations done server-side
- Client receives sorted results

## UI/UX Components

### Common Elements
- Pull-to-refresh on all tabs
- Loading skeletons during data fetch
- Your position always highlighted
- Smooth tab transitions

### Navigation Flow
```
Settings → Leaderboard → 
├── Quick Play (default tab)
├── Regional
├── Private Pools → Individual Pool View
└── Tournament → Tournament Details
```

### Visual Indicators
- 🔥 Streak indicator (3+ wins)
- ↑↓ Rank change arrows
- 🏆 Tournament leader
- 👑 Pool creator (private pools)
- ✓ Verified location (regional)

## Performance Optimization

### Caching Strategy
- Quick Play: No cache (always fresh)
- Regional: 5-minute cache
- Private: 10-minute cache
- Tournament: 1-minute cache during active play

### Query Limits
- Show top 100 for large pools
- "Load more" pagination
- User's position always fetched if outside top 100

### Indexing
Required Firestore indexes:
- `pools.quickplay.daily_date.leaderboard` (profitLoss DESC)
- `pools.regional.state_X.leaderboard` (totalPL DESC)
- `pools.private.poolId.leaderboard` (rank ASC)
- `pools.tournament.tournamentId.leaderboard` (points DESC)

## Implementation Phases

### Phase 1: Basic Structure
- [ ] Create leaderboard screen with 4 tabs
- [ ] Implement navigation from settings
- [ ] Set up basic UI layout

### Phase 2: Quick Play
- [ ] Daily leaderboard reset logic
- [ ] Real-time profit/loss tracking
- [ ] Streak calculation

### Phase 3: Regional
- [ ] Location verification
- [ ] Multi-level filtering (city/state/national)
- [ ] Cumulative stats aggregation

### Phase 4: Private Pools
- [ ] Pool list view
- [ ] Individual pool deep-dive
- [ ] Pool management features

### Phase 5: Tournament
- [ ] Tournament phase tracking
- [ ] Advancement logic
- [ ] Prize distribution display

## Analytics to Track
- Tab usage frequency
- Refresh rate per tab
- Pool participation rates
- Time spent per leaderboard type
- Share/screenshot actions

## Future Enhancements
- Historical leaderboard archives
- Achievement badges
- Leaderboard notifications (passed by friend, new rank milestone)
- Export leaderboard data
- Season-long competitions