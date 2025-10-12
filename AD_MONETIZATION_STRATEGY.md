# Ad Monetization Strategy & Implementation Roadmap

## Overview
This document outlines the current ad implementation, future opportunities, and actionable steps to maximize ad revenue in the Bragging Rights sports app.

---

## Current Implementation ✅

### What's Already Built

#### 1. Google AdMob Integration
- **Service:** `lib/services/ad_reward_service.dart`
- **Platform:** Google AdMob (Rewarded Video Ads)
- **Status:** Fully implemented and functional

**Configuration:**
```dart
// Android App ID: ca-app-pub-6550805819637330~3890172020
// Production Ad Unit (Android): ca-app-pub-6550805819637330/2465409717
// iOS Ad Unit: PENDING - Needs creation in AdMob console
```

#### 2. Reward Structure
- **Reward per ad:** 25 BR
- **Daily limit:** 5 ads per user
- **Max daily earnings:** 125 BR per user
- **Ad length:** ~30 seconds

#### 3. User Experience
- **Location:** BR Shop Screen (`lib/screens/rewards/br_shop_screen.dart`)
- **Features:**
  - Balance display
  - Daily ad progress tracker (X/5 ads watched)
  - Potential earnings calculator
  - Ad preloading for instant playback
  - Success/error feedback
  - Premium upsell (ad-free option)

#### 4. Backend Integration
- **Currency Service:** `lib/services/br_currency_service.dart`
- **Daily limit enforcement:** Firestore tracks `adsWatchedToday` field
- **Date reset logic:** Automatically resets count at midnight
- **Transaction logging:** All ad rewards logged to user wallet
- **Firestore Security:** Rules allow users to read/write their own wallet

---

## Known Issues 🔧

### High Priority Fixes

#### 1. Ad Watch Status Not Reading from Firestore
**File:** `lib/services/ad_reward_service.dart` (lines 193-212)

**Issue:**
```dart
Future<AdWatchStatus> getAdWatchStatus(String userId) async {
  return AdWatchStatus(
    adsWatchedToday: 0, // ← HARDCODED! Should read from Firestore
    maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
    brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
    canWatchMore: true,
  );
}
```

**Fix:**
```dart
Future<AdWatchStatus> getAdWatchStatus(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = userDoc.data() ?? {};
    final adsWatched = data['adsWatchedToday'] ?? 0;
    final lastAdDate = data['lastAdWatchDate'] as Timestamp?;

    // Reset count if it's a new day
    final today = DateTime.now();
    final lastDate = lastAdDate?.toDate();
    final isSameDay = lastDate != null &&
        lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;

    final actualAdsWatched = isSameDay ? adsWatched : 0;
    final canWatch = actualAdsWatched < BRCurrencyService.MAX_ADS_PER_DAY;

    return AdWatchStatus(
      adsWatchedToday: actualAdsWatched,
      maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
      brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
      canWatchMore: canWatch,
    );
  } catch (e) {
    debugPrint('Error getting ad watch status: $e');
    return AdWatchStatus(
      adsWatchedToday: 0,
      maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
      brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
      canWatchMore: false,
    );
  }
}
```

#### 2. Missing iOS Ad Unit ID
**File:** `lib/services/ad_reward_service.dart` (line 17)

**Current:**
```dart
static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXX/2222222222'; // iOS when needed
```

