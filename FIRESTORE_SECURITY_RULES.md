# Firestore Security Rules Documentation

## Overview
This document explains the security rules implemented for the Bragging Rights app's Firestore database. These rules ensure data integrity, prevent cheating, and protect user privacy.

## Quick Deployment

### Windows:
```bash
deploy_firestore_rules.bat
```

### Mac/Linux:
```bash
chmod +x deploy_firestore_rules.sh
./deploy_firestore_rules.sh
```

### Manual Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

## Security Principles

### 1. **Authentication Required**
- Most operations require user authentication
- Public access only for leaderboards and config

### 2. **Data Ownership**
- Users can only access their own sensitive data
- Wallet balances are read-only to prevent cheating
- Transaction history is immutable

### 3. **Business Logic Enforcement**
- Bets require sufficient balance
- Games must not have started
- Pool joining follows buy-in rules

## Collection-Specific Rules

### 👤 **Users Collection** (`/users/{userId}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | Own profile only | Privacy protection |
| **Create** | During signup only | Controlled registration |
| **Update** | Own profile, excluding protected fields | Prevent privilege escalation |
| **Delete** | Admin only | Account management |

**Protected Fields:**
- `uid` - Cannot be changed
- `email` - Cannot be changed  
- `createdAt` - Cannot be changed
- `isPremium` - Cannot be self-assigned

#### Wallet Subcollection (`/users/{userId}/wallet`)
- **Read:** User can view own balance
- **Write:** ❌ Blocked (Cloud Functions only)
- **Purpose:** Prevents balance manipulation

#### Stats Subcollection (`/users/{userId}/stats`)
- **Read:** User can view own stats
- **Write:** ❌ Blocked (Cloud Functions only)
- **Purpose:** Ensures accurate statistics

### 🎲 **Bets Collection** (`/bets/{betId}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | Own bets only | Privacy |
| **Create** | Multiple validations required | Fair play |
| **Update** | ❌ Blocked | Prevent manipulation |
| **Delete** | Before game starts only | Allow cancellation |

**Bet Creation Validations:**
- ✅ User is authenticated
- ✅ Betting own account (`userId` matches auth)
- ✅ Sufficient balance (≥ wager amount)
- ✅ Valid amount (10-1000 BR)
- ✅ Game hasn't started
- ✅ Status is 'pending'
- ✅ All required fields present

### 🏆 **Pools Collection** (`/pools/{poolId}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | All authenticated users | Discovery |
| **Create** | Authenticated users | Community features |
| **Update** | Join only (specific fields) | Controlled participation |
| **Delete** | Creator or admin | Ownership |

**Pool Creation Requirements:**
- `createdBy` must match auth user
- `participants` must be empty
- `totalPot` must be 0
- `status` must be 'open'

**Pool Joining Restrictions:**
- Pool must be open
- Only update `participants`, `totalPot`, `status`
- Pot must increase by exact buy-in amount

### 🏈 **Games Collection** (`/games/{gameId}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | All authenticated users | Game discovery |
| **Write** | Admin only | Data integrity |

### 💰 **Transactions Collection** (`/transactions/{transactionId}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | Own transactions only | Financial privacy |
| **Write** | ❌ Blocked | Audit trail integrity |

### 🥇 **Leaderboards Collection** (`/leaderboards/{period}`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | Public access | Community engagement |
| **Write** | ❌ Blocked | Prevent manipulation |

### 🔔 **Notifications Collection** (`/notifications/{userId}/messages`)
| Operation | Rule | Reason |
|-----------|------|--------|
| **Read** | Own notifications | Privacy |
| **Update** | Mark as read only | User control |
| **Delete** | Own notifications | Cleanup |
| **Create** | ❌ Blocked | Server-generated only |

## Helper Functions

### `isAuthenticated()`
Checks if request has valid authentication token

### `isOwner(userId)`
Verifies the requesting user owns the resource

