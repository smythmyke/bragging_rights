# Edge Cards Cleanup Summary

## 📋 What We Found

### Power Cards System (REMOVE ENTIRELY)
**Location:** `card_service.dart`, `card_definitions.dart`, `power_card_widget.dart`

**Power Cards Identified:**
- `double_down` - 2x bet multiplier (needs play-by-play)
- `mulligan` - Redo bet (pre-game only)
- `insurance` - Partial refund protection
- `split_bet` - Hedge both sides
- `time_freeze` - Lock bet before game
- `crystal_ball` - See "predictions" (fake)
- `copycat` - Copy top bettor
- `hedge` - Auto hedge in-game

**Why Remove:**
- ❌ Most require play-by-play data (not available)
- ❌ "Live game" triggers impossible without real-time tracking
- ❌ Confuses users about what app can actually do
- ❌ Technical debt with no value

**Files to Clean:**
1. `lib/services/card_service.dart` - Remove PowerCard logic (lines 92-222)
2. `lib/data/card_definitions.dart` - Remove all PowerCard definitions
3. `lib/widgets/power_card_widget.dart` - Delete entire file
4. `lib/screens/card_detail_screen.dart` - Remove PowerCard references
5. `lib/screens/cards/card_inventory_screen.dart` - Remove PowerCard UI

---

### Edge Intel Cards - Keep vs Remove

#### ✅ KEEP (6 Cards with Full Data)
1. **Injury Intelligence** - ESPN injury reports ✅
2. **Weather Impact** - ESPN weather API ✅
3. **Social Sentiment** - Reddit API ✅
4. **Matchup Analysis** - ESPN stats ✅
5. **Breaking News** - NewsAPI ✅
6. **Betting Movement** - Odds API ✅

#### ❌ REMOVE (2 Cards - No Data)
7. **Insider/Camp Info** - No API provides this ❌
8. **Clutch Performance** - Needs play-by-play ❌

**Files to Clean:**
1. `lib/widgets/edge/edge_card_types.dart` - Remove `insider` and `clutch` from enum (lines 11-12, 129-148)
2. Update EdgeCardCategory enum to remove these types
3. Remove from card configs map
4. Remove teaser/title logic

---

## 🗂️ Files to Modify

### 1. `edge_card_types.dart`
**Remove:**
- Line 11: `insider,` from EdgeCardCategory enum
- Line 12: `clutch,` from EdgeCardCategory enum
- Lines 129-138: Insider card config
- Lines 139-148: Clutch card config
- Lines 171-172: Insider teaser text
- Lines 173-174: Clutch teaser text
- Lines 193-194: Insider obfuscated title
- Lines 195-196: Clutch obfuscated title

**Result:** EdgeCardCategory enum will have 6 types instead of 8

---

### 2. `card_service.dart`
**This is for Power Cards (different from Edge Intel)**

**Remove:**
- Lines 92-122: `getUserCardsByType()` method (PowerCard specific)
- Lines 200-222: `canUseCard()` method (PowerCard game state logic)
- Lines 275-303: `giveStarterCards()` method (PowerCard starters)
- Lines 306-316: `purchaseCardPack()` stub

**Keep:**
- Card inventory tracking (generic)
- Add/use card methods (can work for any card type)
- Purchase card method (generic, not PowerCard specific)

---

### 3. Files to Delete Entirely
```
❌ lib/widgets/power_card_widget.dart
❌ lib/data/card_definitions.dart (if only PowerCards)
❌ lib/data/card_sound_mappings.dart (PowerCard sounds)
❌ lib/screens/card_detail_screen.dart (PowerCard specific)
```

---

## 🔧 Cleanup Steps

### Step 1: Remove Unusable Edge Intel Cards
```dart
// edge_card_types.dart - Line 4
enum EdgeCardCategory {
  injury,
  weather,
  social,
  matchup,
  breaking,
  betting,
  // REMOVED: insider,
  // REMOVED: clutch,
}

// Remove configs at lines 129-148
// Remove teaser logic at lines 171-174
// Remove title logic at lines 193-196
```

### Step 2: Clean Card Service (Power Cards)
**Option A: Delete Power Card Methods**
- Remove `getUserCardsByType()` - lines 92-122
- Remove `canUseCard()` - lines 200-222
- Remove `giveStarterCards()` - lines 275-303
- Remove `purchaseCardPack()` - lines 306-316

**Option B: Keep Generic Card Infrastructure**
- Keep inventory tracking (works for any card)
- Keep `addCardsToUser()`, `useCard()`, `purchaseCard()`
- Just remove PowerCard-specific logic

