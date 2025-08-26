# Cloud Functions Deployment Guide

## Overview
This guide covers the deployment and management of Cloud Functions for the Bragging Rights app's bet settlement system.

## Functions Implemented

### 1. **Bet Settlement** (`settleGameBets`)
- **Trigger**: When game status changes to 'final'
- **Purpose**: Automatically settles all pending bets
- **Features**:
  - Determines winners/losers based on bet type
  - Calculates payouts using American odds
  - Updates wallet balances
  - Creates transaction records
  - Updates user statistics

### 2. **Weekly Allowance** (`weeklyAllowance`)
- **Schedule**: Every Monday at 9 AM EST
- **Purpose**: Distributes 25 BR weekly allowance
- **Features**:
  - Checks last allowance date (7-day minimum)
  - Processes all active users
  - Creates transaction records
  - Logs distribution summary

### 3. **Manual Settlement** (`manualSettleGame`)
- **Type**: HTTPS Callable (Admin only)
- **Purpose**: Manually trigger bet settlement for testing
- **Security**: Requires admin custom claim

### 4. **Cancel Bet** (`cancelBet`)
- **Type**: HTTPS Callable
- **Purpose**: Allow users to cancel pending bets
- **Validation**:
  - User owns the bet
  - Bet is pending
  - Game hasn't started
  - Refunds wager amount

### 5. **Get User Stats** (`getUserStats`)
- **Type**: HTTPS Callable
- **Purpose**: Retrieve user statistics and ranking
- **Returns**: Win rate, profit, ranking, percentile

## Installation & Deployment

### Prerequisites
```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Select project
firebase use bragging-rights-ea6e1
```

### Install Dependencies
```bash
cd functions
npm install
```

### Deploy Functions

#### Deploy All Functions
```bash
firebase deploy --only functions
```

#### Deploy Specific Function
```bash
# Deploy only bet settlement
firebase deploy --only functions:settleGameBets

# Deploy only weekly allowance
firebase deploy --only functions:weeklyAllowance
```

### Test Locally with Emulator
```bash
# Start emulator
firebase emulators:start --only functions

# Or use npm script
npm run serve
```

## Testing

### Run Unit Tests
```bash
cd functions
npm test
```

### Test in Firebase Console
1. Go to Firebase Console → Functions
2. Click on function name
3. Use "Test" tab to trigger manually

### Test Bet Settlement
```javascript
// In Firebase Console or client app
const settleBets = firebase.functions().httpsCallable('manualSettleGame');
const result = await settleBets({ gameId: 'game123' });
console.log(result.data);
```

### Test Bet Cancellation
```javascript
const cancelBet = firebase.functions().httpsCallable('cancelBet');
const result = await cancelBet({ betId: 'bet456' });
console.log(result.data);
```

## Bet Settlement Logic

### Moneyline Bets
- Winner determined by game winner
- Payout calculated based on odds

### Spread Bets
- Winner determined by point spread
- Home team score adjusted by spread
- Compared to away team score

### Total (Over/Under) Bets
- Winner determined by total score vs line
- Push if exactly on line (refund wager)

### Payout Calculation
```javascript
// Positive odds (+150)
// Profit = wager * (odds / 100)
// $100 bet at +150 = $100 + ($100 * 1.5) = $250

// Negative odds (-110)
// Profit = wager * (100 / |odds|)
// $110 bet at -110 = $110 + ($110 * 0.909) = $210
```

## Security Considerations

### Function Security
1. **Authentication Required**: Most functions require auth
2. **Admin Functions**: Protected by custom claims
3. **Data Validation**: All inputs validated
4. **Transaction Safety**: Uses Firestore transactions
5. **Rate Limiting**: Consider adding rate limits

### Setting Admin Users
```javascript
// One-time setup in Admin SDK or Cloud Shell
const admin = require('firebase-admin');
admin.initializeApp();

// Set admin claim
await admin.auth().setCustomUserClaims('USER_ID', { admin: true });
```

## Monitoring & Debugging

### View Logs
```bash
# View all function logs
firebase functions:log

# View specific function logs
firebase functions:log --only settleGameBets

# Stream logs in real-time
firebase functions:log --follow
```

### Common Issues & Solutions

#### Issue: Function timeout
**Solution**: Increase timeout in function configuration
```javascript
exports.settleGameBets = functions
  .runWith({ timeoutSeconds: 300 })
  .firestore.document('games/{gameId}')
  .onUpdate(/* ... */);
```

#### Issue: Insufficient permissions
**Solution**: Check service account permissions in Firebase Console

#### Issue: Memory errors
**Solution**: Increase memory allocation
```javascript
exports.weeklyAllowance = functions
  .runWith({ memory: '1GB' })
  .pubsub.schedule(/* ... */);
```

## Cost Optimization

### Reduce Invocations
- Batch operations when possible
- Use efficient queries
- Implement caching where appropriate

### Monitor Usage
- Check Firebase Console → Functions → Usage
- Set up budget alerts
- Review function execution times

## Production Checklist

### Before Deployment
- [ ] Test all functions locally
- [ ] Run unit tests
- [ ] Test with emulator
- [ ] Review security rules
- [ ] Check error handling

### After Deployment
- [ ] Monitor initial executions
- [ ] Check error logs
- [ ] Verify wallet updates
- [ ] Test bet cancellation
- [ ] Confirm scheduled functions

## Scheduled Function Times

| Function | Schedule | Time Zone | Frequency |
|----------|----------|-----------|-----------|
| weeklyAllowance | 0 9 * * 1 | America/New_York | Weekly (Monday 9 AM) |

## Environment Variables

Currently using default Firebase config. For production, consider adding:

```javascript
// functions/.env
ALLOWANCE_AMOUNT=25
MAX_BET_AMOUNT=1000
MIN_BET_AMOUNT=10
ADMIN_EMAIL=admin@braggingrights.com
```

## Scaling Considerations

### Current Limits
- Concurrent executions: 1000 (default)
- Timeout: 60 seconds (default)
- Memory: 256MB (default)

### For Production Scale
1. Increase timeouts for settlement functions
2. Add retry logic for failed operations
3. Implement queue system for large batches
4. Consider regional deployments
5. Add comprehensive error tracking

## Support Commands

### Reset User Wallet (Admin)
```javascript
// Run in Cloud Shell or Admin SDK
const resetWallet = async (userId) => {
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('wallet')
    .doc('current')
    .update({ balance: 500 });
};
```

### Force Settlement (Admin)
```javascript
// Manually update game to trigger settlement
await admin.firestore()
  .collection('games')
  .doc('gameId')
  .update({ status: 'final' });
```

## Next Steps

1. **Add More Bet Types**: Parlays, props, futures
2. **Implement Odds Updates**: Real-time odds changes
3. **Add Notifications**: Push notifications for bet results
4. **Create Admin Dashboard**: Web interface for management
5. **Add Analytics**: Track popular bets, user behavior
6. **Implement Limits**: Daily/weekly betting limits
7. **Add Responsible Gaming**: Self-exclusion, timeouts

## Contact & Support

For issues or questions:
1. Check function logs first
2. Review error messages in Firebase Console
3. Test with emulator for debugging
4. Check Firestore Rules for permission issues