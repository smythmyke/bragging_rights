# Welcome Back Overlay - Debug Guide

## Issue: Overlay not showing on app launch

### ✅ Changes Made:

1. **Updated `shouldShowWelcomeBack()`** - Now returns `true` every time (removed 1-hour delay)
2. **Added extensive debug logging** - Track every step of the process

---

## 🔍 Debug Logging

When you run the app, watch the console for these messages:

### Expected Flow:
```
🎉 Welcome Back: Starting check...
✅ Welcome Back: User found: <user_id>
🔍 Welcome Back: Should show? true
📊 Welcome Back: Fetching data...

📊 WelcomeBackService: Starting data fetch...
✅ WelcomeBackService: User ID: <user_id>
✅ WelcomeBackService: User document found
✅ WelcomeBackService: Data compiled successfully
   - Balance: 0 → 1500
   - Settled bets: 0
   - Active bets: 0
   - Stats: 0-0 (0.0%)
🎉 WelcomeBackService: Returning data!

✅ Welcome Back: Data fetched successfully
🎨 Welcome Back: Showing overlay!
```

### If overlay doesn't show, look for:

**❌ No user logged in:**
```
🎉 Welcome Back: Starting check...
❌ Welcome Back: No user logged in
```
→ **Fix:** Make sure user is authenticated before HomeScreen loads

**❌ User document doesn't exist:**
```
📊 WelcomeBackService: Starting data fetch...
✅ WelcomeBackService: User ID: <user_id>
❌ WelcomeBackService: User document does not exist
```
→ **Fix:** Create user document in Firestore at `users/<user_id>`

**❌ Should show = false:**
```
✅ Welcome Back: User found: <user_id>
🔍 Welcome Back: Should show? false
```
→ **Fix:** This shouldn't happen with new code (always returns true)

**❌ No data returned:**
```
📊 Welcome Back: Fetching data...
❌ Welcome Back: No data available
```
→ **Fix:** Check error in WelcomeBackService logs

**❌ Error in service:**
```
❌ Error fetching welcome back data: <error_message>
Stack trace: ...
```
→ **Fix:** Check Firestore permissions, collection structure

---

## 📋 Firestore Requirements

### Minimum Required:

**1. User Document:** `users/<user_id>/`
```javascript
{
  uid: "<user_id>",
  email: "user@example.com",
  displayName: "User Name",
  // These fields are optional (will use defaults if missing)
  lastLoginAt: Timestamp,
  lastSeenBalance: 0,
  lastSeenGlobalRank: 999,
  lastSeenFriendsRank: 999
}
```

**2. Wallet Subcollection (optional):** `users/<user_id>/wallet/current`
```javascript
{
  balance: 1500
}
```
→ If missing, defaults to 0

**3. Stats Subcollection (optional):** `users/<user_id>/stats/overall`
```javascript
{
  totalBets: 10,
  wins: 6,
  losses: 4,
  winRate: 60.0,
  currentStreak: 2,
  totalProfit: 500
}
```
→ If missing, all stats default to 0

**4. Bets Subcollection (optional):** `users/<user_id>/bets/<bet_id>`
```javascript
{
  gameName: "Lakers vs Celtics",
  betType: "Lakers ML",
  amount: 100,
  result: "won",  // or "lost"
  status: "settled",  // or "pending"
  settledAt: Timestamp
}
```
→ If missing, shows empty settled bets list

---

## 🧪 Quick Test

### Option 1: Use existing user
Just run the app. Overlay should show immediately.

### Option 2: Create test data in Firestore

```javascript
// In Firestore console, create:
users/test_user_123/ {
  uid: "test_user_123",
  email: "test@test.com",
  displayName: "Test User",
  lastLoginAt: [timestamp 2 hours ago],
  lastSeenBalance: 1000,
  lastSeenGlobalRank: 50,
  lastSeenFriendsRank: 5
}

users/test_user_123/wallet/current {
  balance: 1500
}

users/test_user_123/stats/overall {
  totalBets: 10,
  wins: 7,
  losses: 3,
  winRate: 70.0,
  currentStreak: 3,
  totalProfit: 500
}
```

Then log in as that user and open the app.

---

## 🐛 Common Issues

### 1. **Overlay shows but is blank/white**
→ **Cause:** Data is null or malformed
→ **Fix:** Check console for errors in WelcomeBackData model

### 2. **Overlay flashes then disappears**
→ **Cause:** Error in widget build method
→ **Fix:** Check for errors in `welcome_back_overlay.dart`

### 3. **App crashes on launch**
→ **Cause:** Missing import or Phosphor icons not installed
→ **Fix:** Run `flutter pub get` to ensure all dependencies are installed

### 4. **"No such method" error**
→ **Cause:** Missing fields in UserModel or WelcomeBackData
→ **Fix:** Hot reload might not work - do full restart (`flutter run`)

---

## 🔧 Temporary Test: Force Show Overlay

If you want to test the UI without waiting for data, modify `home_screen.dart`:

```dart
// In _checkWelcomeBackOverlay():
void _checkWelcomeBackOverlay() async {
  // TEMPORARY: Force show with mock data
  await Future.delayed(const Duration(milliseconds: 500));

  setState(() {
    _welcomeBackData = WelcomeBackData(
      lastLoginAt: DateTime.now().subtract(Duration(hours: 8)),
      oldBalance: 1000,
      newBalance: 1450,
      settledBets: [],  // Empty for now
      oldGlobalRank: 50,
      newGlobalRank: 38,
      oldFriendsRank: 5,
      newFriendsRank: 2,
      friendsPassed: ['Mike'],
      activeBetsCount: 5,
      totalBets: 15,
      wins: 10,
      losses: 5,
      winRate: 66.7,
      currentStreak: 3,
      totalProfit: 450,
    );
    _showWelcomeBackOverlay = true;
  });
}
```

This will show the overlay with dummy data, so you can test the UI/animations.

---

## ✅ Verification Steps

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Watch console** for debug messages (look for 🎉 emoji)

3. **Overlay should appear** after 500ms

4. **Check overlay displays:**
   - ✅ "Welcome Back!" header
   - ✅ Last seen time
   - ✅ Balance change (with animation)
   - ✅ Performance stats
   - ✅ Leaderboard changes
   - ✅ Active bets count
   - ✅ "Got It, Let's Go!" button

5. **Tap dismiss button** → Overlay should fade out

6. **Check Firestore** → `lastLoginAt` should be updated

7. **Restart app** → Overlay should show again

---

## 📝 Next Steps After Testing

Once overlay shows correctly:

1. **Remove debug logs** (or reduce verbosity)
2. **Replace mock rank data** with real leaderboard service
3. **Add settled bets** query (if bets collection exists)
4. **Test with real user data**

---

**Last Updated:** 2025-10-09
**Status:** Updated to show on every app launch