### Step 3: Remove Power Card Files
```bash
# Delete these files:
rm lib/widgets/power_card_widget.dart
rm lib/data/card_definitions.dart
rm lib/data/card_sound_mappings.dart
rm lib/screens/card_detail_screen.dart
```

### Step 4: Update Edge Screens
**Files to check:**
- `lib/screens/premium/edge_screen.dart`
- `lib/screens/premium/edge_screen_v2.dart`
- `lib/screens/premium/edge_detail_screen.dart`
- `lib/screens/premium/edge_detail_screen_v2.dart`

**Remove references to:**
- `EdgeCardCategory.insider`
- `EdgeCardCategory.clutch`
- Any PowerCard imports

---

## 🎯 What This Achieves

### Before Cleanup:
- 8 Edge Intel card types (2 unusable)
- 8+ Power Cards (all unusable)
- Confusing UX with impossible features
- Technical debt

### After Cleanup:
- 6 Edge Intel cards (all functional)
- No Power Cards (removed entirely)
- Clear value proposition
- Maintainable codebase

---

## 📊 Impact Analysis

### Edge Intel Cards:
**Before:** 8 card types
**After:** 6 card types (-25%)
**Lost Features:** Insider info, clutch stats (unavailable anyway)
**Gained:** Clarity, focus on working features

### Power Cards:
**Before:** Full system with 8+ cards
**After:** Completely removed (-100%)
**Lost Features:** In-game power-ups (impossible without play-by-play)
**Gained:** No false promises, cleaner codebase

---

## ✅ Post-Cleanup Verification

1. **Edge Page Loads:** Verify Edge screen shows 6 card categories
2. **No Errors:** Check console for removed enum errors
3. **Purchase Flow:** Test buying Intel cards (should work)
4. **Card Display:** Verify card UI shows correct 6 types
5. **Firebase Cleanup:** Consider removing old PowerCard docs

---

## 🚀 Next Steps After Cleanup

1. **Expand Remaining Cards** with more ESPN data
2. **Add 4 New Intel Cards:**
   - Pitcher/Goalie Spotlight
   - Line Value Detector
   - Trend Tracker
   - Public Fade Alert
3. **Dynamic Pricing** - Cards cost more near game time
4. **Bundle Discounts** - Buy 3+ cards for 20% off

---

## 📝 Files Modified Summary

| File | Action | Lines Changed |
|------|--------|--------------|
| `edge_card_types.dart` | Edit | Remove 2 enums, 4 configs |
| `card_service.dart` | Edit | Remove 4 methods (~130 lines) |
| `power_card_widget.dart` | Delete | Entire file |
| `card_definitions.dart` | Delete | Entire file |
| `card_sound_mappings.dart` | Delete | Entire file |
| `card_detail_screen.dart` | Delete | Entire file |
| Edge screens (4 files) | Edit | Remove 2 enum references |

**Total Impact:** ~500-700 lines of code removed, cleaner architecture

---

## ⚠️ Migration Notes

### If Users Have PowerCards in Firestore:
```javascript
// Cloud Function to migrate/refund
exports.migratePowerCards = functions.https.onCall(async (data, context) => {
  const userId = context.auth.uid;

  // Get user's PowerCard inventory
  const cardsSnapshot = await admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('cards')
    .get();

  let refundAmount = 0;

  // Calculate refund (50 BR per PowerCard)
  cardsSnapshot.forEach(doc => {
    const powerCardIds = ['double_down', 'mulligan', 'insurance', ...];
    if (powerCardIds.includes(doc.id)) {
      const quantity = doc.data().quantity || 0;
      refundAmount += quantity * 50; // 50 BR per card

      // Delete PowerCard
      doc.ref.delete();
    }
  });

  // Credit user wallet
  if (refundAmount > 0) {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        brBalance: admin.firestore.FieldValue.increment(refundAmount)
      });
  }

  return { refunded: refundAmount };
});
```

---

## 🎉 Expected Outcome

**User-Facing:**
- Clearer Edge page with 6 working Intel cards
- No confusing "Power Cards" that don't work
- Better trust (we only show features we can deliver)

**Developer-Facing:**
- ~500-700 lines of dead code removed
- No PowerCard technical debt
- Focus on building real features (new Intel cards)

**Business Impact:**
- Users trust Intel cards (they work)
- Clear monetization (buy Intel before betting)
- Can add new cards with confidence (we have the data)
