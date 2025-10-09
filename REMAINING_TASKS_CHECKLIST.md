# Remaining Tasks Checklist

**Date Created**: 2025-10-08
**Status**: 🔴 IN PROGRESS
**Purpose**: Track remaining implementation tasks and verify existing code before making changes

---

## ⚠️ CRITICAL: Check Before You Code!

**BEFORE implementing ANY task below:**

1. ✅ **Search the codebase** for existing implementation
2. ✅ **Read the relevant file** to check if the code already exists
3. ✅ **Test the feature** to see if it's already working
4. ✅ **Update this checklist** to mark items as "Already Implemented" if found
5. ✅ **Update the source document** that said it was incomplete

**Why?** To avoid:
- ❌ Duplicate code/methods
- ❌ Overwriting working features
- ❌ Wasting time on completed tasks
- ❌ Breaking existing functionality

---

## 📋 Priority 1: BR Earning Prompts Integration

**Source**: `BR_PROMPT_INTEGRATION_GUIDE.md:162-168`
**Files Created**:
- ✅ `lib/services/br_prompt_service.dart`
- ✅ `lib/widgets/br_prompts/br_earn_prompts.dart`

### Task 1.1: Daily Login Prompt
**Status**: ⏳ NEEDS VERIFICATION

**Instructions**:
1. **FIRST**: Check if already implemented
   ```bash
   # Search for daily login prompt usage
   grep -r "BRPromptService.checkDailyLogin" bragging_rights_app/lib/
   grep -r "checkDailyLogin" bragging_rights_app/lib/screens/home/
   ```

2. **IF NOT FOUND**: Implement in home screen
   - **File**: `bragging_rights_app/lib/screens/home/home_screen.dart`
   - **Location**: In `initState()` method
   - **Code to add**:
     ```dart
     import 'package:bragging_rights/services/br_prompt_service.dart';

     @override
     void initState() {
       super.initState();

       // Show daily login prompt after UI settles
       WidgetsBinding.instance.addPostFrameCallback((_) {
         BRPromptService.checkDailyLogin(context);
       });
     }
     ```

3. **IF FOUND**:
   - [ ] Mark as "Already Implemented" below
   - [ ] Update `BR_PROMPT_INTEGRATION_GUIDE.md:162` - check the box
   - [ ] Test the feature works
   - [ ] Move to next task

**Verification**:
- [ ] Code exists in codebase
- [ ] Prompt shows once per day on app open
- [ ] Can dismiss with "Maybe Later"
- [ ] "Watch Now" navigates to `/br-shop`

---

### Task 1.2: Low Balance Banner
**Status**: ⏳ NEEDS VERIFICATION

**Instructions**:
1. **FIRST**: Check if already implemented
   ```bash
   # Search for low balance monitoring
   grep -r "BRPromptService.checkLowBalance" bragging_rights_app/lib/
   grep -r "checkLowBalance" bragging_rights_app/lib/screens/home/
   ```

2. **IF NOT FOUND**: Add to BR balance display
   - **File**: `bragging_rights_app/lib/screens/home/home_screen.dart`
   - **Location**: Where BR balance is displayed (StreamBuilder)
   - **Code to add**:
     ```dart
     import 'package:bragging_rights/services/br_prompt_service.dart';

     StreamBuilder<int>(
       stream: _walletService.getBalanceStream(),
       builder: (context, snapshot) {
         final balance = snapshot.data ?? 0;

         // Check if we should show low balance prompt
         if (balance < 25) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             BRPromptService.checkLowBalance(context, balance);
           });
         }

         return Text('$balance BR');
       },
     )
     ```

3. **IF FOUND**:
   - [ ] Mark as "Already Implemented" below
   - [ ] Update `BR_PROMPT_INTEGRATION_GUIDE.md:163` - check the box
   - [ ] Test the feature works

**Verification**:
- [ ] Code exists in codebase
- [ ] Banner shows when BR < 25
- [ ] Shows once per session
- [ ] Auto-dismisses after 5 seconds
- [ ] "Get BR" button navigates to `/br-shop`

