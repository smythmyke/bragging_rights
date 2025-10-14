# Mini-Games Simplified Implementation
**Date:** October 13, 2025
**Status:** ✅ Complete - Ready for Deployment

---

## 🎯 Overview

This document outlines the simplified mini-games system implementation that removes score tracking/leaderboards and focuses on:
1. ✅ Users pay BR to play games
2. ✅ Track total plays per game
3. ✅ Favorite/heart feature for games
4. ✅ Weekly featured game rotation

---

## ✅ Completed Changes

### **Phase 1: Removed Score Tracking System**
- ❌ Removed `topPrize` display from game cards
- ❌ Removed `topPrize` display from featured game section
- ❌ Removed `LeaderboardEntry`, `GameLeaderboard`, and `UserGameStats` classes from model
- ❌ Marked `topPrize` field as deprecated in model

### **Phase 2: Favorites System** ❤️
**Model Changes:**
- ✅ Added `isFavorited` field to `MiniGameModel` (runtime only, not stored in Firestore)

**Service Methods (`mini_games_service.dart`):**
- ✅ `toggleFavorite(gameId)` - Add/remove game from favorites
- ✅ `isFavorited(gameId)` - Check if game is favorited
- ✅ `_getUserFavorites(userId)` - Load user's favorites (internal)
- ✅ Updated `getActiveGames()` to automatically set `isFavorited` flag

**UI Changes (`mini_games_lobby_screen.dart`):**
- ✅ Heart icon on top-right of each game card
- ✅ Filled red heart when favorited, outline when not
- ✅ Tap heart to toggle favorite status
- ✅ Snackbar feedback: "❤️ Added to favorites!" / "💔 Removed from favorites"

**Firestore Structure:**
```
/users/{userId}/favorites/{gameId}
  - gameId: string
  - addedAt: timestamp
```

### **Phase 3: Play Count Tracking** 📊
**Implementation:**
- ✅ `trackGamePlay()` increments `playerCount` field when event = 'started'
- ✅ Uses `FieldValue.increment(1)` for atomic updates
- ✅ Existing game analytics tracking kept intact

**When it updates:**
- When user starts playing a game (in `MiniGamePlayScreen.initState()`)
- Every play increments the counter (same user playing 5 times = 5 plays)

### **Phase 4: Featured Game Rotation** 🌟
**Cloud Function: `rotateFeaturedMiniGame`**
- ⏰ Runs: Every Monday at midnight UTC (`0 0 * * 1`)
- 🎲 Selects: Random active game
- ⏳ Duration: Featured until next Monday (7 days)
- 📝 Logs: Creates entry in `system_logs` collection

**Manual Rotation Function: `manualRotateFeaturedGame`**
- 🔐 Admin only (requires `admin` custom claim)
- 🎮 Callable via Flutter app
- Returns: Featured game details + expiration date

**Firestore Updates:**
- Sets `featured: true` on selected game
- Sets `featured: false` on all other games
- Sets `featuredUntil` timestamp (7 days from now)

---

## 📁 Files Modified

### Flutter App
1. **`lib/models/mini_game_model.dart`**
   - Added `isFavorited` field (runtime only)
   - Marked `topPrize` as deprecated
   - Removed unused leaderboard classes

2. **`lib/services/mini_games_service.dart`**
   - Added `toggleFavorite()` method
   - Added `isFavorited()` method
   - Added `_getUserFavorites()` method
   - Updated `getActiveGames()` to load favorites
   - Updated `trackGamePlay()` to increment `playerCount`

3. **`lib/screens/mini_games/mini_games_lobby_screen.dart`**
   - Removed `topPrize` from stats display
   - Added heart icon to game cards
   - Added `_handleFavoriteTap()` method
   - Wrapped card in Stack to position heart icon

### Cloud Functions
4. **`functions/index.js`**
   - Added `rotateFeaturedMiniGame` scheduled function
   - Added `manualRotateFeaturedGame` callable function

### Security Rules
5. **`firestore.rules`**
   - Added rules for `/users/{userId}/favorites/{gameId}`

---

## 🔧 Deployment Instructions

### 1. Deploy Flutter App Changes
```bash
cd bragging_rights_app
flutter clean
flutter pub get
flutter run
```

### 2. Deploy Cloud Functions
```bash
cd functions
npm install  # If dependencies changed
firebase deploy --only functions:rotateFeaturedMiniGame,functions:manualRotateFeaturedGame
```

### 3. Deploy Firestore Security Rules
```bash
firebase deploy --only firestore:rules
```

