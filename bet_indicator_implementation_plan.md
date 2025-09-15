# Bet Indicator Implementation Plan
## Corner Ribbon Design with Persistence

### Overview
Implement a corner ribbon indicator that shows "BET PLACED" on game cards where users have active bets, with persistent storage to maintain state across app sessions.

---

## Phase 1: Data Structure & Storage Setup

### 1.1 Create Bet Tracking Model
**File:** `lib/models/user_bet_status.dart`
```dart
class UserBetStatus {
  final String gameId;
  final String userId;
  final DateTime betPlacedAt;
  final List<String> poolIds;
  final double totalAmount;
  final bool isActive;

  // Constructor, fromMap, toMap methods
}
```

### 1.2 Local Storage Service
**File:** `lib/services/bet_tracking_service.dart`
- Use `shared_preferences` for local caching
- Store bet status as JSON strings
- Key format: `user_bets_${userId}_${date}`
- Methods:
  ```dart
  - Future<void> saveBetStatus(String gameId, UserBetStatus status)
  - Future<UserBetStatus?> getBetStatus(String gameId)
  - Future<Map<String, UserBetStatus>> getAllBetStatuses()
  - Future<void> clearOldBetStatuses() // Clean up bets older than 30 days
  - Future<void> syncWithFirestore() // Sync local with cloud
  ```

### 1.3 Firestore Integration
**Collection Structure:**
```
users/
  {userId}/
    active_bets/
      {gameId}/
        - betPlacedAt: timestamp
        - poolIds: array
        - totalAmount: number
        - lastUpdated: timestamp
        - gameDate: timestamp
        - sport: string
```

---

## Phase 2: UI Implementation

### 2.1 Corner Ribbon Widget
**File:** `lib/widgets/bet_placed_ribbon.dart`
```dart
class BetPlacedRibbon extends StatelessWidget {
  final bool isVisible;
  final String text;

  Widget build() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.neonGreen, AppTheme.primaryCyan],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          boxShadow: AppTheme.neonGlow(
            color: AppTheme.neonGreen,
            intensity: 0.4,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          'BET PLACED',
          style: TextStyle(
            color: AppTheme.deepBlue,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
```

### 2.2 Update Game Card Widget
**File:** `lib/screens/games/all_games_screen.dart`
- Add Stack wrapper to game cards
- Position ribbon in top-right corner
- Check bet status for each game
- Update _buildGameCard method:
  ```dart
  Stack(
    children: [
      Card(...), // Existing card
      if (hasBet) BetPlacedRibbon(),
    ],
  )
  ```

---

## Phase 3: State Management

### 3.1 Bet Status Provider
**File:** `lib/providers/bet_status_provider.dart`
```dart
class BetStatusProvider extends ChangeNotifier {
  final BetTrackingService _trackingService;
  Map<String, UserBetStatus> _activeBets = {};

  // Load bet statuses on init
  Future<void> loadBetStatuses()

  // Check if game has bet
  bool hasActiveBet(String gameId)

  // Add new bet status
  Future<void> addBetStatus(gameId, poolIds, amount)

  // Remove bet status (when game ends)
  Future<void> removeBetStatus(String gameId)

  // Sync with Firestore
  Future<void> syncBetStatuses()
}
```

### 3.2 Integration Points
1. **When Bet is Placed:**
   - `bet_selection_screen.dart` - After successful bet submission
   - Update local storage immediately
   - Queue Firestore sync

2. **When App Launches:**
   - Load cached bet statuses
   - Sync with Firestore in background
   - Clean up old/expired bets

3. **When Returning to Games Screen:**
   - Check loaded bet statuses
   - Display ribbons accordingly

---

## Phase 4: Data Flow

### 4.1 Bet Placement Flow
```
1. User places bet in bet_selection_screen
   ↓
2. Save to Firestore pools collection (existing)
   ↓
3. Save to user's active_bets collection (new)
   ↓
4. Update local storage cache
   ↓
5. Notify BetStatusProvider
   ↓
6. UI updates with ribbon
```

### 4.2 App Launch Flow
```
1. App starts
   ↓
2. Load user authentication
   ↓
3. Load cached bet statuses from SharedPreferences
   ↓
4. Display UI with cached data (fast)
   ↓
5. Sync with Firestore in background
   ↓
6. Update UI if changes detected
```

---

## Phase 5: Implementation Steps

### Step 1: Setup Storage (Day 1)
- [ ] Add shared_preferences dependency
- [ ] Create UserBetStatus model
- [ ] Implement BetTrackingService
- [ ] Add Firestore collection rules

### Step 2: Create UI Components (Day 1)
- [ ] Build BetPlacedRibbon widget
- [ ] Test ribbon positioning and styling
- [ ] Ensure ribbon matches Cyber Blue theme

### Step 3: Integrate with Game Cards (Day 2)
- [ ] Update all_games_screen.dart
- [ ] Add Stack wrapper to game cards
- [ ] Connect to bet status data

### Step 4: Hook into Bet Placement (Day 2)
- [ ] Update bet_selection_screen.dart
- [ ] Save bet status on successful submission
- [ ] Handle pool selection tracking

### Step 5: Add State Management (Day 3)
- [ ] Create BetStatusProvider
- [ ] Integrate with main app
- [ ] Handle loading states

### Step 6: Testing & Optimization (Day 3)
- [ ] Test persistence across app restarts
- [ ] Verify Firestore sync
- [ ] Handle edge cases (offline, errors)
- [ ] Performance optimization

---

## Technical Considerations

### Performance
- Cache bet statuses locally for instant display
- Lazy load from Firestore
- Use pagination for users with many bets
- Clean up old data regularly

### Offline Support
- SharedPreferences works offline
- Queue Firestore operations for when online
- Show cached data immediately

### Data Cleanup
- Remove bet statuses for completed games after 7 days
- Archive historical betting data
- Implement automatic cleanup on app launch

### Security Rules
```javascript
// Firestore Rules
match /users/{userId}/active_bets/{gameId} {
  allow read, write: if request.auth.uid == userId;
}
```

---

## Alternative Considerations

### Why Not Just Query Existing Pools?
- Performance: Querying all pools for every game is expensive
- Speed: Local cache provides instant display
- Offline: Works without internet connection
- Scalability: Dedicated bet tracking scales better

### Future Enhancements
1. Show bet amount on ribbon
2. Different ribbon colors for different bet types
3. Animation when new bet is placed
4. Quick view of bet details on tap
5. Filter to show only games with bets

---

## Dependencies Required
```yaml
dependencies:
  shared_preferences: ^2.2.2
  provider: ^6.1.1  # If not already added
```

---

## Success Metrics
- Ribbon appears within 100ms of screen load
- Persists across app restarts
- Syncs accurately with Firestore
- No performance degradation with 100+ bets
- Works offline and syncs when online