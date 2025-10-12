# Mini-Games Implementation Progress

**Status:** Phase 0 - Core Infrastructure Complete ✅
**Date:** October 12, 2025
**Current Game:** Sports Trivia Challenge (Live)

---

## ✅ What We've Completed

### **1. Core Infrastructure**
- ✅ Created `MiniGameModel`, `LeaderboardEntry`, `GameLeaderboard` data models
- ✅ Built `MiniGamesService` for Firestore operations
- ✅ Replaced Edge tab (Power Card Shop) with Mini-Games Lobby
- ✅ Created `MiniGamesLobbyScreen` - displays available games in grid
- ✅ Created `MiniGamePlayScreen` - WebView with auto-score capture
- ✅ Created `LeaderboardScreen` - real-time leaderboard with countdown timer
- ✅ Added `webview_flutter` dependency to pubspec.yaml

### **2. Game Mechanics**
- ✅ **Entry Fee:** 5 BR deducted on game load (no confirmation dialog)
- ✅ **Auto-Score Capture:** JavaScript bridge (`FlutterGameBridge`) for automatic score submission
- ✅ **Manual Score Fallback:** Dialog with input field if auto-capture fails
- ✅ **Weekly Leaderboards:** Auto-rotating every Monday at midnight UTC
- ✅ **Prize Distribution:** Top 10 players (500/250/100/50/50/50/50/50/50/50 BR)
- ✅ **Post-Game UX:**
  - Shows current rank and "prize zone" indicator
  - "Watch ad to play free" option
  - "Back to Lobby" button

### **3. Sports Trivia Game (First Game)**
- ✅ **70 Questions:** 10 each for NBA, NFL, MLB, NHL, MLS, Boxing, MMA
- ✅ **Sport Selection:** Grid with 8 options (7 sports + ALL)
- ✅ **10-Second Timer:** Per question with warning animation at 3 seconds
- ✅ **Scoring System:**
  - Base: 100 points per correct answer
  - Time Bonus: Remaining seconds × 10 points
  - Max possible: ~2,000 points
- ✅ **Visual Polish:**
  - Smooth card flip animations
  - Green/red answer feedback
  - Streak badges (3+ correct in a row)
  - Particle effects and celebrations
  - Mini leaderboard preview at end
- ✅ **Action Buttons:** Play Again, Share Score, Back to Lobby
- ✅ **File Size:** ~42KB (ultra-lightweight)

### **4. Firebase Setup**
- ✅ **Hosting:** Configured and deployed
  - URL: `https://bragging-rights-ea6e1.web.app/sports_trivia.html`
  - Public folder: `bragging_rights_app/web/games`
  - 1-hour cache headers
- ✅ **Firestore:**
  - Added Sports Trivia to `mini-games` collection
  - Created initial leaderboard (`sports_trivia_week_41`)
  - Schema supports multiple games and weekly rotation
- ✅ **Cloud Functions:**
  - `rotateWeeklyLeaderboards` - Runs every Monday 12:00 AM UTC
  - `distributeWeeklyPrizes` - Runs every Monday 12:30 AM UTC
  - `manualDistributePrizes` - Admin-triggered for testing

### **5. Files Created**

**Flutter/Dart:**
- `lib/models/mini_game_model.dart` - Game data models
- `lib/services/mini_games_service.dart` - Firestore integration
- `lib/screens/mini_games/mini_games_lobby_screen.dart` - Game lobby
- `lib/screens/mini_games/mini_game_play_screen.dart` - WebView player
- `lib/screens/mini_games/leaderboard_screen.dart` - Leaderboard display

**HTML5 Game:**
- `bragging_rights_app/web/games/sports_trivia.html` - Complete trivia game

**Cloud Functions:**
- `functions/mini_games_scheduler.js` - Rotation and prize distribution
- `functions/add_trivia_game.js` - Database initialization script

**Documentation:**
- `MINI_GAMES_MONETIZATION_STRATEGY.md` - Full strategy doc
- `MINI_GAMES_PROGRESS.md` - This file

---

## 🎯 What We Need to Do Next

### **Immediate Testing (Priority 1)**

#### **Test in Flutter App:**
1. **Build and run the app** on Android/iOS emulator or device
   ```bash
   cd bragging_rights_app
   flutter run
   ```

2. **Navigate to Mini-Games:**
   - Tap "Edge" tab (4th icon in bottom navigation)
   - Should see "Mini-Games Arena" with Sports Trivia card

3. **Test Complete Game Flow:**
   - Ensure BR balance shows correctly (need at least 5 BR to play)
   - Tap PLAY on Sports Trivia card
   - Game should load in WebView
   - Play through 10 questions
   - Verify auto-score submission works
   - Check post-game dialog shows rank
   - Test "Watch Ad to Play Free" flow
   - Verify "Back to Lobby" returns correctly

4. **Test Leaderboard:**
   - Tap trophy icon on Sports Trivia card
   - Verify leaderboard shows submitted scores
   - Check countdown timer shows time remaining
   - Confirm user's rank and stats display correctly

#### **Test Edge Cases:**
1. **Insufficient BR:**
   - User with <5 BR should see "Insufficient BR" dialog
   - Should return to lobby without charging

2. **Exit Without Submitting:**
   - Start game, don't finish
   - Press back button
   - Should show warning about non-refundable entry fee

3. **Multiple Games:**
   - Play 2-3 games in a row
   - Verify BR deducts correctly each time
   - Ensure best score is tracked

4. **Leaderboard Updates:**
   - Play game and submit score
   - Immediately check leaderboard
   - Verify score appears in real-time

---

### **Phase 0 Expansion (Priority 2)**

After testing Sports Trivia, add 2-4 more free HTML5 games:

