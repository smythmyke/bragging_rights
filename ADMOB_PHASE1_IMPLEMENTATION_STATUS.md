# AdMob Phase 1 Implementation Status

**Date Started**: 2025-10-08
**Phase**: 1 - Rewarded Ads Only
**Status**: ✅ CORE IMPLEMENTATION COMPLETE - READY FOR TESTING

---

## Implementation Checklist

### ✅ Completed Tasks

1. **Package Installation**
   - ✅ Added `google_mobile_ads: ^5.2.0` to pubspec.yaml
   - ✅ Ran `flutter pub get` successfully
   - **File**: `bragging_rights_app/pubspec.yaml:64`

2. **Android Configuration**
   - ✅ Added AdMob App ID to AndroidManifest.xml
   - ✅ Using test ID temporarily: `ca-app-pub-3940256099942544~3347511713`
   - **File**: `bragging_rights_app/android/app/src/main/AndroidManifest.xml:14-17`
   - **Note**: Replace with production ID when AdMob account is created

3. **Ad Service Configuration**
   - ✅ Updated `ad_reward_service.dart` with test/production ID switching
   - ✅ Automatically uses test IDs in debug mode
   - ✅ Will use production IDs in release builds
   - **File**: `bragging_rights_app/lib/services/ad_reward_service.dart:10-34`

4. **Main App Initialization**
   - ✅ Imported AdRewardService in main.dart
   - ✅ Added AdMob initialization in main() function
   - ✅ Initialization happens after Firebase, before app startup
   - **File**: `bragging_rights_app/lib/main.dart:11,74-76`

---

## 🔴 Pending Tasks

### Step 1: Create AdMob Account (USER ACTION REQUIRED)

**Instructions for user:**

1. Go to: https://admob.google.com/
2. Sign in with your Google account (same as Firebase)
3. Click "Get Started" or "Add your first app"

**Create Android App:**
- App name: `Bragging Rights`
- Platform: `Android`
- App published: `No` (or Yes if on Play Store)
- **Save the Android App ID**: `ca-app-pub-XXXXXX~YYYYYY`

**Create Ad Unit (Android):**
- Go to: Apps > Bragging Rights > Ad units > Add ad unit
- Type: **Rewarded**
- Ad unit name: `BR Reward Video`
- **Save the Android Rewarded Ad Unit ID**: `ca-app-pub-XXXXXX/1111111111`

**For iOS (when needed):**
- Create iOS app
- Create iOS rewarded ad unit
- Get iOS IDs

**Next Action**: Once you have the IDs, provide them and I'll update the code.

---

### Step 2: Update Code with Production IDs

**Files to update:**

1. **Android Manifest** (`android/app/src/main/AndroidManifest.xml:17`)
   ```xml
   <!-- Replace this line: -->
   android:value="ca-app-pub-3940256099942544~3347511713"/>

   <!-- With your actual Android App ID: -->
   android:value="ca-app-pub-XXXXXX~YYYYYY"/>
   ```

2. **Ad Service** (`lib/services/ad_reward_service.dart:16`)
   ```dart
   // Replace this line:
   static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-XXXXXX/1111111111';

   // With your actual Android Rewarded Ad Unit ID:
   static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-YOUR_ACTUAL_ID/YOUR_ACTUAL_ID';
   ```

---

### Step 3: Create BR Shop Screen (Rewarded Ad UI)

**Status**: ⏳ Pending

**Location**: `lib/screens/wallet/br_shop_screen.dart` (to be created)

**UI Design**:
```
┌─────────────────────────────────────────┐
│ 🎬 WATCH & EARN                         │
│                                         │
│ Watch 30-second video                   │
│ Earn 25 BR instantly                    │
│                                         │
│ Today: 0/5 videos watched              │
│                                         │
│ [WATCH NOW - EARN 25 BR]               │
└─────────────────────────────────────────┘

Or purchase BR:
┌──────────┬──────────┬──────────┐
│ 100 BR   │ 600 BR   │ 1500 BR  │
│ $0.99    │ $4.99    │ $9.99    │
└──────────┴──────────┴──────────┘
```

**Implementation Notes**:
- Show rewarded ad card at top (prominent)
- Display ads watched today (0/5)
- Show "WATCH NOW" button
- Below that, show purchase options
- Hide ad card for premium users

---

### Step 4: Add "Out of BR" Modal

**Status**: ⏳ Pending

**Trigger**: When user tries to join pool but balance < entry cost

**UI Design**:
```
┌─────────────────────────────────────────┐
│ ⚠️ Not Enough BR                        │
│                                         │
│ You need 50 BR to join this pool        │
│ Current balance: 30 BR                  │
│                                         │
│ 🎬 WATCH AD - EARN 25 BR                │
│ [WATCH NOW]                             │
│                                         │
│ Or:                                     │
│ [Buy 100 BR - $0.99]                   │
│ [Go Premium - No Ads Ever]             │
│                                         │
│ [Cancel]                                │
└─────────────────────────────────────────┘
```

**Implementation Notes**:
- Detect insufficient balance before pool join
- Show modal with 3 options: Watch ad, Buy BR, Go Premium
- After watching ad → retry pool join
- High conversion trigger (70-80% engagement)

---

### Step 5: Add Daily Bonus Screen Ad Upsell

**Status**: ⏳ Pending

**Trigger**: After user claims daily login bonus (50 BR)

**UI Design**:
```
┌─────────────────────────────────────────┐
│ ✅ Daily Bonus Claimed!                 │
│                                         │
│ You earned: 50 BR                       │
│ New balance: 250 BR                     │
│                                         │
│ Want More?                              │
│ Watch videos to earn up to 125 BR today!│
│                                         │
│ [WATCH VIDEO - EARN 25 BR]             │
│ (5/5 remaining today)                   │
│                                         │
│ [Continue to App]                       │
└─────────────────────────────────────────┘
```

