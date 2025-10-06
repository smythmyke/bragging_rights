# Firestore Database Schema - Freemium Model

## Users Collection Updates

### Path: `users/{userId}`

Add these fields to existing user documents:

```json
{
  // Existing fields...

  // BR Currency Fields (NEW)
  "brBalance": 0,                          // Current BR currency balance
  "totalBrEarned": 0,                      // Lifetime BR earned (analytics)
  "totalBrSpent": 0,                       // Lifetime BR spent (analytics)
  "lastDailyBonus": null,                  // Timestamp - last daily bonus claim
  "loginStreak": 0,                        // Current consecutive login days
  "longestLoginStreak": 0,                 // All-time longest streak
  "lastLoginDate": null,                   // Date string (YYYY-MM-DD) for streak tracking
  "referralCode": "",                      // User's unique referral code
  "referredBy": null,                      // UserId of referrer (if any)
  "adsWatchedToday": 0,                    // Count of ads watched today (reset daily)
  "lastAdWatchDate": null,                 // Date string (YYYY-MM-DD) for daily reset

  // Subscription Fields (NEW - Phase 2)
  "isPremium": false,                      // Premium subscription status
  "subscriptionType": null,                // "monthly", "annual", or null
  "subscriptionStartDate": null,           // Timestamp
  "subscriptionEndDate": null,             // Timestamp
  "trialEndDate": null,                    // Timestamp - 7-day trial
  "prizeWeeksRemaining": 0,                // Weeks of free premium from prizes
  "prizeExpiryDate": null,                 // When prize period ends
  "autoSubscribeAfterPrize": false,        // Auto-convert to paid after prize
  "lastSubscriptionCheck": null,           // Timestamp - last status verification

  // Prize & Competition Fields (NEW - Phase 3)
  "totalPrizesWon": 0,                     // Count of prizes won
  "cumulativePrizeValue": 0.0,             // Dollar value for tax reporting (e.g., 11.94)
  "needs1099": false,                      // True if cumulative >= $600
  "w9Submitted": false,                    // Tax form submission status
  "competitionStats": {
    "totalCompetitionsEntered": 0,
    "totalWins": 0,
    "bestRanking": null,                   // Best finish (1-10)
    "currentMonthQualified": false         // Met 10+ pool minimum
  }
}
```

### Firestore Indexes for Users Collection

```
users collection:
- isPremium (ascending) + subscriptionEndDate (ascending)
- prizeWeeksRemaining (descending)
- cumulativePrizeValue (descending)
```

---

## BR Transactions Collection (NEW)

### Path: `br_transactions/{transactionId}`

Track all BR currency movements for transparency and debugging.

```json
{
  "userId": "string",                      // User who performed transaction
  "type": "string",                        // "earn" or "spend"
  "source": "string",                      // Where BR came from/went to
  "amount": 0,                             // BR amount (positive number)
  "balanceBefore": 0,                      // Balance before transaction
  "balanceAfter": 0,                       // Balance after transaction
  "timestamp": "Timestamp",                // When transaction occurred
  "metadata": {}                           // Additional context (optional)
}
```

### Transaction Source Types

**Earn Sources:**
- `daily_bonus` - 50 BR daily login
- `streak_bonus` - 100 BR at 7-day streak
- `referral` - 200 BR for successful referral
- `ad_watch` - 25 BR per video ad (max 5/day)
- `achievement` - Achievement completion bonus
- `admin_grant` - Manual admin adjustment

**Spend Sources:**
- `pool_entry` - Joined a betting pool
- `admin_deduct` - Manual admin adjustment

### Example Documents

```json
// Daily bonus transaction
{
  "userId": "user123",
  "type": "earn",
  "source": "daily_bonus",
  "amount": 50,
  "balanceBefore": 100,
  "balanceAfter": 150,
  "timestamp": "2025-01-06T10:30:00Z",
  "metadata": {
    "streak": 3,
    "loginDate": "2025-01-06"
  }
}

// Pool entry transaction
{
  "userId": "user123",
  "type": "spend",
  "source": "pool_entry",
  "amount": 100,
  "balanceBefore": 150,
  "balanceAfter": 50,
  "timestamp": "2025-01-06T14:20:00Z",
  "metadata": {
    "poolId": "pool456",
    "gameId": "game789"
  }
}

// Referral bonus transaction
{
  "userId": "user123",
  "type": "earn",
  "source": "referral",
  "amount": 200,
  "balanceBefore": 50,
  "balanceAfter": 250,
  "timestamp": "2025-01-06T16:45:00Z",
  "metadata": {
    "referredUserId": "user456",
    "referredUsername": "JohnDoe"
  }
}
```

### Firestore Indexes for BR Transactions

```
br_transactions collection:
- userId (ascending) + timestamp (descending)
- type (ascending) + timestamp (descending)
- source (ascending) + timestamp (descending)
```

---

## Subscriptions Collection (NEW - Phase 2)

### Path: `subscriptions/{subscriptionId}`

Track subscription lifecycle and payments.

