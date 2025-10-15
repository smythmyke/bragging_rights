# Simple Bet Submission Build Plan

## Overview
Implement the missing bet submission flow for the simple betting system (NCAA, NBA, NHL, MLB, Soccer, Tennis). Currently, users can select bets but have no way to submit them to Firestore.

## Current State Analysis

### What Works ✅
1. **Bet Selection UI** (`bet_selection_screen.dart`)
   - Users can browse 4-5 betting tabs per sport
   - Select/deselect bets via `SimpleBetCard`
   - Adjust confidence levels (1-5 stars)
   - State tracked in `_selectedSimpleBets` map and `_winnerBet`

2. **SimpleBetSlipWidget** (`bet_slip_widget.dart` lines 522-1019)
   - Complete UI component built but **NOT USED**
   - Shows selected bets, confidence, potential points
   - Wager selector (25, 50, 100, 200 BR)
   - Balance validation
   - "Place Bet" button

3. **Data Models**
   - `SimpleBet` - Individual bet
   - `SimpleBetSlip` - Bet slip with metadata
   - `SimpleBetSlipBuilder` - Helper constructor

4. **Settlement Service**
   - `SimpleBetSettlementService` exists for settling completed games

### What's Missing ❌
1. **No Bet Slip Display** - Widget never rendered in UI
2. **No Submission Service** - No method to save bets to Firestore
3. **No Submit Action** - "Place Bet" button not wired up
4. **No Wallet Integration** - No balance deduction
5. **No Post-Submission Flow** - No navigation/confirmation

---

## Implementation Plan

### Phase 1: Create Submission Service

#### Task 1.1: Create `simple_bet_submission_service.dart`
**Location**: `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

**Service Class Structure**:
```dart
class SimpleBetSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();

  // Singleton pattern
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
    // Implementation details below
  }

  /// Validate bet slip before submission
  bool _validateBetSlip({
    required SimpleBet winnerBet,
    required int wagerAmount,
    required double userBalance,
  }) {
    // Validation logic
  }
}
```

**Method: `submitBetSlip()`**
1. Validate inputs:
   - Winner bet is present
   - Wager amount > 0
   - User has sufficient balance
2. Check for duplicate bet slips (same user + game + pending)
3. Generate unique bet slip ID
4. Create SimpleBetSlip object with all fields
5. Save to Firestore `simple_bet_slips` collection
6. Deduct wager from user's wallet
7. Return bet slip ID on success, null on failure

**Firestore Document Structure**:
```dart
{
  'id': betSlipId,
  'gameId': gameId,
  'userId': userId,
  'sport': sport,
  'homeTeam': homeTeam,
  'awayTeam': awayTeam,
  'gameTime': Timestamp,
  'winnerBet': { /* SimpleBet.toMap() */ },
  'optionalBets': [ /* List<SimpleBet.toMap()> */ ],
  'wagerAmount': int,
  'submittedAt': Timestamp,
  'settled': false,
  'settledAt': null,
  'totalPotentialPoints': double,
  'totalEarnedPoints': null,
  'status': 'pending', // 'pending', 'settled', 'cancelled'
}
```

**Error Handling**:
- Insufficient balance → return null, show error
- Duplicate submission → return null, show warning
- Firestore error → return null, show error

**Files to Create**:
- `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

---

### Phase 2: Integrate Bet Slip Widget

#### Task 2.1: Add State Variables to `bet_selection_screen.dart`
**Location**: Around line 133 (near `_selectedSimpleBets` and `_winnerBet`)

**Add**:
```dart
int _wagerAmount = 50; // Default wager
final SimpleBetSubmissionService _submissionService = SimpleBetSubmissionService();
```

#### Task 2.2: Create Method to Build SimpleBetSlip
**Location**: `bet_selection_screen.dart` (new method)

