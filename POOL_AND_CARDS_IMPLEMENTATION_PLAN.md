# Pool and Cards Implementation Plan

## Overview
This document outlines the implementation plan for enhancing the Bragging Rights pool system with auto-generation, card indicators, and improved UI/UX.

## Phase 1: UI Consistency & Quick Fixes

### 1.1 Fix Bets Tab Card Dimensions
- **Issue**: Quick Play card width doesn't match Active Wagers card dimensions
- **Solution**: Ensure both cards use consistent container constraints and padding
- **Files to modify**:
  - `screens/bets/active_bets_screen.dart`
- **Acceptance Criteria**:
  - All cards in Bets tab have uniform width
  - Consistent padding and margins across card types

## Phase 2: Regional Detection System

### 2.1 IP-Based Geolocation
- **Primary Method**: IP-based location (no permissions required)
- **Service**: Use `http://ip-api.com/json` for free tier
- **Implementation**:
  ```dart
  class LocationService {
    Future<RegionInfo> detectRegion() async {
      // 1. Try IP-based detection
      // 2. Fallback to Platform.localeName
      // 3. Default to "National" if all fail
    }
  }
  ```
- **Data Structure**:
  ```dart
  class RegionInfo {
    String country;
    String state;
    String city;
    String neighborhood;
    RegionalLevel defaultLevel;
  }
  ```

### 2.2 Fallback Strategy
1. **IP Geolocation** → Get country, state, city
2. **Device Locale** → Use `Platform.localeName` if IP fails
3. **User Selection** → Manual region selection in profile
4. **Default** → National level pools only

## Phase 3: Pool Auto-Generation System

### 3.1 Pool Generation Rules
- **Requirement**: Every displayed game must have available pools
- **Pool Types per Game**:
  ```
  Quick Play: 4 tiers ($10, $25, $50, $100)
  Regional: Based on user's detected region
    - Neighborhood (20 max, 15 min)
    - City (50 max, 38 min)
    - State (100 max, 75 min)
    - National (200 max, 150 min)
  Tournament: For playoff/championship games
  Private: User-created on demand
  ```

### 3.2 Minimum Player Requirements (75% Rule)
| Pool Type | Max Players | Min Required (75%) |
|-----------|-------------|-------------------|
| Quick Play Small | 10 | 8 |
| Quick Play Medium | 20 | 15 |
| Quick Play Large | 30 | 23 |
| Quick Play VIP | 40 | 30 |
| Regional Neighborhood | 20 | 15 |
| Regional City | 50 | 38 |
| Regional State | 100 | 75 |
| Regional National | 200 | 150 |
| Tournament | 32 | 24 |
| Private | User-defined | 75% of max |

### 3.3 Pool Generation Triggers
- **On Game Creation**: Generate all pool types for new games
- **On High Demand**: When pool reaches 80% capacity, create duplicate
- **Periodic Check**: Every 5 minutes, ensure pools exist for upcoming games
- **User Action**: "Create Pool" button when all pools full (limit 4 per user)

### 3.4 Pool Service Enhancements
```dart
class PoolService {
  // Existing methods...
  
  Future<void> ensurePoolsForGame(String gameId) async {
    // Check existing pools
    // Generate missing pool types
    // Handle capacity-based duplication
  }
  
  Future<bool> canUserCreatePool(String userId) async {
    // Check user's active pool count (max 4)
    // Return true if under limit
  }
}
```

## Phase 4: Power Cards UI Integration

### 4.1 Navbar Card Indicators
- **Location**: Left of wallet balance
- **Format**: `[🎯 5] [🛡️ 3] | 💰 1,250 BR`
- **Remove**: Refresh icon (keep pull-to-refresh)
- **Categories**:
  - Offensive (🎯): Double Down, Mulligan, Crystal Ball, Copycat
  - Defensive (🛡️): Insurance, Shield, Time Freeze, Split

### 4.2 Card Inventory Pages
- **Navigation**: Tap card indicator → Dedicated inventory page
- **Page Structure**:
  ```
  AppBar: "Offensive Cards" / "Defensive Cards"
  Body: Grid/List of owned cards
  Each Card Shows:
    - Icon & Name
    - Quantity owned
    - When to use
    - Effect description
    - How to activate
  ```

### 4.3 Card Data Model
```dart
class PowerCard {
  final String id;
  final String name;
  final String icon;
  final CardType type; // offensive, defensive
  final String whenToUse;
  final String effect;
  final String howToUse;
  final String rarity; // common, uncommon, rare, legendary
  final int quantity;
}
```

### 4.4 Card Definitions
```dart
// lib/data/card_definitions.dart
const Map<String, PowerCard> cardDefinitions = {
  // Offensive Cards
  'double_down': PowerCard(
    id: 'double_down',
    name: 'Double Down',
    icon: '🎯',
    type: CardType.offensive,
    whenToUse: 'Before halftime',
    effect: 'Double your winnings if your pick wins',
    howToUse: 'Tap card during live game before halftime',
    rarity: 'common',
  ),
  'mulligan': PowerCard(
    id: 'mulligan',
    name: 'Mulligan',
    icon: '🔄',
    type: CardType.offensive,
    whenToUse: 'Before game starts',
    effect: 'Change your pick once',
    howToUse: 'Use in pool details before lock time',
    rarity: 'common',
  ),
  
  // Defensive Cards
  'insurance': PowerCard(
    id: 'insurance',
    name: 'Insurance',
    icon: '🛡️',
    type: CardType.defensive,
    whenToUse: 'Before 4th quarter',
    effect: 'Get 50% refund if you lose',
    howToUse: 'Activate before 4th quarter starts',
    rarity: 'uncommon',
  ),
  'shield': PowerCard(
    id: 'shield',
    name: 'Shield',
    icon: '🛡️',
    type: CardType.defensive,
    whenToUse: 'When targeted',
    effect: 'Block one offensive card used against you',
    howToUse: 'Auto-activates when targeted',
    rarity: 'uncommon',
  ),
};
```

