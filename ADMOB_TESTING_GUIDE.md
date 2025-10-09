# AdMob Phase 1 - Testing Guide

**Date**: 2025-10-08
**Status**: ✅ READY FOR TESTING

---

## ✅ What's Been Implemented

1. **AdMob SDK Setup**
   - ✅ google_mobile_ads package installed
   - ✅ Android App ID configured: `ca-app-pub-6550805819637330~3890172020`
   - ✅ Production Rewarded Ad Unit ID: `ca-app-pub-6550805819637330/2465409717`
   - ✅ Test IDs configured for development

2. **BR Shop Screen Created**
   - ✅ Full rewarded ad UI with neon cyber theme
   - ✅ Shows current BR balance
   - ✅ "Watch & Earn" card with ad counter
   - ✅ Premium upsell card
   - ✅ Route added: `/br-shop`

3. **Smart ID Switching**
   - ✅ Debug mode = Test IDs (works immediately)
   - ✅ Release mode = Production IDs (your real ads)

---

## 🧪 How to Test

### Test 1: Access BR Shop

**Steps:**
1. Run the app: `flutter run`
2. Navigate to BR Shop:
   ```dart
   // From anywhere in the app:
   Navigator.pushNamed(context, '/br-shop');
   ```
3. Or add a button temporarily to home screen:
   ```dart
   ElevatedButton(
     onPressed: () => Navigator.pushNamed(context, '/br-shop'),
     child: const Text('BR Shop'),
   )
   ```

**Expected:**
- Screen loads showing your current BR balance
- "Watch & Earn" card displays
- Shows "0/5 videos watched today"

---

### Test 2: Watch Rewarded Ad (Debug Mode - Test IDs)

**Steps:**
1. Open BR Shop screen
2. Tap **"WATCH NOW - EARN 25 BR"** button
3. Wait for ad to load (may take 2-5 seconds)
4. Ad should appear full-screen
5. Watch the entire ad (30 seconds)
6. Close the ad

**Expected:**
- Loading spinner appears briefly
- Test ad displays (Google test ad)
- After completion: Green success message
- "Earned 25 BR! New balance: XXX BR"
- Counter updates to "1/5 videos watched"

**If Ad Doesn't Load:**
- Check logs for: `✅ AdMob initialized`
- Check logs for: `✅ Rewarded ad loaded`
- Wait a few seconds and try again
- Make sure you have internet connection

---

### Test 3: Daily Limit Test

**Steps:**
1. Watch 5 ads in a row (tap button 5 times, wait for each)
2. After 5th ad, button should disable
3. Button text changes to: "DAILY LIMIT REACHED"

**Expected:**
- After 5 ads: Button becomes gray/disabled
- Total earned: 125 BR
- Can't watch more until tomorrow (midnight reset)

---

### Test 4: Premium User Test

**Steps:**
1. In Firebase Console, set your user's `isPremium` to `true`
2. Reload BR Shop screen
3. "Watch & Earn" card should be hidden

**Expected:**
- No ad card shown
- Only balance and premium benefits displayed
- Premium users never see ads

---

### Test 5: Ad Failure Handling

**Steps:**
1. Turn off WiFi/Data
2. Try to watch ad

**Expected:**
- Error message: "Ad not ready. Please try again."
- OR: "Ad is loading... Please wait a moment"
- App doesn't crash
- User-friendly error shown

---

## 🔍 Debug Logs to Watch

When testing, watch the debug console for these logs:

### Successful Flow:
```
✅ AdMob initialized
✅ Rewarded ad loaded
📺 Rewarded ad showed full screen
🎉 User earned reward: 1 BR
👋 Rewarded ad dismissed
💰 Awarded 25 BR to user [userId]
```

### If Ad Fails:
```
❌ Rewarded ad failed to load: [error details]
OR
❌ Rewarded ad failed to show: [error details]
```

---

## 📱 Testing on Physical Device

### Debug Build (Test Ads):
```bash
flutter run
```
- Uses test ad IDs
- Shows Google test ads
- No revenue generated
- Works immediately