#### **Option A: Simple Custom Games (Recommended)**
Build these from scratch (1-2 hours each):

1. **Sports Memory Match**
   - 16 cards (8 pairs) with team logos/player images
   - Timer and move counter
   - Score based on speed and moves
   - Estimated: 1 hour to build

2. **Higher or Lower (Stats Game)**
   - Show two players/teams with one stat visible
   - Guess if the hidden stat is higher or lower
   - 10 rounds, score based on streak
   - Estimated: 1 hour to build

3. **Quick Draw (Reaction Game)**
   - Sports-themed reaction time game
   - Tap when specific logo/color appears
   - Score based on accuracy and speed
   - Estimated: 1.5 hours to build

#### **Option B: Adapt Premade Games**
Download and modify open-source games:

1. **Memory Match** - Use Khaled's Memory Puzzle (MIT)
2. **Pong** - Use Basic Pong (CC0)
3. **Flappy Bird** - Reskin as "Basketball Hoops"

**Each requires:**
- Add touch event handlers
- Add `FlutterGameBridge.postMessage(score)` for auto-submission
- Replace graphics with sports themes
- Estimated: 2-3 hours per game

#### **Recommended Next Games:**
1. Sports Memory Match (custom)
2. Higher or Lower Stats (custom)
3. Sports Trivia (✅ already done)

**Target:** 3-5 games for Phase 0 launch

---

### **Phase 1: GameDistribution (Optional)**

**Only proceed if:**
- Phase 0 games get 20%+ user engagement
- Users request more game variety
- Ad revenue shows promise

**What to do:**
1. Research GameDistribution partnership terms
2. Integrate their SDK/iframe embed
3. Add 5-10 games from their catalog
4. Implement 50/50 revenue split tracking

**Estimated time:** 1 week

---

### **Phase 2: Premium Games (Future)**

**Only proceed if:**
- Mini-games generate $500+/month revenue
- User retention improves significantly

**Options:**
1. Purchase templates from CodeCanyon ($20-100 each)
2. Commission custom games from developers
3. Build advanced Flutter-native games with Flame engine

**Estimated time:** 2-4 weeks

---

## 📊 Success Metrics (Track After Launch)

### **Week 1 Goals:**
- ✅ 10%+ of users try mini-games
- ✅ 3+ average plays per user
- ✅ $0.20+ ad revenue per active user

### **Week 2-4 Goals:**
- ✅ 20%+ user engagement
- ✅ 5+ average plays per user
- ✅ $0.40+ ad revenue per active user
- ✅ Leaderboard has 50+ active competitors

### **Decision Points:**

**Continue with Phase 0 (free games) if:**
- Engagement is 15%+
- Revenue is $300+/month
- Users aren't complaining about game quality

**Upgrade to Phase 1 (GameDistribution) if:**
- Engagement is 25%+
- Users request more games
- Quality concerns arise

**Pivot or cancel if:**
- Engagement is <10%
- High cheating rates
- Technical issues persist

---

## 🐛 Known Issues / To-Do

### **Testing Needed:**
- [ ] Verify auto-score capture works in production WebView
- [ ] Test on both Android and iOS
- [ ] Confirm weekly rotation happens automatically
- [ ] Test prize distribution Cloud Function
- [ ] Verify ad-for-free-play flow works

### **Potential Issues to Watch:**
1. **WebView Performance:**
   - Some older Android devices may struggle with WebView
   - Monitor crash reports

2. **Score Cheating:**
   - Users could manually submit fake scores
   - Monitor leaderboard for suspicious scores (>2000 points)
   - Implement screenshot verification for top 3

3. **BR Economy:**
   - Entry fees burn 5 BR per play
   - Prizes inject 1,200 BR per week
   - Net burn: ~13,800 BR per week (assuming 3,000 plays)
   - **Monitor:** Ensure users aren't running out of BR

4. **Cloud Functions Costs:**
   - Scheduled functions run weekly (minimal cost)
   - Monitor Firebase usage dashboard

---

## 🔧 Maintenance Tasks

### **Weekly:**
- Review leaderboard for suspicious scores
- Check Firebase Hosting bandwidth usage
- Monitor Cloud Functions execution logs

### **Monthly:**
- Add 10-20 new trivia questions to keep content fresh
- Review analytics for engagement trends
- Consider adding seasonal/event-based questions

### **Quarterly:**
- Evaluate revenue vs. development time
- Decide on Phase 1/2 progression
- Update game difficulty based on average scores

---

## 📝 Quick Reference

### **Important URLs:**
- **Game URL:** https://bragging-rights-ea6e1.web.app/sports_trivia.html
- **Firebase Console:** https://console.firebase.google.com/project/bragging-rights-ea6e1/overview
- **Firestore Collection:** `mini-games` / `leaderboards` / `user-stats`

### **Key Files:**
- **Game Code:** `bragging_rights_app/web/games/sports_trivia.html`
- **Service:** `bragging_rights_app/lib/services/mini_games_service.dart`
- **Lobby:** `bragging_rights_app/lib/screens/mini_games/mini_games_lobby_screen.dart`
- **Cloud Functions:** `functions/mini_games_scheduler.js`

### **Admin Commands:**
```bash
# Deploy game updates
firebase deploy --only hosting

# Deploy Cloud Functions
firebase deploy --only functions

# Add new game to Firestore
cd functions && node add_trivia_game.js

# Test Cloud Functions locally
firebase emulators:start --only functions,firestore
```

---

## 🚀 Next Session Checklist

When you return to this project:

1. ✅ Read this document
2. ✅ Test Sports Trivia in the app
3. ✅ Verify score submission and leaderboard work
4. ✅ Fix any bugs found during testing
5. ✅ Decide: Add more Phase 0 games OR move to Phase 1

**Good luck! 🎮🏆**
