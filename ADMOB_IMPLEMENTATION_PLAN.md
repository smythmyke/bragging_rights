# Google AdMob Implementation Plan - Bragging Rights

**Date Created**: 2025-10-07
**Status**: 📋 **PLANNING**
**Target Launch**: Phase 1 (Rewarded Ads Only)
**Revenue Goal**: $500-1,500/month from 1,000-2,000 free users

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Three-Phase Rollout Strategy](#three-phase-rollout-strategy)
3. [Technical Implementation](#technical-implementation)
4. [Ad Placement Strategy](#ad-placement-strategy)
5. [Frequency & Limits](#frequency--limits)
6. [Premium vs Free Experience](#premium-vs-free-experience)
7. [Revenue Projections](#revenue-projections)
8. [User Experience Guidelines](#user-experience-guidelines)
9. [Testing & Optimization](#testing--optimization)
10. [Legal & Compliance](#legal--compliance)
11. [Analytics & Monitoring](#analytics--monitoring)
12. [Implementation Checklist](#implementation-checklist)

---

## Executive Summary

### Goals
- **Primary**: Generate $500-1,500/month passive revenue from free users
- **Secondary**: Create premium upgrade incentive (ad-free experience)
- **Tertiary**: Maintain user retention (>25% D7) while monetizing

### Strategy
**Start conservative, optimize based on data**

- **Phase 1** (Month 1-2): Rewarded ads only → Low risk, high acceptance
- **Phase 2** (Month 3-4): Add light interstitials → Test impact on retention
- **Phase 3** (Month 5+): Optimize & scale → Maximize revenue without churn

### Key Principles
1. ✅ **User-first**: Never interrupt critical actions (bet placement, pool join)
2. ✅ **Premium value**: Ad-free is a major selling point for $1.99/mo
3. ✅ **Respect limits**: Daily caps, cooldowns, session limits
4. ✅ **Transparency**: Users know what they're getting into
5. ✅ **Quality**: Only show high-quality, relevant ads

---

## Three-Phase Rollout Strategy

### Phase 1: Rewarded Video Ads Only (Months 1-2)

**Timeline**: 2 weeks implementation + 6 weeks testing

#### Features
- ✅ Rewarded video ads (15-30 seconds)
- ✅ User-initiated (opt-in only)
- ✅ Earn 25 BR per ad
- ✅ Max 5 ads per day
- ✅ Premium users = zero ads

#### Placement Locations
```
1. BR Currency Shop (primary)
2. Out of BR Modal (when user can't afford pool)
3. Daily Bonus Screen (after claiming)
```

#### Success Metrics
- **Target**: 30% of free users watch 1+ ad per day
- **Revenue**: $300-800/month (1,000 free users)
- **Retention**: Maintain >25% D7 retention
- **User Feedback**: <5% complaints about ads

#### Ad Settings
```yaml
Ad Type: Rewarded Video
Max per Day: 5
Reward per Ad: 25 BR
Premium Users: No ads
Frequency: User-initiated only
```

---

### Phase 2: Light Interstitial Ads (Months 3-4)

**Timeline**: After Phase 1 success, 4-6 weeks testing

#### New Features
- ✅ Interstitial ads (full-screen, 5 sec skip)
- ✅ Auto-show at strategic moments
- ✅ Max 3 per session
- ✅ 10-minute cooldown between ads
- ✅ Premium users still = zero ads

#### Additional Placement Locations
```
4. After Pool Completion (completed 3+ pools)
5. After Viewing Bet History
6. After Achievement Unlock
7. Between major navigation (with cooldown)
```

#### Success Metrics
- **Target**: 50% revenue increase vs Phase 1
- **Revenue**: $600-1,500/month
- **Retention**: Maintain >23% D7 (2% drop acceptable)
- **Premium Conversion**: +1-2% boost ("Remove Ads" messaging)

#### Ad Settings
```yaml
Rewarded Ads: Same as Phase 1
Interstitial Ads:
  - Max per Session: 3
  - Cooldown: 10 minutes
  - Triggers: Pool completion, bet history, achievements
  - Premium Users: No ads
```

---

### Phase 3: Optimization & Scaling (Months 5+)

**Timeline**: Ongoing optimization

#### Advanced Features
- ✅ Native ads in pool lists (labeled as sponsored)
- ✅ Smart targeting (show ads when user is engaged)
- ✅ A/B testing different frequencies
- ✅ Dynamic ad placement based on user behavior
- ✅ "Remove Ads" one-time IAP ($2.99)

#### Optimization Areas
```
- Test different CPM networks (Facebook, Unity, AppLovin)
- Adjust frequencies based on cohort analysis
- Implement ad mediation for best prices
- Create "ad fatigue" detection system
- Premium trial triggers: "Try 7 days ad-free"
```

#### Success Metrics
- **Revenue**: $1,500-3,000/month (at 3,000 free users)
- **Premium Conversion**: 5-8% (up from 2-5%)
- **Retention**: Maintain >25% D7
- **Ad Revenue per User**: $0.50-1.00/month

---

## Technical Implementation

### Prerequisites

#### 1. Create AdMob Account
```
1. Go to https://admob.google.com/
2. Sign in with Google account
3. Create new app:
   - Name: Bragging Rights
   - Platform: Android + iOS
   - Category: Sports
4. Get App IDs:
   - Android App ID: ca-app-pub-XXXXXX~YYYYYY
   - iOS App ID: ca-app-pub-XXXXXX~ZZZZZZ
```

#### 2. Create Ad Units

**Rewarded Video Ad:**
```
Name: BR Reward Video
Format: Rewarded
Android ID: ca-app-pub-XXXXXX/1111111111
iOS ID: ca-app-pub-XXXXXX/2222222222
```

**Interstitial Ad (Phase 2):**
```
Name: Pool Completion Interstitial
Format: Interstitial
Android ID: ca-app-pub-XXXXXX/3333333333
iOS ID: ca-app-pub-XXXXXX/4444444444
```

---

### Step-by-Step Implementation

#### Step 1: Install Package

**File**: `pubspec.yaml`

```yaml
dependencies:
  google_mobile_ads: ^5.2.0  # Add this line
```

Run:
```bash
cd bragging_rights_app
flutter pub get
```

---

#### Step 2: Configure Android

**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
    android:label="bragging_rights_app"
    android:icon="@mipmap/ic_launcher">

    <!-- ADD THIS BLOCK -->
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-XXXXXX~YYYYYY"/>  <!-- Replace with your Android App ID -->

    <!-- Rest of your manifest -->
  </application>
</manifest>
```

---

#### Step 3: Configure iOS

**File**: `ios/Runner/Info.plist`

```xml
<dict>
  <!-- ADD THIS BLOCK -->
  <key>GADApplicationIdentifier</key>
  <string>ca-app-pub-XXXXXX~ZZZZZZ</string>  <!-- Replace with your iOS App ID -->

  <!-- For iOS 14+ ATT (App Tracking Transparency) -->
  <key>NSUserTrackingUsageDescription</key>
  <string>We show personalized ads to support free users. Your data stays private.</string>

  <!-- SKAdNetwork IDs for ad networks -->
  <key>SKAdNetworkItems</key>
  <array>
    <!-- Google AdMob -->
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <!-- Facebook -->
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <!-- Unity Ads -->
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4468km3ulz.skadnetwork</string>
    </dict>
    <!-- Add more as needed -->
  </array>

  <!-- Rest of your Info.plist -->
</dict>
```

---

#### Step 4: Update Ad Service with Real IDs

**File**: `lib/services/ad_reward_service.dart`

```dart
class AdRewardService {
  // REPLACE TEST IDS WITH YOUR ACTUAL AD UNIT IDS FROM ADMOB

  // Test IDs (for development only)
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  // Production IDs (replace with yours)
  static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-XXXXXX/1111111111';
  static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXX/2222222222';

  // Use test IDs in debug mode, production IDs in release
  String get _adUnitId {
    final isProduction = bool.fromEnvironment('dart.vm.product');

    if (defaultTargetPlatform == TargetPlatform.android) {
      return isProduction ? _prodRewardedAdUnitIdAndroid : _testRewardedAdUnitIdAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return isProduction ? _prodRewardedAdUnitIdIOS : _testRewardedAdUnitIdIOS;
    }
    return _testRewardedAdUnitIdAndroid;
  }
}
```

---

#### Step 5: Initialize AdMob in Main

**File**: `lib/main.dart`

```dart
import 'services/ad_reward_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize AdMob SDK
  await AdRewardService.initialize();
  debugPrint('✅ AdMob initialized');

  runApp(const MyApp());
}
```

---

#### Step 6: Create Interstitial Ad Service (Phase 2)

**File**: `lib/services/interstitial_ad_service.dart` (NEW)

```dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  // Ad Unit IDs
  static const String _testInterstitialIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _prodInterstitialIdAndroid = 'ca-app-pub-XXXXXX/3333333333';
  static const String _prodInterstitialIdIOS = 'ca-app-pub-XXXXXX/4444444444';

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;

  // Frequency control
  DateTime? _lastShownTime;
  int _sessionAdCount = 0;
  static const int MAX_ADS_PER_SESSION = 3;
  static const int MIN_MINUTES_BETWEEN_ADS = 10;

  String get _adUnitId {
    final isProduction = bool.fromEnvironment('dart.vm.product');
    if (defaultTargetPlatform == TargetPlatform.android) {
      return isProduction ? _prodInterstitialIdAndroid : _testInterstitialIdAndroid;
    } else {
      return isProduction ? _prodInterstitialIdIOS : _testInterstitialIdIOS;
    }
  }

  /// Load interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_isAdLoading || _isAdReady) return;

    _isAdLoading = true;

    await InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdReady = true;
          _isAdLoading = false;
          debugPrint('✅ Interstitial ad loaded');

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
              loadInterstitialAd(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _isAdReady = false;
          debugPrint('❌ Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Check if we can show an ad (respects frequency limits)
  bool canShowAd() {
    // Session limit
    if (_sessionAdCount >= MAX_ADS_PER_SESSION) {
      debugPrint('⏸️ Session ad limit reached');
      return false;
    }

    // Cooldown period
    if (_lastShownTime != null) {
      final minutesSince = DateTime.now().difference(_lastShownTime!).inMinutes;
      if (minutesSince < MIN_MINUTES_BETWEEN_ADS) {
        debugPrint('⏸️ Cooldown active: ${MIN_MINUTES_BETWEEN_ADS - minutesSince} min remaining');
        return false;
      }
    }

    // Ad ready
    if (!_isAdReady || _interstitialAd == null) {
      debugPrint('⏸️ Ad not ready');
      return false;
    }

    return true;
  }

  /// Show interstitial ad
  Future<bool> showInterstitialAd() async {
    if (!canShowAd()) return false;

    await _interstitialAd!.show();
    _lastShownTime = DateTime.now();
    _sessionAdCount++;

    debugPrint('📺 Showed interstitial ad (#$_sessionAdCount this session)');
    return true;
  }

  /// Reset session counter (call on app restart)
  void resetSession() {
    _sessionAdCount = 0;
    debugPrint('🔄 Ad session reset');
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
```

---

## Ad Placement Strategy

### Phase 1: Rewarded Video Only

#### **Placement 1: BR Currency Shop** 🏪
**Screen**: `lib/screens/wallet/br_shop_screen.dart` (or wherever you show BR purchase)

**UI Design**:
```dart
// Prominent placement at top
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [AppTheme.neonGreen, AppTheme.primaryCyan],
    ),
    borderRadius: BorderRadius.circular(16),
  ),
  padding: EdgeInsets.all(16),
  child: Row(
    children: [
      Icon(Icons.video_library, size: 48),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Watch & Earn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Earn 25 BR per video (3/5 today)', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      ElevatedButton(
        onPressed: _onWatchAdTapped,
        child: Text('WATCH'),
      ),
    ],
  ),
)
```

**When**: Any time user visits BR shop

**Expected Engagement**: 40-60% of users who visit shop

---

#### **Placement 2: Out of BR Modal** ⚠️
**Screen**: Any screen where user tries to join pool without enough BR

**UI Design**:
```dart
// Modal/Dialog that appears when user can't afford entry
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Not Enough BR'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('You need 50 BR to join this pool'),
        SizedBox(height: 8),
        Text('Current balance: ${userBalance} BR',
             style: TextStyle(color: Colors.grey)),
        SizedBox(height: 16),

        // WATCH AD OPTION (highlighted)
        ElevatedButton.icon(
          icon: Icon(Icons.play_circle),
          label: Text('WATCH AD - EARN 25 BR'),
          onPressed: _watchAdAndRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonGreen,
          ),
        ),

        SizedBox(height: 8),

        // Buy BR option
        TextButton(
          onPressed: _navigateToBRShop,
          child: Text('Or Buy BR'),
        ),
      ],
    ),
  ),
);
```

**When**: User tries to join pool but balance < entry cost

**Expected Engagement**: 70-80% (high motivation!)

---

#### **Placement 3: Daily Bonus Screen** 🎁
**Screen**: After user claims daily login bonus

**UI Design**:
```dart
// After showing "Daily Bonus: 50 BR Claimed" message
Container(
  margin: EdgeInsets.only(top: 16),
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppTheme.surfaceBlue,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppTheme.neonGreen),
  ),
  child: Column(
    children: [
      Text('Want More BR?', style: TextStyle(fontSize: 16)),
      SizedBox(height: 8),
      Text('Watch videos to earn up to 125 BR today!',
           style: TextStyle(fontSize: 12, color: Colors.grey)),
      SizedBox(height: 12),
      ElevatedButton(
        onPressed: _watchRewardedAd,
        child: Text('WATCH AD - EARN 25 BR (${adsRemaining}/5 left)'),
      ),
    ],
  ),
)
```

**When**: After daily bonus claim (once per day)

**Expected Engagement**: 30-40%

---

### Phase 2: Interstitial Ad Triggers

#### **Trigger 1: After Pool Completion** ✅
**Condition**: User has completed 3+ pools in current session

```dart
void _onPoolCompleted() async {
  _poolsCompletedThisSession++;

  // Show interstitial after every 3 pools
  if (_poolsCompletedThisSession >= 3 && _poolsCompletedThisSession % 3 == 0) {
    if (!_isPremiumUser && _interstitialService.canShowAd()) {
      await _interstitialService.showInterstitialAd();
    }
  }
}
```

**Why**: User is in "completion" mode, natural break point

---

#### **Trigger 2: After Viewing Bet History** 📊
**Condition**: User views past bets screen for 10+ seconds

```dart
class PastBetsScreen extends StatefulWidget {
  @override
  void dispose() {
    // If user spent meaningful time on this screen
    if (_timeOnScreen > Duration(seconds: 10)) {
      if (!_isPremiumUser && _interstitialService.canShowAd()) {
        _interstitialService.showInterstitialAd();
      }
    }
    super.dispose();
  }
}
```

**Why**: User is reviewing past activity, low-pressure moment

---

#### **Trigger 3: After Achievement Unlock** 🏆
**Condition**: User unlocks an achievement

```dart
void _onAchievementUnlocked() {
  // Show celebration UI
  _showAchievementDialog();

  // After user closes dialog, show ad (optional)
  Future.delayed(Duration(seconds: 2), () {
    if (!_isPremiumUser && _interstitialService.canShowAd()) {
      _interstitialService.showInterstitialAd();
    }
  });
}
```

**Why**: User just got positive reinforcement, in good mood

---

#### **Trigger 4: Navigation Between Tabs** 🔄
**Condition**: User switches between main tabs (Games → Bets → Pools)

```dart
int _lastTabIndex = 0;
int _tabSwitchCount = 0;

void _onTabChanged(int newIndex) {
  if (newIndex != _lastTabIndex) {
    _tabSwitchCount++;
    _lastTabIndex = newIndex;

    // Show ad after 5 tab switches
    if (_tabSwitchCount >= 5 && _tabSwitchCount % 5 == 0) {
      if (!_isPremiumUser && _interstitialService.canShowAd()) {
        _interstitialService.showInterstitialAd();
      }
    }
  }
}
```

**Why**: Natural navigation break, user is browsing

⚠️ **IMPORTANT**: This is the MOST aggressive trigger. Start with 10 switches, lower if retention stays strong.

---

## Frequency & Limits

### Daily Limits

```dart
// Constants (configurable)
class AdConfig {
  // Rewarded Ads
  static const int MAX_REWARDED_ADS_PER_DAY = 5;
  static const int BR_PER_REWARDED_AD = 25;
  static const int MAX_BR_FROM_ADS_PER_DAY = 125; // 5 × 25

  // Interstitial Ads (Phase 2)
  static const int MAX_INTERSTITIAL_ADS_PER_SESSION = 3;
  static const int MIN_MINUTES_BETWEEN_INTERSTITIALS = 10;
  static const int MIN_POOLS_BEFORE_FIRST_INTERSTITIAL = 3;

  // Premium Users
  static const bool PREMIUM_USERS_SEE_ADS = false;
}
```

### Reset Schedule

**Daily Reset**: 12:00 AM local time
```dart
// In BRCurrencyService or AdRewardService
bool _shouldResetDailyAds(DateTime lastAdDate) {
  final now = DateTime.now();
  final lastDate = DateTime(lastAdDate.year, lastAdDate.month, lastAdDate.day);
  final today = DateTime(now.year, now.month, now.day);

  return today.isAfter(lastDate);
}
```

**Session Reset**: On app restart
```dart
// In main app state or home screen
@override
void initState() {
  super.initState();
  _interstitialService.resetSession(); // Reset counter
}
```

---

## Premium vs Free Experience

### Free Tier (With Ads)

**What They See:**
```
✅ All app features (simple scoring)
✅ Rewarded video ads (optional, earn BR)
✅ Interstitial ads (occasional, after actions)
✅ Daily BR bonuses + achievements
✅ Can earn up to 125 BR/day from ads
```

**Ad Experience:**
```
- Rewarded: 5 per day max, user-initiated
- Interstitials: 3 per session max, 10-min cooldown
- Total ad time: ~2-5 minutes per session (if active)
```

**Value Prop**: "Play completely free, watch ads to earn BR faster"

---

### Premium Tier ($1.99/month)

**What They See:**
```
✅ All app features (with real odds)
✅ ZERO ADS (completely ad-free)
✅ Exclusive odds-based pools
✅ Edge Intelligence picks
✅ Daily BR bonuses (same as free)
✅ Priority support
```

**Ad Experience:**
```
- Rewarded: NONE
- Interstitials: NONE
- Total ad time: 0 minutes
```

**Value Prop**: "Get the edge with real odds + enjoy ad-free experience"

---

### Upgrade Messaging

#### **In-App Prompts** (For Free Users)

**After Watching 3 Ads:**
```
"🎯 You've earned 75 BR from ads today!

Want to skip the ads and get even better features?

Premium subscribers get:
✓ Zero ads forever
✓ Real Vegas odds
✓ Exclusive pools with bigger prizes
✓ AI-powered picks

Try FREE for 7 days, then just $1.99/month

[START FREE TRIAL] [Maybe Later]"
```

**After Seeing 2 Interstitials:**
```
"😤 Tired of ads?

Premium = No ads + Real odds + Exclusive features

Less than a coffee per month!

[UPGRADE TO PREMIUM] [Stay Free]"
```

**In Settings Screen:**
```
Current Plan: FREE
Ads Watched Today: 3/5

[UPGRADE TO PREMIUM - GO AD-FREE]
↑ Highlighted button
```

---

## Revenue Projections

### Phase 1: Rewarded Ads Only (Months 1-2)

**Assumptions:**
- 1,000 free users
- 30% watch ads daily (300 active)
- Average 2 ads per user per day
- $20 CPM (rewarded video average)

**Calculation:**
```
300 users × 2 ads/day × 30 days = 18,000 ad views/month
18,000 ÷ 1,000 × $20 CPM = $360 gross
$360 × 68% (after Google's 32% cut) = $245 net/month
```

**Range**: $150-400/month (conservative to optimistic)

---

### Phase 2: Rewarded + Interstitials (Months 3-4)

**Assumptions:**
- 1,500 free users (growth)
- Rewarded: Same as Phase 1 (35% engagement)
- Interstitials: 2 per session, 60% of users
- $10 CPM (interstitial average)

**Calculation:**
```
Rewarded:
525 users × 2 ads/day × 30 days = 31,500 views
31,500 ÷ 1,000 × $20 CPM × 68% = $428/month

Interstitials:
900 users × 2 ads/day × 30 days = 54,000 views
54,000 ÷ 1,000 × $10 CPM × 68% = $367/month

TOTAL: $428 + $367 = $795/month
```

**Range**: $600-1,200/month

---

### Phase 3: Optimized (Months 5-6)

**Assumptions:**
- 2,500 free users
- Optimized ad placements
- Better CPM from ad mediation
- Some native ads

**Calculation:**
```
Rewarded: $700/month
Interstitials: $600/month
Native: $200/month
TOTAL: $1,500/month
```

**Range**: $1,200-2,500/month

---

### 12-Month Projection

| Month | Free Users | Ad Revenue | Premium Revenue | Total Revenue |
|-------|------------|------------|-----------------|---------------|
| 1-2   | 1,000      | $250       | $300            | $550          |
| 3-4   | 1,500      | $800       | $600            | $1,400        |
| 5-6   | 2,000      | $1,300     | $1,000          | $2,300        |
| 7-9   | 3,000      | $2,000     | $1,500          | $3,500        |
| 10-12 | 4,000      | $2,800     | $2,500          | $5,300        |

**Year 1 Total**: ~$25,000 combined (ads + premium)

---

## User Experience Guidelines

### DO's ✅

1. **Preload Ads**
   ```dart
   // Load next ad in background
   @override
   void initState() {
     super.initState();
     _adService.loadRewardedAd(); // Ready when user wants it
   }
   ```

2. **Show Clear Value**
   ```dart
   // Tell user what they'll earn
   Text('Watch 30-second video → Earn 25 BR')
   ```

3. **Respect Premium Status**
   ```dart
   // ALWAYS check before showing ads
   if (user.isPremium || user.adminOverride?.forcePremiumTier == true) {
     return; // No ads for premium
   }
   ```

4. **Provide Feedback**
   ```dart
   // After ad completes
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Text('✅ Earned 25 BR! New balance: ${newBalance}'),
       backgroundColor: AppTheme.neonGreen,
     ),
   );
   ```

5. **Handle Errors Gracefully**
   ```dart
   // If ad fails to load
   if (!adReady) {
     showDialog(
       context: context,
       builder: (_) => AlertDialog(
         title: Text('Ad Not Available'),
         content: Text('Try again in a few seconds, or purchase BR instead.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
         ],
       ),
     );
   }
   ```

---

### DON'Ts ❌

1. **DON'T Interrupt Critical Actions**
   ```dart
   // NEVER show interstitial during:
   ❌ Bet placement
   ❌ Pool joining
   ❌ Payment flow
   ❌ Form submission
   ❌ Game loading
   ```

2. **DON'T Spam Users**
   ```dart
   // BAD - No cooldown
   ❌ Show ad after every single action

   // GOOD - Respect frequency
   ✅ Max 3 per session, 10-min cooldown
   ```

3. **DON'T Forget to Dispose**
   ```dart
   @override
   void dispose() {
     _adService.dispose(); // Clean up ad resources
     super.dispose();
   }
   ```

4. **DON'T Block UI**
   ```dart
   // BAD - Loading ad blocks UI
   ❌ await loadAd(); // User waits

   // GOOD - Load in background
   ✅ loadAd(); // Non-blocking, ready when needed
   ```

5. **DON'T Show Ads to Premium**
   ```dart
   // ALWAYS check subscription status
   if (user.isPremium) {
     return; // Skip all ad logic
   }
   ```

---

## Testing & Optimization

### Testing Plan

#### Phase 1 Testing (Rewarded Ads)

**Week 1-2: Development**
- ✅ Use test ad IDs
- ✅ Test on Android emulator + physical device
- ✅ Test on iOS simulator + physical device
- ✅ Verify BR currency awarded correctly
- ✅ Test daily limit enforcement
- ✅ Test premium user bypass

**Week 3-4: Alpha Testing**
- ✅ Deploy to 10 alpha testers
- ✅ Track: Ad load success rate, completion rate, BR awards
- ✅ Collect feedback on UX
- ✅ Fix bugs

**Week 5-6: Beta Testing**
- ✅ Deploy to 50-100 beta users
- ✅ Monitor: Ad revenue, user retention, complaints
- ✅ A/B test: Different ad placements
- ✅ Optimize based on data

**Week 7: Production Launch**
- ✅ Switch to production ad IDs
- ✅ Enable for all free users
- ✅ Monitor closely for first week

---

#### Phase 2 Testing (Interstitials)

**Week 1: Conservative Test**
- ✅ Enable for 25% of free users
- ✅ Settings: Max 2 per session, 15-min cooldown
- ✅ Monitor D7 retention closely

**Week 2: Moderate Test**
- ✅ Enable for 50% of users
- ✅ Settings: Max 3 per session, 12-min cooldown
- ✅ Compare retention vs control group

**Week 3: Aggressive Test**
- ✅ Settings: Max 3 per session, 10-min cooldown
- ✅ If retention holds, enable for all users
- ✅ If retention drops >5%, roll back

---

### A/B Testing Ideas

**Test 1: Rewarded Ad Limit**
- Group A: 5 ads per day (current)
- Group B: 10 ads per day
- Measure: Ad revenue, user satisfaction, churn

**Test 2: Interstitial Frequency**
- Group A: Max 2 per session
- Group B: Max 4 per session
- Measure: Revenue, retention, upgrade rate

**Test 3: Upgrade Prompt Timing**
- Group A: Show after 3 ads watched
- Group B: Show after 2 interstitials seen
- Measure: Premium conversion rate

**Test 4: Ad Placement**
- Group A: Interstitial after pool completion
- Group B: Interstitial on tab navigation
- Measure: User engagement, retention

---

### Key Metrics to Track

```dart
// Analytics events to implement

// Rewarded Ads
logEvent('rewarded_ad_loaded', {'screen': screenName});
logEvent('rewarded_ad_shown', {'user_id': userId});
logEvent('rewarded_ad_completed', {'br_earned': 25});
logEvent('rewarded_ad_failed', {'error': errorMessage});

// Interstitials
logEvent('interstitial_loaded');
logEvent('interstitial_shown', {'trigger': 'pool_completion'});
logEvent('interstitial_closed', {'duration_seconds': 5});

// Revenue
logEvent('ad_impression', {
  'ad_type': 'rewarded',
  'ad_network': 'admob',
  'estimated_revenue': 0.025, // $25 CPM / 1000
});

// User Behavior
logEvent('user_frustrated_by_ad', {'action': 'closed_app_after_ad'});
logEvent('premium_upgrade_after_ad', {'ads_seen_before_upgrade': 5});
```

**Dashboard to Build:**
```
Daily Metrics:
- Ad impressions (rewarded, interstitial)
- Ad revenue (estimated)
- Ad completion rate
- Users who saw ads
- BR distributed from ads

Weekly Metrics:
- D7 retention (free vs premium)
- Premium conversion rate
- Ad fatigue indicators
- User complaints about ads

Monthly Metrics:
- Total ad revenue
- CPM trends
- Best performing placements
- Optimal frequency settings
```

---

## Legal & Compliance

### App Store Policies

#### Apple App Store Requirements

**Allowed:**
- ✅ Rewarded video ads (user-initiated)
- ✅ Interstitial ads (between actions)
- ✅ Native ads (clearly labeled)
- ✅ Premium = ad-free option

**Prohibited:**
- ❌ Incentivized clicks (can't say "click this ad")
- ❌ Misleading "free" claims if ads are mandatory
- ❌ Ads during IAP flows
- ❌ Tricking users into clicking ads

**Your Compliance:**
```
✅ Rewarded ads = user chooses to watch
✅ Interstitials = clearly skippable after 5 sec
✅ Premium tier = legitimate ad-free option
✅ "Free to play" = accurate (ads are optional for rewards)
```

---

#### Google Play Store Requirements

**Allowed:**
- ✅ All ad types (rewarded, interstitial, banner, native)
- ✅ Ad mediation (multiple networks)
- ✅ Premium ad-free option

**Prohibited:**
- ❌ Deceptive ads (disguised as content)
- ❌ Interfering with device functionality
- ❌ Ads in notifications
- ❌ Violating Google's ad policies

**Your Compliance:**
```
✅ Using Google AdMob (approved platform)
✅ Ads clearly distinguishable from content
✅ Respects user experience
✅ Age-appropriate (18+)
```

---

### Privacy & GDPR Compliance

#### User Data & Ads

**What AdMob Collects:**
- Device information (OS, model, screen size)
- IP address (for geo-targeting)
- Ad interaction data (clicks, views)
- App activity (for targeting)

**Your Responsibilities:**

1. **Update Privacy Policy**
   ```markdown
   ## Advertising

   Our free tier is supported by ads from Google AdMob.
   AdMob may collect and use your device information and
   app activity to show personalized ads. You can opt out
   of personalized ads in your device settings.

   Premium subscribers ($1.99/month) see zero ads and
   have reduced data collection.

   For more info: https://policies.google.com/privacy
   ```

2. **GDPR Consent (EU Users)**
   ```dart
   // For EU users, get consent before showing ads
   import 'package:google_mobile_ads/google_mobile_ads.dart';

   Future<void> requestConsent() async {
     final params = ConsentRequestParameters();
     ConsentInformation.instance.requestConsentInfoUpdate(
       params,
       () async {
         // Consent updated
         if (await ConsentInformation.instance.isConsentFormAvailable()) {
           loadConsentForm();
         }
       },
       (FormError error) {
         // Handle error
       },
     );
   }
   ```

3. **COPPA Compliance**
   ```dart
   // Since you're 18+ only, no COPPA concerns
   // But if you ever lower age, need special handling
   final request = AdRequest(
     tagForChildDirectedTreatment: false, // Not a kids app
   );
   ```

---

### Terms of Service Updates

**Add Section:**

```markdown
## 7. Advertisements

### Free Tier
Our free tier is ad-supported. You may see:
- Optional rewarded video ads (watch to earn BR currency)
- Occasional interstitial ads (full-screen, between actions)

You can always earn BR for free by watching ads.
Ads are optional and can be skipped or avoided by upgrading to Premium.

### Premium Tier
Premium subscribers ($1.99/month) receive a completely ad-free experience.

### Ad Content
We use Google AdMob to serve ads. We do not control the specific ads shown,
but we configure settings to avoid inappropriate content. If you see an
inappropriate ad, please report it in Settings > Help.

### Opting Out
You can opt out of personalized ads in your device settings:
- iOS: Settings > Privacy > Advertising > Limit Ad Tracking
- Android: Settings > Google > Ads > Opt out of Ads Personalization

Or upgrade to Premium for a completely ad-free experience.
```

---

## Analytics & Monitoring

### AdMob Dashboard Metrics

**Daily Checks:**
```
- Estimated earnings
- Ad requests
- Impressions
- Click-through rate (CTR)
- eCPM (effective cost per thousand impressions)
```

**Weekly Reviews:**
```
- Top performing ad units
- Network performance (if using mediation)
- Invalid traffic percentage
- Policy violations (should be 0%)
```

**Monthly Analysis:**
```
- Revenue trends
- Seasonal patterns
- User engagement with ads
- Optimization opportunities
```

---

### Custom Analytics Events

**File**: `lib/services/ad_analytics_service.dart` (NEW)

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AdAnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Rewarded Ad Events
  Future<void> logRewardedAdRequest(String screen) async {
    await _analytics.logEvent(
      name: 'rewarded_ad_requested',
      parameters: {'screen': screen},
    );
  }

  Future<void> logRewardedAdShown() async {
    await _analytics.logEvent(name: 'rewarded_ad_shown');
  }

  Future<void> logRewardedAdCompleted(int brEarned) async {
    await _analytics.logEvent(
      name: 'rewarded_ad_completed',
      parameters: {'br_earned': brEarned},
    );
  }

  Future<void> logRewardedAdSkipped() async {
    await _analytics.logEvent(name: 'rewarded_ad_skipped');
  }

  // Interstitial Ad Events
  Future<void> logInterstitialShown(String trigger) async {
    await _analytics.logEvent(
      name: 'interstitial_shown',
      parameters: {'trigger': trigger},
    );
  }

  Future<void> logInterstitialClicked() async {
    await _analytics.logEvent(name: 'interstitial_clicked');
  }

  // User Behavior
  Future<void> logDailyAdLimitReached() async {
    await _analytics.logEvent(name: 'daily_ad_limit_reached');
  }

  Future<void> logPremiumUpgradeAfterAds(int adsSeenBeforeUpgrade) async {
    await _analytics.logEvent(
      name: 'premium_upgrade_from_ads',
      parameters: {'ads_seen': adsSeenBeforeUpgrade},
    );
  }

  // Revenue Estimation
  Future<void> logAdRevenue(String adType, double estimatedRevenue) async {
    await _analytics.logEvent(
      name: 'ad_revenue',
      parameters: {
        'ad_type': adType,
        'value': estimatedRevenue,
        'currency': 'USD',
      },
    );
  }
}
```

---

### Performance Monitoring

**Questions to Answer:**

1. **Are ads loading successfully?**
   - Target: >95% load success rate
   - Alert if: <80% for 24 hours

2. **Are users completing rewarded ads?**
   - Target: >70% completion rate
   - Alert if: <50% for 48 hours

3. **Is ad revenue meeting projections?**
   - Target: $0.30-0.50 per free DAU per month
   - Alert if: <$0.20 for 7 days

4. **Are ads affecting retention?**
   - Compare D7 retention: Free (with ads) vs Premium (no ads)
   - Expected: 2-5% difference
   - Alert if: >10% difference

5. **Are interstitials too aggressive?**
   - Monitor: Session length, pools entered, churn rate
   - Alert if: Churn increases >5% after enabling interstitials

---

## Implementation Checklist

### Pre-Launch Setup

#### AdMob Configuration
- [ ] Create AdMob account
- [ ] Add Android app to AdMob
- [ ] Add iOS app to AdMob
- [ ] Create Rewarded Video ad unit (Android)
- [ ] Create Rewarded Video ad unit (iOS)
- [ ] Create Interstitial ad unit (Android) - Phase 2
- [ ] Create Interstitial ad unit (iOS) - Phase 2
- [ ] Configure mediation (optional)
- [ ] Set up payment profile (bank account)

#### Code Changes
- [ ] Add `google_mobile_ads` to pubspec.yaml
- [ ] Update `ad_reward_service.dart` with production IDs
- [ ] Create `interstitial_ad_service.dart` (Phase 2)
- [ ] Create `ad_analytics_service.dart`
- [ ] Update Android manifest with App ID
- [ ] Update iOS Info.plist with App ID
- [ ] Initialize AdMob in main.dart
- [ ] Add ad triggers to relevant screens
- [ ] Implement premium user bypass

#### Testing
- [ ] Test rewarded ads on Android (test IDs)
- [ ] Test rewarded ads on iOS (test IDs)
- [ ] Verify BR currency awarded correctly
- [ ] Test daily limit enforcement
- [ ] Test premium user sees no ads
- [ ] Test ad load failures (airplane mode)
- [ ] Test rapid clicking (shouldn't break)
- [ ] Switch to production IDs for final testing

#### Legal & Compliance
- [ ] Update Privacy Policy (ads section)
- [ ] Update Terms of Service (ads section)
- [ ] Add GDPR consent flow (EU users)
- [ ] Test age gate (18+ enforcement)
- [ ] Review AdMob policies
- [ ] Configure ad categories (block inappropriate)

#### Analytics
- [ ] Set up Firebase Analytics events
- [ ] Create AdMob dashboard
- [ ] Set up revenue tracking
- [ ] Configure alerts (low revenue, high errors)
- [ ] Create weekly report template

---

### Phase 1 Launch Checklist

#### Week Before Launch
- [ ] Final testing with production ad IDs
- [ ] Prepare rollback plan
- [ ] Write announcement for users
- [ ] Train support team on ad questions
- [ ] Set up monitoring dashboards

#### Launch Day
- [ ] Deploy app update with ads
- [ ] Monitor ad load success rate
- [ ] Watch for user complaints
- [ ] Check AdMob dashboard (impressions, revenue)
- [ ] Respond to feedback quickly

#### Week After Launch
- [ ] Review analytics (engagement, retention)
- [ ] Calculate actual vs projected revenue
- [ ] Identify optimization opportunities
- [ ] Plan Phase 2 timing

---

### Phase 2 Launch Checklist

#### Before Enabling Interstitials
- [ ] Phase 1 running smoothly for 4+ weeks
- [ ] User retention stable
- [ ] Ad revenue meeting projections
- [ ] No major complaints about rewarded ads
- [ ] Interstitial code tested thoroughly

#### Gradual Rollout
- [ ] Enable for 10% of users (A/B test)
- [ ] Monitor retention closely
- [ ] Compare revenue: control vs test group
- [ ] If successful, increase to 25% → 50% → 100%
- [ ] If retention drops >5%, roll back

---

## Next Steps - Discussion Topics

Now that you have the comprehensive plan, let's discuss:

### **1. Screen Placements** 📱
- Which screens should show rewarded ads?
- Which screens should show interstitials (Phase 2)?
- Any screens where ads should NEVER appear?

### **2. Aggressiveness Level** ⚡
- Start conservative (my recommendation) or moderate?
- Daily ad limits: 5 or 10 for rewarded?
- Interstitial frequency: 2 or 3 per session?

### **3. Premium Messaging** 💎
- When to show "Go Premium - Remove Ads" prompts?
- How prominent should ad-free be in premium benefits?
- Offer "Remove Ads Only" IAP ($0.99) separate from full premium?

### **4. Testing Strategy** 🧪
- Alpha test group size (10 users or 50)?
- Beta test duration (2 weeks or 4 weeks)?
- A/B test interstitials on 50% or everyone?

### **5. Revenue Targets** 💰
- Is $500-1,500/month realistic for your user base?
- What's your minimum acceptable ad revenue?
- Priority: Revenue or user retention?

---

**Ready to discuss these topics whenever you are!** 🚀

