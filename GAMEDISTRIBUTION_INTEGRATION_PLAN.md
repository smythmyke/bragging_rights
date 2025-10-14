# GameDistribution Integration Plan

This document outlines the step-by-step plan for integrating GameDistribution games into the Bragging Rights mini-games system.

**Status**: Planning Phase
**Target**: Phase 1 Launch
**Priority**: Medium (After Phase 0 validation)

---

## Executive Summary

GameDistribution (GD) provides access to 20,000+ HTML5 games that can be embedded via iframe. This integration will:

- Add professional, high-quality games with zero development effort
- Provide game variety beyond our custom builds
- Generate ad revenue through Azerion's premium network (50% revenue share)
- Complement our custom games (hybrid approach)

---

## Prerequisites

### Before Starting Integration:

✅ **Phase 0 Complete**:
- Sports Trivia game live and tested
- Mini-games infrastructure working (leaderboards, BR economy, WebView)
- User engagement metrics collected (target: 20%+ participation)

✅ **Technical Requirements**:
- Flutter WebView package installed
- Manual score input dialog implemented
- Firebase Firestore schema deployed
- Ad integration working (AdMob/AppLovin)

✅ **Business Requirements**:
- GameDistribution partnership approved
- Revenue share percentage confirmed
- Legal/contract review completed
- Payment terms agreed upon

---

## Integration Steps

### Step 1: GameDistribution Registration

**Timeline**: Day 1-3 (Approval may take 1-3 business days)

**Actions**:
1. Register at https://gamedistribution.com/for-business
2. Select "Publisher" partnership type (not Developer)
3. Complete onboarding questionnaire:
   - Platform: Mobile app (iOS/Android)
   - Expected monthly users: [Your estimate]
   - Integration method: Direct Game Integration (iframe)
   - Ad preferences: Premium video ads
4. Email partnership@azerion.com with details:
   ```
   Subject: Mobile App Integration - Bragging Rights

   Hi Azerion Team,

   We're building a sports betting companion app (Bragging Rights) and want to add
   mini-games using your GameDistribution platform.

   App Details:
   - Platform: Flutter (iOS & Android)
   - Expected users: [estimate] monthly active users
   - Integration: iframe embedding in WebView
   - Monetization: Your premium ads + our AdMob ads

   Questions:
   1. What is the revenue share percentage for mobile WebView integration?
   2. Can we add our own ads outside the iframe?
   3. What are payment minimums and schedules?
   4. Do you have mobile-optimized game filters in the catalog?

   App Store Link: [if available]
   Website: [if available]

   Thank you,
   [Your Name]
   ```

5. Await approval and dashboard access

---

### Step 2: Game Selection

**Timeline**: Day 4-5

**Actions**:
1. Login to GD Publisher Dashboard: https://gamedistribution.com/dev-panel
2. Browse catalog with filters:
   - ✅ Mobile-optimized: **Yes**
   - ✅ Touch controls: **Required**
   - ✅ Language: **English**
   - ✅ Sports/Arcade categories
3. Test 15-20 games in mobile browser:
   - Open game URL on phone
   - Test touch controls
   - Check load times
   - Verify no keyboard-only controls
   - Note average playtime
4. Select 5-7 games for initial rotation:
   - 2-3 sports games (basketball, soccer, baseball)
   - 2-3 arcade games (skill-based, quick play)
   - 1-2 puzzle games (casual appeal)
5. Document each game:
   ```
   Game: Basketball Stars
   GD Game ID: [from URL]
   Embed URL: https://html5.gamedistribution.com/{game-id}/
   Thumbnail URL: [from catalog]
   Category: Basketball
   Controls: Touch (swipe to shoot)
   Avg Playtime: 5 minutes
   Notes: Excellent for NBA fans
   ```

**Recommended Games** (from strategy doc):
- Basketball Stars (Basketball)
- Penalty Shooters 2 (Soccer)
- 8 Ball Billiards Classic (Arcade)
- Baseball Pro (Baseball)
- Golf Orbit (Golf/Arcade)
- Table Tennis World Tour (Table Tennis)
- Racing/Combat Sports (Variety)

---

### Step 3: Flutter WebView Implementation

**Timeline**: Day 6-8

#### 3.1 Add Dependencies

`pubspec.yaml`:
```yaml
dependencies:
  webview_flutter: ^4.4.0
  flutter_inappwebview: ^6.0.0  # Alternative with more features
```

#### 3.2 Create Game WebView Screen