### Release Build (Production Ads):
```bash
flutter build apk --release
flutter install
```
- Uses production ad IDs
- Shows real ads (after 1 hour)
- Generates actual revenue
- **Note**: New ad units take up to 1 hour to activate

---

## ⚠️ Important Notes

### AdMob Activation Time:
Your production ad unit was just created, so:
- **Test IDs**: Work immediately ✅
- **Production IDs**: May take up to 1 hour to start serving ads

If testing in release mode and ads don't load:
1. Wait 1 hour after ad unit creation
2. OR use debug mode with test IDs for now

### Ad Limits:
- **Daily**: 5 rewarded ads max per user
- **Reward**: 25 BR per ad
- **Max BR from ads**: 125 BR per day
- **Reset**: Midnight local time

### Premium Users:
- Set `isPremium: true` in Firestore
- OR set `adminOverride.forcePremiumTier: true`
- Premium users see ZERO ads

---

## 🚀 Next Steps After Testing

### If Tests Pass:
1. ✅ Ads load and play correctly
2. ✅ BR rewards are awarded
3. ✅ Daily limits work
4. ✅ Premium bypass works

**Then:**
- Add "Out of BR" modal (Phase 1B)
- Add Daily Bonus ad upsell (Phase 1C)
- Deploy to beta users
- Monitor AdMob dashboard for revenue

### If Tests Fail:

**Common Issues:**

1. **"Ad not ready"**
   - Solution: Wait 10-30 seconds, try again
   - Ad may still be loading in background

2. **"Ad failed to load"**
   - Check internet connection
   - Check AdMob account status
   - Verify ad unit IDs are correct

3. **Ad loads but no reward**
   - Check Firestore rules allow BR updates
   - Check user document exists
   - Check `br_currency_service.dart` is working

4. **Daily limit not working**
   - Check user document has `adsWatchedToday` field
   - Check `lastAdWatchDate` is being set
   - Check midnight reset logic

---

## 📊 AdMob Dashboard

Check your AdMob console:
https://admob.google.com/

**What to Monitor:**
- Ad requests (should increase when you test)
- Impressions (ads actually shown)
- Estimated earnings (starts at $0 for test ads)
- Fill rate (% of ad requests filled)

**Note**: Test ads show impressions but $0 revenue (this is normal!)

---

## 🎯 Success Criteria

Phase 1 is successful if:
- ✅ Ads load within 5 seconds
- ✅ 70%+ completion rate (users watch full ad)
- ✅ BR reward awarded correctly 100% of the time
- ✅ Daily limits enforce properly
- ✅ Premium users see zero ads
- ✅ No app crashes
- ✅ User experience feels smooth

---

## Quick Test Checklist

```
□ App builds successfully
□ BR Shop screen opens
□ Ad loads (test ID)
□ Can watch full ad
□ BR balance increases by 25
□ Counter shows 1/5
□ Can watch 5 ads total
□ 6th attempt is blocked
□ Premium user sees no ads
□ Error handling works
```

---

## 🆘 Troubleshooting

### Problem: Ads won't load at all

**Solution:**
1. Check `flutter pub get` was run
2. Verify AndroidManifest.xml has correct App ID
3. Check internet connection
4. Wait 30 seconds for initial load
5. Check logs for error messages

### Problem: Earned BR but balance doesn't update

**Solution:**
1. Check Firestore security rules allow writes
2. Verify user document exists in Firestore
3. Check `BRCurrencyService.awardAdReward()` logs
4. Refresh screen to reload balance

### Problem: Button says "Ad not ready"

**Solution:**
1. Wait 10-20 seconds
2. Check console for ` ✅ Rewarded ad loaded`
3. If not loaded, check internet
4. Try navigating away and back

---

**Ready to test! Run `flutter run` and navigate to `/br-shop`** 🚀

**Your Ad Unit IDs:**
- App ID: `ca-app-pub-6550805819637330~3890172020`
- Rewarded Ad: `ca-app-pub-6550805819637330/2465409717`