**Action Required:**
1. Log into [Google AdMob Console](https://apps.admob.com/)
2. Navigate to Apps → Bragging Rights (iOS)
3. Create new Rewarded Ad Unit
4. Copy the ad unit ID (format: `ca-app-pub-XXXXXX/YYYYYYYYYY`)
5. Replace placeholder in code

---

## Revenue Optimization Opportunities 💰

### 1. Ad Mediation (HIGH IMPACT)

**Current State:** Only using Google AdMob
**Problem:** Single ad network = lower CPM rates
**Solution:** Implement ad mediation to increase competition for your ad inventory

#### Recommended Platforms

| Platform | Best For | Revenue Increase | Integration Effort |
|----------|----------|------------------|-------------------|
| **AppLovin MAX** | All app types, maximizes bidding | +30-40% | Medium |
| **Unity LevelPlay (ironSource)** | Gaming/gamification apps | +25-35% | Medium |
| **Google Ad Manager** | Large-scale operations | +20-30% | High |

#### Why Mediation Matters
- Multiple ad networks compete for each impression
- Automatic fallback if one network has no ads
- Higher fill rates (fewer failed ad loads)
- Better eCPM through real-time bidding

#### Implementation Steps (AppLovin MAX)

1. **Add Dependency**
```yaml
# pubspec.yaml
dependencies:
  applovin_max: ^3.0.0
```

2. **Initialize SDK**
```dart
// lib/main.dart
await AppLovinMAX.initialize('YOUR_SDK_KEY');
await AppLovinMAX.setMediationProvider('max');
```

3. **Load Rewarded Ad via Mediation**
```dart
// lib/services/ad_reward_service.dart
AppLovinMAX.loadRewardedAd('YOUR_AD_UNIT_ID');
```

4. **Configure Waterfall in AppLovin Dashboard**
- Add AdMob as mediated network
- Add Unity Ads, Meta Audience Network, etc.
- Set CPM floors to maximize revenue

**Expected Result:** 30-40% increase in ad revenue with minimal code changes

---

### 2. Strategic Ad Placements (MEDIUM-HIGH IMPACT)

#### A. Edge Intelligence "Unlock with Ad" Option

**Concept:** Let users unlock Edge Intelligence cards by watching an ad instead of spending BR

**Implementation:**

**File:** `lib/widgets/edge/edge_card_widget.dart` or `lib/screens/premium/edge_detail_screen_v2.dart`

**Current Unlock Flow:**
```
[Locked Card] → [Pay 50 BR] → [Unlocked]
```

**New Unlock Flow:**
```
[Locked Card] → [Pay 50 BR] OR [Watch Ad] → [Unlocked]
```

**UI Changes:**
```dart
// Add to unlock dialog
Row(
  children: [
    // Option 1: Pay with BR
    Expanded(
      child: ElevatedButton(
        onPressed: () => _unlockWithBR(cardId),
        child: Column(
          children: [
            Icon(PhosphorIconsRegular.coins),
            Text('50 BR'),
          ],
        ),
      ),
    ),
    SizedBox(width: 12),
    // Option 2: Watch Ad
    Expanded(
      child: ElevatedButton(
        onPressed: () => _unlockWithAd(cardId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
        ),
        child: Column(
          children: [
            Icon(PhosphorIconsRegular.videoCamera),
            Text('Watch Ad'),
            Text('FREE', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  ],
)

Future<void> _unlockWithAd(String cardId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Check if ad is available
  if (!_adService.isAdReady()) {
    _showError('Ad not ready. Please try BR unlock or wait a moment.');
    return;
  }

  // Show ad
  final result = await _adService.showRewardedAdForUnlock(user.uid);

  if (result.success) {
    // Unlock the card (skip BR deduction)
    await _unlockCard(cardId, method: 'ad_watch');
    _showSuccess('Card unlocked! Thanks for watching.');
  }
}
```

**Backend Changes:**
```dart
// lib/services/ad_reward_service.dart
Future<AdRewardResult> showRewardedAdForUnlock(String userId) async {
  // Similar to showRewardedAd() but doesn't award BR
  // Just verifies ad was watched successfully
  if (!_isAdReady || _rewardedAd == null) {
    return AdRewardResult(success: false, message: 'Ad not ready');
  }

  bool rewardEarned = false;
  await _rewardedAd!.show(
    onUserEarnedReward: (ad, reward) {
      rewardEarned = true;
    },
  );

  await Future.delayed(const Duration(seconds: 1));

  return AdRewardResult(
    success: rewardEarned,
    message: rewardEarned ? 'Ad watched successfully' : 'Ad closed early',
  );
}
```

**Revenue Impact:**
- Edge cards cost 50 BR (equal to 2 ads)
- If 30% of users choose ad unlock → 2x ad impressions on Edge unlocks
- Higher user engagement (removes BR barrier)

---

#### B. "Double Your Winnings" Post-Bet Bonus

**Concept:** After winning a bet, offer to watch ad for +10-20% bonus on winnings

**User Flow:**
```
[Bet Wins] → [+100 BR] → [Watch ad to get +20 BR bonus?] → [Accept] → [Ad plays] → [+20 BR awarded]
```

**Implementation:**

**File:** `lib/screens/bets/active_bets_screen.dart` or bet settlement notification

**Trigger Point:** When bet status changes from 'pending' to 'won'

```dart
// After bet settles as won
Future<void> _offerWinningsBoost(Bet bet, int winnings) async {
  final bonus = (winnings * 0.2).round(); // 20% bonus

  final shouldShow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('🎉 Congrats on Your Win!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You won $winnings BR'),
          SizedBox(height: 16),
          Text(
            'Watch a quick ad to boost your winnings by $bonus BR!',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('No Thanks'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonGreen,
          ),
          child: Text('Watch Ad (+$bonus BR)'),
        ),
      ],
    ),
  );

  if (shouldShow == true) {
    final result = await _adService.showRewardedAd(user.uid);
    if (result.success) {
      // Award the bonus
      await _brService.awardBonus(user.uid, bonus, reason: 'win_boost_ad');
      _showSuccess('Earned $bonus BR bonus!');
    }
  }
}
```

**When to Show:**
- Only after successful bet wins (high engagement moment)
- Limit to 3 win boost ads per day (prevent abuse)
- Track in Firestore: `winBoostAdsWatchedToday`

**Revenue Impact:**
- Users are most engaged right after winning
- High conversion rate (70-80% likely to watch)
- Doesn't reduce regular ad impressions

---

#### C. "Boost Daily Login Bonus"

**Concept:** Watch ad to double daily login BR bonus

**Current System:** You have `lib/services/welcome_back_service.dart` and `lib/widgets/welcome_back_overlay.dart`

**Enhancement:**
```dart
// In welcome back overlay
Widget _buildDailyBonus(int baseAmount) {
  return Column(
    children: [
      Text('Daily Bonus: $baseAmount BR'),
      SizedBox(height: 12),
      ElevatedButton(
        onPressed: _watchAdForDoubleBonus,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.videoCamera),
            SizedBox(width: 8),
            Text('Watch Ad to Double (${baseAmount * 2} BR)'),
          ],
        ),
      ),
    ],
  );
}
```

**Logic:**
```dart
Future<void> _watchAdForDoubleBonus() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final result = await _adService.showRewardedAd(user.uid);

  if (result.success) {
    // Award the additional bonus amount
    final baseBonus = 50; // Whatever your daily bonus is
    await _brService.awardBonus(user.uid, baseBonus, reason: 'daily_login_boost');
    _showSuccess('Daily bonus doubled to ${baseBonus * 2} BR!');
  }
}
```

**Revenue Impact:**
- Guarantees 1 ad per daily active user
- Non-intrusive (opt-in)
- High conversion (everyone wants more BR)

---

#### D. "Preview Injury Intel with Ad"

**Concept:** Free preview of injury reports by watching ad

**File:** `lib/screens/intel/injury_intel_purchase_screen.dart`

**Implementation:**
```dart
// Add preview button
ElevatedButton(
  onPressed: _watchAdForPreview,
  child: Row(
    children: [
      Icon(PhosphorIconsRegular.videoCamera),
      Text('Watch Ad for Free Preview'),
    ],
  ),
)

Future<void> _watchAdForPreview() async {
  final result = await _adService.showRewardedAdForUnlock(user.uid);

  if (result.success) {
    // Show limited preview (first 3 injuries, no detailed analysis)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InjuryReportViewScreen(
          injuries: injuries.take(3).toList(),
          isPreview: true, // Show "unlock full report" banner
        ),
      ),
    );
  }
}
```

**Revenue Impact:**
- Converts curious users who won't pay BR
- Upsells to full purchase after preview
- Low-friction entry point

---

### 3. Ad Frequency Optimization

#### Current System
- **All users:** 5 ads/day = 125 BR max

#### Proposed Tiered System

```dart
// lib/services/br_currency_service.dart
static int getMaxAdsForUser(Map<String, dynamic> userData) {
  final totalBetsPlaced = userData['totalBetsPlaced'] ?? 0;
  final isPremium = userData['isPremium'] ?? false;

  if (isPremium) return 0; // No ads for premium
  if (totalBetsPlaced >= 50) return 7; // Power users
  if (totalBetsPlaced >= 10) return 6; // Active users
  return 5; // Default
}
```

| User Tier | Criteria | Ads/Day | Daily BR |
|-----------|----------|---------|----------|
| Premium | isPremium = true | 0 | N/A |
| Power User | 50+ bets placed | 7 | 175 BR |
| Active User | 10+ bets placed | 6 | 150 BR |
| Default | All others | 5 | 125 BR |

**Rationale:**
- Reward engaged users with more earning opportunities
- Increase ad impressions from your most active users
- Incentivize bet placement

---

### 4. Alternative Ad Formats

#### A. Banner Ads (Low Priority)

**Pros:**
- Passive revenue (always showing)
- Non-intrusive

**Cons:**
- Low CPM ($1-3 vs $10-25 for video)
- Can clutter UI

**Recommended Placement:**
- Bottom of game details screen
- Bottom of news feed

**Implementation:**
```dart
// lib/widgets/admob_banner_widget.dart
class AdMobBanner extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: AdWidget(
        ad: BannerAd(
          adUnitId: AdRewardService.bannerAdUnitId,
          size: AdSize.banner,
          request: AdRequest(),
          listener: BannerAdListener(),
        )..load(),
      ),
    );
  }
}
```

#### B. Native Ads (Medium Priority)

**Pros:**
- Blends into app UI
- Higher engagement than banners
- Good CPM ($5-12)

**Cons:**
- Harder to implement
- Must be clearly labeled as ads

**Recommended Placement:**
- In news feed between articles
- Between game cards in game list

**Implementation:**
```dart
// In games list
ListView.builder(
  itemCount: games.length,
  itemBuilder: (context, index) {
    // Show native ad every 5 games
    if (index % 5 == 4) {
      return NativeAdWidget();
    }
    return GameCard(game: games[index]);
  },
)
```

#### C. Interstitial Ads (Use Sparingly!)

**Pros:**
- High CPM ($8-20)
- Full-screen attention

**Cons:**
- VERY intrusive
- Can cause user churn if overused

**Recommended Usage:**
- After completing 3 bets in a row
- After 5 minutes of app usage
- MAX 1 per session for free users

**Implementation:**
```dart
// lib/services/interstitial_ad_service.dart
class InterstitialAdService {
  int _actionsCount = 0;

  void trackAction() {
    _actionsCount++;
    if (_actionsCount >= 3) {
      _showInterstitial();
      _actionsCount = 0;
    }
  }
}

// Call after major actions
_interstitialService.trackAction(); // After bet placed
```

---

## Analytics & Tracking 📊

### Key Metrics to Monitor

```dart
// lib/services/ad_analytics_service.dart
class AdAnalyticsService {
  // Track in Firebase Analytics

  Future<void> logAdImpression(String adType) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'ad_impression',
      parameters: {
        'ad_type': adType, // rewarded, banner, native, interstitial
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logAdClicked(String adType) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'ad_clicked',
      parameters: {'ad_type': adType},
    );
  }

  Future<void> logAdCompleted(String adType, int brAwarded) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'ad_completed',
      parameters: {
        'ad_type': adType,
        'br_awarded': brAwarded,
      },
    );
  }

  Future<void> logAdFailed(String adType, String errorCode) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'ad_failed',
      parameters: {
        'ad_type': adType,
        'error_code': errorCode,
      },
    );
  }
}
```

### Metrics Dashboard (Monitor in Firebase Console)

| Metric | Target | Action if Below |
|--------|--------|-----------------|
| Ad Load Success Rate | >95% | Check ad mediation setup |
| Ad Completion Rate | >80% | Review ad quality/length |
| Daily Ads per DAU | 3-5 | Add more placements |
| Effective CPM (eCPM) | $12-20 | Add mediation/optimize waterfall |
| Ad Revenue per DAU | $0.50-1.00 | Increase ad frequency |

---

## Revenue Projections 💵

### Current Setup (AdMob Only, BR Shop Only)

**Assumptions:**
- 1,000 Daily Active Users (DAU)
- 30% of users visit BR Shop
- 50% of shop visitors watch at least 1 ad
- Average: 2 ads per engaging user
- CPM: $12 (US sports content)

**Math:**
```
1,000 DAU × 30% shop visitors × 50% watchers × 2 ads = 300 ad impressions/day
300 impressions × ($12 CPM / 1000) = $3.60/day
$3.60/day × 30 days = $108/month
```

### With Mediation + New Placements

**Assumptions:**
- 1,000 DAU
- 70% engagement with new placements
- Average: 4 ads per engaging user/day
- CPM: $16 (mediation boost)

**Math:**
```
1,000 DAU × 70% engagement × 4 ads = 2,800 ad impressions/day
2,800 impressions × ($16 CPM / 1000) = $44.80/day
$44.80/day × 30 days = $1,344/month
```

**Increase: 12x revenue boost**

### At Scale (10,000 DAU)

```
10,000 DAU × 70% × 4 ads × ($16 / 1000) = $448/day
$448/day × 30 days = $13,440/month
```

---

## Implementation Priority Roadmap 🗓️

### Phase 1: Quick Wins (Week 1)
- [ ] **Fix `getAdWatchStatus()` to read from Firestore** ⚠️ Critical
- [ ] **Create iOS ad unit ID in AdMob console**
- [ ] **Add analytics tracking** (ad impressions, completions, failures)
- [ ] **Test current ad system thoroughly**

### Phase 2: Strategic Placements (Week 2-3)
- [ ] **Add "Unlock with Ad" to Edge Intelligence cards**
- [ ] **Add "Double Your Login Bonus" to Welcome Back screen**
- [ ] **Implement daily login ad boost**
- [ ] **Test new placements with beta users**

### Phase 3: Revenue Optimization (Week 4-6)
- [ ] **Integrate AppLovin MAX mediation**
- [ ] **Configure ad waterfall in AppLovin dashboard**
- [ ] **Add Unity Ads, Meta Audience Network to waterfall**
- [ ] **Monitor eCPM improvements**

### Phase 4: Advanced Features (Month 2)
- [ ] **Add "Double Your Winnings" post-bet ad**
- [ ] **Implement tiered ad frequency system**
- [ ] **Add native ads to news feed**
- [ ] **A/B test different placements**

### Phase 5: Polish & Scale (Month 3+)
- [ ] **Add interstitial ads (sparingly)**
- [ ] **Optimize ad load times**
- [ ] **Build analytics dashboard**
- [ ] **Experiment with banner ads**
- [ ] **Test premium upsell messaging**

---

## Ad Network Comparison

### Google AdMob (Current)
✅ **Pros:**
- Easy integration
- High fill rates globally
- Reliable payments
- Good documentation

❌ **Cons:**
- Lower CPMs without mediation
- Limited optimization options
- Single network dependency

### AppLovin MAX (Recommended)
✅ **Pros:**
- Best-in-class mediation
- Real-time bidding
- 30-40% revenue increase
- Supports 20+ ad networks

❌ **Cons:**
- Requires SDK integration
- Dashboard learning curve
- Additional setup time

### Unity LevelPlay (ironSource)
✅ **Pros:**
- Great for gaming/gamification
- Strong in-app bidding
- Advanced analytics

❌ **Cons:**
- Slightly complex setup
- More gaming-focused

### Meta Audience Network
✅ **Pros:**
- Access to Facebook advertisers
- High CPMs for social content

❌ **Cons:**
- Requires Facebook app review
- More restrictive policies
- Lower fill rates vs AdMob

---

## Best Practices & Tips 💡

### User Experience
1. **Never force ads** - Always make them opt-in for rewards
2. **Respect daily limits** - Don't spam users with ad prompts
3. **Show progress** - Display "3/5 ads watched today"
4. **Instant rewards** - Award BR immediately after ad completion
5. **Clear value prop** - Always show what they'll earn

### Technical
1. **Preload ads** - Load next ad immediately after one finishes
2. **Handle failures gracefully** - "Ad not available, try again later"
3. **Test with real ads** - Don't rely only on test ads
4. **Monitor fill rates** - Track % of successful ad loads
5. **Cache ad state** - Don't spam ad requests

### Business
1. **Balance ads vs premium** - Make premium compelling but keep free tier viable
2. **Track user churn** - Monitor if ads cause users to quit
3. **A/B test everything** - Test ad frequency, placement, rewards
4. **Seasonal optimization** - CPMs are higher during holidays/playoffs
5. **Negotiate with networks** - At scale, you can get better CPM rates

---

## Testing Checklist ✅

### Before Production Launch

#### AdMob Setup
- [ ] Android production ad unit ID configured
- [ ] iOS production ad unit ID configured
- [ ] Test ads load successfully on Android
- [ ] Test ads load successfully on iOS
- [ ] Production ads load in release build
- [ ] Ad rewards properly credit to wallet

#### User Experience
- [ ] Daily limit enforces correctly (5 ads max)
- [ ] Limit resets at midnight
- [ ] Balance updates immediately after ad
- [ ] Transaction logged in Firestore
- [ ] Error messages display correctly
- [ ] Ad not available → graceful fallback

#### Edge Cases
- [ ] No internet → proper error
- [ ] User closes ad early → no reward
- [ ] Ad fails to load → retry option
- [ ] User logs out → ad state cleared
- [ ] Multiple devices → limit shared correctly

---

## Support & Resources

### Documentation
- [Google AdMob Docs](https://developers.google.com/admob)
- [AppLovin MAX Docs](https://dash.applovin.com/documentation/mediation/flutter/getting-started/integration)
- [Unity LevelPlay Docs](https://developers.is.com/ironsource-mobile/unity/levelplay-integration/)

### AdMob Console
- [Dashboard](https://apps.admob.com/)
- [Payment Settings](https://apps.admob.com/v2/payment/payment-settings)
- [Ad Units](https://apps.admob.com/v2/apps)

### Analytics
- [Firebase Console](https://console.firebase.google.com/)
- Monitor: Events → `ad_impression`, `ad_completed`, `ad_failed`

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-11 | 1.0 | Initial document created based on existing implementation |

---

## Questions or Issues?

If you encounter any problems during implementation:

1. Check AdMob console for ad unit status
2. Review Firebase logs for error messages
3. Test with AdMob test ad unit IDs first
4. Verify Firestore security rules allow wallet writes
5. Check that `google_mobile_ads` package is up to date

**Common Issues:**
- "Ad failed to load" → Check internet connection, verify ad unit ID
- "No ads available" → Normal in test environments, use test IDs
- "Reward not credited" → Check Firestore transaction logs
- "Daily limit not enforcing" → Verify `getAdWatchStatus()` implementation

---

**End of Document**
