# Simplified Bet Submission Plan

## Overview
Implement a streamlined bet submission flow for the simple betting system (MLB, NBA, NHL, NCAAF, NCAAB, Soccer, Tennis). Users can select bets and submit directly via a floating button without a multi-step review process.

## Design Philosophy
- **Minimize steps**: No separate bet slip review screen
- **Save screen space**: Floating action button instead of bottom sheet
- **Quick submission**: One-tap submit after selections are made
- **Show essentials only**: Wager selector + total points + submit button

---

## Current State Analysis

### What Works ✅
1. **Bet Selection UI** (`bet_selection_screen.dart`)
   - Users can browse 4-7 betting tabs per sport
   - Select/deselect bets via `SimpleBetCard`
   - Adjust confidence levels (1-5 stars)
   - State tracked in `_selectedSimpleBets` map and `_winnerBet`

2. **SimpleBetSlipWidget** (`bet_slip_widget.dart` lines 522-1019)
   - Complete UI component built but **NOT USED** in this simplified plan
   - We'll create a simpler floating button instead

3. **Data Models**
   - `SimpleBet` - Individual bet
   - `SimpleBetSlip` - Bet slip with metadata
   - `SimpleBetSlipBuilder` - Helper constructor

4. **Settlement Service**
   - `SimpleBetSettlementService` exists for settling completed games

### What's Missing ❌
1. **No Submit Button** - No way to submit selected bets
2. **No Submission Service** - No method to save bets to Firestore
3. **No Wallet Integration** - No balance deduction
4. **No Post-Submission Flow** - No navigation/confirmation

---

## Simplified User Flow

### Step 1: User Selects Bets
- User browses tabs and selects bets
- Adjusts confidence levels (1-5 stars)
- **Must select at least the Winner bet** (required)

### Step 2: Floating Submit Button Appears
Once Winner bet is selected, a floating button appears at the bottom showing:
- **Wager selector** (chips: 25, 50, 100, 200 BR)
- **Total potential points** (auto-calculated)
- **"Place Bet" button**

### Step 3: One-Tap Submit
User taps "Place Bet" → Immediate submission → Success/error feedback → Navigate back

---

## Implementation Plan

### Phase 1: Create Submission Service

#### Task 1.1: Create `simple_bet_submission_service.dart`
**Location**: `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

**Service Structure**:
```dart
class SimpleBetSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();

  static final SimpleBetSubmissionService _instance = SimpleBetSubmissionService._internal();
  factory SimpleBetSubmissionService() => _instance;
  SimpleBetSubmissionService._internal();

  /// Submit a simple bet slip to Firestore
  Future<String?> submitBetSlip({
    required String userId,
    required String gameId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime gameTime,
    required SimpleBet winnerBet,
    required List<SimpleBet> optionalBets,
    required int wagerAmount,
  }) async {
    try {
      // 1. Validate inputs
      if (!_validateBetSlip(winnerBet: winnerBet, wagerAmount: wagerAmount)) {
        return null;
      }

      // 2. Get current balance
      final balance = await _walletService.getUserBalance(userId);
      if (balance < wagerAmount) {
        debugPrint('[BetSubmission] Insufficient balance: $balance < $wagerAmount');
        return null;
      }

      // 3. Check for duplicate bet slips
      final existingBets = await _firestore
          .collection('simple_bet_slips')
          .where('userId', isEqualTo: userId)
          .where('gameId', isEqualTo: gameId)
          .where('settled', isEqualTo: false)
          .get();

      if (existingBets.docs.isNotEmpty) {
        debugPrint('[BetSubmission] User already has a pending bet for this game');
        return null;
      }

      // 4. Generate unique bet slip ID
      final betSlipId = _firestore.collection('simple_bet_slips').doc().id;

      // 5. Calculate total potential points
      double totalPotentialPoints = winnerBet.basePoints * winnerBet.multiplier;
      for (var bet in optionalBets) {
        totalPotentialPoints += bet.basePoints * bet.multiplier;
      }

      // 6. Create bet slip data
      final betSlipData = {
        'id': betSlipId,
        'gameId': gameId,
        'userId': userId,
        'sport': sport,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'gameTime': Timestamp.fromDate(gameTime),
        'winnerBet': winnerBet.toMap(),
        'optionalBets': optionalBets.map((b) => b.toMap()).toList(),
        'wagerAmount': wagerAmount,
        'totalPotentialPoints': totalPotentialPoints,
        'totalEarnedPoints': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'settled': false,
        'settledAt': null,
        'status': 'pending',
      };

      // 7. Save to Firestore first
      await _firestore.collection('simple_bet_slips').doc(betSlipId).set(betSlipData);

      // 8. Deduct wager from wallet
      final success = await _walletService.deductBalance(
        userId,
        wagerAmount,
        'Bet on $sport: $awayTeam @ $homeTeam',
      );

      if (!success) {
        // Rollback: delete bet slip
        await _firestore.collection('simple_bet_slips').doc(betSlipId).delete();
        debugPrint('[BetSubmission] Failed to deduct balance, rolled back bet slip');
        return null;
      }

      // 9. Log transaction
      await _walletService.addTransaction(
        userId,
        -wagerAmount,
        'bet_placed',
        'Bet #$betSlipId: $awayTeam @ $homeTeam',
      );

      debugPrint('[BetSubmission] ✅ Bet slip $betSlipId submitted successfully');
      return betSlipId;

    } catch (e) {
      debugPrint('[BetSubmission] ❌ Error: $e');
      return null;
    }
  }

  bool _validateBetSlip({
    required SimpleBet winnerBet,
    required int wagerAmount,
  }) {
    if (!winnerBet.isRequired) return false;
    if (wagerAmount <= 0) return false;
    return true;
  }
}
```

**Files to Create**:
- `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

