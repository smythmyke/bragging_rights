# Combat Sports Implementation Plan

## Overview
This document outlines the comprehensive plan to properly handle combat sports (UFC, PFL, Bellator, Boxing) in the Bragging Rights app, ensuring correct display of events and full fight card functionality.

## Core Requirements
1. **Fetch full fight cards immediately** - When fetching games, get all competitions for combat sports
2. **Store complete fight cards in Firestore** - Other users can access full data without re-fetching
3. **Display as-is for small events** - If event has 1 fight, show it normally
4. **Treat each boxing match as separate** - Use event name which contains marquee bout

## Technical Implementation

### 1. Fix ESPN Direct Service (`espn_direct_service.dart`)

**Remove:**
- The special UFC-only logic that uses `UfcEventService`
- The `UfcEventService` entirely (it only creates fake single fights)

**Update `_parseESPNEvent`:**
```dart
// For combat sports (UFC, PFL, Bellator, Boxing):
if (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING') {
  // Use event name directly (already formatted perfectly)
  String eventTitle = event['name'] ?? '';
  
  // Parse ALL competitions into fights
  List<Map<String, dynamic>> fights = [];
  for (int i = 0; i < competitions.length; i++) {
    // Parse each competition as a fight
    // Determine fight position (main event is last)
    // Store in fights array
  }
  
  // Return GameModel with:
  // - awayTeam: eventTitle (e.g., "UFC Fight Night: Imavov vs. Borralho")
  // - homeTeam: '' (empty for combat sports)
  // - Store fights in customData field for later use
}
```

### 2. Enhance GameModel (`game_model.dart`)

Add fields to store full fight card:
```dart
class GameModel {
  // Existing fields...
  final List<Map<String, dynamic>>? fights; // For combat sports
  final bool isCombatSport;
  final int? totalFights;
  final String? mainEventFighters; // Extracted from last fight
}
```

### 3. Update Firestore Storage

When saving combat sport games:
```dart
// In _saveGameToFirestore
if (game.isCombatSport && game.fights != null) {
  // Save full fight card
  await docRef.set({
    ...game.toMap(),
    'fights': game.fights, // All competitions
    'totalFights': game.fights.length,
    'mainEvent': game.fights.last, // Last fight is main event
    'isCombatSport': true,
  });
}
```

### 4. Fix Navigation (`pool_selection_screen.dart`)

When navigating to fight card:
```dart
if (isCombatSport) {
  // Fetch the game with full fight data from Firestore
  final gameDoc = await FirebaseFirestore.instance
    .collection('games')
    .doc(gameId)
    .get();
  
  final fights = gameDoc.data()?['fights'] ?? [];
  
  // Convert to FightCardEventModel with ALL fights
  final event = FightCardEventModel(
    id: gameId,
    eventName: gameTitle,
    fights: _convertToFightObjects(fights),
    gameTime: gameTime,
    status: status,
    totalFights: fights.length,
    mainEventTitle: _extractMainEventTitle(fights),
  );
  
  Navigator.pushNamed(context, '/fight-card-grid', 
    arguments: {'event': event, 'poolId': poolId, 'poolName': poolName}
  );
}
```

### 5. Update Fight Card Grid (`fight_card_grid_screen.dart`)

- Display all fights in grid
- Show proper labels based on position:
  - Last fight: Main Event (5 rounds)
  - Second to last: Co-Main Event (3 rounds)
  - Middle fights: Main Card (3 rounds)
  - Early fights: Preliminaries (3 rounds)
- Handle events with 1 fight normally
- Save all picks to Firestore

## Data Flow

### 1. Fetch Phase
```
ESPN API → Parse all competitions → Store in GameModel.fights
```

### 2. Storage Phase
```
GameModel with fights → Firestore (complete fight card stored)
```

### 3. Display Phase
```
Games Page: Show event.name (e.g., "UFC Fight Night: Imavov vs. Borralho")
Pool Join: Load fights from Firestore → Navigate to grid
```

### 4. Betting Phase
```
Fight Card Grid: Display all fights → User makes picks → Save to Firestore
```

## Fight Position Logic

For a card with N fights (indexed 0 to N-1):
- **Fight N-1** (last): Main Event - 5 rounds
- **Fight N-2**: Co-Main Event - 3 rounds
- **Fights N-5 to N-3**: Main Card - 3 rounds
- **Fights 0 to N-6**: Preliminaries - 3 rounds

## Benefits

1. **Performance:** Full data fetched once, cached in Firestore
2. **Consistency:** All combat sports handled identically
3. **Correctness:** Event names display properly (main event fighters)
4. **Completeness:** Users see entire fight card for betting
5. **Efficiency:** Other users get cached data from Firestore

## Implementation Order

1. **First:** Fix `_parseESPNEvent` to use event name and parse all competitions
2. **Second:** Update GameModel to store fights array
3. **Third:** Modify Firestore storage to save complete fight cards
4. **Fourth:** Fix navigation to pass full fight data
5. **Fifth:** Ensure fight card grid displays all fights properly
6. **Finally:** Remove `UfcEventService` (no longer needed)

## Testing Checklist

- [ ] UFC events display correctly on Games page
- [ ] PFL events display correctly
- [ ] Bellator events display correctly (when available)
- [ ] Boxing events display correctly (when available)
- [ ] Full fight card loads when joining pool
- [ ] All fights appear in grid with correct positions
- [ ] Fight picks can be made and saved
- [ ] Cached data loads for subsequent users
- [ ] Single-fight events work normally

## Expected Outcomes

- Games page shows "UFC Fight Night: Imavov vs. Borralho" instead of individual fighter names
- Clicking on combat sport event and joining pool navigates to fight card grid
- Fight card grid shows all 13 fights (for example) with proper labels
- Users can make picks for entire card
- Data is efficiently cached and shared