---

### Task 1.3: Insufficient Funds Dialog (Bet Placement)
**Status**: ⏳ NEEDS VERIFICATION

**Instructions**:
1. **FIRST**: Check if already implemented
   ```bash
   # Search for insufficient funds prompt
   grep -r "BRPromptService.showInsufficientFunds" bragging_rights_app/lib/
   grep -r "showInsufficientFunds" bragging_rights_app/lib/services/bet_service.dart
   ```

2. **ALSO CHECK**: Look for existing insufficient BR handling in bet placement
   ```bash
   # Check bet service for balance checks
   grep -A 10 "place.*bet\|placeBet" bragging_rights_app/lib/services/bet_service.dart | grep -i "balance\|insufficient"
   ```

3. **IF NOT FOUND**: Add to bet placement logic
   - **File**: `bragging_rights_app/lib/services/bet_service.dart` (or wherever bets are placed)
   - **Location**: Before placing bet
   - **Code to add**:
     ```dart
     import 'package:bragging_rights/services/br_prompt_service.dart';

     Future<void> placeBet(int betAmount) async {
       final currentBalance = await _walletService.getBalance();

       // Check if user has enough BR
       if (currentBalance < betAmount) {
         final shouldOpenShop = await BRPromptService.showInsufficientFunds(
           context,
           currentBalance: currentBalance,
           requiredAmount: betAmount,
         );

         if (shouldOpenShop) {
           // User clicked "Watch Now" - they'll be navigated to BR Shop
           return;
         } else {
           // User cancelled
           return;
         }
       }

       // Continue with bet placement...
     }
     ```

4. **IF FOUND**:
   - [ ] Mark as "Already Implemented" below
   - [ ] Update `BR_PROMPT_INTEGRATION_GUIDE.md:164` - check the box
   - [ ] Test the feature works

**Verification**:
- [ ] Code exists in bet placement flow
- [ ] Dialog shows when trying to bet more than balance
- [ ] Shows required vs current balance
- [ ] "Watch Now" navigates to BR Shop
- [ ] "Cancel" dismisses dialog

---

### Task 1.4: Post-Loss Prompt
**Status**: ⏳ NEEDS VERIFICATION

**Instructions**:
1. **FIRST**: Check if already implemented
   ```bash
   # Search for post-loss prompt
   grep -r "BRPromptService.showPostLoss" bragging_rights_app/lib/
   grep -r "showPostLoss" bragging_rights_app/lib/services/
   ```

2. **ALSO CHECK**: Find where bets are settled
   ```bash
   # Search for bet settlement logic
   grep -r "result.*=.*'lost'\|status.*=.*'lost'" bragging_rights_app/lib/
   grep -r "settleBet\|_settleBet" bragging_rights_app/lib/
   ```

3. **IF NOT FOUND**: Add to bet settlement logic
   - **File**: Wherever bets are settled (likely `bet_service.dart` or in a settlement handler)
   - **Location**: After bet result is determined as lost
   - **Code to add**:
     ```dart
     import 'package:bragging_rights/services/br_prompt_service.dart';

     Future<void> settleBet(Bet bet) async {
       if (bet.result == 'lost') {
         // Show encouraging prompt after loss
         BRPromptService.showPostLoss(
           context,
           brLost: bet.amount,
         );
       }
     }
     ```

4. **IF FOUND**:
   - [ ] Mark as "Already Implemented" below
   - [ ] Update `BR_PROMPT_INTEGRATION_GUIDE.md:165` - check the box
   - [ ] Test the feature works

**Verification**:
- [ ] Code exists in settlement flow
- [ ] Prompt shows 3 seconds after loss
- [ ] Shows amount lost
- [ ] Auto-dismisses after 7 seconds
- [ ] "Watch Ad to Recover" navigates to BR Shop

---

## 📋 Priority 2: BR Shop Verification

**Source**: `INTEGRATION_COMPLETE.md`

### Task 2.1: Clickable BR Balance on Home Screen
**Status**: ⏳ NEEDS VERIFICATION

