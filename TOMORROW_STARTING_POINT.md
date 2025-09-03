# Tomorrow's Starting Point - Sept 4, 2025

## 🔴 CRITICAL ISSUES TO FIX (Discovered Sept 3)

### 1. **Pool Creation Not Working** 🚨
- **Issue**: Pools cannot be created properly
- **Impact**: Users cannot start new pools
- **Files to check**:
  - `lib/services/pool_service.dart` - createPool method
  - `lib/screens/pools/pool_selection_screen_v2.dart` - _createAutoPool method
  - Firebase console for any permission errors
- **Priority**: HIGH - Core functionality broken

### 2. **Flickering Information Still Present** 🚨
- **Issue**: Despite timer fix, information still flickering
- **Possible causes**:
  - Multiple StreamBuilders rebuilding
  - Unnecessary setState calls
  - Polling from other services
- **Files to check**:
  - `lib/screens/pools/pool_selection_screen_v2.dart`
  - Any screens using StreamBuilder
- **Priority**: HIGH - Poor user experience

### 3. **Card/Product Purchases Need Verification** 🚨
- **Issue**: Purchases may not be working correctly
- **Check**:
  - Wallet balance deduction
  - Card inventory updates
  - Firebase transaction recording
- **Files to verify**:
  - `lib/services/wallet_service.dart` - updateBalance method
  - `lib/services/card_service.dart` - purchaseCard method
  - `lib/screens/card_detail_screen.dart` - _purchaseCard method
  - `lib/screens/intel_detail_screen.dart` - _purchaseIntel method
- **Priority**: HIGH - Revenue feature broken

### 4. **Current Events Not Showing** 🚨
- **Issue**: Live/current games not displaying
- **Check**:
  - API endpoints returning data
  - Date filtering logic
  - ESPN API changes
- **Files to check**:
  - `lib/services/sports_api_service.dart`
  - `lib/services/espn_direct_service.dart`
  - API response logging
- **Priority**: HIGH - Core functionality broken

### 5. **Tennis Event API Review Needed** ⚠️
- **Issue**: Tennis integration incomplete/not working
- **Status**: 70% complete per checklist
- **Files to review**:
  - `lib/services/tennis_service.dart` (if exists)
  - ESPN Tennis API endpoints
  - Tennis data models
- **Priority**: MEDIUM - New feature incomplete

---

## 🎯 Current State Summary

The app is **functionally broken** in several critical areas despite being 99% code complete. These issues must be fixed before any testing.

## ✅ What's Working
- User authentication and registration
- UI layouts and navigation
- Visual effects and animations
- Cloud Functions deployed
- API integrations (but may need verification)

## 🐛 Known Issues Summary
1. **Pool Creation** - Not working ❌
2. **Information Flickering** - Still present ❌
3. **Purchases** - Need verification ❌
4. **Current Events** - Not displaying ❌
5. **Tennis API** - Incomplete ⚠️
6. **Google Sign-In** - Disabled ⚠️
7. **Windows Developer Mode** - Required for plugins ⚠️

---

## 🚀 Tomorrow's Priority Tasks (IN ORDER)

### Phase 1: Fix Critical Functionality (MORNING)

#### 1. Fix Current Events Display (FIRST PRIORITY)
```dart
// Check ESPN API responses
// lib/services/espn_direct_service.dart
Future<void> debugEventFetching() async {
  print('Fetching events for date: ${DateTime.now()}');
  // Add detailed logging
  // Check date formatting
  // Verify API endpoints
}
```

#### 2. Fix Pool Creation
```dart
// lib/services/pool_service.dart
Future<String> createPool(Pool pool) async {
  // Debug Firebase permissions
  // Check required fields
  // Add error logging
}
```

#### 3. Stop Flickering
- Add debouncing to StreamBuilders
- Check for duplicate listeners
- Review all setState calls
- Consider using ValueListenableBuilder

#### 4. Verify Purchases Work
- Test wallet balance updates
- Confirm Firebase transactions
- Check card inventory updates
- Add purchase logging

### Phase 2: Testing & Verification (AFTERNOON)

#### 5. Test Full User Flow
- [ ] Register new account
- [ ] View current events (must work!)
- [ ] Create a new pool (must work!)
- [ ] Join existing pool
- [ ] Purchase power card
- [ ] Purchase intel product
- [ ] Verify wallet updates

#### 6. Review Tennis API
- [ ] Check endpoint responses
- [ ] Verify data models
- [ ] Test with live tennis data
- [ ] Document what's missing

---

## 📝 Debug Commands to Run First

```bash
# Check for Flutter issues
flutter doctor -v

# Analyze code for problems
flutter analyze

# Clear build cache if needed
flutter clean
flutter pub get

# Run with verbose logging
flutter run -v

# Check Firebase deployment status
firebase deploy --only firestore:rules --debug
```

## 🔍 Debugging Checklist

### For Pool Creation:
1. Open Firebase Console > Firestore
2. Watch for permission denied errors
3. Check pools collection structure
4. Verify user authentication state
5. Add console.log/print statements

### For Flickering:
1. Use Flutter Inspector
2. Enable "Select Widget Mode"
3. Watch rebuild count
4. Check for infinite loops
5. Profile with DevTools

### For Events Not Showing:
1. Check network tab for API calls
2. Print API responses
3. Verify date/time calculations
4. Check timezone handling
5. Test with hardcoded dates

### For Purchases:
1. Monitor Firestore transactions
2. Check wallet balance before/after
3. Verify card inventory updates
4. Look for error messages
5. Test in sequence with delays

---

## 💡 Quick Fixes to Try

### If no events show:
```dart
// Try hardcoded date range
final startDate = DateTime.now().subtract(Duration(days: 1));
final endDate = DateTime.now().add(Duration(days: 7));
```

### If pool creation fails:
```dart
// Check for missing required fields
print('Creating pool with data: ${pool.toJson()}');
```

### If flickering persists:
```dart
// Replace StreamBuilder with FutureBuilder temporarily
// Or add distinctUnique() to streams
```

### If purchases fail:
```dart
// Add try-catch with detailed logging
try {
  await purchaseCard(cardId);
} catch (e, stack) {
  print('Purchase failed: $e\n$stack');
}
```

---

## 🎬 Testing Order (IMPORTANT)

1. **FIRST**: Get events displaying
2. **SECOND**: Fix pool creation
3. **THIRD**: Stop flickering
4. **FOURTH**: Verify purchases
5. **FIFTH**: Test complete flow
6. **LAST**: Review Tennis API

---

## 📊 Success Metrics for Tomorrow

- [ ] At least 5 current events visible
- [ ] Can create and join pools
- [ ] No flickering on any screen
- [ ] Purchases deduct balance correctly
- [ ] Complete user flow works end-to-end
- [ ] Tennis API status documented

## 🚨 If Still Broken by Noon

1. Rollback recent changes
2. Test with last known working commit
3. Check Firebase service status
4. Verify API keys still valid
5. Consider scheduling pair debugging session

---

## 📌 Remember
- **The app is NOT ready for testing until these issues are fixed**
- Focus on fixing broken features before adding new ones
- Keep detailed logs of what you try
- Commit working fixes immediately
- Update this document with solutions found

---

*Last updated: Sept 3, 2025 - CRITICAL ISSUES NEED IMMEDIATE ATTENTION*