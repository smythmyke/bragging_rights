# MMA/Boxing ESPN-Only Integration Build Plan

## Overview
Transition MMA and Boxing sports from dual API approach (Odds API + ESPN) to ESPN-only data source with custom scoring system.

## Goals
- Eliminate fighter name mapping issues
- Fix duplicate selection bugs in Quick Pick
- Provide fighter images and profiles immediately
- Simplify data flow and reduce API calls
- Create engaging skill-based scoring system

## Current Issues to Resolve
1. Fighter IDs from Odds API are just names, not ESPN IDs
2. No event grouping in Odds API requires synthetic event creation
3. Fighter data (images, stats) requires name-to-ESPN ID mapping
4. Duplicate fighter selection in Quick Pick interface

## Phase 1: ESPN Data Integration (Priority: HIGH)

### 1.1 Update MMA Service
**File**: `lib/services/mma_service.dart`
- [ ] Add method `getFullEventWithFights(eventId)` to fetch complete card
- [ ] Ensure all competition IDs are included
- [ ] Add fighter ESPN IDs to each bout
- [ ] Cache full event data in Firestore
- [ ] Add method to list upcoming events with basic info

### 1.2 Update Game Model for MMA
**File**: `lib/models/game_model.dart`
- [ ] Add `isCombatSport` flag
- [ ] Add `espnEventId` field for direct ESPN reference
- [ ] Add `competitions` array to store bout IDs
- [ ] Ensure proper typing for MMA-specific fields

### 1.3 Update Fight Card Model
**File**: `lib/models/fight_card_model.dart`
- [ ] Add ESPN competition ID to Fight class
- [ ] Add ESPN athlete IDs for both fighters
- [ ] Ensure unique fight IDs using ESPN competition IDs
- [ ] Add card position enum (main, co-main, main-card, prelims)

## Phase 2: Custom Scoring System (Priority: HIGH)

### 2.1 Create Scoring Configuration
**New File**: `lib/models/mma_scoring_config.dart`
```dart
class MMAScoring {
  // Base Points
  static const int CORRECT_WINNER = 10;
  static const int CORRECT_METHOD = 5;
  static const int CORRECT_ROUND = 3;

  // Position Multipliers
  static const double MAIN_EVENT_MULTIPLIER = 2.0;
  static const double CO_MAIN_MULTIPLIER = 1.5;
  static const double MAIN_CARD_MULTIPLIER = 1.2;
  static const double PRELIMS_MULTIPLIER = 1.0;

  // Method Types
  enum FinishMethod {
    decision,    // UD, SD, MD
    koTko,       // KO or TKO
    submission,  // All submissions
    other        // DQ, NC, etc.
  }
}
```

### 2.2 Implement Scoring Service
**New File**: `lib/services/mma_scoring_service.dart`
- [ ] Calculate points based on pick accuracy
- [ ] Apply position multipliers
- [ ] Handle method and round bonuses
- [ ] Store scoring breakdowns for transparency

## Phase 3: Pool Generation Updates (Priority: MEDIUM)

### 3.1 Update Pool Generation Service
**File**: `lib/services/pool_generation_service.dart`
- [ ] Use ESPN events directly for MMA/Boxing
- [ ] Remove Odds API grouping logic for combat sports
- [ ] Store ESPN event ID as primary reference
- [ ] Ensure fight IDs are ESPN competition IDs

### 3.2 Update Pool Model
**File**: `lib/models/pool_model.dart`
- [ ] Add `espnEventId` field
- [ ] Add `scoringType` field (odds-based vs skill-based)
- [ ] Add metadata for MMA-specific pool settings

## Phase 4: Quick Pick Interface (Priority: HIGH)

### 4.1 Fix Fighter Selection
**File**: `lib/screens/pools/quick_pick_screen.dart`
- [ ] Use ESPN athlete IDs directly (no mapping)
- [ ] Fix duplicate selection issue with unique fight IDs
- [ ] Load fighter data using ESPN IDs

### 4.2 Enhanced Fighter Display
- [ ] Display fighter headshots from ESPN
- [ ] Show fighter records
- [ ] Add method selection (KO, Sub, Decision)
- [ ] Add round selection for finish predictions
- [ ] Show card position indicator

### 4.3 UI Components
```dart
Fighter Card should display:
- Fighter Image (from ESPN)
- Fighter Name
- Fighter Record (W-L-D)
- Country Flag
- Selection State
- Method Prediction (optional)
- Round Prediction (optional)
```

## Phase 5: Data Migration (Priority: LOW)

### 5.1 Firestore Updates
- [ ] Create new collection for ESPN event cache
- [ ] Update existing pools to new structure
- [ ] Migrate historical data if needed
- [ ] Clean up old Odds API cache

### 5.2 Cache Management
- [ ] Set appropriate TTL for ESPN event data
- [ ] Implement cache invalidation strategy
- [ ] Add manual refresh capability

## Phase 6: Testing & Validation (Priority: HIGH)

### 6.1 Unit Tests
- [ ] Test ESPN event fetching
- [ ] Test scoring calculations
- [ ] Test fighter data retrieval
- [ ] Test pool generation

### 6.2 Integration Tests
- [ ] Test complete Quick Pick flow
- [ ] Test pool creation with ESPN data
- [ ] Test scoring after event completion
- [ ] Test fighter image loading

### 6.3 Edge Cases
- [ ] Handle fighters with no ESPN profile
- [ ] Handle cancelled/postponed fights
- [ ] Handle draw results
- [ ] Handle no-contest situations

## Implementation Order

1. **Week 1**: ESPN Data Integration
   - Update MMA Service
   - Update models
   - Test ESPN data fetching

2. **Week 1-2**: Fix Quick Pick
   - Fix duplicate selection bug
   - Implement ESPN ID usage
   - Add fighter images

3. **Week 2**: Scoring System
   - Implement scoring logic
   - Add UI for method/round selection
   - Test scoring calculations

4. **Week 2-3**: Pool Generation
   - Update to use ESPN events
   - Remove Odds API dependency
   - Test pool creation

5. **Week 3**: Testing & Polish
   - Complete test suite
   - Fix edge cases
   - Performance optimization

## Success Metrics

- [ ] Fighter images display correctly in Quick Pick
- [ ] No duplicate selection issues
- [ ] Pools generate from ESPN events directly
- [ ] Scoring system calculates correctly
- [ ] 50% reduction in API calls
- [ ] Improved user experience with fighter profiles

## Rollback Plan

If issues arise:
1. Keep Odds API integration code (don't delete)
2. Add feature flag for ESPN-only mode
3. Can revert to dual-API approach if needed
4. Maintain backwards compatibility with existing pools

## Future Enhancements

- Add fighter statistics display
- Add head-to-head history
- Add fight predictions/analysis
- Add live fight tracking
- Expand to other MMA promotions (Bellator, ONE, PFL)
- Add prop bets (fight duration, specific round KO, etc.)