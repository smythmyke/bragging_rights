# Auto Pool Creation & Join Implementation Plan

## Overview
Reduce user friction in the pool joining flow by automatically creating and joining pools when none are available for a game.

## Current Flow (3 Steps)
1. User navigates to `PoolSelectionScreen`
2. User clicks "Create Pool" button
3. User clicks "Join" button on newly created pool
4. User arrives at bet selection screen

## Target Flow (0 Steps)
1. User navigates to `PoolSelectionScreen`
2. System auto-creates pool if none exist
3. System auto-joins user to pool
4. User automatically navigated to bet selection screen

---

## Implementation Steps

### Step 1: Add Auto-Create State Variable
**File:** `lib/screens/pools/pool_selection_screen.dart`

Add state variable to track if auto-creation has been attempted:
```dart
bool _hasAttemptedAutoCreate = false;
```

### Step 2: Create Auto-Create Helper Method
**File:** `lib/screens/pools/pool_selection_screen.dart`

Create new method `_autoCreateAndJoinPool()`:
- Check if user has sufficient balance (>= 25 BR)
- Call `_poolService.createPool()` with default settings:
  - Buy-in: 25 BR
  - Max players: 10
  - Min players: 2
  - Type: `PoolType.quick`
  - Name: `${widget.gameTitle} - QUICK`
- On success, immediately call auto-join logic
- On failure, set flag to prevent retry and show manual create button

### Step 3: Create Auto-Join Helper Method
**File:** `lib/screens/pools/pool_selection_screen.dart`

Create new method `_autoJoinAndNavigate(String poolId, String poolName, int buyIn)`:
- Call `_poolService.joinPoolWithResult(poolId, buyIn)`
- On success, navigate to appropriate screen:
  - Combat sports → `/fight-card-grid`
  - Team sports → `/bet-selection`
- Pass all required navigation arguments
- No loading dialogs or confirmation modals (silent operation)

### Step 4: Modify Quick Play StreamBuilder
**File:** `lib/screens/pools/pool_selection_screen.dart`
**Location:** Lines ~400-447

Add logic to detect empty pool list and trigger auto-creation:
```dart
if (pools.isEmpty && !_hasAttemptedAutoCreate) {
  // Trigger auto-create and join
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _autoCreateAndJoinPool();
  });

  // Show loading indicator while auto-creating
  return const Center(
    child: CircularProgressIndicator(),
  );
}
```

### Step 5: Update Flag After Attempt
Set `_hasAttemptedAutoCreate = true` in `_autoCreateAndJoinPool()` to prevent infinite loops.

### Step 6: Handle Edge Cases

#### Insufficient Balance
- If user balance < 25 BR, show message:
  ```
  "Insufficient balance to join pool. You need 25 BR."
  ```
- Display manual "Create Pool" button as fallback

#### Pool Creation Failure
- On failure, set `_hasAttemptedAutoCreate = true`
- Show manual "Create Pool" button
- Optional: Show subtle error message

#### Race Condition (Multiple Users)
- If pool appears during creation, cancel auto-create
- Use existing pool instead
- Check pool list again after creation completes

---

## Files to Modify

### Primary File
- `lib/screens/pools/pool_selection_screen.dart`
  - Add state variables (lines ~39-50)
  - Add `_autoCreateAndJoinPool()` method
  - Add `_autoJoinAndNavigate()` method
  - Modify Quick Play StreamBuilder (lines ~400-447)

---

## Technical Details

### Default Pool Settings
```dart
buyIn: 25,
maxPlayers: 10,
minPlayers: 2,
type: PoolType.quick,
name: '${widget.gameTitle} - QUICK',
```

### Navigation Routes
- **Combat Sports:** `/fight-card-grid`
  - Arguments: `gameId`, `gameTitle`, `sport`, `poolName`, `poolId`

- **Team Sports:** `/bet-selection`
  - Arguments: `gameId`, `gameTitle`, `sport`, `poolName`, `poolId`, `gameTime`, `oddsApiSportKey`

### Balance Check
```dart
final balance = _cachedBalance ?? 0;
if (balance < 25) {
  // Show insufficient balance message
  // Don't auto-create
}
```

---

## User Experience Improvements

### Before
- 3 manual clicks required
- ~15-20 seconds to start making picks
- Potential confusion about pool creation

### After
- 0 clicks required (when no pools exist)
- ~2-3 seconds to start making picks
- Seamless transition to bet selection
- Manual creation still available for custom settings

---

## Testing Checklist

- [ ] Auto-create works when 0 pools exist
- [ ] Auto-join succeeds after creation
- [ ] Navigation works for combat sports (MMA, Boxing)
- [ ] Navigation works for team sports (NBA, NFL, etc.)
- [ ] Insufficient balance shows error message
- [ ] Pool creation failure shows manual button
- [ ] No infinite loops if creation fails
- [ ] Manual "Create Pool" button still works
- [ ] Existing pools don't trigger auto-create
- [ ] User already in pool navigates correctly

---

## Implementation Order

1. Add state variable `_hasAttemptedAutoCreate`
2. Create `_autoCreateAndJoinPool()` method
3. Create `_autoJoinAndNavigate()` method
4. Modify Quick Play StreamBuilder to detect empty pools
5. Test with various sports and edge cases
6. Verify balance checks work correctly
7. Confirm navigation works for all sport types

---

## Notes

- Keep existing manual "Create Pool" functionality intact
- No UI changes required beyond loading states
- Reuse existing service methods (`createPool`, `joinPoolWithResult`)
- Silent operation - no success toasts or confirmation dialogs
- Only applies to Quick Play tab, not Tournament or Season tabs
