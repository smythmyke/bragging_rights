# BR Earning Prompts Integration Guide

Custom themed popups to encourage users to watch ads and earn BR currency.

## 📋 What's Included

### 4 Custom Popup Types:

1. **Insufficient Funds Dialog** (Center, blocking)
   - When: User tries to bet but doesn't have enough BR
   - Style: Center dialog with neon green border, animated icon
   - Actions: "Watch Now" or "Cancel"

2. **Low Balance Banner** (Top, non-blocking)
   - When: BR balance drops below 25 BR
   - Style: Slides down from top, neon green with glow
   - Auto-dismisses after 5 seconds

3. **Daily Login Bottom Sheet** (Bottom, semi-blocking)
   - When: Once per day on app open
   - Style: Bottom sheet with gradient, shows earning potential
   - Actions: "Watch Now" or "Maybe Later"

4. **Post-Loss Floating Card** (Center overlay, non-blocking)
   - When: After user loses a bet
   - Style: Floating card with encouraging message
   - Auto-dismisses after 7 seconds (3s delay before showing)

---

## 🚀 How to Integrate

### 1. Daily Login Prompt

Add to your main app initialization (e.g., `home_screen.dart` or `main.dart`):

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

### 2. Low Balance Monitoring

Add to anywhere you display or update BR balance:

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

### 3. Insufficient Funds (When Placing Bet)

Add to your bet placement logic:

```dart
import 'package:bragging_rights/services/br_prompt_service.dart';

Future<void> _placeBet(int betAmount) async {
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

### 4. Post-Loss Prompt

Add to your bet settlement logic:

```dart
import 'package:bragging_rights/services/br_prompt_service.dart';

Future<void> _settleBet(Bet bet) async {
  if (bet.result == 'lost') {
    // Show encouraging prompt after loss
    BRPromptService.showPostLoss(
      context,
      brLost: bet.amount,
    );
  }
}
```

---

## ⚙️ Configuration

### Thresholds (in `br_prompt_service.dart`):

```dart
static const int LOW_BR_THRESHOLD = 25; // Change this value as needed
```

### Session Management:

```dart
// Reset all session flags (e.g., when user logs out)
BRPromptService.resetSessionFlags();

// Reset specific flags if you want to allow re-showing
BRPromptService.resetLowBalanceFlag();
BRPromptService.resetPostLossFlag();
```

---

## 🎨 Customization

All popups use your neon cyber theme from `app_theme.dart`:
- `AppTheme.neonGreen` - Primary action color
- `AppTheme.neonPurple` - Accent color
- `AppTheme.deepPurple` - Background gradient
- `AppTheme.surfaceBlue` - Background gradient
- `AppTheme.neonGlow()` - Glow effects

To customize messages, edit `lib/widgets/br_prompts/br_earn_prompts.dart`

---

## 📝 Implementation Checklist

- [ ] Add daily login check to home screen `initState()`
- [ ] Add low balance monitoring to wallet/balance displays
- [ ] Add insufficient funds check to bet placement logic
- [ ] Add post-loss prompt to bet settlement logic
- [ ] Test all 4 prompts in different scenarios
- [ ] Verify navigation to `/br-shop` works from all prompts

---

## 🧪 Testing

### Test Each Prompt:

**1. Daily Login:**
- Close and reopen app
- Should show once per day

**2. Low Balance:**
- Manually set balance to < 25 BR
- Navigate around app
- Should show banner once per session

**3. Insufficient Funds:**
- Try to place bet larger than balance
- Dialog should appear
- Test both "Watch Now" and "Cancel"

**4. Post-Loss:**
- Place a bet that will lose
- Wait for settlement
- Prompt shows 3 seconds after loss

---

## 🔧 Troubleshooting

**Prompts not showing?**
- Check if `context` is valid when calling
- Verify `shared_preferences` package is added to `pubspec.yaml`
- Check console for errors

**Showing too often?**
- Session flags prevent multiple shows per session
- Daily login uses SharedPreferences to limit to once/day
- Insufficient funds has no limit (by design - it's blocking)

**Wrong theme/colors?**
- Verify `app_theme.dart` has the required colors
- Check imports in `br_earn_prompts.dart`

---

## 📦 Dependencies

These prompts require:
- `shared_preferences` - For daily login tracking
- `app_theme.dart` - For neon cyber theme colors
- `br_currency_service.dart` - For ad limits and BR amounts

---

## 🎯 Best Practices

1. **Don't spam users** - The service already limits prompts conservatively
2. **Use context appropriately** - Always check `context.mounted` before showing
3. **Test on real devices** - Animations may perform differently
4. **Monitor conversion** - Track how many users click "Watch Now"
5. **Respect user dismissals** - Session flags prevent re-showing

---

Ready to integrate! 🚀