### 4. Test in App
1. ✅ Hot restart Flutter app
2. ✅ Tap Edge tab to view mini-games
3. ✅ Tap heart icon to favorite a game
4. ✅ Play a game to see player count increment
5. ✅ Check featured game displays correctly

---

## 🗄️ Firestore Schema

### `/mini-games/{gameId}`
```javascript
{
  id: "sports_trivia",
  title: "Sports Trivia Challenge",
  active: true,
  featured: false,  // ← Set by Cloud Function
  featuredUntil: null,  // ← Timestamp when featured expires
  brCost: 15,
  playerCount: 0,  // ← Incremented on each play
  averageDuration: 5,
  category: "Trivia",
  thumbnailUrl: "...",
  embedUrl: "...",
  platform: "custom",
  // ... other fields
}
```

### `/users/{userId}/favorites/{gameId}`
```javascript
{
  gameId: "sports_trivia",
  addedAt: Timestamp
}
```

### `/system_logs/{logId}` (auto-created by Cloud Function)
```javascript
{
  type: "mini_games_rotation",
  timestamp: Timestamp,
  featuredGameId: "hexa_sort",
  featuredGameTitle: "Hexa Sort Trick or Treat",
  featuredUntil: Timestamp,
  totalActiveGames: 5
}
```

---

## 🧪 Testing Checklist

### Favorites System
- [ ] Tap heart icon - should toggle favorite status
- [ ] Heart turns red when favorited
- [ ] Snackbar shows confirmation message
- [ ] Favorite persists after app restart
- [ ] Can unfavorite by tapping again
- [ ] Works for all games in lobby

### Play Count Tracking
- [ ] Play a game - `playerCount` should increment in Firestore
- [ ] Play same game again - `playerCount` should increment again
- [ ] Multiple users playing - each play counts separately
- [ ] Display updates in real-time via StreamBuilder

### Featured Game Rotation
- [ ] Featured game displays in large card at top
- [ ] "⭐ FEATURED THIS WEEK" badge visible
- [ ] Shows player count, duration (no top prize)
- [ ] Manual rotation via Cloud Function works (admin only)
- [ ] Scheduled rotation will run every Monday at midnight UTC

---

## 🚀 What's Next (Optional Future Enhancements)

### Potential Additions (Not Required Now)
1. **Filter by Category** - Add filter buttons for Trivia, Arcade, Sports, etc.
2. **Sort Options** - Sort by Most Played, Newest, Favorites, etc.
3. **Game Ratings** - Let users rate games 1-5 stars
4. **Recently Played** - Show "Continue Playing" section
5. **Achievements** - Badges for playing X games, favoriting, etc.
6. **Social Features** - See what friends are playing
7. **Game Stats Page** - Detailed stats per game (total plays, unique players, etc.)

---

## 📊 Current Stats

**Games in Firestore:**
- Sports Trivia (custom)
- Italian Brainrot Baby Clicker (GameDistribution)
- Governor of Poker 3 (GameDistribution)
- Hexa Sort Trick or Treat (GameDistribution)
- Dart Tournament (likely added)

**Featured Game:** Set manually or will auto-rotate Monday midnight UTC

**Player Count:** Starts at 0, increments with each play

---

## ❓ FAQ

**Q: Can users see their favorite games in a separate section?**
A: Not currently implemented. Favorites only show heart icon on cards. Could add "My Favorites" filter in future.

**Q: What happens if no game is featured?**
A: UI falls back to first game in list as featured game (see `mini_games_lobby_screen.dart:95`).

**Q: How do I manually change the featured game?**
A: Call `manualRotateFeaturedGame` Cloud Function from admin panel (requires admin claim).

**Q: Can I reset player counts?**
A: Yes, but requires manual Firestore update or new Cloud Function. Could add weekly reset if needed.

**Q: Does favoriting cost BR?**
A: No, favoriting is free. Only playing games costs BR.

---

## 🔗 Related Documentation

- **Original Plan:** `GAMES_PAGE_IMPROVEMENTS_PLAN.md`
- **Firestore Schema:** `FIRESTORE_MINI_GAMES_SCHEMA.md`
- **GameDistribution Plan:** `GAMEDISTRIBUTION_INTEGRATION_PLAN.md`
- **Setup Guide:** `FULL_FIX_STEP_BY_STEP.md`

---

**Implementation Status:** ✅ Complete
**Deployed:** Pending
**Next Action:** Deploy to production and test