## Phase 5: Shimmer Animation System

### 5.1 Dependencies
```yaml
dependencies:
  flutter_animate: ^4.5.0  # For shimmer effects
  http: ^1.2.0            # For IP geolocation
```

### 5.2 Shimmer Implementation
- **Trigger**: Card shimmers when usable in active game
- **Conditions**:
  ```dart
  bool canUseCard(PowerCard card, GameState game) {
    if (game.status != 'live') return false;
    
    switch(card.id) {
      case 'double_down':
        return game.period < 3; // Before halftime
      case 'insurance':
        return game.period < 4; // Before 4th quarter
      case 'mulligan':
        return game.timeUntilStart > 0; // Before game
      default:
        return false;
    }
  }
  ```

### 5.3 Animation Code
```dart
Widget buildCardIndicator(CardType type, int count, bool canUse) {
  return GestureDetector(
    onTap: () => navigateToCardInventory(type),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: canUse 
          ? type.activeColor.withOpacity(0.2)
          : Colors.grey.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Text(type.icon),
          SizedBox(width: 4),
          Text('$count'),
        ],
      ),
    ),
  ).animate(
    target: canUse ? 1 : 0,
  ).shimmer(
    duration: 2000.ms,
    color: type.activeColor.withOpacity(0.4),
  );
}
```

## Phase 6: Create Pool Feature

### 6.1 Create Pool Button
- **Display Conditions**:
  - All existing pools >90% full OR no pools exist
  - User has <4 active pools
  - Game is >15 minutes from starting
- **Location**: Bottom of each pool tab (Quick Play, Regional, etc.)
- **Style**: Floating action button or card

### 6.2 Pool Creation Flow
```
1. User taps "Create Pool"
2. Check user's active pool count
3. If <4: Show configuration modal
   - Buy-in slider ($5-$500)
   - Max players (10-50)
   - Min players (75% auto-calculated)
   - Power cards toggle
4. If >=4: Show "Max pools reached" message
5. Create pool and auto-join creator
6. Deduct buy-in from wallet
```

### 6.3 User Pool Limits
- **Maximum**: 4 active pools per user
- **Tracking**: Query user's created pools with status='open'
- **Display**: Show count in create button (e.g., "Create Pool (2/4)")

## Phase 7: Database Structure

### 7.1 User Cards Collection
```
firestore:
  users/
    {userId}/
      cards/
        offensive/
          {cardId}: {
            type: "double_down",
            quantity: 3,
            acquiredAt: timestamp,
            lastUsed: timestamp
          }
        defensive/
          {cardId}: {
            type: "insurance",
            quantity: 2,
            acquiredAt: timestamp,
            lastUsed: timestamp
          }
```

### 7.2 Pool Metadata Updates
```
pools/
  {poolId}/
    // Existing fields...
    generationType: "auto" | "user_created"
    creatorId: userId (if user_created)
    region: "neighborhood" | "city" | "state" | "national"
    fillPercentage: 0-100
    minimumRequired: number (75% of max)
```

## Implementation Priority

### Week 1
1. ✅ Fix Bets tab card dimensions
2. ✅ Implement IP-based regional detection
3. ✅ Create pool auto-generation for all games
4. ✅ Add 75% minimum player rule

### Week 2
5. ⬜ Replace refresh icon with card indicators
6. ⬜ Implement card inventory pages
7. ⬜ Add shimmer animations
8. ⬜ Create pool button with limits

### Week 3
9. ⬜ Testing and refinement
10. ⬜ Performance optimization
11. ⬜ Error handling improvements

## Success Metrics

- **Pool Availability**: 100% of games have joinable pools
- **Pool Fill Rate**: >75% of pools reach minimum players
- **Card Visibility**: Users check card inventory >3x per session
- **User Pool Creation**: 20% of active users create custom pools
- **Regional Accuracy**: 90% correct region detection

## Testing Checklist

### Pool System
- [ ] Pools auto-generate for all games
- [ ] 75% minimum rule triggers activation/cancellation
- [ ] Duplicate pools created at 80% capacity
- [ ] User can create max 4 pools
- [ ] Regional pools match user location

### Card System
- [ ] Card indicators show correct counts
- [ ] Cards shimmer when usable
- [ ] Inventory pages display all card details
- [ ] Tapping indicators navigates correctly
- [ ] Card quantities update after use

### UI/UX
- [ ] All cards have consistent dimensions
- [ ] Navbar properly displays cards and wallet
- [ ] Create pool button shows/hides correctly
- [ ] Pull-to-refresh still works
- [ ] Animations perform smoothly

## Notes

- Pool timing/scheduling to be discussed and implemented separately
- Notification system deferred to future phase
- Card shop/marketplace planned for future update
- Tournament bracket system needs separate design phase