**Doc Claims**: "COMPLETE" (`INTEGRATION_COMPLETE.md:28-59`)

**Instructions**:
1. **FIRST**: Verify implementation exists
   ```bash
   # Search for BR balance click handler
   grep -A 5 "GestureDetector\|InkWell\|onTap.*br-shop" bragging_rights_app/lib/screens/home/home_screen.dart
   ```

2. **Check for**:
   - GestureDetector or InkWell wrapping BR balance
   - `onTap: () => Navigator.pushNamed(context, '/br-shop')`
   - Green "+" icon next to balance
   - `PhosphorIconsRegular.plusCircle` with `AppTheme.neonGreen`

3. **IF NOT FOUND**:
   - [ ] Document says it's done but it's NOT - update `INTEGRATION_COMPLETE.md:28`
   - [ ] Implement the feature:
     ```dart
     GestureDetector(
       onTap: () => Navigator.pushNamed(context, '/br-shop'),
       child: Row(
         children: [
           Text('$brBalance BR', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
           SizedBox(width: 4),
           Icon(PhosphorIconsRegular.plusCircle, color: AppTheme.neonGreen, size: 20),
         ],
       ),
     )
     ```

4. **IF FOUND**:
   - [ ] Mark as "✅ Verified - Already Implemented" below
   - [ ] Test tap navigation works
   - [ ] Confirm with user it's working

**Verification**:
- [ ] BR balance has click/tap handler
- [ ] Green "+" icon visible next to balance
- [ ] Tap navigates to `/br-shop`
- [ ] Route opens BR Shop screen

---

### Task 2.2: Pool Selection - Enhanced Error Dialog
**Status**: ⏳ NEEDS VERIFICATION

**Doc Claims**: "COMPLETE" (`INTEGRATION_COMPLETE.md:62-93`)

**Instructions**:
1. **FIRST**: Check current implementation
   ```bash
   # Find pool join insufficient BR handling
   grep -A 10 "Insufficient.*balance.*pool\|balance < 25" bragging_rights_app/lib/screens/pools/pool_selection_screen.dart
   ```

2. **Look for**:
   - Method `_showInsufficientBRDialog(int required, int balance)` around line 1843-1898
   - Dialog with "Get BR" button
   - Navigation to `/br-shop`

3. **Check what currently exists**:
   - If it's still a SnackBar → NOT implemented (doc is wrong)
   - If it's a Dialog with "Get BR" → ✅ Implemented

4. **IF NOT FOUND**:
   - [ ] Update `INTEGRATION_COMPLETE.md:62` to mark as incomplete
   - [ ] Implement enhanced dialog per doc specs

5. **IF FOUND**:
   - [ ] Mark as "✅ Verified - Already Implemented" below
   - [ ] Test the dialog appears correctly
   - [ ] Test "Get BR" navigates to shop

**Verification**:
- [ ] Trying to join pool without enough BR shows dialog (not snackbar)
- [ ] Dialog shows warning icon and "Insufficient BR" title
- [ ] Shows required amount vs current balance
- [ ] "Get BR" button navigates to BR Shop
- [ ] "Cancel" dismisses dialog

---

### Task 2.3: Quick Play - Enhanced Error Dialog
**Status**: ⏳ NEEDS VERIFICATION

**Doc Claims**: "COMPLETE" (`INTEGRATION_COMPLETE.md:96-123`)

**Instructions**:
1. **FIRST**: Check current implementation
   ```bash
   # Find quick play insufficient BR handling
   grep -A 10 "Insufficient BR.*You need 25\|balance < 25" bragging_rights_app/lib/screens/home/home_screen.dart
   ```

2. **Look for**:
   - Method `_showInsufficientBRDialog(int required, int balance)` around line 4798-4853
   - Dialog with "Get BR" button (same as pool selection)
   - Called around line 4140

3. **Check what currently exists**:
   - If it's still a SnackBar → NOT implemented (doc is wrong)
   - If it's a Dialog with "Get BR" → ✅ Implemented

