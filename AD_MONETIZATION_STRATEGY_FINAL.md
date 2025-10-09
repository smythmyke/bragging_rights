# Ad Monetization Strategy - FINAL (Option B: Sustainable Growth)

**Date Finalized**: 2025-10-07
**Status**: ✅ **APPROVED FOR IMPLEMENTATION**
**Strategy**: Moderate ads + Premium-focused + Long-term growth
**Revenue Target**: $10,000/month within 18-24 months
**Decision**: Option B - Sustainable, user-retention focused approach

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Strategic Vision](#strategic-vision)
3. [Revenue Model](#revenue-model)
4. [Ad Placement Rules (Finalized)](#ad-placement-rules-finalized)
5. [Frequency Limits & Controls](#frequency-limits--controls)
6. [Premium Strategy](#premium-strategy)
7. [User Experience Philosophy](#user-experience-philosophy)
8. [Implementation Phases](#implementation-phases)
9. [Revenue Projections (18-24 Month Timeline)](#revenue-projections-18-24-month-timeline)
10. [Success Metrics & KPIs](#success-metrics--kpis)
11. [What We're NOT Doing (Rejected Strategies)](#what-were-not-doing-rejected-strategies)
12. [Technical Implementation](#technical-implementation)
13. [Launch Checklist](#launch-checklist)

---

## Executive Summary

### Core Philosophy

**"User retention over short-term revenue"**

We prioritize building a sustainable, growing user base over maximizing immediate ad revenue. Users who stick around become premium subscribers - our true revenue engine.

### Strategic Decisions

✅ **Moderate Ad Frequency** - Enough to drive premium upgrades, not so much to cause uninstalls
✅ **Premium-Focused** - Subscriptions are 60-70% of target revenue, not ads
✅ **18-24 Month Timeline** - Realistic path to $10k/month through user growth
✅ **No Aggressive Tactics** - No ads on pool entry, pick submission, or timed intervals

### Revenue Mix (At $10k/month Target)

```
Premium Subscriptions:  $6,000-7,000  (60-70%)
Ad Revenue:            $2,000-3,000  (20-30%)
BR Currency Sales:     $1,000-1,500  (10-15%)
────────────────────────────────────
TOTAL:                 $9,000-11,500/month
```

### User Requirements

To hit $10k/month revenue:
- **20,000 Monthly Active Users**
- **15% Premium Conversion** = 3,000 premium subscribers
- **60% Free User Ad Engagement** = 10,200 users seeing 3-4 ads/day

---

## Strategic Vision

### The Problem We Avoided

**Rejected Strategy (Option A - Aggressive):**
```
❌ Ads on pool entry (before joining)
❌ Ads on pick submission (after making picks)
❌ Timed interval ads (background spam)
❌ 10+ ads per session
❌ Result: 60-80% churn rate, app death spiral
```

**Why Option A Would Fail:**
- Users uninstall immediately after 2-3 forced ads
- App gets 1-2 star reviews ("Too many ads!")
- No organic growth through word-of-mouth
- Constant user acquisition costs
- Unsustainable business model

---

### The Solution We're Implementing

**Approved Strategy (Option B - Sustainable):**
```
✅ Strategic ad placement (natural break points only)
✅ User-initiated rewarded ads (opt-in)
✅ Limited interstitials (max 3 per session, 10-min cooldown)
✅ Premium = Ad-free (major selling point)
✅ Result: 25-30% D7 retention, healthy growth
```

**Why Option B Succeeds:**
- Users tolerate moderate ads
- Premium becomes attractive alternative
- Good reviews, organic growth
- Sustainable acquisition through referrals
- Long-term revenue growth

---

## Revenue Model

### Revenue Sources (Priority Order)

#### 1. Premium Subscriptions ($1.99/month) - **PRIMARY REVENUE**

**Target:** 70% of total revenue

```yaml
Benefits:
  - Zero ads (completely ad-free)
  - Real Vegas odds (vs simple scoring)
  - Exclusive premium pools (higher BR prizes)
  - Edge Intelligence AI picks
  - Advanced analytics
  - Priority support
  - Early access to new features

Pricing:
  - Monthly: $1.99/month
  - Annual: $19.99/year (save $3.89 = 16% discount)
  - 7-day free trial for new users

Revenue Calculation:
  3,000 premium users × $1.99 × 68% (after fees) = $4,074/month
  Plus annual subscriptions (20% of users):
  600 annual × ($19.99 ÷ 12) × 68% = $680/month
  ─────────────────────────────────
  TOTAL: $4,754/month from premium
```

**Conversion Funnel:**
```
20,000 MAU
  ↓
15% try free trial → 3,000 trial starts
  ↓
70% convert to paid → 2,100 paid monthly
  ↓
20% choose annual → 420 annual + 1,680 monthly
  ↓
Plus ongoing conversions from free tier
  ↓
Target: 3,000+ premium subscribers steady state
```

---

#### 2. Ad Revenue (Google AdMob) - **SECONDARY REVENUE**

**Target:** 25% of total revenue

```yaml
Free Users Seeing Ads:
  20,000 MAU × 85% free tier = 17,000 free users
  17,000 × 60% daily active = 10,200 free DAU

Rewarded Ads (Opt-in):
  10,200 × 40% engagement × 2 ads/day = 8,160 views/day
  8,160 × 30 days = 244,800 views/month
  244,800 ÷ 1,000 × $20 CPM × 68% = $3,329/month

Interstitial Ads (Auto-show):
  10,200 × 70% see ads × 1.5 ads/day = 10,710 views/day
  10,710 × 30 days = 321,300 views/month
  321,300 ÷ 1,000 × $10 CPM × 68% = $2,185/month

Ad Revenue Total: $3,329 + $2,185 = $5,514/month
Conservative Estimate: $3,000-4,000/month (accounting for variability)
```

**CPM Assumptions:**
- Rewarded Video: $15-25 CPM (high engagement, completion required)
- Interstitial: $8-12 CPM (standard mobile game rate)
- Google's Cut: 32% (68% to us)

---

#### 3. BR Currency Sales (In-App Purchases) - **TERTIARY REVENUE**

**Target:** 10% of total revenue

```yaml
Purchase Options:
  - 100 BR = $0.99
  - 600 BR = $4.99 (20% bonus)
  - 1,500 BR = $9.99 (50% bonus)

User Behavior:
  - 5% of free users buy BR (instead of watching ads)
  - Average purchase: $2.49 (weighted average)
  - Frequency: 1-2 times per month

Calculation:
  17,000 free users × 5% = 850 purchasers
  850 × $2.49 × 1.5 purchases/month = $3,174
  $3,174 × 68% (after fees) = $2,158/month

Conservative Estimate: $1,000-1,500/month
```

---

### Combined Revenue Target

**At 20,000 MAU:**

| Source | Monthly Revenue | % of Total |
|--------|----------------|------------|
| Premium Subscriptions | $4,500-5,000 | 65% |
| Ad Revenue | $3,000-4,000 | 28% |
| BR Currency Sales | $500-1,000 | 7% |
| **TOTAL** | **$8,000-10,000** | **100%** |

**Margin Analysis:**
```
Gross Revenue:        $10,000
Cost of Goods Sold:
  - Platform fees (32%): -$3,200
  - API costs:           -$300
  - Server costs:        -$200
  ─────────────────────────────
Net Revenue:          $6,300/month
Annual:               $75,600/year
```

---

## Ad Placement Rules (Finalized)

### Interstitial Ads (Full-Screen, Auto-Show)

**WHERE to Show:**

#### ✅ Trigger 1: After Pool Completion
```dart
// Show after user completes 3 pools in current session
Location: After user submits picks and sees "Pool joined" confirmation
Condition: poolsCompletedThisSession >= 3 && poolsCompletedThisSession % 3 == 0
Cooldown: Must respect 10-minute global cooldown
Premium: Skip if user.isPremium == true
```

**User Flow:**
```
User joins Pool 1 → Makes picks → Submits ✅
User joins Pool 2 → Makes picks → Submits ✅
User joins Pool 3 → Makes picks → Submits ✅
  ↓
🎬 INTERSTITIAL AD (30 seconds)
  ↓
User returns to pools list
  ↓
Joins Pool 4 → Makes picks → Submits ✅
Joins Pool 5 → Makes picks → Submits ✅
Joins Pool 6 → Makes picks → Submits ✅
  ↓
🎬 INTERSTITIAL AD (if 10 minutes passed since last ad)
```

**Why This Works:**
- Natural break point (user completed an action)
- User has achieved something (positive mood)
- Not interrupting active decision-making
- Predictable pattern (every 3 pools)

---

#### ✅ Trigger 2: After Viewing Bet History
```dart
// Show after user spends time reviewing past bets
Location: When user navigates away from "Past Bets" screen
Condition: timeOnScreen >= 30 seconds
Cooldown: Must respect 10-minute global cooldown
Session Limit: Still counts toward max 3 per session
Premium: Skip if user.isPremium == true
```

**User Flow:**
```
User taps "Past Bets" tab
  ↓
Views bet history for 45 seconds
  ↓
Taps back or switches tab
  ↓
🎬 INTERSTITIAL AD (if cooldown allows)
```

**Why This Works:**
- User is browsing, not actively betting
- Low-stakes moment (reviewing past activity)
- Less intrusive than mid-action ads

---

#### ✅ Trigger 3: After Achievement Unlock
```dart
// Show after user unlocks achievement and closes dialog
Location: 2 seconds after achievement dialog closes
Condition: Achievement unlocked (any type)
Cooldown: Must respect 10-minute global cooldown
Session Limit: Still counts toward max 3 per session
Premium: Skip if user.isPremium == true
```

**User Flow:**
```
User unlocks achievement
  ↓
Achievement dialog appears: "🏆 Win Streak! Earned 100 BR"
  ↓
User closes dialog (positive emotion)
  ↓
Wait 2 seconds
  ↓
🎬 INTERSTITIAL AD (if cooldown allows)
```

**Why This Works:**
- User just got rewarded (happy moment)
- Natural pause after closing dialog
- Positive association with ad

---

#### ✅ Trigger 4: Navigation Between Major Tabs
```dart
// Show after significant browsing activity
Location: When switching between Games ↔ Bets ↔ Pools
Condition: User has switched tabs 5+ times in session
Frequency: Show after every 5 tab switches
Cooldown: Must respect 10-minute global cooldown
Session Limit: Still counts toward max 3 per session
Premium: Skip if user.isPremium == true
```

**User Flow:**
```
Session starts
  ↓
User browses: Games → Pools → Bets → Games → Pools (5 switches)
  ↓
🎬 INTERSTITIAL AD (if cooldown allows)
  ↓
User continues browsing: Bets → Games → Pools → Bets → Games (5 more)
  ↓
🎬 INTERSTITIAL AD (if cooldown allows and session limit not hit)
```

**Why This Works:**
- User is actively browsing (engaged)
- Natural navigation break
- Indicates user is spending time in app (not rushing)

**⚠️ IMPORTANT:** This is the most aggressive trigger. Can be disabled or increased to 10 switches if retention suffers.

---

### Rewarded Video Ads (Opt-In, User-Initiated)

**WHERE to Show:**

#### ✅ Placement 1: BR Currency Shop
```dart
// Primary rewarded ad placement
Location: Top of BR shop screen (prominent button)
UI: Large card with "Watch & Earn" branding
Reward: 25 BR per video
Daily Limit: 5 ads per day
Premium: Hidden if user.isPremium == true
```

**UI Design:**
```
┌─────────────────────────────────────────┐
│ 🎬 WATCH & EARN                         │
│                                         │
│ Watch 30-second video                   │
│ Earn 25 BR instantly                    │
│                                         │
│ Today: 2/5 videos watched              │
│ Earned: 50 BR                           │
│                                         │
│        [WATCH NOW - EARN 25 BR]        │
└─────────────────────────────────────────┘

Or purchase BR:
┌───────────────┬───────────────┬──────────┐
│ 100 BR        │ 600 BR        │ 1500 BR  │
│ $0.99         │ $4.99         │ $9.99    │
│               │ +20% BONUS    │ +50%     │
└───────────────┴───────────────┴──────────┘
```

**Why This Works:**
- User is already thinking about BR
- Clear value proposition
- Optional (respects user choice)
- Limited daily (prevents spam)

---

#### ✅ Placement 2: "Out of BR" Modal
```dart
// High-conversion placement
Location: Modal that appears when user tries to join pool but can't afford it
Reward: 25 BR per video
Immediate: Can retry pool join after watching
Premium: Shows "Upgrade to Premium" instead
```

**UI Design:**
```
┌─────────────────────────────────────────┐
│          ⚠️ Not Enough BR               │
│                                         │
│ You need 50 BR to join this pool        │
│ Current balance: 30 BR                  │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │   🎬 WATCH AD - EARN 25 BR          │ │
│ │   Then try again!                   │ │
│ │                                     │ │
│ │   [WATCH NOW]                       │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Or:                                     │
│ [Buy 100 BR - $0.99]                   │
│ [Go Premium - No Ads Ever]             │
│                                         │
│ [Cancel]                                │
└─────────────────────────────────────────┘
```

**Why This Works:**
- User is highly motivated (wants to join pool NOW)
- Clear path to success (watch ad → can join)
- 70-80% conversion rate (industry high)
- Perfect premium upgrade opportunity

---

#### ✅ Placement 3: Daily Bonus Screen
```dart
// Post-reward upsell
Location: After user claims daily login bonus (50 BR)
Timing: Show card inviting to earn more
Reward: 25 BR per video
Premium: Hidden if user.isPremium == true
```

**UI Design:**
```
┌─────────────────────────────────────────┐
│    ✅ Daily Bonus Claimed!              │
│                                         │
│    You earned: 50 BR                    │
│    New balance: 250 BR                  │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │   Want More?                        │ │
│ │                                     │ │
│ │   Watch videos to earn up to        │ │
│ │   125 BR today!                     │ │
│ │                                     │ │
│ │   [WATCH VIDEO - EARN 25 BR]        │ │
│ │   (3/5 remaining today)             │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ [Continue to App]                       │
└─────────────────────────────────────────┘
```

**Why This Works:**
- User just got free BR (positive emotion)
- Natural "more BR" upsell opportunity
- Doesn't interrupt flow (can skip)
- 30-40% engagement rate

---

#### ✅ Placement 4: Premium Pool Unlock (NEW CONCEPT)
```dart
// Hybrid: Ad-gated premium content
Location: When free user taps on premium-exclusive pool
Requirement: Watch 1 ad to unlock access for 24 hours
Reward: Access to premium pool + 25 BR
Premium: Instant access without ad
```

**UI Design:**
```
┌─────────────────────────────────────────┐
│      🔒 Premium Pool                    │
│                                         │
│  UFC 300 - High Rollers                 │
│  Entry: 100 BR                          │
│  Prize Pool: 5,000 BR                   │
│  Players: 47 premium users              │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │  Free Tier Access:                  │ │
│ │                                     │ │
│ │  🎬 Watch 1 ad to unlock            │ │
│ │  Access for 24 hours                │ │
│ │                                     │ │
│ │  [WATCH & UNLOCK]                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│  Or upgrade to Premium:                 │
│  ✅ Instant access to all premium pools│
│  ✅ Zero ads forever                    │
│  ✅ Real Vegas odds                     │
│                                         │
│  [START FREE TRIAL - 7 DAYS]           │
│  Then $1.99/month                       │
│                                         │
│  [Cancel]                               │
└─────────────────────────────────────────┘
```

**Why This Works:**
- Creates premium value perception
- Free users can still access (with ad)
- Premium users see immediate benefit
- Drives upgrades ("Just upgrade already!")

---

### ❌ NO ADS ZONES (Strictly Prohibited)

**NEVER Show Ads:**

```
❌ Pool Entry Flow
   - Before joining a pool
   - While selecting a pool
   - During pool browsing

❌ Pick Submission Flow
   - While making picks
   - After clicking "Submit"
   - During bet placement

❌ Payment Flows
   - During BR purchase
   - During premium upgrade
   - In subscription screens

❌ Critical UI Moments
   - App startup/loading
   - Login/signup flow
   - Settings configuration
   - Error states

❌ Timed Intervals
   - No background timers
   - No random "every X minutes" ads
   - No idle timeout ads
```

**Why These Are Banned:**
- Destroys user experience
- Causes immediate uninstalls
- Violates app store policies
- Breaks user trust
- Interrupts revenue flows (don't interrupt purchases!)

---

## Frequency Limits & Controls

### Hard Limits (Cannot Be Exceeded)

```dart
class AdFrequencyConfig {
  // Rewarded Ads (User-Initiated)
  static const int MAX_REWARDED_ADS_PER_DAY = 5;
  static const int BR_PER_REWARDED_AD = 25;
  static const int MAX_BR_FROM_ADS_PER_DAY = 125;

  // Interstitial Ads (Auto-Show)
  static const int MAX_INTERSTITIAL_PER_SESSION = 3;
  static const int MIN_MINUTES_BETWEEN_INTERSTITIALS = 10;
  static const int MIN_ACTIONS_BEFORE_FIRST_INTERSTITIAL = 3; // 3 pools completed

  // Premium Override
  static const bool PREMIUM_USERS_SEE_ADS = false;
  static const bool ADMIN_OVERRIDE_RESPECTED = true;

  // Session Definition
  static const int SESSION_TIMEOUT_MINUTES = 30; // New session after 30 min idle
}
```

### Daily Reset Schedule

```dart
// Reset at midnight local time
bool shouldResetDailyLimits(DateTime lastReset) {
  final now = DateTime.now();
  final lastResetDate = DateTime(lastReset.year, lastReset.month, lastReset.day);
  final today = DateTime(now.year, now.month, now.day);

  return today.isAfter(lastResetDate);
}

// User document structure in Firestore
{
  'userId': 'user123',
  'ads': {
    'rewardedAdsWatchedToday': 3,
    'lastRewardedAdDate': '2025-10-07',
    'interstitialsShownThisSession': 2,
    'lastInterstitialTime': '2025-10-07T15:30:00Z',
    'sessionStartTime': '2025-10-07T14:00:00Z',
  }
}
```

### Session Management

```dart
// New session criteria
bool isNewSession(DateTime? lastActivity) {
  if (lastActivity == null) return true;

  final minutesSinceLastActivity = DateTime.now().difference(lastActivity).inMinutes;
  return minutesSinceLastActivity >= AdFrequencyConfig.SESSION_TIMEOUT_MINUTES;
}

// On app launch or return from background
@override
void initState() {
  super.initState();

  final lastActivity = prefs.getDateTime('lastActivity');
  if (isNewSession(lastActivity)) {
    _interstitialService.resetSessionCounters();
    debugPrint('🔄 New session started - ad counters reset');
  }
}
```

### Cooldown Enforcement

```dart
// Check if interstitial can be shown
bool canShowInterstitial() {
  // Check premium status
  if (user.isPremium) {
    debugPrint('⛔ Premium user - no ads');
    return false;
  }

  // Check session limit
  if (_interstitialsThisSession >= MAX_INTERSTITIAL_PER_SESSION) {
    debugPrint('⛔ Session limit reached (${_interstitialsThisSession}/${MAX_INTERSTITIAL_PER_SESSION})');
    return false;
  }

  // Check cooldown
  if (_lastInterstitialTime != null) {
    final minutesSince = DateTime.now().difference(_lastInterstitialTime!).inMinutes;
    if (minutesSince < MIN_MINUTES_BETWEEN_INTERSTITIALS) {
      debugPrint('⛔ Cooldown active: ${MIN_MINUTES_BETWEEN_INTERSTITIALS - minutesSince} min remaining');
      return false;
    }
  }

  // Check if ad is loaded
  if (!_adService.isAdReady()) {
    debugPrint('⏳ Ad not ready yet');
    return false;
  }

  return true;
}
```

---

## Premium Strategy

### Premium as the Star (Not Ads)

**Core Philosophy:**
> "Ads are not our business model. Premium subscriptions are. Ads exist to make premium attractive."

### Premium Benefits (In Priority Order)

```yaml
1. Zero Ads (PRIMARY BENEFIT):
   - Completely ad-free experience
   - No rewarded ads, no interstitials
   - Uninterrupted gameplay
   - Message: "Skip all ads forever"

2. Real Vegas Odds (SECONDARY BENEFIT):
   - Live betting lines from The Odds API
   - Precise underdog bonuses
   - Line shopping across sportsbooks
   - Message: "Get the sharpest edge"

3. Exclusive Premium Pools (TERTIARY BENEFIT):
   - Higher BR prize pools
   - Premium-only competitions
   - Early access to major events
   - Message: "Compete at the highest level"

4. Edge Intelligence (VALUE-ADD):
   - AI-powered pick recommendations
   - Historical trends analysis
   - Advanced analytics dashboard
   - Message: "Let AI do the research"

5. Priority Features (NICE-TO-HAVE):
   - Priority customer support
   - Early access to new features
   - Custom themes (future)
   - Profile badges
```

### Premium Messaging Throughout App

#### In Free Tier UI (Constant Reminders)

**Settings Screen:**
```
┌─────────────────────────────────────────┐
│  👤 Account                             │
│                                         │
│  Current Plan: FREE                     │
│  Ads watched today: 3/5                 │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 🚀 UPGRADE TO PREMIUM               ││
│  │                                     ││
│  │ ✅ Zero ads forever                 ││
│  │ ✅ Real Vegas odds                  ││
│  │ ✅ Exclusive pools                  ││
│  │                                     ││
│  │ Try FREE for 7 days                 ││
│  │ Then just $1.99/month               ││
│  │                                     ││
│  │ [START FREE TRIAL]                  ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**After Watching 3 Ads:**
```
┌─────────────────────────────────────────┐
│          🎯 Nice Work!                  │
│                                         │
│  You've earned 75 BR from ads today     │
│                                         │
│  Want to skip the ads?                  │
│                                         │
│  Premium subscribers get:               │
│  ✓ Zero ads forever                     │
│  ✓ Real Vegas odds for better scoring   │
│  ✓ Exclusive high-stakes pools          │
│  ✓ AI-powered Edge picks                │
│                                         │
│  Less than a coffee per month!          │
│                                         │
│  [TRY FREE FOR 7 DAYS]                  │
│  Then $1.99/month, cancel anytime       │
│                                         │
│  [Maybe Later]                          │
└─────────────────────────────────────────┘
```

**After 2nd Interstitial:**
```
┌─────────────────────────────────────────┐
│         😤 Tired of Ads?                │
│                                         │
│  Premium = No Ads + Better Features     │
│                                         │
│  $1.99/month • Try 7 days FREE          │
│                                         │
│  [UPGRADE NOW]  [Stay Free]             │
└─────────────────────────────────────────┘
```

**In Premium Pool Preview:**
```
┌─────────────────────────────────────────┐
│      🔒 Premium Exclusive               │
│                                         │
│  Super Bowl LVIII - High Rollers        │
│  Prize Pool: 10,000 BR                  │
│  147 premium users competing            │
│                                         │
│  Premium features:                      │
│  ✅ Real-time Vegas odds                │
│  ✅ Edge Intelligence picks             │
│  ✅ Advanced analytics                  │
│  ✅ Zero ads                             │
│                                         │
│  [UNLOCK WITH PREMIUM]                  │
│  7-day free trial, then $1.99/month     │
│                                         │
│  Free users: [Watch ad to access]       │
└─────────────────────────────────────────┘
```

### Premium Trial Flow

**7-Day Free Trial (All New Users):**

```
Day 1: Welcome & Feature Tour
  - "Welcome to Premium! Here's what you unlocked..."
  - Show exclusive pools
  - Demonstrate real odds vs simple scoring
  - First Edge Intelligence pick

Day 2: Engagement
  - Push notification: "Check out today's Edge picks"
  - In-app: "You've scored 23% higher with real odds!"

Day 3: Social Proof
  - "Join 2,847 premium users competing today"
  - Show leaderboard position improvement

Day 4: Mid-trial Check-in
  - "Halfway through your trial - having fun?"
  - Show stats: "You've saved 15 minutes by skipping ads"

Day 5: Pre-conversion Nudge
  - "2 days left in your trial"
  - "Lock in $1.99/month before trial ends"
  - Show annual option: "$19.99/year (save 16%)"

Day 6: Urgency
  - "Tomorrow your trial ends"
  - "Don't lose access to premium pools"
  - One-click subscribe button

Day 7: Conversion or Graceful Downgrade
  - If subscribed: "Welcome to Premium! 🎉"
  - If not: "Trial ended. You can still play free!"
  - Show what they're losing: "You'll see ads again"
```

### Premium Conversion Triggers

**High-Intent Moments:**

```dart
// Trigger 1: After watching 3 ads in one session
if (adsWatchedThisSession >= 3 && !hasSeenUpgradePromptToday) {
  showPremiumUpgradeDialog(
    title: 'Skip the Ads',
    message: 'You\'ve watched 3 ads today. Go ad-free for just \$1.99/month',
  );
}

// Trigger 2: When viewing premium pool
if (!user.isPremium && pool.isPremiumOnly) {
  showPremiumPoolPreview(
    pool: pool,
    ctaText: 'Unlock with Premium - Try Free for 7 Days',
  );
}

// Trigger 3: After seeing 2 interstitials
if (interstitialsThisSession >= 2) {
  showBottomBanner(
    message: 'Tired of ads? Upgrade to Premium',
    ctaText: 'Try Free',
  );
}

// Trigger 4: When out of BR (after showing ad option)
if (userBalance < poolCost) {
  showOutOfBRModal(
    options: [
      'Watch Ad - Earn 25 BR',
      'Buy BR - $0.99',
      'Go Premium - Never run out again', // Premium gets daily bonuses
    ],
  );
}

// Trigger 5: After 5-game win streak
if (currentWinStreak >= 5 && !user.isPremium) {
  showDialog(
    title: '🔥 5-Game Win Streak!',
    message: 'Imagine your score with real Vegas odds. Premium users score 30% higher on average.',
    cta: 'Try Premium Free for 7 Days',
  );
}
```

---

## User Experience Philosophy

### Golden Rules

**Rule 1: Respect the User**
```
✅ Give users choice (rewarded ads are opt-in)
✅ Be transparent (clear ad labels, timing)
✅ Provide value (BR rewards, premium alternative)
❌ Never trick users into clicking ads
❌ Never spam or annoy
❌ Never interrupt critical flows
```

**Rule 2: Ads Should Feel Fair**
```
✅ Show ads at natural break points
✅ Limit frequency (max 3 per session)
✅ Offer skip option when possible
✅ Premium users never see ads
❌ Don't show ads mid-action
❌ Don't show same ad repeatedly
❌ Don't make ads feel like punishment
```

**Rule 3: Premium is the Reward**
```
✅ Make premium desirable (not just "no ads")
✅ Show premium value constantly
✅ Make trial easy to start
✅ Make cancellation easy (build trust)
❌ Don't make free tier unusable
❌ Don't hide all features behind paywall
❌ Don't be pushy about upgrades
```

### User Personas & Ad Tolerance

**Persona 1: Casual Free User (60% of users)**
```
Profile:
  - Uses app 2-3 times per week
  - Joins 1-2 pools per session
  - Happy to watch ads for BR
  - Won't pay for premium

Ad Experience:
  - Sees 1-2 ads per session (rewarded + 1 interstitial)
  - Total ad time: 30-60 seconds
  - Tolerance: High (used to mobile game ads)
  - Conversion likelihood: 2-5%
```

**Persona 2: Engaged Free User (25% of users)**
```
Profile:
  - Uses app daily
  - Joins 5+ pools per session
  - Watches max rewarded ads (5/day)
  - Annoyed by interstitials

Ad Experience:
  - Sees 5-7 ads per session
  - Total ad time: 2-3 minutes
  - Tolerance: Medium (getting annoyed)
  - Conversion likelihood: 15-25% (prime target)
```

**Persona 3: Premium Subscriber (15% target)**
```
Profile:
  - Uses app daily
  - Joins 10+ pools per session
  - Values time and exclusive features
  - Pays $1.99/month happily

Ad Experience:
  - Sees ZERO ads
  - Feels superior to free users
  - Enjoys exclusive features
  - Retention: High (low churn)
```

### Feedback Loops

**Positive Feedback (Encourage):**
```
✅ User watches ad → Gets BR → Can join pool → Positive association
✅ User sees interstitial → Annoyed → Upgrades to premium → Happy
✅ Premium user → Zero ads → Tells friends → Organic growth
```

**Negative Feedback (Avoid):**
```
❌ User sees too many ads → Uninstalls → Tells friends app sucks
❌ User forced to watch ad mid-action → 1-star review → Bad ASO
❌ Premium trial ends → Bombarded with ads → Feels punished → Churns
```

---

## Implementation Phases

### Phase 1: Rewarded Ads Only (Months 1-2)

**Goal:** Build trust, test engagement, minimize risk

**What to Implement:**
```
✅ Rewarded video ads (3 placements)
  - BR Currency Shop
  - Out of BR Modal
  - Daily Bonus Screen

✅ Daily limit: 5 ads
✅ Reward: 25 BR per ad
✅ Premium bypass (no ads for subscribers)

❌ NO interstitials yet
❌ NO forced ads
```

**Success Metrics:**
```
Target: 30% of free users watch 1+ ad per day
Revenue: $300-800/month (at 1,000 free users)
Retention: Maintain D7 >25%
User Feedback: <5% complaints about ads
```

**Phase 1 Timeline:**
```
Week 1-2: Development & testing
Week 3-4: Alpha testing (10 users)
Week 5-6: Beta testing (100 users)
Week 7-8: Production launch & monitoring
```

**Go/No-Go Decision (End of Phase 1):**
```
Proceed to Phase 2 if:
  ✅ D7 retention >=25%
  ✅ Ad engagement >=25%
  ✅ Premium conversion >=2%
  ✅ <10% user complaints
  ✅ Revenue meeting projections

Abort if:
  ❌ D7 retention <20%
  ❌ >20% user complaints
  ❌ Mass uninstalls after ad launch
```

---

### Phase 2: Add Light Interstitials (Months 3-4)

**Goal:** Increase revenue, test interstitial tolerance, drive premium upgrades

**What to Implement:**
```
✅ Interstitial ads (4 triggers)
  - After completing 3 pools
  - After viewing bet history (30+ sec)
  - After achievement unlock
  - After 5 tab switches

✅ Session limit: Max 3 per session
✅ Cooldown: 10 minutes minimum between ads
✅ Premium bypass (no ads for subscribers)
✅ A/B test: 50% of users get interstitials, 50% control group
```

**Success Metrics:**
```
Target: 50% revenue increase vs Phase 1
Revenue: $600-1,500/month
Retention: Maintain D7 >23% (2% drop acceptable)
Premium Conversion: +1-2% boost from "tired of ads" users
```

**Phase 2 Timeline:**
```
Week 1: Enable for 25% of users (conservative)
Week 2: Monitor retention closely
Week 3: Expand to 50% if retention holds
Week 4: Expand to 100% or adjust frequency
```

**A/B Test Setup:**
```dart
// Randomly assign 50% of users to test group
final testGroup = userId.hashCode % 2 == 0;

if (testGroup) {
  // Show interstitials (Phase 2)
  if (canShowInterstitial()) {
    showInterstitialAd();
  }
} else {
  // Control group (Phase 1 only)
  // No interstitials, just rewarded ads
}

// Track metrics separately
analytics.logEvent('user_group', {
  'group': testGroup ? 'interstitial_test' : 'control',
});
```

**Go/No-Go Decision (End of Phase 2):**
```
Declare success if:
  ✅ Retention drop <5% (vs control group)
  ✅ Revenue increase >30%
  ✅ Premium conversion increase >1%
  ✅ User complaints <15%

Roll back if:
  ❌ Retention drop >10%
  ❌ Massive user complaints
  ❌ App rating drops below 4.0
  ❌ Churn spike
```

---

### Phase 3: Optimize & Scale (Months 5-6)

**Goal:** Maximize revenue without sacrificing retention

**What to Implement:**
```
✅ Ad mediation (multiple networks)
  - Google AdMob (primary)
  - Facebook Audience Network
  - Unity Ads
  - AppLovin

✅ Dynamic frequency adjustment
  - Increase interstitials to 4/session for low-churn users
  - Decrease to 2/session for high-churn cohorts
  - Machine learning optimization (future)

✅ Native ads (optional)
  - Sponsored pools in pool list
  - Clearly labeled as "Sponsored"
  - Non-intrusive

✅ "Remove Ads" IAP option
  - One-time purchase: $2.99
  - Removes ads but no premium features
  - For users who don't want full premium
```

**Success Metrics:**
```
Target: 25% revenue increase vs Phase 2
Revenue: $1,500-2,500/month (at 3,000 free users)
Retention: Maintain D7 >25%
Premium Conversion: 8-12%
```

**Phase 3 Timeline:**
```
Month 5: Implement ad mediation & test
Month 6: Dynamic frequency & native ads
Ongoing: Continuous optimization
```

---

### Phase 4: Scale to $10k/Month (Months 7-24)

**Goal:** Grow user base to 20,000 MAU

**Focus Areas:**
```
✅ User Acquisition (organic + paid)
  - ASO (App Store Optimization)
  - Social media marketing
  - Referral program
  - Influencer partnerships

✅ Retention Optimization
  - Improve onboarding flow
  - Add social features
  - Weekly challenges
  - Push notification strategy

✅ Premium Conversion
  - Better trial experience
  - More exclusive features
  - Annual plan promotion
  - Premium-only events

✅ Ad Revenue Optimization
  - CPM improvements via mediation
  - Better ad placements
  - Seasonal campaigns
  - Geo-targeting
```

**Growth Targets:**
```
Month 7-9:   5,000 MAU  → $2,000/month revenue
Month 10-12: 8,000 MAU  → $3,500/month revenue
Month 13-15: 12,000 MAU → $5,500/month revenue
Month 16-18: 16,000 MAU → $7,500/month revenue
Month 19-24: 20,000 MAU → $10,000/month revenue ✅
```

---

## Revenue Projections (18-24 Month Timeline)

### Conservative Growth Path

| Month | MAU | Free Users | Premium Users | Ad Revenue | Premium Revenue | BR Sales | Total Revenue |
|-------|-----|------------|---------------|------------|-----------------|----------|---------------|
| 1-2   | 1,000 | 950 | 50 (5%) | $250 | $68 | $50 | **$368** |
| 3-4   | 1,500 | 1,350 | 150 (10%) | $550 | $204 | $100 | **$854** |
| 5-6   | 2,500 | 2,125 | 375 (15%) | $1,000 | $510 | $200 | **$1,710** |
| 7-9   | 4,000 | 3,400 | 600 (15%) | $1,600 | $816 | $300 | **$2,716** |
| 10-12 | 6,500 | 5,525 | 975 (15%) | $2,600 | $1,326 | $500 | **$4,426** |
| 13-15 | 10,000 | 8,500 | 1,500 (15%) | $4,000 | $2,040 | $800 | **$6,840** |
| 16-18 | 15,000 | 12,750 | 2,250 (15%) | $6,000 | $3,060 | $1,200 | **$10,260** ✅ |

**Achieves $10k/month in Month 16-18 (1.5 years)**

---

### Moderate Growth Path

| Month | MAU | Free Users | Premium Users | Ad Revenue | Premium Revenue | BR Sales | Total Revenue |
|-------|-----|------------|---------------|------------|-----------------|----------|---------------|
| 1-2   | 1,500 | 1,350 | 150 (10%) | $450 | $204 | $100 | **$754** |
| 3-4   | 2,500 | 2,125 | 375 (15%) | $850 | $510 | $200 | **$1,560** |
| 5-6   | 4,000 | 3,200 | 800 (20%) | $1,500 | $1,088 | $350 | **$2,938** |
| 7-9   | 7,000 | 5,600 | 1,400 (20%) | $2,600 | $1,904 | $600 | **$5,104** |
| 10-12 | 12,000 | 9,600 | 2,400 (20%) | $4,500 | $3,264 | $1,000 | **$8,764** |
| 13-15 | 18,000 | 14,400 | 3,600 (20%) | $6,750 | $4,896 | $1,500 | **$13,146** ✅ |

**Achieves $10k/month in Month 10-12 (1 year)**

---

### Optimistic Growth Path

| Month | MAU | Free Users | Premium Users | Ad Revenue | Premium Revenue | BR Sales | Total Revenue |
|-------|-----|------------|---------------|------------|-----------------|----------|---------------|
| 1-2   | 2,000 | 1,600 | 400 (20%) | $650 | $544 | $150 | **$1,344** |
| 3-4   | 4,000 | 3,000 | 1,000 (25%) | $1,200 | $1,360 | $300 | **$2,860** |
| 5-6   | 7,000 | 4,900 | 2,100 (30%) | $2,300 | $2,856 | $500 | **$5,656** |
| 7-9   | 12,000 | 8,400 | 3,600 (30%) | $3,900 | $4,896 | $850 | **$9,646** |
| 10-12 | 18,000 | 12,600 | 5,400 (30%) | $5,900 | $7,344 | $1,300 | **$14,544** ✅ |

**Achieves $10k/month in Month 7-9 (9 months)**

---

### Key Assumptions

**Ad Revenue:**
```
CPM Rates:
  - Rewarded: $20 (average)
  - Interstitial: $10 (average)
  - Google's cut: 32%

Engagement:
  - 40% of free users watch rewarded ads
  - Average 2 rewarded per day
  - 70% of free users see interstitials
  - Average 1.5 interstitials per day
```

**Premium Revenue:**
```
Pricing:
  - Monthly: $1.99
  - Annual: $19.99 (20% of subscribers)
  - Apple/Google cut: 32%

Conversion:
  - Phase 1: 5% of MAU
  - Phase 2: 10% of MAU
  - Phase 3: 15% of MAU
  - Phase 4: 15-30% of MAU (mature app)

Churn:
  - Monthly churn: 10%
  - Replaced by new conversions
```

**BR Sales:**
```
Engagement:
  - 5% of free users buy BR
  - Average purchase: $2.49
  - Frequency: 1.5 times per month
  - Apple/Google cut: 32%
```

---

## Success Metrics & KPIs

### Daily Metrics

**User Engagement:**
```
✅ DAU (Daily Active Users)
✅ DAU/MAU Ratio (target: >30%)
✅ Session length (target: >10 minutes)
✅ Pools joined per user (target: >3)
```

**Ad Performance:**
```
✅ Rewarded ad requests
✅ Rewarded ad completions (target: >70%)
✅ Interstitial impressions
✅ Interstitial click-through rate (CTR)
✅ Ad load success rate (target: >95%)
```

**Revenue:**
```
✅ Ad impressions (total)
✅ Estimated ad revenue (eCPM)
✅ Premium signups (trial starts)
✅ BR currency purchases
```

---

### Weekly Metrics

**Retention:**
```
✅ D1 retention (target: >40%)
✅ D7 retention (target: >25%)
✅ D30 retention (target: >15%)
✅ Cohort analysis (retention by signup date)
```

**Monetization:**
```
✅ Free → Trial conversion rate (target: >10%)
✅ Trial → Paid conversion rate (target: >70%)
✅ Premium churn rate (target: <10%/month)
✅ Revenue per user (ARPU)
✅ Lifetime value (LTV) by cohort
```

**Ad Fatigue Indicators:**
```
⚠️ Ad skip rate increasing
⚠️ Session length decreasing
⚠️ Uninstalls spiking after ad views
⚠️ App rating dropping
⚠️ User complaints in reviews
```

---

### Monthly Metrics

**Growth:**
```
✅ Monthly Active Users (MAU)
✅ New user signups
✅ User acquisition cost (CAC)
✅ Organic vs paid traffic ratio
✅ Referral program performance
```

**Revenue Breakdown:**
```
✅ Ad revenue (total & per user)
✅ Premium subscription revenue
✅ BR currency sales revenue
✅ Total revenue
✅ Net revenue (after fees)
```

**Product Health:**
```
✅ App store rating (target: >4.0)
✅ NPS (Net Promoter Score)
✅ Feature adoption rates
✅ Bug/crash rate (target: <1%)
✅ Support ticket volume
```

---

### Alerts & Thresholds

**Critical Alerts (Immediate Action Required):**
```
🚨 D7 retention drops below 20%
🚨 Premium churn exceeds 15% per month
🚨 Ad revenue drops >30% week-over-week
🚨 App rating falls below 3.5
🚨 Ad load success rate <80%
```

**Warning Alerts (Monitor Closely):**
```
⚠️ D7 retention drops below 23%
⚠️ Premium conversion drops below 5%
⚠️ Ad engagement drops >20%
⚠️ Session length decreases >15%
⚠️ User complaints increase >50%
```

**Opportunity Alerts (Optimize):**
```
💡 Premium conversion exceeds 15% (can raise price or reduce trial)
💡 Ad engagement exceeds 60% (can add more rewarded opportunities)
💡 D7 retention exceeds 30% (can be slightly more aggressive with ads)
```

---

## What We're NOT Doing (Rejected Strategies)

### Explicitly Rejected (Never Implement)

**❌ Ads on Pool Entry**
```
Rejected Because:
  - Interrupts user intent (wants to join NOW)
  - Immediate frustration point
  - 50%+ uninstall trigger
  - Breaks user flow
  - Poor conversion to premium (users just leave)

Alternative:
  - Show rewarded ad option if out of BR
  - Offer premium trial before entering exclusive pools
```

---

**❌ Ads on Pick Submission**
```
Rejected Because:
  - Punishes user for completing action
  - Feels like bait-and-switch
  - Extremely frustrating (user already invested time)
  - High abandonment rate
  - Negative reviews guaranteed

Alternative:
  - Show ad AFTER picks are submitted (completion trigger)
  - Only show if 3+ pools completed (natural break)
```

---

**❌ Timed Interval Ads**
```
Rejected Because:
  - Feels random and unfair
  - Interrupts user at worst times
  - No user control
  - Industry worst practice
  - Guaranteed churn spike

Alternative:
  - Action-based triggers only
  - Predictable patterns (every 3 pools)
  - User always knows when to expect ads
```

---

**❌ Banner Ads**
```
Rejected Because:
  - Low CPM ($0.50-2.00)
  - Takes up screen space
  - Looks cheap/unprofessional
  - Users develop "banner blindness"
  - Minimal revenue impact

Alternative:
  - Full-screen interstitials (higher CPM)
  - Rewarded videos (best CPM + user value)
```

---

**❌ Forced Video Ads (No Skip)**
```
Rejected Because:
  - Extremely frustrating
  - Users close app
  - Bad reviews
  - App store policy violations (in some cases)

Alternative:
  - 5-second skip option for interstitials
  - Rewarded ads require full watch (but user chose to watch)
```

---

**❌ Ads for Premium Users**
```
Rejected Because:
  - Premium's #1 benefit is "no ads"
  - Violates user trust
  - Instant churn
  - Refund requests
  - Legal issues (false advertising)

Alternative:
  - Premium = ZERO ads, period
  - Make this crystal clear in marketing
  - Never compromise this promise
```

---

**❌ Deceptive Ad Placements**
```
Rejected Because:
  - Tricks users into clicking
  - Violates app store policies
  - Google AdMob policy violation (account ban)
  - Unethical
  - Damages reputation

Examples to Avoid:
  - Fake close buttons
  - Ads disguised as content
  - Hidden skip buttons
  - Misleading CTAs
```

---

**❌ Ads During Payment Flows**
```
Rejected Because:
  - Apple/Google policy violation
  - Interrupts revenue generation
  - Confuses user intent
  - Can trigger refunds
  - May cause payment abandonment

Never Show Ads:
  - During BR purchase flow
  - During premium signup
  - During subscription management
  - In any payment screen
```

---

## Technical Implementation

### Step 1: Install Google Mobile Ads Package

**File:** `pubspec.yaml`

```yaml
dependencies:
  google_mobile_ads: ^5.2.0  # Add this line

  # Existing dependencies
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  # ... rest of your dependencies
```

Run:
```bash
flutter pub get
```

---

### Step 2: Update Existing Ad Service

**File:** `lib/services/ad_reward_service.dart` (already exists)

Update with production Ad Unit IDs:

```dart
class AdRewardService {
  // Production Ad Unit IDs (replace with your actual IDs from AdMob)
  static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-XXXXXX/1111111111';
  static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXX/2222222222';

  // Test IDs (for development)
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  String get _adUnitId {
    final isProduction = bool.fromEnvironment('dart.vm.product');

    if (defaultTargetPlatform == TargetPlatform.android) {
      return isProduction ? _prodRewardedAdUnitIdAndroid : _testRewardedAdUnitIdAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return isProduction ? _prodRewardedAdUnitIdIOS : _testRewardedAdUnitIdIOS;
    }
    return _testRewardedAdUnitIdAndroid;
  }

  // Rest of existing code remains the same
}
```

---

### Step 3: Create Interstitial Ad Service (Phase 2)

**File:** `lib/services/interstitial_ad_service.dart` (NEW)

```dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterstitialAdService {
  // Production Ad Unit IDs
  static const String _prodInterstitialIdAndroid = 'ca-app-pub-XXXXXX/3333333333';
  static const String _prodInterstitialIdIOS = 'ca-app-pub-XXXXXX/4444444444';

  // Test IDs
  static const String _testInterstitialIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIdIOS = 'ca-app-pub-3940256099942544/4411468910';

  // Frequency controls (from finalized strategy)
  static const int MAX_ADS_PER_SESSION = 3;
  static const int MIN_MINUTES_BETWEEN_ADS = 10;
  static const int MIN_ACTIONS_BEFORE_FIRST_AD = 3; // 3 pools completed

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;

  DateTime? _lastShownTime;
  int _sessionAdCount = 0;

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
              debugPrint('❌ Failed to show interstitial: $error');
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

  /// Check if we can show an ad (respects all frequency limits)
  bool canShowAd({int actionsCompleted = 0}) {
    // Check minimum actions requirement
    if (actionsCompleted < MIN_ACTIONS_BEFORE_FIRST_AD) {
      debugPrint('⏸️ Need ${MIN_ACTIONS_BEFORE_FIRST_AD - actionsCompleted} more actions before first ad');
      return false;
    }

    // Check session limit
    if (_sessionAdCount >= MAX_ADS_PER_SESSION) {
      debugPrint('⏸️ Session ad limit reached ($_sessionAdCount/$MAX_ADS_PER_SESSION)');
      return false;
    }

    // Check cooldown
    if (_lastShownTime != null) {
      final minutesSince = DateTime.now().difference(_lastShownTime!).inMinutes;
      if (minutesSince < MIN_MINUTES_BETWEEN_ADS) {
        debugPrint('⏸️ Cooldown active: ${MIN_MINUTES_BETWEEN_ADS - minutesSince} min remaining');
        return false;
      }
    }

    // Check if ad is ready
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

    // Save to SharedPreferences for persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_interstitial_time', _lastShownTime!.toIso8601String());
    await prefs.setInt('session_ad_count', _sessionAdCount);

    return true;
  }

  /// Reset session counters (call on app restart or after 30 min idle)
  void resetSession() {
    _sessionAdCount = 0;
    debugPrint('🔄 Interstitial session reset');
  }

  /// Get session stats
  Map<String, dynamic> getSessionStats() {
    return {
      'adsShownThisSession': _sessionAdCount,
      'maxAdsPerSession': MAX_ADS_PER_SESSION,
      'adsRemaining': MAX_ADS_PER_SESSION - _sessionAdCount,
      'lastShownTime': _lastShownTime?.toIso8601String(),
      'minutesSinceLastAd': _lastShownTime != null
        ? DateTime.now().difference(_lastShownTime!).inMinutes
        : null,
    };
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
```

---

### Step 4: Create Ad Manager (Centralized Control)

**File:** `lib/services/ad_manager_service.dart` (NEW)

```dart
import 'package:flutter/foundation.dart';
import 'ad_reward_service.dart';
import 'interstitial_ad_service.dart';
import '../models/user_model.dart'; // Adjust import

/// Centralized ad management service
/// Handles all ad logic, premium checks, and frequency limits
class AdManagerService {
  final AdRewardService _rewardedService = AdRewardService();
  final InterstitialAdService _interstitialService = InterstitialAdService();

  // Track user actions for interstitial triggers
  int _poolsCompletedThisSession = 0;
  int _tabSwitchCount = 0;
  DateTime? _sessionStartTime;

  /// Initialize both ad services
  static Future<void> initialize() async {
    await AdRewardService.initialize();
    debugPrint('✅ Ad services initialized');
  }

  /// Start new session (reset counters)
  void startNewSession() {
    _sessionStartTime = DateTime.now();
    _poolsCompletedThisSession = 0;
    _tabSwitchCount = 0;
    _interstitialService.resetSession();

    // Preload ads
    _rewardedService.loadRewardedAd();
    _interstitialService.loadInterstitialAd();

    debugPrint('🎮 New ad session started');
  }

  /// Check if user should see any ads
  bool shouldShowAds(UserModel user) {
    // Premium users never see ads
    if (user.isPremium == true) {
      return false;
    }

    // Check admin override
    if (user.adminOverride?.forcePremiumTier == true) {
      return false; // Force premium = no ads
    }

    if (user.adminOverride?.forceFreeTier == true) {
      return true; // Force free = show ads
    }

    // Default: Free users see ads
    return true;
  }

  /// Show rewarded ad (user-initiated)
  Future<AdRewardResult> showRewardedAd(String userId, UserModel user) async {
    if (!shouldShowAds(user)) {
      return AdRewardResult(
        success: false,
        message: 'Premium users don\'t need to watch ads!',
      );
    }

    return await _rewardedService.showRewardedAd(userId);
  }

  /// Track pool completion and maybe show interstitial
  Future<void> onPoolCompleted(UserModel user) async {
    if (!shouldShowAds(user)) return;

    _poolsCompletedThisSession++;

    // Show ad after every 3 pools
    if (_poolsCompletedThisSession % 3 == 0) {
      if (_interstitialService.canShowAd(actionsCompleted: _poolsCompletedThisSession)) {
        await _interstitialService.showInterstitialAd();
      }
    }
  }

  /// Track tab switch and maybe show interstitial
  Future<void> onTabSwitch(UserModel user) async {
    if (!shouldShowAds(user)) return;

    _tabSwitchCount++;

    // Show ad after every 5 tab switches
    if (_tabSwitchCount % 5 == 0) {
      if (_interstitialService.canShowAd(actionsCompleted: 1)) {
        await _interstitialService.showInterstitialAd();
      }
    }
  }

  /// Show interstitial after viewing bet history
  Future<void> onBetHistoryViewed(UserModel user, Duration timeSpent) async {
    if (!shouldShowAds(user)) return;

    // Only show if user spent meaningful time (30+ seconds)
    if (timeSpent.inSeconds >= 30) {
      if (_interstitialService.canShowAd(actionsCompleted: 1)) {
        await _interstitialService.showInterstitialAd();
      }
    }
  }

  /// Show interstitial after achievement unlock
  Future<void> onAchievementUnlocked(UserModel user) async {
    if (!shouldShowAds(user)) return;

    // Wait 2 seconds after achievement dialog
    await Future.delayed(const Duration(seconds: 2));

    if (_interstitialService.canShowAd(actionsCompleted: 1)) {
      await _interstitialService.showInterstitialAd();
    }
  }

  /// Check if user can watch more rewarded ads today
  Future<bool> canWatchRewardedAd(String userId) async {
    return await _rewardedService.canWatchAd(userId);
  }

  /// Get ad session statistics
  Map<String, dynamic> getStats() {
    return {
      'session': {
        'startTime': _sessionStartTime?.toIso8601String(),
        'poolsCompleted': _poolsCompletedThisSession,
        'tabSwitches': _tabSwitchCount,
      },
      'interstitial': _interstitialService.getSessionStats(),
    };
  }

  void dispose() {
    _rewardedService.dispose();
    _interstitialService.dispose();
  }
}
```

---

### Step 5: Update Main App to Initialize Ads

**File:** `lib/main.dart`

```dart
import 'services/ad_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize AdMob
  await AdManagerService.initialize();
  debugPrint('✅ Ads initialized');

  runApp(const MyApp());
}
```

---

### Step 6: Integration Examples

**Example 1: Show Rewarded Ad in BR Shop**

**File:** `lib/screens/wallet/br_shop_screen.dart`

```dart
import '../../services/ad_manager_service.dart';

class BRShopScreen extends StatefulWidget {
  // ... existing code
}

class _BRShopScreenState extends State<BRShopScreen> {
  final AdManagerService _adManager = AdManagerService();

  @override
  void initState() {
    super.initState();
    _adManager.startNewSession(); // Preload ads
  }

  Future<void> _watchAdForBR() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Show ad
    final result = await _adManager.showRewardedAd(userId, user);

    // Close loading
    Navigator.pop(context);

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
          ? '✅ Earned ${result.brAwarded} BR! New balance: ${result.newBalance}'
          : '❌ ${result.message}'),
        backgroundColor: result.success ? AppTheme.neonGreen : AppTheme.errorPink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: const Text('BR Currency')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Show rewarded ad option for free users
            if (!user.isPremium) ...[
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.neonGreen, AppTheme.primaryCyan],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.video_library, size: 48, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Watch & Earn',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Watch 30-second video',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          const Text(
                            'Earn 25 BR instantly',
                            style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<AdWatchStatus>(
                            future: _adManager._rewardedService.getAdWatchStatus(userId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final status = snapshot.data!;
                              return Text(
                                'Today: ${status.adsWatchedToday}/${status.maxAdsPerDay} videos watched',
                                style: const TextStyle(fontSize: 11, color: Colors.white60),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _watchAdForBR,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.neonGreen,
                      ),
                      child: const Text('WATCH'),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Or purchase BR:', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
            ],

            // BR Purchase options
            // ... existing purchase cards
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _adManager.dispose();
    super.dispose();
  }
}
```

---

**Example 2: Show Interstitial After Pool Completion**

**File:** `lib/screens/pools/pool_join_screen.dart`

```dart
Future<void> _submitPicks() async {
  // ... existing pick submission logic

  // After successfully joining pool
  await _poolService.joinPool(poolId, picks);

  // Track completion (may trigger interstitial)
  final user = Provider.of<UserProvider>(context, listen: false).user;
  await _adManager.onPoolCompleted(user);

  // Navigate back
  Navigator.pop(context);
}
```

---

## Launch Checklist

### Pre-Launch (Before Any Ads Go Live)

#### AdMob Setup
- [ ] Create Google AdMob account
- [ ] Add Android app to AdMob
- [ ] Add iOS app to AdMob
- [ ] Create Rewarded Video ad unit (Android)
- [ ] Create Rewarded Video ad unit (iOS)
- [ ] Set up payment profile (bank account for revenue)
- [ ] Configure mediation settings (optional, Phase 3)
- [ ] Block inappropriate ad categories

#### Code Implementation
- [ ] Install `google_mobile_ads` package
- [ ] Update `ad_reward_service.dart` with production IDs
- [ ] Create `interstitial_ad_service.dart` (Phase 2)
- [ ] Create `ad_manager_service.dart` (centralized control)
- [ ] Update Android manifest with AdMob App ID
- [ ] Update iOS Info.plist with AdMob App ID
- [ ] Initialize AdMob in `main.dart`
- [ ] Implement premium user bypass in all ad logic
- [ ] Add rewarded ad UI to BR shop
- [ ] Add rewarded ad UI to "Out of BR" modal
- [ ] Add rewarded ad UI to daily bonus screen

#### Testing (Use Test Ad IDs)
- [ ] Test rewarded ads on Android physical device
- [ ] Test rewarded ads on iOS physical device
- [ ] Verify BR currency awarded correctly
- [ ] Test daily limit enforcement (5 ads max)
- [ ] Test premium user sees no ads
- [ ] Test admin override (force free/premium tier)
- [ ] Test ad load failures (airplane mode)
- [ ] Test rapid clicking (shouldn't crash)
- [ ] Test session reset after 30 min idle

#### Legal & Compliance
- [ ] Update Privacy Policy (ad data collection section)
- [ ] Update Terms of Service (ad-supported free tier)
- [ ] Add GDPR consent flow for EU users (if applicable)
- [ ] Verify age gate is working (18+ enforcement)
- [ ] Review Google AdMob policies
- [ ] Configure allowed ad categories

#### Analytics
- [ ] Set up Firebase Analytics events for ads
- [ ] Create AdMob dashboard
- [ ] Set up revenue tracking
- [ ] Configure alerts (low revenue, high errors)
- [ ] Create weekly report template

---

### Phase 1 Launch (Rewarded Ads Only)

#### Week Before Launch
- [ ] Switch to production ad IDs (replace test IDs)
- [ ] Final testing with production ads
- [ ] Prepare rollback plan (how to disable ads quickly)
- [ ] Write announcement for users (optional)
- [ ] Brief support team on ad-related questions

#### Launch Day
- [ ] Deploy app update with rewarded ads
- [ ] Monitor AdMob dashboard (impressions, revenue)
- [ ] Monitor Firebase Analytics (ad events)
- [ ] Watch for user complaints (reviews, support)
- [ ] Check ad load success rate (target: >95%)

#### Week 1 Post-Launch
- [ ] Daily: Check ad revenue vs projections
- [ ] Daily: Monitor D1, D7 retention
- [ ] Daily: Review user feedback (app store reviews)
- [ ] Weekly: Calculate actual ad engagement rate
- [ ] Weekly: Review premium conversion rate
- [ ] Weekly: Identify optimization opportunities

#### Week 4 Post-Launch
- [ ] Month 1 retrospective: Did we hit targets?
- [ ] Decision: Proceed to Phase 2 or iterate on Phase 1?
- [ ] Document learnings
- [ ] Plan Phase 2 timeline

---

### Phase 2 Launch (Add Interstitials)

#### Preparation
- [ ] Phase 1 stable for 4+ weeks
- [ ] Retention metrics healthy (D7 >25%)
- [ ] Create interstitial ad units in AdMob
- [ ] Implement interstitial service code
- [ ] Add interstitial triggers to screens
- [ ] A/B test setup (50% test, 50% control)

#### Gradual Rollout
- [ ] Week 1: Enable for 25% of users
- [ ] Week 1: Monitor retention vs control group
- [ ] Week 2: Expand to 50% if retention holds
- [ ] Week 3: Expand to 75%
- [ ] Week 4: Enable for 100% or adjust frequency

#### Success Criteria (Phase 2)
- [ ] Revenue increase >30% vs Phase 1
- [ ] Retention drop <5% vs control
- [ ] Premium conversion increase >1%
- [ ] User complaints <15%
- [ ] Ad load success rate >90%

---

### Ongoing Monitoring

#### Daily Checks
- [ ] Ad revenue (AdMob dashboard)
- [ ] Ad impressions (target: trending up)
- [ ] Ad load success rate (target: >95%)
- [ ] User complaints (app reviews, support tickets)

#### Weekly Reviews
- [ ] Cohort retention analysis
- [ ] Revenue per user (ARPU)
- [ ] Premium conversion funnel
- [ ] Ad engagement trends

#### Monthly Reviews
- [ ] Total revenue vs target
- [ ] User growth rate
- [ ] Premium subscriber count
- [ ] Product roadmap adjustments
- [ ] Competitive analysis

---

## Document Control

**Owner:** Product/Business Lead
**Reviewers:** Engineering, Marketing, Legal
**Last Updated:** 2025-10-07
**Version:** 1.0 (Finalized)
**Next Review:** After Phase 1 launch (Month 2)

---

## Approval & Sign-Off

**Strategy Approved By:** [Your Name]
**Date:** 2025-10-07
**Status:** ✅ **READY FOR IMPLEMENTATION**

**Key Decisions Memorialized:**
- ✅ Option B (Sustainable) approved over Option A (Aggressive)
- ✅ No ads on pool entry, pick submission, or timed intervals
- ✅ Premium users get zero ads (non-negotiable)
- ✅ 18-24 month timeline to $10k/month revenue
- ✅ Ad-driven premium conversion strategy

**Next Action:** Begin Phase 1 implementation (Rewarded ads only)

---

**End of Document**