```json
{
  "userId": "string",                      // User who owns subscription
  "status": "string",                      // "active", "trial", "expired", "cancelled", "prize"
  "type": "string",                        // "monthly" ($1.99), "annual" ($19.99), "prize"
  "platform": "string",                    // "apple", "google"
  "productId": "string",                   // IAP product ID
  "originalTransactionId": "string",       // Apple/Google receipt ID
  "startDate": "Timestamp",                // Subscription start
  "endDate": "Timestamp",                  // When subscription expires
  "trialEndDate": "Timestamp | null",      // 7-day trial end (if applicable)
  "autoRenew": true,                       // Auto-renewal enabled
  "cancelledAt": "Timestamp | null",       // When user cancelled
  "lastVerified": "Timestamp",             // Last receipt verification
  "prizeSource": "string | null",          // "competition_win" if from prize
  "prizeWeeks": 0,                         // Number of weeks awarded
  "autoSubscribeAfterPrize": false,        // Convert to paid after prize
  "reminderSent": false,                   // 7-day reminder sent (if autoSubscribe = false)
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### Subscription Status Values

- `trial` - User in 7-day free trial
- `active` - Paid subscription active
- `prize` - Free weeks from competition win
- `expired` - Subscription ended, not renewed
- `cancelled` - User cancelled, runs until endDate

### Firestore Indexes for Subscriptions

```
subscriptions collection:
- userId (ascending) + status (ascending)
- status (ascending) + endDate (ascending)
- autoSubscribeAfterPrize (ascending) + endDate (ascending) + reminderSent (ascending)
```

---

## Prizes Collection (NEW - Phase 3)

### Path: `prizes/{prizeId}`

Track all prize awards and redemptions.

```json
{
  "userId": "string",                      // Winner
  "username": "string",                    // Winner's display name
  "competitionId": "string",               // Which competition they won
  "competitionMonth": "string",            // "2025-01" format
  "rank": 0,                               // Placement (1-10)
  "prizeType": "string",                   // "subscription_weeks"
  "prizeValue": 0.0,                       // Dollar value (e.g., 11.94 for 6 weeks)
  "prizeWeeks": 0,                         // Number of weeks awarded (1-6 MAX)
  "status": "string",                      // "pending", "active", "expired", "converted"
  "awardedAt": "Timestamp",                // When prize was awarded
  "claimedAt": "Timestamp | null",         // When user accepted prize
  "startDate": "Timestamp | null",         // Prize period start
  "endDate": "Timestamp | null",           // Prize period end
  "autoSubscribeAfterPrize": false,        // User's choice from popup
  "reminderSent": false,                   // 7-day reminder sent
  "convertedToPaid": false,                // Auto-subscribed after expiry
  "convertedAt": "Timestamp | null",       // When converted
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### Prize Status Values

- `pending` - Awarded but not claimed
- `active` - Prize period active (free premium)
- `expired` - Prize period ended, no conversion
- `converted` - Converted to paid subscription

### Prize Weeks Constraint

**CRITICAL:** `prizeWeeks` field MUST enforce:
- MIN: 1 week
- MAX: 6 weeks
- No prize can ever exceed 6 weeks ($11.94 value)

### Firestore Indexes for Prizes

```
prizes collection:
- userId (ascending) + status (ascending)
- status (ascending) + endDate (ascending)
- competitionId (ascending) + rank (ascending)
- autoSubscribeAfterPrize (ascending) + endDate (ascending)
```

---

## Competitions Collection (NEW - Phase 3)

### Path: `competitions/{competitionId}`

Monthly skill-based competitions.

```json
{
  "type": "string",                        // "monthly_premium"
  "title": "string",                       // "January 2025 Premium Challenge"
  "description": "string",                 // Competition details
  "status": "string",                      // "upcoming", "active", "completed"
  "startDate": "Timestamp",                // Competition start
  "endDate": "Timestamp",                  // Competition end
  "entryRequirements": {
    "isPremium": true,                     // Must be premium subscriber
    "minPools": 10                         // Must enter 10+ pools
  },
  "prizes": [
    {
      "rank": 1,
      "prizeType": "subscription_weeks",
      "weeks": 6,
      "value": 11.94
    },
    {
      "rank": 2,
      "prizeType": "subscription_weeks",
      "weeks": 4,
      "value": 7.96
    },
    {
      "rank": 3,
      "prizeType": "subscription_weeks",
      "weeks": 2,
      "value": 3.98
    },
    {
      "rank": 4,
      "prizeType": "subscription_weeks",
      "weeks": 1,
      "value": 1.99
    }
    // ... ranks 5-10 also get 1 week
  ],
  "totalParticipants": 0,                  // Count of eligible users
  "winnersAnnounced": false,               // Winners selected
  "winnersAnnouncedAt": "Timestamp | null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### Firestore Indexes for Competitions

```
competitions collection:
- status (ascending) + startDate (descending)
- type (ascending) + status (ascending)
```

---

## Leaderboards Collection (NEW - Phase 3)

### Path: `leaderboards/{competitionId}/entries/{userId}`

Track competition standings.

```json
{
  "userId": "string",
  "username": "string",
  "score": 0.0,                            // Total skill score
  "correctPicks": 0,                       // Number of correct picks
  "totalPicks": 0,                         // Total picks made
  "poolsEntered": 0,                       // Number of pools entered
  "qualified": false,                      // Met minimum requirements
  "rank": 0,                               // Current ranking
  "submittedAt": "Timestamp",              // First entry timestamp (tiebreaker)
  "lastUpdated": "Timestamp"               // Last score update
}
```

### Firestore Indexes for Leaderboards

```
leaderboards/{competitionId}/entries subcollection:
- qualified (descending) + score (descending) + submittedAt (ascending)
- rank (ascending)
```

---

## Achievements Collection (NEW - Week 5)

### Path: `achievements/{achievementId}`

Define available achievements and rewards.

```json
{
  "id": "string",                          // "first_win", "hot_streak", etc.
  "title": "string",                       // "First Win"
  "description": "string",                 // "Win your first pool"
  "icon": "string",                        // Icon identifier
  "rewardBR": 0,                           // BR currency reward
  "requirements": {
    "type": "string",                      // "pool_win", "streak", "picks", etc.
    "count": 0                             // Target count
  },
  "isActive": true,                        // Available to earn
  "createdAt": "Timestamp"
}
```

### Path: `users/{userId}/achievements/{achievementId}`

Track user achievement progress.

```json
{
  "achievementId": "string",
  "userId": "string",
  "progress": 0,                           // Current progress toward goal
  "target": 0,                             // Goal (from achievement definition)
  "completed": false,                      // Achievement unlocked
  "completedAt": "Timestamp | null",       // When unlocked
  "rewardClaimed": false,                  // BR reward claimed
  "rewardClaimedAt": "Timestamp | null"
}
```

---

## Firebase Security Rules

### Rules for BR Transactions

```javascript
match /br_transactions/{transactionId} {
  // Users can only read their own transactions
  allow read: if request.auth != null &&
                 request.auth.uid == resource.data.userId;

  // Only server/cloud functions can write transactions
  allow write: if false;
}
```

### Rules for Subscriptions

```javascript
match /subscriptions/{subscriptionId} {
  // Users can read their own subscriptions
  allow read: if request.auth != null &&
                 request.auth.uid == resource.data.userId;

  // Only server can write subscriptions
  allow write: if false;
}
```

### Rules for Prizes

```javascript
match /prizes/{prizeId} {
  // Users can read their own prizes
  allow read: if request.auth != null &&
                 request.auth.uid == resource.data.userId;

  // Users can update autoSubscribeAfterPrize when claiming
  allow update: if request.auth != null &&
                   request.auth.uid == resource.data.userId &&
                   request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['autoSubscribeAfterPrize', 'claimedAt', 'updatedAt']);

  // Only server can create prizes
  allow create: if false;
}
```

### Rules for Competitions

```javascript
match /competitions/{competitionId} {
  // Anyone can read active competitions
  allow read: if true;

  // Only server can write competitions
  allow write: if false;
}
```

### Rules for Leaderboards

```javascript
match /leaderboards/{competitionId}/entries/{userId} {
  // Anyone can read leaderboard entries
  allow read: if true;

  // Only server can write entries
  allow write: if false;
}
```

---

## Cloud Functions Required

### Daily Scheduled Functions

1. **resetDailyAdCounters** - Reset `adsWatchedToday` at midnight
2. **checkLoginStreaks** - Reset streaks for users who didn't login
3. **checkSubscriptionStatus** - Verify subscriptions with Apple/Google
4. **checkPrizeExpiry** - Monitor prize periods and send reminders
5. **convertExpiredPrizes** - Auto-subscribe users with autoSubscribeAfterPrize = true

### Event-Triggered Functions

1. **onUserCreate** - Initialize BR balance, generate referral code
2. **onPoolJoin** - Deduct BR currency, create transaction
3. **onPoolWin** - Award achievement progress
4. **onPrizeAward** - Create prize document, send notification
5. **onSubscriptionChange** - Update user isPremium status

---

## Migration Steps

### Phase 1 (Week 2): BR Currency

1. Add BR fields to existing users collection
2. Create br_transactions collection
3. Set up Cloud Function: onUserCreate
4. Set up Cloud Function: resetDailyAdCounters
5. Set up Cloud Function: checkLoginStreaks
6. Update Firebase Security Rules

### Phase 2 (Week 7): Subscriptions

1. Create subscriptions collection
2. Add subscription fields to users
3. Set up Cloud Function: checkSubscriptionStatus
4. Set up Cloud Function: onSubscriptionChange
5. Update Firebase Security Rules

### Phase 3 (Week 13): Competitions & Prizes

1. Create prizes collection
2. Create competitions collection
3. Create leaderboards collection
4. Create achievements collection
5. Set up Cloud Functions: prize management
6. Update Firebase Security Rules