```dart
SimpleBetSlip? _buildCurrentBetSlip() {
  if (_winnerBet == null) return null;

  final optionalBets = _selectedSimpleBets.values
      .where((bet) => !bet.isRequired)
      .toList();

  return SimpleBetSlip(
    id: '', // Will be set by service
    gameId: widget.gameId ?? '',
    userId: _userId ?? '',
    sport: widget.sport,
    homeTeam: _homeTeam ?? '',
    awayTeam: _awayTeam ?? '',
    gameTime: widget.gameTime ?? DateTime.now(),
    winnerBet: _winnerBet!,
    optionalBets: optionalBets,
    wagerAmount: _wagerAmount,
    submittedAt: DateTime.now(),
  );
}
```

#### Task 2.3: Add SimpleBetSlipWidget to UI
**Location**: `bet_selection_screen.dart` in `build()` method

**Change Scaffold to include**:
```dart
return Scaffold(
  appBar: _buildAppBar(),
  body: _buildBody(),
  // ADD THIS:
  bottomSheet: _buildCurrentBetSlip() != null
    ? SimpleBetSlipWidget(
        betSlip: _buildCurrentBetSlip()!,
        onRemoveBet: _removeBet,
        onConfidenceChanged: _updateBetConfidence,
        onClear: _clearAllBets,
        onPlaceBet: _handleBetSubmission,
        userBalance: _userBalance,
        wagerAmount: _wagerAmount,
        onWagerChanged: (amount) {
          setState(() {
            _wagerAmount = amount;
          });
        },
      )
    : null,
);
```

#### Task 2.4: Implement Helper Methods
**Location**: `bet_selection_screen.dart` (new methods)

```dart
void _removeBet(SimpleBet bet) {
  setState(() {
    _selectedSimpleBets.remove(bet.id);
    if (bet.isRequired && _winnerBet?.id == bet.id) {
      _winnerBet = null;
    }
  });
}

void _updateBetConfidence(SimpleBet bet, int confidence) {
  setState(() {
    final updatedBet = bet.copyWith(
      confidence: confidence,
      multiplier: SimpleBet.getMultiplier(confidence),
    );
    _selectedSimpleBets[bet.id] = updatedBet;

    if (bet.isRequired && _winnerBet?.id == bet.id) {
      _winnerBet = updatedBet;
    }
  });
}

void _clearAllBets() {
  setState(() {
    _selectedSimpleBets.clear();
    _winnerBet = null;
  });
}

Future<void> _handleBetSubmission(SimpleBetSlip betSlip) async {
  // Implementation in Task 2.5
}
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

---

### Phase 3: Wire Up Submission

#### Task 3.1: Implement `_handleBetSubmission()` Method
**Location**: `bet_selection_screen.dart`

```dart
Future<void> _handleBetSubmission(SimpleBetSlip betSlip) async {
  // 1. Show loading indicator
  setState(() {
    _isSubmitting = true;
  });

  try {
    // 2. Call submission service
    final betSlipId = await _submissionService.submitBetSlip(
      userId: _userId!,
      gameId: widget.gameId!,
      sport: widget.sport,
      homeTeam: _homeTeam!,
      awayTeam: _awayTeam!,
      gameTime: widget.gameTime!,
      winnerBet: betSlip.winnerBet,
      optionalBets: betSlip.optionalBets,
      wagerAmount: _wagerAmount,
    );

    // 3. Handle result
    if (betSlipId != null) {
      // Success!
      _showSuccessDialog(betSlipId);

      // Clear bet slip
      _clearAllBets();

      // Refresh wallet balance
      await _loadUserBalance();
    } else {
      // Failed
      _showErrorDialog('Failed to submit bet. Please try again.');
    }
  } catch (e) {
    debugPrint('Error submitting bet: $e');
    _showErrorDialog('An error occurred. Please try again.');
  } finally {
    setState(() {
      _isSubmitting = false;
    });
  }
}