---

### Phase 2: Add Floating Submit Button

#### Task 2.1: Add State Variables to `bet_selection_screen.dart`

**Add to state variables** (around line 133):
```dart
int _wagerAmount = 50; // Default wager
double _userBalance = 0.0;
bool _isSubmitting = false;
final SimpleBetSubmissionService _submissionService = SimpleBetSubmissionService();
final WalletService _walletService = WalletService();
```

#### Task 2.2: Load User Balance

**Add method**:
```dart
Future<void> _loadUserBalance() async {
  if (_userId == null) return;

  try {
    final balance = await _walletService.getUserBalance(_userId!);
    setState(() {
      _userBalance = balance;
    });
  } catch (e) {
    debugPrint('Error loading user balance: $e');
  }
}
```

**Call in initState**:
```dart
@override
void initState() {
  super.initState();
  _loadUserBalance();
  // ... rest of init
}
```

#### Task 2.3: Create Floating Submit Button Widget

**Add method**:
```dart
Widget _buildFloatingSubmitButton() {
  // Don't show if no winner selected
  if (_winnerBet == null) return const SizedBox.shrink();

  // Calculate total potential points
  double totalPotentialPoints = _winnerBet!.basePoints * _winnerBet!.multiplier;
  for (var bet in _selectedSimpleBets.values) {
    if (!bet.isRequired) {
      totalPotentialPoints += bet.basePoints * bet.multiplier;
    }
  }

  // Check if user has sufficient balance
  final hasSufficientBalance = _userBalance >= _wagerAmount;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surfaceBlue,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      border: Border(
        top: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wager selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Wager: ',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              ...[25, 50, 100, 200].map((amount) {
                final isSelected = _wagerAmount == amount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _wagerAmount = amount;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryCyan.withOpacity(0.3)
                            : AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryCyan
                              : AppTheme.borderCyan.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '$amount',
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryCyan
                              : AppTheme.textLight,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 12),

          // Potential points + Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Potential: ${totalPotentialPoints.toStringAsFixed(1)} pts',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Balance: ${_userBalance.toStringAsFixed(0)} BR',
                style: TextStyle(
                  color: hasSufficientBalance
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Place Bet button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isSubmitting || !hasSufficientBalance)
                  ? null
                  : _handleBetSubmission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                disabledBackgroundColor: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Place Bet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

#### Task 2.4: Add to Scaffold

**Update build() method** to include the floating button:
```dart
return Scaffold(
  appBar: _buildAppBar(),
  body: _buildBody(),
  // ADD THIS:
  bottomNavigationBar: _buildFloatingSubmitButton(),
);
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

---

### Phase 3: Wire Up Submission

#### Task 3.1: Implement `_handleBetSubmission()` Method

