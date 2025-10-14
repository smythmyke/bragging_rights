# Games Page Improvements Plan
**Project:** Bragging Rights Mini-Games Arena
**Date:** October 13, 2025
**Status:** Planning Phase
**Based On:** `games_page_ui_prototype.html` analysis

---

## 📋 Overview

This document outlines the plan to enhance the Mini-Games Lobby screen based on the UI prototype comparison. The goal is to improve user engagement, provide better game information, and create a more polished experience while maintaining real-time Firestore integration.

### Key Constraints
- ❌ **No category filter tabs** - Keep simple scrollable list
- ✅ **Keep game preview images** - No generic icons/emojis
- ✅ **BR cost must be prominent** - Show on every game card
- ✅ **Real-time data** - Continue using Firestore StreamBuilder

---

## 🎯 Improvements to Implement

### **Priority 1: Featured Game Section** ⭐
**Goal:** Highlight a weekly featured game to drive engagement and showcase new content

#### Visual Design
- Large horizontal card at top of screen (below header, above grid)
- Full-width container spanning edge-to-edge
- Animated gradient background (matching app theme colors)
- Two-column layout (responsive to screen size):
  - **Left Column (60%):** Game information
    - "⭐ FEATURED THIS WEEK" badge
    - Large game title (28-32px font)
    - Game description (2-3 sentences)
    - Statistics row: 👥 Players, 🏆 Top Prize, ⏱️ Duration
    - Large "Play Now - X BR" button
  - **Right Column (40%):** Game preview
    - Large game thumbnail/preview image
    - Subtle border/glow effect
    - Fallback to game icon if image unavailable

#### Technical Implementation
**File:** `lib/screens/mini_games/mini_games_lobby_screen.dart`

**New Widget:**
```dart
Widget _buildFeaturedGame(MiniGameModel game) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primaryCyan, AppTheme.deepPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryCyan.withOpacity(0.3),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Animated background effect
          _buildAnimatedBackground(),

          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                // Left: Game info
                Expanded(
                  flex: 60,
                  child: _buildFeaturedGameInfo(game),
                ),
                SizedBox(width: 20),
                // Right: Preview image
                Expanded(
                  flex: 40,
                  child: _buildFeaturedGamePreview(game),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Responsive Behavior:**
- Desktop/Tablet: Side-by-side layout (60/40 split)
- Mobile (< 600px width): Stack vertically (info on top, preview below)

**Animation:**
- Subtle rotating gradient overlay (20s duration)
- Play button pulse effect (scale 1.0 → 1.05 → 1.0, 2s duration)

#### Data Requirements
**Firestore Schema Addition:**
```javascript
// mini-games/{gameId}
{
  featured: true,              // Boolean - Is this featured?
  featuredUntil: Timestamp,    // Auto-expire date
  description: "Test your...", // 2-3 sentence description
  playerCount: 2847,           // Updated by Cloud Function
  averageDuration: 3,          // Minutes (integer)
  topPrize: 500,              // BR amount for 1st place
}
```

**Cloud Function Update:**
Add to `functions/mini_games_scheduler.js`:
```javascript
// Rotate featured game every Monday
exports.rotateFeaturedGame = functions.pubsub
  .schedule('0 0 * * 1')  // Monday midnight UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    // Set featured = false for all games
    // Pick random game and set featured = true
    // Set featuredUntil = now + 7 days
  });
```

**Query Logic:**
```dart
// In MiniGamesLobbyScreen build method
StreamBuilder<List<MiniGameModel>>(
  stream: _gamesService.getActiveGames(),
  builder: (context, snapshot) {
    final games = snapshot.data ?? [];
    final featuredGame = games.firstWhere(
      (g) => g.featured == true,
      orElse: () => games.first, // Fallback to first game
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildFeaturedGame(featuredGame)),
        SliverPadding(...), // Regular grid
      ],
    );
  },
)
```

**Estimated Time:** 3-4 hours
**Complexity:** Medium
**User Impact:** High (30-50% engagement increase expected)

---

### **Priority 2: Game Statistics on Cards** 📊
**Goal:** Help users make informed decisions before playing

#### Information to Display
Each game card should show:
1. **👥 Player Count** - "1.2k players" or "847 players"
2. **⏱️ Duration** - "~3 min" or "~5 min"
3. **🏆 Top Prize** - "500 BR Prize" (for leaderboard games)
4. **💰 Cost** - "15 BR" - **MUST BE PROMINENT**

#### Visual Design
**Layout:**
```
┌─────────────────────────────┐
│   [Game Preview Image]      │
│                              │
├─────────────────────────────┤
│ [Category Badge]             │
│ Game Title Here              │
│                              │
│ 👥 1.2k  ⏱️ ~3min  🏆 500 BR │  ← Stats row
│                              │
│ [PLAY - 15 BR] ← Cost Badge │  ← Prominent button
└─────────────────────────────┘
```

**Stats Row Styling:**
- Small icons (14px) with matching text
- Color: `Colors.white.withOpacity(0.7)`
- Horizontal layout with spacing
- Font size: 12px

**Cost Display:**
- Part of play button text: "PLAY - 15 BR"
- Alternative: Badge next to button with gold/yellow background
- Must be impossible to miss before tapping

#### Technical Implementation

**Update Model:** `lib/models/mini_game_model.dart`
```dart
class MiniGameModel {
  // Existing fields...
  final String title;
  final int brCost;