### `isAdmin()`
Checks for admin custom claim (requires setup in Firebase Auth)

### `getUserBalance()`
Retrieves user's current BR balance from wallet

### `hasEnoughBalance(amount)`
Validates user has sufficient funds for transaction

### `isValidBetAmount(amount)`
Ensures bet is within allowed range (10-1000 BR)

### `gameNotStarted(gameId)`
Verifies game status is still 'scheduled'

### `poolIsOpen(poolId)`
Checks if pool is accepting new participants

## Testing the Rules

### 1. Firebase Console Simulator
1. Go to Firebase Console → Firestore → Rules
2. Click "Rules Playground"
3. Test different scenarios:
   - Authenticated vs unauthenticated
   - Own data vs other users' data
   - Valid vs invalid operations

### 2. Automated Testing
```bash
# Install test dependencies
npm install --save-dev @firebase/rules-unit-testing

# Run tests
npm test

# Or with emulator
firebase emulators:exec --only firestore "npm test"
```

### 3. Monitor in Production
- Check Firebase Console → Firestore → Usage
- Look for security rule denials
- Set up alerts for repeated violations

## Security Best Practices

### ✅ DO:
- Test rules thoroughly before production
- Use Cloud Functions for sensitive operations
- Implement rate limiting in Cloud Functions
- Monitor for security rule violations
- Keep rules as simple as possible
- Document any custom admin operations

### ❌ DON'T:
- Allow direct wallet balance modifications
- Trust client-side validation alone
- Use overly complex rule logic
- Grant unnecessary permissions
- Forget to test edge cases
- Leave debug rules in production

## Setting Up Admin Users

To enable admin functionality:

1. **Create Custom Claims** (Cloud Function):
```javascript
const admin = require('firebase-admin');

exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Verify the request is from an existing admin
  if (!context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied');
  }
  
  // Set admin claim on target user
  await admin.auth().setCustomUserClaims(data.uid, { admin: true });
  
  return { message: 'Admin claim set successfully' };
});
```

2. **Initial Admin Setup** (Firebase Console):
```javascript
// Run in Cloud Shell or local admin SDK
admin.auth().setCustomUserClaims('YOUR_ADMIN_UID', { admin: true });
```

## Common Issues & Solutions

### Issue: "Missing or insufficient permissions"
**Causes:**
- User not authenticated
- Trying to access another user's data
- Missing required fields in request
- Insufficient balance for operation

**Solution:** Check authentication status and request data

### Issue: Wallet balance not updating
**Cause:** Direct writes to wallet are blocked
**Solution:** Use Cloud Functions for wallet operations

### Issue: Can't place bet
**Possible Causes:**
- Insufficient balance
- Game already started
- Invalid bet amount
- Missing required fields

**Solution:** Verify all conditions in rules

## Monitoring & Alerts

### Set up monitoring for:
1. **Failed Rules** - Repeated denials may indicate:
   - Bug in client code
   - Attempted exploitation
   - Missing functionality

2. **Successful Operations** - Track:
   - Bet placement rates
   - Pool creation/joining
   - Transaction volume

3. **Admin Operations** - Log all admin actions

## Migration Notes

### From Development to Production:
1. Test all rules in development first
2. Backup existing rules before deployment
3. Deploy during low-traffic period
4. Monitor closely after deployment
5. Have rollback plan ready

### Breaking Changes:
If rules need major changes:
1. Version the rules file
2. Test with production data copy
3. Announce maintenance window
4. Deploy with monitoring
5. Quick rollback if issues

## Support & Troubleshooting

### Debug Mode (Development Only):
```javascript
// Temporary debug rule - NEVER use in production
allow read, write: if request.auth != null; 
```

### Logs & Analytics:
- Enable Firestore audit logs
- Use Firebase Analytics for user behavior
- Set up custom monitoring dashboards

### Contact:
- Technical issues: Check Firebase Console logs
- Security concerns: Review audit logs immediately
- Rule violations: Check client-side code first