**Add method**:
```dart
Future<void> _handleBetSubmission() async {
  if (_winnerBet == null) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
    // Collect optional bets
    final optionalBets = _selectedSimpleBets.values
        .where((bet) => !bet.isRequired)
        .toList();

    // Call submission service
    final betSlipId = await _submissionService.submitBetSlip(
      userId: _userId!,
      gameId: widget.gameId!,
      sport: widget.sport,
      homeTeam: _homeTeam ?? '',
      awayTeam: _awayTeam ?? '',
      gameTime: widget.gameTime ?? DateTime.now(),
      winnerBet: _winnerBet!,
      optionalBets: optionalBets,
      wagerAmount: _wagerAmount,
    );

    if (betSlipId != null) {
      // Success!
      await _showSuccessDialog(betSlipId);

      // Clear bet slip
      _clearAllBets();

      // Refresh wallet balance
      await _loadUserBalance();

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Failed
      await _showErrorDialog(
        'Failed to place bet. Please check your balance and try again.',
      );
    }
  } catch (e) {
    debugPrint('Error submitting bet: $e');
    await _showErrorDialog('An error occurred. Please try again.');
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

void _clearAllBets() {
  setState(() {
    _selectedSimpleBets.clear();
    _winnerBet = null;
  });
}

Future<void> _showSuccessDialog(String betSlipId) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surfaceBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
          const SizedBox(width: 12),
          Text(
            'Bet Placed!',
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        'Your bet has been placed successfully.\n\nGood luck!',
        style: TextStyle(
          color: AppTheme.textLight,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
          },
          child: Text(
            'OK',
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _showErrorDialog(String message) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surfaceBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorRed, size: 28),
          const SizedBox(width: 12),
          Text(
            'Error',
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: AppTheme.textLight,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'OK',
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

---

### Phase 4: Verify Wallet Service

#### Task 4.1: Check WalletService Methods Exist

**Location**: `bragging_rights_app/lib/services/wallet_service.dart`

**Required methods**:
- `Future<double> getUserBalance(String userId)` - Get current balance
- `Future<bool> deductBalance(String userId, int amount, String reason)` - Deduct BR coins
- `Future<void> addTransaction(String userId, int amount, String type, String description)` - Log transaction

**If missing, implement these methods in wallet_service.dart**

---

## Testing Checklist

### Manual Testing
- [ ] Select only winner bet → floating button appears
- [ ] Add optional bets → button stays visible
- [ ] Change wager amounts → UI updates
- [ ] Change confidence levels → potential points update
- [ ] Try to submit with insufficient balance → button disabled, shows red balance
- [ ] Submit valid bet → success dialog appears
- [ ] Check Firestore → bet slip document created correctly
- [ ] Check wallet → wager deducted from balance
- [ ] Check transactions → transaction logged
- [ ] Try to submit duplicate bet → prevented with error
- [ ] Submit bet → navigate back → selections cleared
- [ ] Test with MLB game (7 tabs)
- [ ] Test with NBA game (7 tabs)
- [ ] Test with NHL game (5 tabs)
- [ ] Test with NCAAF game (4 tabs)
- [ ] Test with NCAAB game (5 tabs)

### Edge Cases
- [ ] Game starts before submission completes → handle gracefully
- [ ] Network error during submission → show error, don't deduct wallet
- [ ] Firestore write fails → rollback wallet deduction
- [ ] Wallet service fails → rollback bet slip creation
- [ ] User closes screen mid-submission → handle cleanup
- [ ] User has exactly enough balance → works
- [ ] User has 0 balance → button disabled

---

## Files Summary

### New Files to Create (1)
1. `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

### Files to Modify (2)
1. `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`
   - Add state variables (_wagerAmount, _userBalance, _isSubmitting)
   - Add _loadUserBalance() method
   - Add _buildFloatingSubmitButton() widget
   - Add _handleBetSubmission() method
   - Add _clearAllBets() method
   - Add success/error dialogs
   - Update Scaffold to include bottomNavigationBar

2. `bragging_rights_app/lib/services/wallet_service.dart` (verify/update if needed)
   - Ensure getUserBalance() exists
   - Ensure deductBalance() exists
   - Ensure addTransaction() exists

---

## Implementation Order

1. **Create Submission Service** (Phase 1)
   - Implement SimpleBetSubmissionService
   - Add validation and Firestore logic
   - Integrate wallet service calls

2. **Add Floating Button UI** (Phase 2)
   - Add state variables
   - Implement _buildFloatingSubmitButton()
   - Add to Scaffold
   - Load user balance

3. **Wire Up Submission** (Phase 3)
   - Implement _handleBetSubmission()
   - Add success/error dialogs
   - Test end-to-end

4. **Verify Wallet** (Phase 4)
   - Check wallet service methods
   - Test deduction and transactions

---

## Success Criteria

✅ Floating submit button appears when winner bet is selected
✅ Wager selector allows choosing 25, 50, 100, or 200 BR
✅ Total potential points calculated and displayed
✅ User balance displayed with color coding (green/red)
✅ "Place Bet" button disabled when insufficient balance
✅ One-tap submission saves to Firestore
✅ Wallet balance deducted correctly
✅ Transaction logged
✅ Success dialog shown
✅ Selections cleared after submission
✅ User cannot submit duplicate bets
✅ All error scenarios handled gracefully
✅ Works for all sports (MLB, NBA, NHL, NCAAF, NCAAB, Soccer, Tennis)

---

## Notes

- **Minimal UI**: No separate bet slip review - just a compact floating button
- **One-tap submit**: Reduces friction and speeds up betting flow
- **Essential info only**: Wager, potential points, balance, submit button
- **Space efficient**: Uses bottomNavigationBar slot instead of bottom sheet
- **All sports supported**: MLB, NBA, NHL, NCAAF, NCAAB, Soccer, Tennis
- **Point-based scoring**: Base points × confidence multiplier
- **Settlement happens later**: Via SimpleBetSettlementService when game completes
- **Confidence multipliers**: 1★=1.0x, 2★=1.5x, 3★=2.0x, 4★=2.5x, 5★=3.0x