**Implementation Notes**:
- Show after daily bonus claim
- Optional (user can skip)
- 30-40% expected engagement

---

### Step 6: Testing

**Status**: ⏳ Pending

**Test Scenarios**:

1. **Ad Load Test**
   - Launch app
   - Check logs for: `✅ AdMob initialized`
   - Navigate to BR shop
   - Verify ad loads without errors

2. **Ad Display Test**
   - Tap "WATCH NOW" button
   - Ad should show full-screen
   - Complete video (30 seconds)
   - Verify reward earned

3. **BR Reward Test**
   - Watch complete ad
   - Check BR balance increased by 25
   - Verify user document updated (adsWatchedToday++)
   - Check Firebase logs

4. **Daily Limit Test**
   - Watch 5 ads in a row
   - 6th attempt should show: "Daily ad limit reached"
   - Next day: Counter resets to 0

5. **Premium User Test**
   - Set user to premium (isPremium = true)
   - BR shop should NOT show ad option
   - No ads should appear anywhere

**Test Devices**:
- Android physical device (test IDs work)
- Android emulator (test IDs work)
- iOS device (when iOS setup is complete)

---

## Current State Summary

### ✅ What Works Now:

1. **Package installed** - google_mobile_ads is available
2. **Android manifest configured** - AdMob App ID placeholder set
3. **Ad service ready** - Test/production ID switching implemented
4. **AdMob SDK initialized** - Happens on app startup

### 🔴 What's Needed:

1. **AdMob Account** - User needs to create and get real IDs
2. **Production IDs** - Replace placeholders with actual IDs
3. **UI Screens** - BR shop, Out of BR modal, Daily bonus upsell
4. **Testing** - Verify ads load and reward correctly

---

## Next Steps (In Order)

1. **User creates AdMob account** ← CURRENT BLOCKER
   - Get Android App ID
   - Get Android Rewarded Ad Unit ID

2. **Update production IDs in code**
   - AndroidManifest.xml
   - ad_reward_service.dart

3. **Implement UI screens**
   - BR Shop screen with ad card
   - Out of BR modal
   - Daily bonus upsell

4. **Test with test IDs** (debug mode)
   - Verify ad loading
   - Test BR rewards
   - Test daily limits

5. **Switch to production IDs** (release mode)
   - Build release APK
   - Test on device
   - Monitor AdMob dashboard

6. **Deploy to beta users**
   - 10-50 beta testers
   - Monitor engagement
   - Collect feedback

---

## File Changes Made

### Modified Files:

1. **pubspec.yaml**
   - Added: `google_mobile_ads: ^5.2.0`
   - Line: 64

2. **android/app/src/main/AndroidManifest.xml**
   - Added: AdMob App ID meta-data
   - Lines: 14-17
   - Status: Using test ID (needs production ID)

3. **lib/services/ad_reward_service.dart**
   - Added: Test/production ID switching logic
   - Lines: 10-34
   - Status: Placeholders for production IDs (needs real IDs)

4. **lib/main.dart**
   - Added: AdRewardService import
   - Added: AdMob initialization call
   - Lines: 11, 74-76

### Files to Create:

1. **lib/screens/wallet/br_shop_screen.dart** (NEW)
   - Purpose: Main rewarded ad UI
   - Status: Not created yet

2. **lib/widgets/out_of_br_modal.dart** (NEW)
   - Purpose: Show when user lacks BR
   - Status: Not created yet

3. **lib/widgets/daily_bonus_ad_upsell.dart** (NEW)
   - Purpose: Upsell after daily bonus
   - Status: Not created yet

---

## Revenue Projections (Phase 1)

**Target Metrics:**
- 30% of free users watch 1+ ad per day
- Average 2 ads per user per day
- 1,000 free users
- $20 CPM (rewarded video average)

**Calculation:**
```
300 users × 2 ads/day × 30 days = 18,000 ad views/month
18,000 ÷ 1,000 × $20 CPM = $360 gross
$360 × 68% (after Google's 32% cut) = $245 net/month
```

**Expected Range**: $150-400/month

---

## Important Notes

### Test IDs vs Production IDs:

**Test IDs** (currently active in debug mode):
- Android App: `ca-app-pub-3940256099942544~3347511713`
- Android Rewarded: `ca-app-pub-3940256099942544/5224354917`
- iOS Rewarded: `ca-app-pub-3940256099942544/1712485313`

**Production IDs** (placeholders - NEED TO REPLACE):
- Android App: `ca-app-pub-XXXXXX~YYYYYY`
- Android Rewarded: `ca-app-pub-XXXXXX/1111111111`
- iOS Rewarded: `ca-app-pub-XXXXXX/2222222222`

### Build Modes:

**Debug Mode** (`flutter run`):
- Uses test IDs automatically
- No AdMob account needed for testing
- Safe to develop with

**Release Mode** (`flutter build apk --release`):
- Uses production IDs automatically
- Requires real AdMob account
- Generates actual revenue

---

## Resources

**AdMob Console**: https://admob.google.com/
**AdMob Documentation**: https://developers.google.com/admob/flutter
**Strategy Doc**: `AD_MONETIZATION_STRATEGY_FINAL.md`
**Implementation Plan**: `ADMOB_IMPLEMENTATION_PLAN.md`

---

**Last Updated**: 2025-10-08
**Next Review**: After AdMob account creation
**Owner**: Claude Code + User
