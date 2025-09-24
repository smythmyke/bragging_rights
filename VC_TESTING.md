# Victory Coins Testing Guide

## Overview
Victory Coins (VC) have been integrated into the betting system. Users earn VC when they win bets with Bragging Rights (BR) coins.

## VC Conversion Rates
- **Favorite Win** (odds < -200): 15% of BR wagered
- **Even Odds Win** (-110 to +110): 25% of BR wagered
- **Underdog Win** (odds > +110): 40% of BR wagered
- **2-Team Parlay**: 35% of BR wagered
- **MMA Card Picks**:
  - Perfect Card: 150% of BR wagered
  - 80%+ accuracy: 80% of BR wagered
  - 60-79% accuracy: 40% of BR wagered
  - 40-59% accuracy: 20% of BR wagered

## Earning Caps
- **Daily**: 500 VC
- **Weekly**: 2,500 VC
- **Monthly**: 8,000 VC

## Testing Scenarios

### 1. Regular Bet Win
1. Place a bet on any game with BR coins
2. Wait for game to complete
3. Check that:
   - BR winnings are credited
   - VC is awarded based on odds and wager
   - VC transaction is logged in Firestore

### 2. MMA Pool Win
1. Enter an MMA pool competition
2. Make fight picks
3. After event completion, verify:
   - BR prize is distributed
   - VC is awarded based on accuracy
   - Wallet shows both BR and VC updates

### 3. Earning Cap Test
1. Win multiple bets to approach daily cap (500 VC)
2. Verify that VC earning stops at cap
3. Check that caps reset at appropriate times:
   - Daily: Midnight local time
   - Weekly: Monday
   - Monthly: 1st of month

### 4. UI Verification
1. Check home screen shows:
   - VC balance
   - Earning progress bars
   - Cap reset timers
2. Verify wallet service streams update in real-time

## Firestore Collections
- `victory_coins/{userId}` - User's VC balance and caps
- `vc_transactions` - Transaction history
- `users/{userId}/wallet/current` - BR balance (existing)

## Cloud Functions Updated
- `settleGameBets` - Awards VC for regular bet wins
- `processPayout` - Modified to include VC awarding
- `awardVictoryCoins` - New function for VC calculations

## Known Limitations
- Parlay VC calculation uses default 2-team rate (35%)
- Cap resets are not timezone-aware (uses server time)
- No VC spending features implemented yet (only earning)

## Next Steps
1. Implement tournament entry with VC
2. Add VC purchase options
3. Create VC spending features
4. Add detailed VC transaction history in app