  // NEW FIELDS:
  final int playerCount;        // e.g., 2847
  final int averageDuration;    // Minutes, e.g., 3
  final int topPrize;           // BR amount, e.g., 500
  final String category;        // e.g., "Trivia", "Sports"

  // Update fromFirestore factory
  factory MiniGameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MiniGameModel(
      // ...existing fields...
      playerCount: data['playerCount'] ?? 0,
      averageDuration: data['averageDuration'] ?? 5,
      topPrize: data['topPrize'] ?? 0,
      category: data['category'] ?? 'General',
    );
  }
}
```

**Update Card Widget:** `lib/screens/mini_games/mini_games_lobby_screen.dart`
```dart
Widget _buildGameCard(MiniGameModel game) {
  return GestureDetector(
    onTap: () => _handleGameTap(game),
    child: Container(
      decoration: BoxDecoration(...),
      child: Column(
        children: [
          // Game thumbnail (existing - keep image support)
          _buildGameThumbnail(game),

          // Game info section
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  _buildCategoryBadge(game.category),
                  SizedBox(height: 8),

                  // Game title
                  Text(game.title, style: ...),
                  SizedBox(height: 8),

                  // Statistics row
                  _buildStatsRow(game),

                  Spacer(),

                  // Play button with cost
                  _buildPlayButton(game),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildStatsRow(MiniGameModel game) {
  return Row(
    children: [
      Icon(PhosphorIconsRegular.users, size: 14, color: Colors.white70),
      SizedBox(width: 4),
      Text(_formatPlayerCount(game.playerCount)),

      SizedBox(width: 12),

      Icon(PhosphorIconsRegular.clock, size: 14, color: Colors.white70),
      SizedBox(width: 4),
      Text('~${game.averageDuration}min'),

      if (game.topPrize > 0) ...[
        SizedBox(width: 12),
        Icon(PhosphorIconsRegular.trophy, size: 14, color: AppTheme.neonGreen),
        SizedBox(width: 4),
        Text('${game.topPrize} BR', style: TextStyle(color: AppTheme.neonGreen)),
      ],
    ],
  );
}

String _formatPlayerCount(int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}

Widget _buildPlayButton(MiniGameModel game) {
  return ElevatedButton(
    onPressed: () => _handleGameTap(game),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.neonGreen,
      padding: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhosphorIconsBold.play, size: 16, color: AppTheme.deepBlue),
        SizedBox(width: 8),
        Text(
          'PLAY',
          style: TextStyle(
            color: AppTheme.deepBlue,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 8),
        // Cost badge - PROMINENT
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${game.brCost} BR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
```

**Estimated Time:** 2-3 hours
**Complexity:** Low-Medium
**User Impact:** Medium-High (reduces pre-play uncertainty)

---

### **Priority 3: Category Badges** 🏷️
**Goal:** Quick visual identification of game type

#### Visual Design
- Small rounded badge above game title
- Semi-transparent background with category color
- 10-12px font size
- Examples: "Trivia", "Sports", "Arcade", "Puzzle"

#### Color Scheme
```dart
Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'trivia':
      return Colors.purple;
    case 'sports':
      return Colors.blue;
    case 'arcade':
      return Colors.green;
    case 'puzzle':
      return Colors.orange;
    case 'strategy':
      return Colors.red;
    default:
      return AppTheme.primaryCyan;
  }
}
```

#### Implementation
```dart
Widget _buildCategoryBadge(String category) {
  final color = _getCategoryColor(category);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withOpacity(0.5),
        width: 1,
      ),
    ),
    child: Text(
      category.toUpperCase(),
      style: TextStyle(
        color: color.withOpacity(0.9),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );
}
```

**Estimated Time:** 30-45 minutes
**Complexity:** Low
**User Impact:** Low-Medium (improves scannability)

---

### **Priority 4: Enhanced Card Interactions** ✨
**Goal:** Add polish and tactile feedback to game cards

#### Interaction States
1. **Normal:** Default styling
2. **Pressed:** Scale to 0.98, slight opacity change
3. **Released:** Spring back animation

#### Implementation
```dart
class _MiniGamesLobbyScreenState extends State<MiniGamesLobbyScreen> {
  String? _pressedCardId;

  Widget _buildGameCard(MiniGameModel game) {
    final isPressed = _pressedCardId == game.id;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedCardId = game.id),
      onTapUp: (_) => setState(() => _pressedCardId = null),
      onTapCancel: () => setState(() => _pressedCardId = null),
      onTap: () => _handleGameTap(game),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..scale(isPressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(...),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPressed
              ? AppTheme.primaryCyan.withOpacity(0.6)
              : AppTheme.primaryCyan.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isPressed
                ? AppTheme.primaryCyan.withOpacity(0.4)
                : Colors.black.withOpacity(0.2),
              blurRadius: isPressed ? 12 : 8,
              offset: Offset(0, isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Column(...),
      ),
    );
  }
}
```

**Estimated Time:** 1 hour
**Complexity:** Low
**User Impact:** Low (polish)

---

## 🗄️ Firestore Schema Updates

### Updated `mini-games` Collection Schema
```javascript
{
  // ===== EXISTING FIELDS =====
  id: "sports_trivia_v1",
  title: "Sports Trivia Challenge",
  description: "Quick trivia game",
  gameUrl: "https://bragging-rights-ea6e1.web.app/sports_trivia.html",
  thumbnailUrl: "https://.../trivia_thumbnail.jpg",
  icon: "brain",
  isActive: true,
  brCost: 15,
  createdAt: Timestamp,
  updatedAt: Timestamp,

  // ===== NEW FIELDS (TO ADD) =====

  // Featured Game
  featured: false,                    // Boolean - Is this the featured game?
  featuredUntil: null,                // Timestamp - When to unfeature
  longDescription: "Test your sports knowledge across NBA, NFL, MLB, NHL, and more! 10 questions, race against the clock, compete for weekly prizes.", // 2-3 sentences for featured card

  // Game Statistics
  playerCount: 2847,                  // Integer - Total plays (updated by Cloud Function)
  averageDuration: 3,                 // Integer - Minutes per game session
  topPrize: 500,                      // Integer - BR amount for 1st place

  // Categorization
  category: "Trivia",                 // String - "Trivia", "Sports", "Arcade", "Puzzle", etc.

  // Optional (Future)
  rating: 4.8,                        // Float - Average user rating (1-5)
  totalRatings: 1247,                 // Integer - Number of ratings
  difficulty: "Medium",               // String - "Easy", "Medium", "Hard"
  tags: ["Sports", "NBA", "NFL"],     // Array - For future search/filter
}
```

### Migration Script
**File:** `scripts/update_mini_games_schema.js`
```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function updateGamesSchema() {
  const gamesRef = db.collection('mini-games');
  const snapshot = await gamesRef.get();

  const batch = db.batch();

  snapshot.forEach(doc => {
    batch.update(doc.ref, {
      // Featured
      featured: false,
      featuredUntil: null,
      longDescription: doc.data().description || 'Play this exciting mini-game!',

      // Stats
      playerCount: 0,  // Will be updated by play counter
      averageDuration: 5,  // Default 5 minutes
      topPrize: 500,  // Default prize

      // Category
      category: _inferCategory(doc.data().title),
    });
  });

  await batch.commit();
  console.log('✅ Updated all game documents');
}

function _inferCategory(title) {
  const lower = title.toLowerCase();
  if (lower.includes('trivia') || lower.includes('quiz')) return 'Trivia';
  if (lower.includes('ball') || lower.includes('sport')) return 'Sports';
  if (lower.includes('memory') || lower.includes('puzzle')) return 'Puzzle';
  return 'Arcade';
}

updateGamesSchema();
```

**Run:** `cd scripts && node update_mini_games_schema.js`

---

## 📊 Cloud Functions Updates

### 1. Player Count Tracker
**File:** `functions/index.js`
```javascript
// Increment playerCount when game is played
exports.trackGamePlay = functions.firestore
  .document('user-stats/{userId}/game-history/{historyId}')
  .onCreate(async (snap, context) => {
    const gameId = snap.data().gameId;

    const gameRef = admin.firestore()
      .collection('mini-games')
      .doc(gameId);

    await gameRef.update({
      playerCount: admin.firestore.FieldValue.increment(1),
    });
  });
```

### 2. Featured Game Rotation
**File:** `functions/index.js`
```javascript
// Rotate featured game every Monday at midnight UTC
exports.rotateFeaturedGame = functions.pubsub
  .schedule('0 0 * * 1')  // Monday 00:00 UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🔄 Rotating featured game...');

    const gamesRef = admin.firestore().collection('mini-games');

    // 1. Unfeature all games
    const allGames = await gamesRef.where('isActive', '==', true).get();
    const batch = admin.firestore().batch();

    allGames.forEach(doc => {
      batch.update(doc.ref, { featured: false });
    });

    await batch.commit();

    // 2. Select random game to feature
    const activeGames = allGames.docs.filter(doc => doc.data().isActive);
    const randomGame = activeGames[Math.floor(Math.random() * activeGames.length)];

    const nextWeek = new Date();
    nextWeek.setDate(nextWeek.getDate() + 7);

    await randomGame.ref.update({
      featured: true,
      featuredUntil: admin.firestore.Timestamp.fromDate(nextWeek),
    });

    console.log(`✅ Featured game set to: ${randomGame.data().title}`);
    return null;
  });
```

### 3. Update Existing Functions
**File:** `functions/mini_games_scheduler.js`
```javascript
// Add playerCount reset to weekly rotation
exports.rotateWeeklyLeaderboards = functions.pubsub
  .schedule('0 0 * * 1')
  .timeZone('UTC')
  .onRun(async (context) => {
    // ...existing rotation logic...

    // NEW: Reset playerCount for new week
    const gamesRef = admin.firestore().collection('mini-games');
    const games = await gamesRef.get();

    const batch = admin.firestore().batch();
    games.forEach(doc => {
      batch.update(doc.ref, { playerCount: 0 });
    });
    await batch.commit();

    console.log('✅ Player counts reset for new week');
  });
```

**Deploy:** `firebase deploy --only functions`

---

## 🎨 Theme & Styling Guidelines

### Color Palette for Categories
```dart
// lib/theme/app_theme.dart

class AppTheme {
  // Existing colors...
  static const Color deepBlue = Color(0xFF0a0e27);
  static const Color primaryCyan = Color(0xFF00d4ff);
  static const Color neonGreen = Color(0xFF39ff14);

  // NEW: Category colors
  static const Color categoryTrivia = Color(0xFF9b59b6);    // Purple
  static const Color categorySports = Color(0xFF3498db);    // Blue
  static const Color categoryArcade = Color(0xFF2ecc71);    // Green
  static const Color categoryPuzzle = Color(0xFFe67e22);    // Orange
  static const Color categoryStrategy = Color(0xFFe74c3c);  // Red

  // Featured game gradient
  static const List<Color> featuredGradient = [
    Color(0xFF667eea),  // Purple-blue
    Color(0xFF764ba2),  // Purple
  ];
}
```

### Animation Durations
```dart
// Consistent animation timings
const Duration cardPressAnimation = Duration(milliseconds: 150);
const Duration featuredGamePulse = Duration(seconds: 2);
const Duration backgroundRotation = Duration(seconds: 20);
const Duration shimmerEffect = Duration(milliseconds: 1500);
```

---

## 📱 Responsive Breakpoints

### Layout Adjustments by Screen Size

#### **Mobile (< 600px)**
- Featured game: Vertical stack (info top, image bottom)
- Game grid: 2 columns
- Stats row: Wrap if needed
- Font sizes: Slightly smaller

#### **Tablet (600px - 900px)**
- Featured game: Side-by-side (50/50 split)
- Game grid: 3 columns
- Stats row: Single line

#### **Desktop (> 900px)**
- Featured game: Side-by-side (60/40 split)
- Game grid: 4 columns
- Max width: 1200px centered

```dart
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 900;

  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: _buildFeaturedGame(
          featuredGame,
          vertical: isMobile,  // Stack vertically on mobile
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(...),
        ),
      ),
    ],
  );
}
```

---

## ✅ Implementation Checklist

### **Phase 1: Data Foundation (2-3 hours)**
- [ ] Update `MiniGameModel` with new fields
  - [ ] `playerCount`, `averageDuration`, `topPrize`
  - [ ] `category`, `featured`, `longDescription`
  - [ ] Update `fromFirestore()` factory
  - [ ] Update `toFirestore()` method
- [ ] Create migration script `update_mini_games_schema.js`
- [ ] Run migration on existing games in Firestore
- [ ] Verify data in Firebase Console

### **Phase 2: Game Cards Enhancement (2-3 hours)**
- [ ] Add category badge widget
- [ ] Add stats row widget (player count, duration, prize)
- [ ] Update play button to show cost prominently
- [ ] Add card press animation
- [ ] Test on various screen sizes
- [ ] Verify all game cards display correctly

### **Phase 3: Featured Game Section (3-4 hours)**
- [ ] Create `_buildFeaturedGame()` widget
- [ ] Implement animated background effect
- [ ] Build responsive layout (mobile/tablet/desktop)
- [ ] Add featured game info section
- [ ] Add featured game preview section
- [ ] Integrate with StreamBuilder
- [ ] Test with featured = true/false games
- [ ] Add fallback if no featured game

### **Phase 4: Cloud Functions (2 hours)**
- [ ] Create `trackGamePlay` function
- [ ] Create `rotateFeaturedGame` scheduled function
- [ ] Update `rotateWeeklyLeaderboards` to reset player counts
- [ ] Deploy functions to Firebase
- [ ] Test scheduled function triggers
- [ ] Monitor function logs

### **Phase 5: Testing & Polish (2 hours)**
- [ ] Test featured game rotation manually
- [ ] Verify player count increments correctly
- [ ] Test all games with/without images
- [ ] Test BR cost display on all cards
- [ ] Test responsive layouts on 3+ screen sizes
- [ ] Test animations and interactions
- [ ] Check accessibility (tap targets, contrast)
- [ ] Performance test with 10+ games

### **Phase 6: Documentation (1 hour)**
- [ ] Update `MINI_GAMES_PROGRESS.md`
- [ ] Document new Firestore schema
- [ ] Add screenshots to docs
- [ ] Create admin guide for featuring games
- [ ] Update API documentation

---

## 📸 Expected Results

### Before
- Simple grid of game cards
- Only title and play button
- No featured content
- No game information
- Cost hidden in banner

### After
- Eye-catching featured game at top
- Rich game cards with stats
- Clear cost display on every card
- Category identification
- Player counts for social proof
- Duration expectations set
- Prize information visible
- Polished animations

### Metrics to Track
- **Engagement Rate:** % of users who tap a game (expect 20% increase)
- **Featured Game CTR:** % who play featured vs regular (expect 2-3x higher)
- **Session Length:** Time spent browsing games (expect 30% increase)
- **Repeat Plays:** Users who return to play again (expect 15% increase)

---

## 🚀 Deployment Plan

### 1. Development
- Branch: `feature/games-page-improvements`
- Test locally with Firebase emulators
- Manual testing on Android/iOS

### 2. Staging
- Deploy to staging Firebase project
- QA testing with real data
- Gather internal feedback

### 3. Production
- Gradual rollout (10% → 50% → 100%)
- Monitor analytics dashboard
- Watch for errors/crashes
- Collect user feedback

### 4. Post-Launch
- A/B test featured game rotation frequency
- Optimize player count update frequency
- Consider adding rating system
- Plan next iteration based on data

---

## 🔮 Future Enhancements (Not in This Phase)

### Potential Additions
1. **User Reviews & Ratings** - Let users rate games 1-5 stars
2. **Personal Best Tracking** - Show user's best score on each card
3. **Daily Challenges** - Special badge for daily featured game
4. **Achievements** - Badges for playing X games, winning Y times
5. **Search** - Search games by name (only needed with 20+ games)
6. **Game Previews** - Video/GIF preview on card tap
7. **Social Sharing** - Share game invites to friends
8. **Favorites** - Bookmark favorite games

---

## 📞 Support & Questions

### Implementation Questions
- Check `MINI_GAMES_PROGRESS.md` for current status
- Review `FIRESTORE_MINI_GAMES_SCHEMA.md` for database structure
- See `AVATAR_SYSTEM_IMPLEMENTATION_SUMMARY.md` for similar pattern

### Testing
- Use Firebase emulators for local testing
- Test with both featured and non-featured games
- Verify cost is always visible before play
- Check responsive layouts on multiple devices

### Deployment
- `firebase deploy --only hosting` - Deploy game files
- `firebase deploy --only firestore:rules` - Deploy security rules
- `firebase deploy --only functions` - Deploy Cloud Functions

---

## ✨ Summary

This plan enhances the Mini-Games Lobby with:
- ⭐ **Featured Game Section** - Drive engagement to specific games
- 📊 **Game Statistics** - Player count, duration, prizes
- 🏷️ **Category Badges** - Quick visual identification
- 💰 **Prominent Cost Display** - Clear BR cost on all cards
- ✨ **Polished Interactions** - Smooth animations and feedback

**Total Estimated Time:** 12-15 hours
**Priority Order:** Data foundation → Card enhancements → Featured section → Functions
**Success Metric:** 20%+ increase in mini-games engagement

**Status:** Ready for implementation 🚀