`lib/screens/mini_games/game_webview_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GameWebViewScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final String embedUrl;
  final String platform; // 'gamedistribution' or 'custom'

  const GameWebViewScreen({
    Key? key,
    required this.gameId,
    required this.gameName,
    required this.embedUrl,
    required this.platform,
  }) : super(key: key);

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            _showError('Failed to load game: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show score input dialog when user exits
        await _handleGameExit();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.gameName),
          backgroundColor: Colors.black,
          actions: [
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => _handleGameExit(),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text(
                      'Loading ${widget.gameName}...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGameExit() async {
    final playDuration = DateTime.now().difference(_gameStartTime!);

    // Show score input dialog for GD games
    if (widget.platform == 'gamedistribution') {
      final score = await _showScoreInputDialog();
      if (score != null) {
        await _submitScore(score, playDuration);
      }
    }

    // For custom games, score is auto-captured via JavaScript bridge
    // (Already implemented in your Sports Trivia)
  }

  Future<int?> _showScoreInputDialog() async {
    final TextEditingController scoreController = TextEditingController();

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 12),
            Text('Game Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What was your final score?',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                hintText: 'Enter score',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.purple, width: 2),
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top 10 finishers: Screenshot required',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final score = int.tryParse(scoreController.text);
              if (score == null || score < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid score'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, score);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: Text('Submit Score'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScore(int score, Duration playDuration) async {
    // TODO: Implement Firestore submission
    // 1. Update weekly leaderboard
    // 2. Update user stats
    // 3. Check if user is in top 10 → request screenshot
    // 4. Show ad (rewarded or interstitial)
    // 5. Navigate to leaderboard

    debugPrint('Score submitted: $score (played for ${playDuration.inMinutes} minutes)');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

#### 3.3 Update Game Launch Flow

`lib/screens/mini_games/mini_games_lobby_screen.dart`:
```dart
void _handleGameTap(MiniGameModel game) {
  // Check BR balance
  if (_currentBR < game.brCost) {
    _showInsufficientBRDialog();
    return;
  }

  // Deduct BR
  _deductBRForPlay(game.brCost);

  // Navigate to appropriate screen based on platform
  if (game.platform == 'gamedistribution') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameWebViewScreen(
          gameId: game.id,
          gameName: game.name,
          embedUrl: game.embedUrl,
          platform: game.platform,
        ),
      ),
    );
  } else if (game.platform == 'custom') {
    // Your existing custom game screens (e.g., Sports Trivia)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MiniGamePlayScreen(game: game),
      ),
    );
  }
}
```

---

### Step 4: Firestore Integration

**Timeline**: Day 9-10

#### 4.1 Add Game Documents

Add each GD game to `/mini-games/` collection:

```dart
await FirebaseFirestore.instance.collection('mini-games').doc('basketball_stars').set({
  'id': 'basketball_stars',
  'name': 'Basketball Stars',
  'slug': 'basketball-stars',
  'category': 'sports',
  'sportType': 'basketball',
  'platform': 'gamedistribution',
  'embedUrl': 'https://html5.gamedistribution.com/{game-id}/?gd_sdk_referrer_url=https://braggingrightsapp.com',
  'gdGameId': '{game-id}',
  'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../basketball_stars/thumbnail.jpg',
  'bannerUrl': 'https://firebasestorage.googleapis.com/.../basketball_stars/banner.jpg',
  'icon': '🏀',
  'description': 'Shoot hoops and score big in this addictive basketball game!',
  'avgPlaytime': '5min',
  'brCost': 5,
  'revenueShare': 0.5,
  'active': true,
  'featured': false,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'totalPlays': 0,
});
```

#### 4.2 Upload Thumbnails to Firebase Storage

```bash
# Upload via Firebase Console or CLI
firebase storage:upload game_assets/basketball_stars/thumbnail.jpg gs://bragging-rights.appspot.com/game_images/basketball_stars/thumbnail.jpg
```

---

### Step 5: Score Submission & Leaderboard

**Timeline**: Day 11-12

#### 5.1 Implement Score Submission

`lib/services/mini_games_service.dart`:
```dart
Future<void> submitScore({
  required String gameId,
  required String userId,
  required int score,
  required Duration playDuration,
}) async {
  final weekId = _getCurrentWeekId();
  final leaderboardPath = 'weekly-leaderboards/${weekId}_$gameId/scores';

  // Check if user already has a score
  final existingScoreDoc = await FirebaseFirestore.instance
      .collection(leaderboardPath)
      .doc(userId)
      .get();

  if (existingScoreDoc.exists) {
    final existingScore = existingScoreDoc.data()?['score'] ?? 0;

    // Only update if new score is better
    if (score > existingScore) {
      await FirebaseFirestore.instance
          .collection(leaderboardPath)
          .doc(userId)
          .update({
        'score': score,
        'bestScoreAt': FieldValue.serverTimestamp(),
        'attempts': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Just increment attempts
      await FirebaseFirestore.instance
          .collection(leaderboardPath)
          .doc(userId)
          .update({
        'attempts': FieldValue.increment(1),
        'lastAttemptAt': FieldValue.serverTimestamp(),
      });
    }
  } else {
    // First attempt - create new entry
    await FirebaseFirestore.instance
        .collection(leaderboardPath)
        .doc(userId)
        .set({
      'userId': userId,
      'username': 'User Name', // TODO: Get from user profile
      'score': score,
      'gameId': gameId,
      'weekId': weekId,
      'attempts': 1,
      'brSpent': 5,
      'bestScoreAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update user stats
  await _updateUserStats(userId, gameId, score, playDuration);

  // Calculate rank
  await _updateRankings(weekId, gameId);

  // Check if top 10 → request screenshot
  await _checkTopTenStatus(userId, gameId, weekId);
}

String _getCurrentWeekId() {
  final now = DateTime.now();
  final year = now.year;
  final week = ((now.difference(DateTime(year, 1, 1)).inDays) / 7).ceil();
  return '$year-w${week.toString().padLeft(2, '0')}';
}
```

---

### Step 6: Ad Integration

**Timeline**: Day 13-14

#### 6.1 Show Ads After Game

Add to `_handleGameExit()` in GameWebViewScreen:

```dart
Future<void> _handleGameExit() async {
  // ... score submission code ...

  // Show ad after score submission
  final adService = AdRewardService();
  if (adService.isAdReady()) {
    await adService.showInterstitialAd();
  }

  // Navigate to leaderboard
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => LeaderboardScreen(gameId: widget.gameId),
    ),
  );
}
```

#### 6.2 "Play Again" with Ad Option

```dart
void _showPlayAgainDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Play Again?'),
      content: Text('Watch an ad to play free, or pay 5 BR'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _playGameWithAd();
          },
          child: Text('Watch Ad (Free)'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _playGameWithBR();
          },
          child: Text('Pay 5 BR'),
        ),
      ],
    ),
  );
}
```

---

### Step 7: Testing

**Timeline**: Day 15-16

**Test Checklist**:
- ✅ Game loads in WebView
- ✅ Touch controls work properly
- ✅ Game plays smoothly (no lag)
- ✅ Back button shows score input dialog
- ✅ Score submits to Firestore correctly
- ✅ Leaderboard updates in real-time
- ✅ User rank calculates correctly
- ✅ Ad shows after game completion
- ✅ BR deduction works
- ✅ "Play again" flow works
- ✅ Top 10 screenshot request triggers
- ✅ Works on both iOS and Android

---

## Revenue Tracking

### Monitor These Metrics:

**From GameDistribution Dashboard**:
- Total impressions
- Ad eCPM
- Revenue per game
- Fill rate

**From Your Analytics**:
- Plays per game
- Average playtime
- Completion rate
- User retention

**Revenue Comparison**:
```
GD Game Revenue (50% split):
  10,000 plays × $0.015 CPM = $150/month × 0.5 = $75 YOUR SHARE

