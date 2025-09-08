# Performance and Navigation Issues

## Date: 2025-09-08

## 1. CRITICAL PERFORMANCE ISSUES (App Freezing)

### Main Problems Identified:

#### A. Excessive API Calls
- **Issue**: The app is repeatedly fetching odds data for games in rapid succession
- **Evidence**: Logs show hundreds of "Fetching odds from ESPN" calls for the same games
- **Impact**: Network congestion, battery drain, UI freezing

#### B. InfoEdgeCarousel Excessive Rebuilds
- **Issue**: The widget is constantly rebuilding without state changes
- **Evidence**: "Building Winner (Moneyline), current page: 1" appears dozens of times consecutively
- **Impact**: UI thread blocking, poor scrolling performance

#### C. Type Casting Errors in Odds Fetching
- **Issue**: `type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>'` 
- **Location**: NFL odds fetching from ESPN API
- **Impact**: Failed API calls trigger retry loops

#### D. Memory Cache Inefficiency
- **Issue**: Even when data is cached ("Memory cache hit"), processing continues
- **Impact**: Unnecessary computation despite having cached data

### Root Causes:
1. Odds enrichment service appears to be running in an infinite loop or being triggered by every widget rebuild
2. Improper state management causing unnecessary rebuilds
3. Network connectivity issues causing Firestore retry loops
4. Missing debouncing/throttling on API calls

### Recommended Fixes:
1. Implement debouncing for odds fetching (minimum 30-second intervals)
2. Add `AutomaticKeepAliveClientMixin` to prevent unnecessary rebuilds
3. Fix the type casting error in ESPN odds parsing
4. Implement proper error boundaries to prevent retry loops
5. Add request deduplication to prevent multiple simultaneous calls for same data

## 2. NAVIGATION IMPROVEMENTS NEEDED

### Current Swipe Navigation Status:

#### Where Swipe Navigation EXISTS:
- `PageView` widgets in:
  - Bet slip widget
  - Info edge carousel
- `Dismissible` widgets in:
  - Transaction history screen (swipe to dismiss)

#### Where Swipe Navigation is MISSING:
1. **No swipe-back navigation** between screens
   - Cannot swipe back from OptimizedGamesScreen to Games tab
   - Cannot swipe back from pool selection to games
   - Cannot swipe back from bet selection screens

2. **No swipe between tabs** in HomeScreen
   - Must use bottom navigation bar to switch between Games, Bets, Pools, Edge, More
   - Industry standard is to allow swiping between adjacent tabs

3. **No gesture navigation** in list views
   - Cannot swipe between game details
   - Cannot swipe between different pools

### Recommended Navigation Enhancements:

#### Priority 1 (Easy wins):
```dart
// Add to all detail screens:
- Wrap Scaffold with GestureDetector or use PopScope
- Implement iOS-style swipe-from-edge gesture
- Material Design swipe-back for Android
```

#### Priority 2 (Tab navigation):
```dart
// Replace IndexedStack with PageView in HomeScreen:
PageView(
  controller: _pageController,
  onPageChanged: (index) => setState(() => _selectedIndex = index),
  children: [
    _buildGamesTab(),
    _buildBetsTab(),
    _buildPoolsTab(),
    _buildEdgeTab(),
    _buildMoreTab(),
  ],
)
```

#### Priority 3 (Advanced gestures):
- Swipe up/down for refreshing lists
- Pinch to zoom on charts/statistics
- Long press for quick actions on games/bets

## 3. FILES TO MODIFY

### For Performance Fixes:
1. `/lib/services/game_odds_enrichment_service.dart` - Add debouncing
2. `/lib/widgets/info_edge_carousel.dart` - Fix excessive rebuilds
3. `/lib/services/espn_direct_service.dart` - Fix type casting error
4. `/lib/screens/games/optimized_games_screen.dart` - Add KeepAlive mixin

### For Navigation Improvements:
1. `/lib/screens/home/home_screen.dart` - Add PageView for tabs
2. `/lib/screens/games/optimized_games_screen.dart` - Add swipe-back
3. `/lib/screens/pools/pool_selection_screen.dart` - Add swipe-back
4. `/lib/screens/betting/bet_selection_screen.dart` - Add swipe-back

## 4. TESTING CHECKLIST

After implementing fixes:
- [ ] App loads without freezing
- [ ] Games list scrolls smoothly
- [ ] Odds load once and cache properly
- [ ] No repeated API calls for same data
- [ ] Swipe-back works on all detail screens
- [ ] Can swipe between main tabs
- [ ] Memory usage remains stable
- [ ] Network requests are minimized

## 5. MONITORING

Add logging for:
- API call frequency (should be max 1 per game per 30 seconds)
- Widget rebuild count (should only rebuild on actual state changes)
- Memory usage over time
- Network request count per session

## Notes:
- The app is currently making 100+ API calls per minute when it should make <10
- Users are experiencing 3-5 second freezes when navigating
- Battery drain is likely significant due to excessive processing