4. **IF NOT FOUND**:
   - [ ] Update `INTEGRATION_COMPLETE.md:96` to mark as incomplete
   - [ ] Implement enhanced dialog (can reuse from pool selection)

5. **IF FOUND**:
   - [ ] Mark as "✅ Verified - Already Implemented" below
   - [ ] Test the dialog appears correctly

**Verification**:
- [ ] Quick Play with insufficient BR shows dialog (not snackbar)
- [ ] Same enhanced dialog style as pool selection
- [ ] "Get BR" button works
- [ ] Navigation to BR Shop successful

---

## 📋 Priority 3: Testing Tasks

### Task 3.1: AdMob Integration Testing
**Source**: `ADMOB_TESTING_GUIDE.md:259-272`

**Instructions**:
1. **Run the app**: `flutter run`
2. **Work through checklist**:

**Test Checklist**:
- [ ] App builds successfully without errors
- [ ] BR Shop screen opens via `/br-shop` route
- [ ] Test ad loads (may take 2-5 seconds)
- [ ] Can watch full 30-second ad
- [ ] BR balance increases by 25 after ad
- [ ] Counter updates to show "1/5 videos watched"
- [ ] Can watch 5 ads total in one day
- [ ] 6th attempt shows "DAILY LIMIT REACHED" (disabled button)
- [ ] Set `isPremium: true` → "Watch & Earn" card is hidden
- [ ] Turn off WiFi → Shows error message (doesn't crash)

**If any test fails**:
- [ ] Document the failure in a new `ADMOB_TESTING_RESULTS.md` file
- [ ] Check `ADMOB_TESTING_GUIDE.md:276-303` for troubleshooting
- [ ] Fix the issue before proceeding

---

### Task 3.2: BR Shop Integration Testing
**Source**: `INTEGRATION_COMPLETE.md:306-352`

**Test Checklist**:
- [ ] **Basic Navigation**:
  - [ ] Tap BR balance on home screen → Opens BR Shop
  - [ ] Navigate to `/br-shop` directly → Opens BR Shop
  - [ ] BR Shop displays current balance correctly
  - [ ] BR Shop shows all 4 purchase packages
  - [ ] BR Shop shows rewarded ad section (if user not premium)

- [ ] **Rewarded Ads**:
  - [ ] Tap "WATCH NOW" → Ad loads
  - [ ] Watch complete ad → Earn 25 BR
  - [ ] Balance updates in BR Shop immediately
  - [ ] Counter shows "1/5 videos watched"
  - [ ] Watch 5 ads → Button disables (daily limit)
  - [ ] Next day → Counter resets to "0/5"

- [ ] **Purchase Flow (Test Mode)**:
  - [ ] Tap any price button → Confirmation dialog appears
  - [ ] Tap "Confirm (Test)" → BR added to account (Firestore)
  - [ ] Balance updates in BR Shop
  - [ ] Balance updates on home screen
  - [ ] Can use new BR to join pools/place bets

- [ ] **Insufficient BR Dialogs**:
  - [ ] Try to join pool with insufficient BR → Dialog appears
  - [ ] Dialog shows correct amounts (need vs have)
  - [ ] Tap "Get BR" → Opens BR Shop
  - [ ] Get BR from shop → Return to pool → Can now join
  - [ ] Try Quick Play with insufficient BR → Dialog appears
  - [ ] Same flow as pool join test works

- [ ] **Premium User**:
  - [ ] Set `isPremium: true` in Firestore
  - [ ] Open BR Shop → "Watch & Earn" section is HIDDEN
  - [ ] Only shows: Balance card, Premium benefits, Purchase packages
  - [ ] Verify no ads appear anywhere in app

---

### Task 3.3: BR Prompts Testing
**Source**: `BR_PROMPT_INTEGRATION_GUIDE.md:173-193`

**Only test AFTER Tasks 1.1-1.4 are verified/implemented**

**Test Scenarios**:

1. **Daily Login Test**:
   - [ ] Close app completely
   - [ ] Reopen app
   - [ ] Daily login prompt appears after home screen loads
   - [ ] Shows earning potential (125 BR/day)
   - [ ] Can dismiss with "Maybe Later"
   - [ ] "Watch Now" navigates to BR Shop
   - [ ] Prompt only shows once per day

2. **Low Balance Test**:
   - [ ] Manually set balance to < 25 BR (in Firestore or by spending)
   - [ ] Navigate around app (home → pools → games)
   - [ ] Low balance banner slides down from top
   - [ ] Shows neon green border with glow
   - [ ] Auto-dismisses after 5 seconds
   - [ ] Shows only once per session

3. **Insufficient Funds Test**:
   - [ ] Try to place bet larger than current balance
   - [ ] "Insufficient Funds" dialog appears (centered, blocking)
   - [ ] Shows required amount, current balance, and shortfall
   - [ ] "Watch Now" button present
   - [ ] Click "Watch Now" → Navigates to BR Shop
   - [ ] After earning BR → Can return and place bet
   - [ ] "Cancel" dismisses dialog

4. **Post-Loss Test**:
   - [ ] Place a bet that will lose (or simulate loss)
   - [ ] Wait for bet settlement
   - [ ] 3 seconds after loss → Floating card appears
   - [ ] Shows encouraging message + amount lost
   - [ ] "Watch Ad to Recover" button present
   - [ ] Auto-dismisses after 7 seconds (total: 3s delay + 7s display)
   - [ ] Can tap to dismiss early
   - [ ] Shows only once per session

---

### Task 3.4: Bet Settlement Automation Testing
**Source**: `BET_SETTLEMENT_CRITICAL_FIX.md:89-144`

**Test Scenarios**:

**Scenario 1: Manual Game Completion** (Quick test)
1. [ ] Find a live game with pending bets in Firestore
2. [ ] Note the `gameId` and bet IDs
3. [ ] In Firestore Console: Update game status to `'final'` with scores
4. [ ] Within 5 seconds: Check Cloud Function triggers (`firebase functions:log --only settleGameBets`)
5. [ ] Verify bet status updates to `'won'` or `'lost'`
6. [ ] Verify winner's wallet balance increases
7. [ ] Verify loser's bet marked as lost

**Scenario 2: Real Game Completion** (Full integration test)
1. [ ] Place a test bet on an upcoming game
2. [ ] Wait for game to complete naturally
3. [ ] Wait for next background refresh (or manually refresh)
4. [ ] Game should update to `status: 'final'` in Firestore
5. [ ] Cloud Function auto-triggers within 5 minutes
6. [ ] Bet settles automatically
7. [ ] Wallet updates automatically
8. [ ] UI shows completed game for 4 hours

**Scenario 3: UI Filtering** (Check old games hidden)
1. [ ] After Scenario 1 or 2 completes
2. [ ] Immediately check games list → Game should be visible
3. [ ] Wait 4+ hours (or manually update game's `gameTime` in Firestore)
4. [ ] Refresh games list → Game should be hidden from UI
5. [ ] Check Firestore → Game still exists with `status: 'final'`

---

## 📋 Priority 4: User Action Required

### Task 4.1: App Icon Generation
**Source**: `ICON_SETUP_INSTRUCTIONS.md`

**User must complete** (cannot be automated):

1. [ ] Open file in browser: `C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\convert_svg_to_png.html`
2. [ ] Click "Download PNG (1024x1024)" button
3. [ ] Save file as: `br_initials_icon.png`
4. [ ] Move to: `bragging_rights_app\assets\images\br_initials_icon.png`
5. [ ] Run command:
   ```bash
   cd bragging_rights_app
   dart run flutter_launcher_icons
   ```
6. [ ] Verify icon files generated:
   ```bash
   ls android/app/src/main/res/mipmap-*/
   ```
7. [ ] Rebuild app:
   ```bash
   flutter clean
   flutter run
   ```
8. [ ] Check app icon on device home screen

**Expected Result**:
- Dark blue background (matching app theme)
- Gold "B" with dark outline
- White "R" with dark outline
- Gold underline
- Visible on Android, Web, Windows

---

## 📋 Priority 5: Future Enhancements

### Task 5.1: Real In-App Purchases (IAP)
**Status**: 🔜 AFTER TESTING PASSES

**Current**: Using test purchases that just add BR to Firestore

**Required**:
- [ ] Integrate with existing `PurchaseService` (if exists - search first!)
- [ ] Connect to Google Play Billing
- [ ] Configure 4 products in Play Console:
  - Starter Pack: 100 BR - $0.99
  - Value Pack: 550 BR - $4.99
  - Pro Pack: 1200 BR - $9.99
  - Elite Pack: 2500 BR - $19.99
- [ ] Test real money transactions (use test account)
- [ ] Verify BR credits after purchase
- [ ] Handle edge cases (failed purchase, refunds, etc.)

---

### Task 5.2: Premium Subscription Flow
**Status**: 🔜 AFTER TESTING PASSES

**Required**:
- [ ] Create subscription product in Play Console
- [ ] 7-day free trial implementation
- [ ] Monthly billing ($1.99/month per docs)
- [ ] Premium badge/indicator in UI
- [ ] Ad removal verification (already built, just needs to activate)
- [ ] Premium benefits page
- [ ] Cancellation/downgrade flow

---

### Task 5.3: Analytics & Monitoring
**Status**: 🔜 AFTER DEPLOYMENT

**Required**:
- [ ] Track BR Shop opens (event: `br_shop_opened`)
- [ ] Track ad watch rate (event: `rewarded_ad_watched`)
- [ ] Track ad completion rate (event: `rewarded_ad_completed`)
- [ ] Track purchase conversions (event: `br_purchased`)
- [ ] Monitor revenue in AdMob dashboard
- [ ] Set up Firebase Analytics custom events
- [ ] Create dashboard for KPIs

---

## 📊 Progress Tracking

### Overall Status

**Priority 1 (BR Prompts)**:
- [ ] Task 1.1: Daily Login Prompt
- [ ] Task 1.2: Low Balance Banner
- [ ] Task 1.3: Insufficient Funds Dialog
- [ ] Task 1.4: Post-Loss Prompt

**Priority 2 (BR Shop Verification)**:
- [ ] Task 2.1: Clickable BR Balance
- [ ] Task 2.2: Pool Selection Dialog
- [ ] Task 2.3: Quick Play Dialog

**Priority 3 (Testing)**:
- [ ] Task 3.1: AdMob Testing (11 items)
- [ ] Task 3.2: BR Shop Testing (23 items)
- [ ] Task 3.3: BR Prompts Testing (4 scenarios)
- [ ] Task 3.4: Bet Settlement Testing (3 scenarios)

**Priority 4 (User Action)**:
- [ ] Task 4.1: App Icon Generation (8 steps)

**Priority 5 (Future)**:
- [ ] Task 5.1: Real IAP
- [ ] Task 5.2: Premium Subscription
- [ ] Task 5.3: Analytics

---

## 📝 Notes & Discoveries

### Already Implemented (Update as you verify):
```
Example:
- ✅ Task 2.1 - Clickable BR Balance - VERIFIED in home_screen.dart:3477-3503
- ✅ Task 2.2 - Pool Selection Dialog - VERIFIED in pool_selection_screen.dart:1843-1898
```

(Update this section as you verify tasks)

---

### Documents That Need Correction:
```
Example:
- ❌ INTEGRATION_COMPLETE.md:28 claims clickable BR balance is done, but it's NOT - corrected
- ❌ BR_PROMPT_INTEGRATION_GUIDE.md:162 says task unchecked, but it IS done - corrected
```

(Update this section when you find discrepancies)

---

## 🚀 Getting Started

**To begin implementation**:

1. **Start with Task 1.1** (Daily Login Prompt)
2. **Run the search command** to check if it exists
3. **If found**: Mark as complete and update source doc
4. **If not found**: Implement following the instructions
5. **Test the feature** works correctly
6. **Move to next task**

**Do NOT skip the verification step!** Always search first to avoid duplicates.

---

**Last Updated**: 2025-10-08
**Next Review**: After Priority 1 & 2 completion
**Owner**: Development Team