Custom Game Revenue (100%):
  10,000 plays × $0.015 CPM = $150/month × 1.0 = $150 YOUR SHARE
```

---

## Success Criteria

**Launch GD games if**:
✅ Phase 0 has 20%+ user engagement
✅ Revenue share is 50%+ to you
✅ At least 5 quality mobile games found
✅ Contract terms are favorable

**Skip GD games if**:
❌ Revenue share is <30%
❌ Contract has unfavorable terms
❌ Technical integration is too complex
❌ Custom games perform better

---

## Timeline Summary

| Phase | Duration | Tasks |
|-------|----------|-------|
| Registration | 1-3 days | Register, await approval |
| Game Selection | 2 days | Browse catalog, test games, select 5-7 |
| Development | 3 days | WebView screen, score dialog, Firestore |
| Integration | 2 days | Add games to system, upload assets |
| Testing | 2 days | Full QA on iOS/Android |
| **Total** | **10-12 days** | Ready for launch |

---

## Open Questions

1. **Revenue Share**: What % do we get? (Awaiting GD response)
2. **Payment Terms**: Minimum payout? NET 30/60 days?
3. **Our Ads**: Can we add AdMob ads outside iframe?
4. **Score Access**: Can we get scores via JavaScript or API?
5. **Game Updates**: What happens if GD updates/removes a game?

---

## Next Steps

**Immediate**:
1. ✅ Register with GameDistribution
2. ⏳ Await partnership approval
3. ⏳ Review contract terms

**After Approval**:
4. Browse catalog and select games
5. Begin Flutter WebView implementation
6. Test with 1-2 games first
7. Full rollout after successful testing

---

**Document Owner**: Development Team
**Last Updated**: January 12, 2025
**Next Review**: After Phase 0 metrics collected
**Status**: Ready to Execute (Pending Phase 0 validation)