void _showSuccessDialog(String betSlipId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bet Placed!'),
      content: Text(
        'Your bet has been placed successfully.\n\n'
        'Bet ID: $betSlipId\n'
        'Good luck!',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Close bet selection screen
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

#### Task 3.2: Add Loading State
**Location**: `bet_selection_screen.dart` state variables

**Add**:
```dart
bool _isSubmitting = false;
```

**Update SimpleBetSlipWidget**:
```dart
SimpleBetSlipWidget(
  // ... other params
  onPlaceBet: _isSubmitting ? null : _handleBetSubmission, // Disable during submission
  // ... other params
)
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

---

### Phase 4: Wallet Integration

#### Task 4.1: Check WalletService Methods
**Location**: `bragging_rights_app/lib/services/wallet_service.dart`

**Verify these methods exist**:
- `getUserBalance(String userId)` - Get current balance
- `deductBalance(String userId, int amount, String reason)` - Deduct BR coins
- `addTransaction(String userId, int amount, String type, String description)` - Log transaction

#### Task 4.2: Integrate in Submission Service
**Location**: `simple_bet_submission_service.dart` in `submitBetSlip()`

```dart
// After validating and before saving to Firestore:

// 1. Get current balance
final balance = await _walletService.getUserBalance(userId);
if (balance < wagerAmount) {
  debugPrint('[BetSubmission] Insufficient balance: $balance < $wagerAmount');
  return null;
}

// 2. Save bet slip to Firestore first
await _firestore.collection('simple_bet_slips').doc(betSlipId).set(betSlipData);

// 3. Deduct wager from wallet
final success = await _walletService.deductBalance(
  userId,
  wagerAmount,
  'Bet on $sport: $homeTeam vs $awayTeam',
);

if (!success) {
  // Rollback: delete bet slip
  await _firestore.collection('simple_bet_slips').doc(betSlipId).delete();
  debugPrint('[BetSubmission] Failed to deduct balance, rolled back bet slip');
  return null;
}

// 4. Log transaction
await _walletService.addTransaction(
  userId,
  -wagerAmount,
  'bet_placed',
  'Bet #$betSlipId: $homeTeam vs $awayTeam',
);
```

**Files to Check**:
- `bragging_rights_app/lib/services/wallet_service.dart`

**Files to Modify**:
- `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

---

### Phase 5: User Balance Display

#### Task 5.1: Load User Balance in `bet_selection_screen.dart`
**Location**: State variables and initState

**Add state variable**:
```dart
double _userBalance = 0.0;
final WalletService _walletService = WalletService();
```

**Load balance in initState or separate method**:
```dart
Future<void> _loadUserBalance() async {
  if (_userId == null) return;

  final balance = await _walletService.getUserBalance(_userId!);
  setState(() {
    _userBalance = balance;
  });
}

@override
void initState() {
  super.initState();
  _loadUserBalance();
  // ... rest of init
}
```

**Pass to SimpleBetSlipWidget**:
```dart
SimpleBetSlipWidget(
  // ... other params
  userBalance: _userBalance,
  // ... other params
)
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

---

### Phase 6: Duplicate Bet Prevention

#### Task 6.1: Check for Existing Bets
**Location**: `simple_bet_submission_service.dart` in `submitBetSlip()`

**Add before creating bet slip**:
```dart
// Check if user already has a pending bet for this game
final existingBets = await _firestore
    .collection('simple_bet_slips')
    .where('userId', isEqualTo: userId)
    .where('gameId', isEqualTo: gameId)
    .where('settled', isEqualTo: false)
    .get();

if (existingBets.docs.isNotEmpty) {
  debugPrint('[BetSubmission] User already has a pending bet for this game');
  // Optional: Allow user to replace existing bet
  return null;
}
```

**Files to Modify**:
- `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

---

### Phase 7: Testing & Validation

#### Manual Testing Checklist
- [ ] Select only winner bet → bet slip appears
- [ ] Add optional bets → bet slip updates
- [ ] Change confidence levels → potential points update correctly
- [ ] Select different wager amounts → summary updates
- [ ] Try to submit with insufficient balance → shows error
- [ ] Submit valid bet → success dialog appears
- [ ] Check Firestore → bet slip document created correctly
- [ ] Check wallet → wager deducted from balance
- [ ] Check transactions → transaction logged
- [ ] Try to submit duplicate bet → prevented with error
- [ ] Submit bet → navigate back → bet slip cleared
- [ ] Test with NCAAF game (4 tabs)
- [ ] Test with NCAAB game (5 tabs with team stats)
- [ ] Test with NBA game
- [ ] Test with NHL game
- [ ] Test with MLB game

#### Edge Cases to Test
- [ ] Game starts before submission completes → handle gracefully
- [ ] Network error during submission → show error, don't deduct wallet
- [ ] Firestore write fails → rollback wallet deduction
- [ ] Wallet service fails → rollback bet slip creation
- [ ] User closes screen mid-submission → handle cleanup
- [ ] User has exactly enough balance → works
- [ ] User has 0 balance → disabled correctly
- [ ] Missing game data (gameId, gameTime) → validation catches

#### Error Scenarios
- [ ] No winner selected → bet slip doesn't appear / submit disabled
- [ ] Negative wager amount → validation prevents
- [ ] Empty optional bets list → works (only winner)
- [ ] Confidence level out of range → validation prevents
- [ ] Invalid userId → error handled
- [ ] Invalid gameId → error handled

---

## Files Summary

### New Files to Create (1)
1. `bragging_rights_app/lib/services/simple_bet_submission_service.dart`

### Files to Modify (2)
1. `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`
   - Add state variables (_wagerAmount, _userBalance, _isSubmitting)
   - Add _buildCurrentBetSlip() method
   - Add SimpleBetSlipWidget to bottomSheet
   - Implement helper methods (_removeBet, _updateBetConfidence, _clearAllBets)
   - Implement _handleBetSubmission() method
   - Add success/error dialogs
   - Load user balance on init

2. `bragging_rights_app/lib/services/wallet_service.dart` (verify/update)
   - Ensure getUserBalance() exists
   - Ensure deductBalance() exists
   - Ensure addTransaction() exists

### Existing Files Used (No Changes)
- `bragging_rights_app/lib/widgets/bet_slip_widget.dart` - SimpleBetSlipWidget already built
- `bragging_rights_app/lib/models/simple_bet.dart` - SimpleBet model
- `bragging_rights_app/lib/models/simple_bet_slip.dart` - SimpleBetSlip model

---

## Implementation Order

1. **Start with Submission Service** (Phase 1)
   - Create the service class
   - Implement submitBetSlip() method
   - Add validation logic
   - Test with mock data

2. **Wire Up UI** (Phase 2)
   - Add state variables
   - Create _buildCurrentBetSlip() method
   - Add SimpleBetSlipWidget to bottomSheet
   - Test UI appears correctly

3. **Connect Submission** (Phase 3)
   - Implement _handleBetSubmission()
   - Add loading states
   - Add success/error dialogs
   - Test end-to-end flow

4. **Wallet Integration** (Phases 4-5)
   - Integrate wallet service calls
   - Add balance display
   - Test deduction and transactions

5. **Polish & Validation** (Phases 6-7)
   - Add duplicate bet prevention
   - Run all manual tests
   - Fix edge cases
   - Test error scenarios

---

## Success Criteria

✅ Users can see a bet slip at the bottom of the screen showing selected bets
✅ Users can adjust wager amount (25, 50, 100, 200 BR)
✅ Users can see their current balance
✅ Users can see total potential points
✅ "Place Bet" button is enabled only when valid (has winner, sufficient balance)
✅ Clicking "Place Bet" saves bet slip to Firestore
✅ Wallet balance is deducted correctly
✅ Transaction is logged
✅ Success dialog appears after submission
✅ Bet slip clears after submission
✅ User cannot submit duplicate bets for same game
✅ All error scenarios handled gracefully
✅ Works for all sports (NCAAF, NCAAB, NBA, NHL, MLB, Soccer, Tennis)

---

## Notes

- Simple betting system is point-based (no odds)
- Each sport has different bet types/tabs but submission flow is identical
- Bet settlement happens separately via `SimpleBetSettlementService` after game completes
- Wallet uses "BR" (Bragging Rights) as currency unit
- All timestamps should use Firestore `Timestamp.fromDate(DateTime)`
- Bet slips have status: 'pending', 'settled', 'cancelled'
- Users must select exactly 1 winner bet (enforced in UI)
- Optional bets can be 0 to N (no limit)
- Confidence multipliers: 1→1.0x, 2→1.5x, 3→2.0x, 4→2.5x, 5→3.0x
