# Achievements System Schema

## Firestore Collection: `achievements`

Each document represents a specific achievement that users can earn.

### Document Structure

```javascript
{
  "id": "first_pool",  // Unique achievement ID
  "name": "First Pool Entry",  // Display name
  "description": "Join your first pool",  // What user needs to do
  "category": "pools",  // Category: pools, picks, streaks, social, special
  "tier": "bronze",  // Difficulty: bronze, silver, gold, platinum
  "brReward": 50,  // BR reward for completing
  "iconName": "pool_circle",  // Icon identifier
  "requirements": {
    "type": "pool_join_count",  // Type of achievement
    "count": 1  // Number required
  },
  "isActive": true,  // Can users earn this?
  "isRepeatable": false,  // Can earn multiple times?
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

## Firestore Collection: `user_achievements`

Tracks which achievements each user has earned.

### Document ID Format: `{userId}_{achievementId}`

```javascript
{
  "userId": "abc123",
  "achievementId": "first_pool",
  "earnedAt": Timestamp,
  "progress": 1,  // Current progress (for multi-step achievements)
  "claimed": true,  // Has user claimed the reward?
  "claimedAt": Timestamp,  // When reward was claimed
  "brRewarded": 50  // Amount of BR given
}
```

## Initial Achievements List

### 🎯 Pool Achievements
| ID | Name | Description | Tier | BR Reward | Requirements |
|----|------|-------------|------|-----------|--------------|
| `first_pool` | First Pool Entry | Join your first pool | Bronze | 50 | Join 1 pool |
| `pool_regular` | Pool Regular | Join 10 pools | Silver | 100 | Join 10 pools |
| `pool_veteran` | Pool Veteran | Join 50 pools | Gold | 250 | Join 50 pools |
| `pool_legend` | Pool Legend | Join 100 pools | Platinum | 500 | Join 100 pools |

### 🏆 Picks Achievements
| ID | Name | Description | Tier | BR Reward | Requirements |
|----|------|-------------|------|-----------|--------------|
| `first_win` | First Win | Win your first pool | Bronze | 100 | Win 1 pool |
| `winning_streak_3` | Hot Streak | Win 3 pools in a row | Silver | 200 | Win 3 consecutive |
| `winning_streak_5` | On Fire | Win 5 pools in a row | Gold | 400 | Win 5 consecutive |
| `perfect_week` | Perfect Week | Win all pools in a week | Gold | 500 | 100% win rate for 7 days |
| `underdog_king` | Underdog King | Win 10 pools with underdog picks | Silver | 300 | Win 10 with underdog bonus |

### 📅 Streak Achievements
| ID | Name | Description | Tier | BR Reward | Requirements |
|----|------|-------------|------|-----------|--------------|
| `login_streak_3` | Engaged Fan | Login 3 days in a row | Bronze | 50 | 3-day streak |
| `login_streak_7` | Weekly Warrior | Login 7 days in a row | Silver | 150 | 7-day streak |
| `login_streak_30` | Monthly Master | Login 30 days in a row | Gold | 500 | 30-day streak |
| `login_streak_100` | Century Club | Login 100 days in a row | Platinum | 1000 | 100-day streak |

### 👥 Social Achievements
| ID | Name | Description | Tier | BR Reward | Requirements |
|----|------|-------------|------|-----------|--------------|
| `first_referral` | Influencer | Refer your first friend | Bronze | 200 | 1 referral |
| `referral_master` | Referral Master | Refer 5 friends | Silver | 500 | 5 referrals |
| `pool_creator` | Pool Creator | Create your first private pool | Bronze | 100 | Create 1 pool |
| `tournament_host` | Tournament Host | Host a pool with 10+ players | Silver | 300 | Create pool with 10+ |

### ⭐ Special Achievements
| ID | Name | Description | Tier | BR Reward | Requirements |
|----|------|-------------|------|-----------|--------------|
| `early_adopter` | Early Adopter | Join during beta | Platinum | 1000 | Sign up before launch |
| `first_week` | First Week | Complete 5 pools in first week | Silver | 250 | 5 pools in 7 days |
| `high_roller` | High Roller | Join a pool with 100+ BR buy-in | Gold | 200 | Join high-stakes pool |
| `comeback_kid` | Comeback Kid | Win after being in last place | Silver | 200 | Win from last place |

## Achievement Types

```javascript
// requirement.type can be:
"pool_join_count"       // Number of pools joined
"pool_win_count"        // Number of pools won
"win_streak"            // Consecutive wins
"login_streak"          // Consecutive daily logins
"referral_count"        // Number of successful referrals
"pool_create_count"     // Number of pools created
"underdog_win_count"    // Wins with underdog bonus
"high_stakes_join"      // Join pool with min buy-in
"perfect_week"          // 100% win rate for 7 days
"early_signup"          // Sign up before date
"first_week_pools"      // Complete N pools in first 7 days
```

## Achievement Categories

- **pools**: Pool participation achievements
- **picks**: Winning and pick strategy achievements
- **streaks**: Login and consistency achievements
- **social**: Referral and community achievements
- **special**: Unique/time-limited achievements

## Achievement Tiers

- **Bronze**: Easy to achieve, small rewards (50-100 BR)
- **Silver**: Moderate effort, medium rewards (150-300 BR)
- **Gold**: Challenging, large rewards (400-500 BR)
- **Platinum**: Very rare, exceptional rewards (1000+ BR)

## Progress Tracking

User progress is tracked in real-time through:

1. **Pool Service**: Tracks pool joins, wins, creation
2. **BR Currency Service**: Tracks login streaks
3. **Referral Service**: Tracks successful referrals
4. **Scoring Service**: Tracks underdog wins, streaks

When a tracked event occurs, the achievement service checks if any achievements are newly completed and awards BR accordingly.

## Firestore Security Rules

```javascript
match /achievements/{achievementId} {
  allow read: if request.auth != null;
  allow write: if false;  // Only admin can create/modify achievements
}

match /user_achievements/{userAchievementId} {
  allow read: if request.auth != null &&
                 userAchievementId.matches(request.auth.uid + '_.*');
  allow write: if false;  // Only server/cloud functions can award achievements
}
```

## Cloud Functions

### `onPoolJoined` Trigger
- Checks pool join count achievements
- Awards BR for first pool, 10 pools, etc.

### `onPoolWon` Trigger
- Checks win count achievements
- Checks win streak achievements
- Checks underdog win achievements

### `onDailyLogin` Trigger
- Checks login streak achievements
- Awards BR for 3, 7, 30, 100 day streaks

### `onReferralComplete` Trigger
- Checks referral count achievements
- Awards BR for first referral, 5 referrals, etc.

## Implementation Notes

1. **Idempotent**: Achievement awards should be idempotent (check if already earned)
2. **Atomic**: Use transactions to prevent double-rewarding
3. **Notifications**: Show toast/modal when achievement is earned
4. **History**: Keep permanent record in user_achievements
5. **Icons**: Use Flutter Icons or custom SVGs for achievement badges
6. **Display**: Show progress bars for multi-step achievements
