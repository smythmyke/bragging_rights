# MOCK DATA REMOVAL PLAN

## Overview
This plan outlines the complete removal of all mock/hardcoded data from the Bragging Rights app to prepare for production deployment. Only real data from Firestore and APIs will be displayed.

## Current Status & Required Changes

### 1. HOME SCREEN (`home_screen.dart`)
**Status:** ✅ Partially complete
- **Completed:** Removed mock games ("Lakers vs Celtics")
- **Still Needed:** Remove any hardcoded countdown timers or placeholder data

### 2. POOL SELECTION SCREEN (`pool_selection_screen_v2.dart`)
**Status:** ✅ Partially complete
- **Completed:** Changed `_useMockData` flag to `false`
- **Still Needed:**
  - Remove `_initializeMockPools()` function entirely
  - Remove all mock pool variables (`_mockQuickPools`, `_mockRegionalPools`, `_mockPrivatePools`, `_mockTournamentPools`)
  - Remove `_buildMockQuickPlayList()` function
  - Update UI to show "No pools available" when no real data exists

### 3. BET SELECTION SCREEN (`bet_selection_screen.dart`)
**Current Issues:**
- Hardcoded "Lakers vs Celtics" throughout
- Hardcoded "McGregor vs Chandler" for MMA
- Hardcoded player names (LeBron, AD, Tatum, Jaylen Brown)
- Hardcoded odds and betting lines
- Hardcoded prop bets

**Solution:** 
- Pass actual game data through navigation parameters
- Show "No betting data available" if game data missing
- Remove all hardcoded team/player references
- Create dynamic bet cards based on real odds data

### 4. GAME DETAIL SCREEN (`game_detail_screen.dart`)
**Current Issues:**
- Hardcoded "Lakers vs Celtics" in title
- Mock community picks percentages (65/35)
- Mock odds data
- Mock team stats (win streaks, home/away records)
- Mock head-to-head data
- Mock player stats
- Mock chat messages

**Solution:**
- Fetch real game data from Firestore
- Show placeholder UI when no data available
- Remove all hardcoded statistics

### 5. ENHANCED POOL SCREEN (`enhanced_pool_screen.dart`)
**Current Issues:**
- Mock pool data comment mentions
- Hardcoded "Lakers" vs "Celtics" odds display (62% vs 38%)

**Solution:**
- Remove mock data loading
- Use real pool data from Firestore
- Display actual pool participants and odds

### 6. EDGE SCREEN (`edge_screen.dart`)
**Current Issues:**
- Hardcoded social sentiment ("78% positive on Lakers")
- Mock insider information ("Celtics flew in late", "Team dinner drama")
- Mock betting line movements
- Hardcoded team references

**Solution:**
- Show "Premium insights coming soon" placeholder
- Remove all hardcoded team references
- Keep UI structure but populate with real data when available

### 7. SERVICES TO UPDATE
- **`pool_service.dart`**: Ensure no fallback mock data
- **`settlement_service.dart`**: Remove any test data references
- **`team_logo_service.dart`**: Ensure it handles missing teams gracefully

## Implementation Strategy

### Phase 1: Remove Mock Data Storage
1. Delete all mock data variables and initialization functions
2. Remove mock data generation methods
3. Clean up unused imports
4. Remove hardcoded team/player names

### Phase 2: Update UI Components
1. Replace hardcoded values with dynamic data from props/navigation
2. Add "No data available" states for all screens
3. Implement loading states while fetching real data
4. Create consistent empty state messages

### Phase 3: Data Flow Updates
1. Ensure all screens receive game data through navigation parameters
2. Update navigation calls to pass actual game/pool/bet data
3. Add proper error handling for missing data
4. Implement null safety checks

### Phase 4: Placeholder UI
1. Create consistent "empty state" components
2. Add informative messages when no real data exists
3. Ensure app doesn't crash when data is missing
4. Use shimmer effects or skeleton loaders during data fetching

## Breaking Changes Expected
1. **Bet selection** won't show any bets without real game odds data
2. **Pool selection** will show empty until pools are created in Firestore
3. **Game details** will be blank without game data from API
4. **Edge/premium features** will show "coming soon" message
5. **Chat/social features** will show no messages until users interact

## Implementation Priority Order
1. **Critical**: Bet Selection Screen (most mock data, core functionality)
2. **High**: Pool Selection Screen (already partially done)
3. **High**: Game Detail Screen (heavily mocked)
4. **Medium**: Edge Screen (premium feature)
5. **Low**: Enhanced Pool Screen (dependent on pool data)

## Files to Modify
```
lib/screens/betting/bet_selection_screen.dart
lib/screens/pools/pool_selection_screen_v2.dart
lib/screens/pools/enhanced_pool_screen.dart
lib/screens/game/game_detail_screen.dart
lib/screens/premium/edge_screen.dart
lib/screens/home/home_screen.dart
lib/services/pool_service.dart
lib/services/settlement_service.dart
lib/services/team_logo_service.dart
```

## Success Criteria
- [ ] No hardcoded team names (Lakers, Celtics, etc.)
- [ ] No hardcoded player names
- [ ] No mock odds or betting lines
- [ ] No fake statistics or records
- [ ] No mock chat messages
- [ ] App shows appropriate "no data" messages
- [ ] App doesn't crash when data is missing
- [ ] All data comes from Firestore or external APIs

## Post-Implementation Testing
1. Test app with no data in Firestore
2. Test app with partial data
3. Test navigation between screens
4. Verify no crashes occur
5. Ensure loading states work properly
6. Confirm empty states are user-friendly

## Notes
- This is a breaking change that will temporarily reduce app functionality
- Real data must be populated in Firestore for full functionality
- Consider implementing a data seeding script for testing
- Ensure Firebase security rules allow necessary data access