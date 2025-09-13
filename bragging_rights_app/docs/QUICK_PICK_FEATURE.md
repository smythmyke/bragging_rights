# Quick Pick Feature - MMA/Boxing Fight Cards

## Overview
A streamlined, image-based selection interface for casual fans to quickly make fight predictions without needing deep knowledge of odds or statistics.

## Problem Statement
Current fight card selection requires navigating through multiple screens, viewing detailed stats, and understanding betting odds. This creates friction for casual fans who just want to participate socially.

## Solution
Dual-mode approach offering both Quick Pick (visual/fast) and Detailed Pick (analytical) interfaces.

## Architecture

### Data Structure

#### Firestore Schema
```
firestore/
├── fighters/
│   └── {fighterId}/
│       ├── profile/
│       │   ├── name: String
│       │   ├── nickname: String
│       │   ├── record: String (e.g., "25-1-0")
│       │   ├── weightClass: String
│       │   ├── reach: Double
│       │   ├── stance: String
│       │   ├── age: Int
│       │   ├── camp: String
│       │   ├── headshotUrl: String
│       │   ├── flagUrl: String
│       │   ├── lastUpdated: Timestamp
│       │   └── espnId: String
│       └── stats/
│           ├── wins: Int
│           ├── losses: Int
│           ├── draws: Int
│           ├── kos: Int
│           ├── submissions: Int
│           ├── decisions: Int
│           └── lastFight: Timestamp
```

#### Update Frequency
- **Profile data**: 30-day cache (rarely changes)
- **Stats/Record**: Post-fight updates (check lastFight timestamp)
- **Images**: 90-day cache (stable URLs)

### User Interface

#### Mode Selection
```
┌─────────────────────────────┐
│    UFC 311 - Choose Mode    │
├─────────────────────────────┤
│                             │
│  [🎯] Quick Pick            │
│  Tap fighter photos         │
│  ⏱️ 30 seconds              │
│                             │
│  [📊] Detailed Analysis     │
│  View odds & stats          │
│  ⏱️ 5+ minutes              │
│                             │
└─────────────────────────────┘
```

#### Quick Pick Interface
```
┌─────────────────────────────┐
│  UFC 311 - Quick Picks (5/12)│
├─────────────────────────────┤
│      🏆 MAIN EVENT          │
├─────────────────────────────┤
│  [Photo]        [Photo]     │
│  Makhachev    Tsarukyan     │
│   25-1          22-3        │
│     ✓                       │
├─────────────────────────────┤
│      CO-MAIN EVENT          │
├─────────────────────────────┤
│  [Photo]        [Photo]     │
│  Prochazka      Hill        │
│   30-4          12-2        │
│                  ✓          │
├─────────────────────────────┤
│      MAIN CARD              │
├─────────────────────────────┤
│  [Photo]        [Photo]     │
│  Dvalishvili  Nurmagomedov  │
│   17-4          17-0        │
│     ✓                       │
└─────────────────────────────┘
    [Submit Picks (5/12)]
```

### Implementation Plan

#### Phase 1: Fighter Data Service
```dart
class FighterDataService {
  // Fetch fighter profile from ESPN
  Future<FighterProfile> getFighterProfile(String espnId);
  
  // Cache in Firestore
  Future<void> cacheFighterData(FighterProfile profile);
  
  // Get with cache check
  Future<FighterProfile> getFighterWithCache(String fighterId);
}
```

#### Phase 2: Quick Pick Screen
```dart
class QuickPickScreen extends StatefulWidget {
  final FightCardEventModel event;
  final Pool pool;
  
  // Track selections
  Map<String, String> selections = {};
  
  // Submit all at once
  Future<void> submitAllPicks();
}
```

#### Phase 3: Mode Selection
```dart
// In pool_selection_screen.dart
showModalBottomSheet(
  context: context,
  builder: (context) => PickModeSelector(
    onModeSelected: (mode) {
      if (mode == PickMode.quick) {
        Navigator.push(QuickPickScreen());
      } else {
        Navigator.push(FightCardScreen());
      }
    },
  ),
);
```

## User Journey

### Casual Fan Flow
1. Enter pool → See mode selection
2. Choose "Quick Pick" 
3. Scroll through fight card
4. Tap fighter photos to select
5. Submit all picks at once
6. See confirmation

### Power User Flow
1. Enter pool → See mode selection
2. Choose "Detailed Analysis"
3. Navigate existing detailed flow
4. View odds, stats, intel
5. Make informed selections

## Benefits

### For Users
- **Casual fans**: 90% faster pick submission
- **Visual learners**: Photo-based recognition
- **Social players**: Lower barrier to entry
- **Power users**: Existing flow preserved

### For Platform
- **Increased engagement**: More users complete picks
- **Data insights**: Track which mode users prefer
- **Progressive disclosure**: Convert casual → power users
- **Reduced abandonment**: Simpler flow = higher completion

## Success Metrics
- Pick completion rate by mode
- Time to complete picks
- Mode preference by user segment
- Conversion from quick → detailed mode
- User retention by initial mode choice

## Technical Considerations

### Performance
- Batch fetch fighter data (single query for all fighters)
- Image lazy loading with placeholders
- Cache images locally after first load
- Optimistic UI updates for selections

### Compatibility
- Both modes create identical `FightPick` objects
- No changes to scoring/results systems
- Backward compatible with existing pools

### Future Enhancements
- Swipe gestures for confidence levels
- Fighter comparison overlay
- Quick stats tooltip on long press
- Voice selection for accessibility
- Shake to random pick

## Implementation Timeline
1. **Week 1**: Fighter data service + Firestore schema
2. **Week 2**: Quick Pick UI component
3. **Week 3**: Mode selection + navigation
4. **Week 4**: Testing + refinement

## Dependencies
- ESPN API for fighter data
- Firebase Storage for image caching
- Firestore for fighter profiles
- Existing pool/pick infrastructure