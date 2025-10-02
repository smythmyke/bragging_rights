# Injury Intel Card Integration Guide
## Integration into EdgeScreenV2

**Date:** January 2025
**Target:** `lib/screens/premium/edge_screen_v2.dart`
**Flow:** Bet Selection → "Get The Edge" button → EdgeScreenV2 → Injury Intel Cards

---

## ✅ Completed Components

### **Models**
- ✅ `lib/models/injury_model.dart` - Injury data structure with ESPN API parsing
- ✅ `lib/models/intel_card_model.dart` - Intel Card purchase system

### **Services**
- ✅ `lib/services/injury_service.dart` - ESPN injury API integration
- ✅ `lib/services/intel_card_service.dart` - Purchase, ownership, analytics

### **Widgets**
- ✅ `lib/widgets/injury_intel_card_widget.dart` - Purchase card UI
- ✅ `lib/widgets/injury_report_widget.dart` - Injury report display

### **Configuration**
- ✅ Removed free injury displays from `game_details_screen.dart`
- ✅ Updated `intel_product.dart` to mark injury reports as BR-purchasable (50 BR)

---

## 🎯 Integration Plan

### **Phase 1: Update EdgeScreenV2 to Support Injury Intel Cards**

EdgeScreenV2 already has:
- Card-based UI system (`EdgeCardData`)
- Category system with `EdgeCardCategory.injury`
- Unlocking mechanism
- BR balance integration
- Firebase Auth

**What Needs to Change:**

1. **Replace existing injury card generation** (lines 135-143 in `edge_screen_v2.dart`)
   - Currently creates generic injury cards from intelligence insights
   - Replace with real Injury Intel Card system

2. **Add Injury Intel Card support**
   - Import new models and services
   - Generate IntelCard instances for games with injury data
   - Check user ownership via IntelCardService
   - Handle purchase flow

3. **Update card rendering**
   - Use `InjuryIntelCardWidget` for injury cards
   - Show `InjuryReportWidget` when owned and unlocked

---

## 🔧 Integration Steps

### **Step 1: Update EdgeScreenV2 Imports**

Add to `edge_screen_v2.dart`:

```dart
import '../../models/intel_card_model.dart';
import '../../models/injury_model.dart';
import '../../services/injury_service.dart';
import '../../services/intel_card_service.dart';
import '../../widgets/injury_intel_card_widget.dart';
import '../../widgets/injury_report_widget.dart';
```

### **Step 2: Add Services to State**

Add to `_EdgeScreenV2State`:

```dart
final InjuryService _injuryService = InjuryService();
final IntelCardService _intelCardService = IntelCardService();

// State for injury intel
List<IntelCard> _availableIntelCards = [];
Map<String, UserIntelCard> _ownedIntelCards = {};
Map<String, GameInjuryReport> _injuryReports = {};
```

### **Step 3: Load Injury Intel Cards**

Add to `_loadData()` method (after line 85):

```dart
// Generate Injury Intel Cards if sport supports it
if (_injuryService.sportSupportsInjuries(widget.sport)) {
  _availableIntelCards = _intelCardService.generateGameIntelCards(
    gameId: widget.gameId ?? widget.eventId ?? '',
    sport: widget.sport,
    gameTime: widget.gameTime ?? DateTime.now(),
  );

  // Check user ownership for each card
  if (user != null) {
    for (final card in _availableIntelCards) {
      final userCard = await _intelCardService.getUserIntelCard(
        userId: user.uid,
        cardId: card.id,
      );

      if (userCard != null) {
        _ownedIntelCards[card.id] = userCard;

        // Fetch injury data if owned
        if (userCard.injuryData == null) {
          final report = await _loadInjuryReport(card, homeTeam, awayTeam);
          if (report != null) {
            _injuryReports[card.id] = report;
          }
        } else {
          _injuryReports[card.id] = userCard.injuryData!;
        }
      }
    }
  }
}
```

### **Step 4: Add Injury Report Loading Method**

```dart
Future<GameInjuryReport?> _loadInjuryReport(
  IntelCard card,
  String homeTeam,
  String awayTeam,
) async {
  try {
    // Parse team IDs from game data or eventId
    // This will need to extract team IDs from ESPN event data
    // For now, use placeholder logic

    final report = await _injuryService.getGameInjuries(
      sport: widget.sport.toLowerCase(),
      homeTeamId: 'homeTeamId', // TODO: Extract from game data
      homeTeamName: homeTeam,
      homeTeamLogo: null, // TODO: Get from ESPN API
      awayTeamId: 'awayTeamId', // TODO: Extract from game data
      awayTeamName: awayTeam,
      awayTeamLogo: null, // TODO: Get from ESPN API
    );

    return report;
  } catch (e) {
    debugPrint('Error loading injury report: $e');
    return null;
  }
}
```

### **Step 5: Add Purchase Handler**

```dart
Future<void> _purchaseIntelCard(IntelCard card) async {
  final user = _auth.currentUser;
  if (user == null) {
    _showError('Please sign in to purchase Intel Cards');
    return;
  }

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Purchase Injury Intel'),
      content: Text(
        'Purchase complete injury reports for ${card.brCost} BR?\n\n'
        'This will unlock injury status for both teams.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Buy for ${card.brCost} BR'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  // Purchase
  final result = await _intelCardService.purchaseIntelCard(
    userId: user.uid,
    card: card,
  );

  // Close loading
  Navigator.pop(context);

  if (result.success) {
    // Load injury data
    final teams = widget.gameTitle.split(' vs ');
    String homeTeam = teams.length > 0 ? teams[0].trim() : 'Team 1';
    String awayTeam = teams.length > 1 ? teams[1].trim() : 'Team 2';

    final report = await _loadInjuryReport(card, homeTeam, awayTeam);

    setState(() {
      _ownedIntelCards[card.id] = result.userCard!;
      if (report != null) {
        _injuryReports[card.id] = report;
      }
      _userBRBalance -= card.brCost;
    });

    _showSuccess('Injury Intel unlocked!');
  } else {
    _showError(result.message);
  }
}

void _showSuccess(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ),
  );
}

void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}
```

### **Step 6: Render Injury Intel Cards in UI**

Add to the card list rendering (after line 300 in build method):

```dart
// Render Injury Intel Cards
if (_availableIntelCards.isNotEmpty) {
  children.add(
    const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'INJURY INTELLIGENCE',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );

  for (final card in _availableIntelCards) {
    final owned = _ownedIntelCards.containsKey(card.id);

    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Intel Card
            InjuryIntelCardWidget(
              card: card,
              owned: owned,
              onPurchase: () => _purchaseIntelCard(card),
              onView: owned ? () => _scrollToReport(card.id) : null,
            ),

            // Injury Report (if owned)
            if (owned && _injuryReports.containsKey(card.id)) ...[
              const SizedBox(height: 16),
              InjuryReportWidget(
                report: _injuryReports[card.id]!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## 📊 Data Flow

```
User on Bet Selection Screen
    ↓
Clicks "Get The Edge" button
    ↓
Navigator.pushNamed('/edge', arguments: {...})
    ↓
EdgeScreenV2 loads with:
  - gameTitle: "Lakers vs Warriors"
  - gameId: "401234567"
  - sport: "NBA"
  - gameTime: DateTime(2025, 1, 15, 19, 30)
    ↓
EdgeScreenV2._loadData():
  1. Load BR balance
  2. Parse team names from gameTitle
  3. Check if sport supports injuries (NBA ✅)
  4. Generate IntelCards (50 BR each)
  5. Check user ownership
  6. Load injury data if owned
    ↓
Render UI:
  - Show InjuryIntelCardWidget (locked or owned)
  - If owned: Show InjuryReportWidget with data
    ↓
User clicks "💰 GET INTEL - 50 BR"
    ↓
_purchaseIntelCard():
  1. Confirm purchase
  2. Deduct BR via IntelCardService
  3. Fetch injury data from ESPN
  4. Save to Firestore
  5. Update UI with unlocked report
```

---

## 🎨 UI Preview Reference

All UI components match the design in `INJURY_INTEL_PREVIEW.html`:
- Locked card with gradient border (cyan)
- Owned card with green border + "OWNED" badge
- Price tag with BR cost
- Expiration timer
- Team logos in injury sections
- Color-coded injury status (OUT=red, QUESTIONABLE=amber)
- Impact scoring visualization
- Intel Insight section

---

## 🔐 Firestore Collections

### **user_intel_cards**
```javascript
{
  userId: string,
  cardId: string,
  cardType: "IntelCardType.gameInjuryReport",
  purchasedAt: timestamp,
  brSpent: 50,
  gameId: string,
  expiresAt: timestamp,
  viewed: boolean,
  injuryData: {
    homeTeamName: string,
    awayTeamName: string,
    homeInjuries: [...],
    awayInjuries: [...],
    fetchedAt: timestamp
  }
}
```

### **analytics_intel_purchases**
```javascript
{
  userId: string,
  cardId: string,
  cardType: string,
  brCost: 50,
  sport: "NBA",
  gameId: string,
  purchasedAt: timestamp
}
```

---

## ⚠️ Important Notes

### **Team ID Extraction**
The current implementation needs team IDs to fetch ESPN injury data. These should be extracted from:
- `widget.gameId` (ESPN event ID)
- ESPN event API response
- Or passed from bet_selection_screen when navigating

**Recommended approach:**
Update bet_selection_screen to pass team IDs in navigation arguments:

```dart
Navigator.pushNamed(
  context,
  '/edge',
  arguments: {
    'gameTitle': widget.gameTitle,
    'sport': widget.sport,
    'gameId': _gameData?.id,
    'eventId': _gameData?.eventId,
    'gameTime': _gameData?.startTime,
    'homeTeamId': _gameData?.homeTeamId,  // ADD THIS
    'awayTeamId': _gameData?.awayTeamId,  // ADD THIS
  },
);
```

### **Team Logos**
ESPN provides team logos via:
```
https://a.espncdn.com/i/teamlogos/nba/500/{teamAbbreviation}.png
```

Extract abbreviation from team data or use team ID.

### **Expiration Handling**
Intel Cards expire when the game starts. EdgeScreenV2 should:
1. Check if card is expired before allowing purchase
2. Show "EXPIRED" state for past games
3. Clean up expired cards periodically

---

## 🧪 Testing Checklist

- [ ] Navigate from bet selection to edge screen
- [ ] Verify injury cards only show for NBA/NFL/MLB/NHL/Soccer
- [ ] Verify "locked" state shows correct price (50 BR)
- [ ] Purchase with sufficient BR balance
- [ ] Verify BR deduction
- [ ] Injury report displays with team logos
- [ ] Verify impact scores calculate correctly
- [ ] Try purchasing with insufficient BR (should fail)
- [ ] Try purchasing same card twice (should fail)
- [ ] Verify purchased cards persist after app restart
- [ ] Verify expired cards cannot be purchased

---

## 📝 Next Steps

1. ✅ Update bet_selection_screen to pass team IDs
2. ✅ Implement Step 1-6 in EdgeScreenV2
3. ✅ Test purchase flow with real ESPN API
4. ✅ Deploy Firestore security rules
5. ✅ Monitor analytics for purchase rates

---

**Status:** Ready for Implementation
**Owner:** Development Team
**Priority:** High (Revenue Feature)
