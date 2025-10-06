# Technical Implementation Guide - Freemium Model

**Document Purpose:** Complete technical requirements for implementing the freemium model

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Database Schema Changes](#database-schema-changes)
3. [Phase 1: Free Tier Implementation](#phase-1-free-tier-implementation)
4. [Phase 2: Premium Tier Implementation](#phase-2-premium-tier-implementation)
5. [Phase 3: Competition System](#phase-3-competition-system)
6. [Testing Requirements](#testing-requirements)
7. [Deployment Checklist](#deployment-checklist)

---

## Phase Overview

### Timeline

| Phase | Duration | Features | Status |
|-------|----------|----------|--------|
| Phase 1 | Weeks 1-6 | Free tier, simple scoring, BR economy | Not Started |
| Phase 2 | Weeks 7-12 | Premium subscription, odds integration | Not Started |
| Phase 3 | Weeks 13-18 | Competitions, prizes, leaderboards | Not Started |
| Phase 4 | Weeks 19-24 | Polish, optimization, scale testing | Not Started |

---

## Database Schema Changes

### Firestore Collections

#### 1. `users` Collection (Updates)

```dart
// Add these fields to existing user documents
{
  // Existing fields...

  // BR Currency
  'brBalance': 0,                    // int - current BR balance
  'brLifetimeEarned': 0,             // int - total BR earned (free)
  'brLifetimePurchased': 0,          // int - total BR purchased
  'brLifetimeSpent': 0,              // int - total BR spent on pools

  // Premium Subscription
  'subscriptionTier': 'free',        // 'free' | 'premium'
  'subscriptionStatus': 'none',      // 'none' | 'active' | 'trial' | 'cancelled' | 'expired'
  'subscriptionStartDate': null,     // Timestamp or null
  'subscriptionEndDate': null,       // Timestamp or null
  'subscriptionPlatform': null,      // 'apple' | 'google' | null
  'subscriptionProductId': null,     // String - store product ID
  'trialUsed': false,                // bool - has user used free trial

  // Engagement Tracking
  'lastLoginDate': Timestamp,        // Timestamp - for daily bonus
  'loginStreak': 0,                  // int - consecutive days
  'lastBonusClaimed': null,          // Timestamp or null

  // Prize Tracking
  'lifetimePrizesWon': 0.0,          // double - cumulative prize value (for tax reporting)
  'prizesWonThisYear': 0.0,          // double - reset Jan 1st
  'taxReportingRequired': false,     // bool - if > $600 this year
  'w9Submitted': false,              // bool - for tax reporting
}
```

#### 2. `br_transactions` Collection (New)

```dart
// Document ID: auto-generated
{
  'userId': 'user_id',
  'type': 'earn' | 'purchase' | 'spend' | 'prize' | 'refund',
  'amount': 50,                      // int - BR amount (positive or negative)
  'balanceAfter': 150,               // int - balance after transaction
  'source': 'daily_login' | 'referral' | 'purchase' | 'pool_entry' | 'prize' | 'achievement',
  'sourceId': 'pool_id' | 'achievement_id' | 'purchase_id',  // optional
  'metadata': {
    'description': 'Daily login bonus',
    'purchaseAmount': 0.99,          // if purchase
    'platform': 'apple',             // if purchase
  },
  'timestamp': FieldValue.serverTimestamp(),
  'createdAt': FieldValue.serverTimestamp(),
}

// Indexes needed:
// - userId + timestamp (descending)
// - userId + type + timestamp
```

#### 3. `subscriptions` Collection (New)

```dart
// Document ID: userId
{
  'userId': 'user_id',
  'tier': 'free' | 'premium',
  'status': 'active' | 'trial' | 'cancelled' | 'expired' | 'paused',

  // Current subscription
  'currentPeriodStart': Timestamp,
  'currentPeriodEnd': Timestamp,
  'autoRenew': true,

  // Platform details
  'platform': 'apple' | 'google',
  'productId': 'com.braggingright.premium.monthly',
  'originalTransactionId': 'store_transaction_id',
  'latestReceiptData': 'encrypted_receipt',  // for verification

  // Billing
  'billingCycle': 'monthly' | 'annual',
  'priceAtPurchase': 1.99,
  'currency': 'USD',

  // Extensions (prizes)
  'extensionMonths': 0,              // int - free months from prizes
  'extensionAppliedDate': null,      // Timestamp - when extension was added
  'extensionExpiryDate': null,       // Timestamp - when extension ends

  // History
  'subscriptionHistory': [
    {
      'action': 'started' | 'renewed' | 'cancelled' | 'extended' | 'expired',
      'timestamp': Timestamp,
      'reason': 'user_action' | 'prize' | 'payment_failed',
      'metadata': {},
    }
  ],

  // Timestamps
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}

// Indexes needed:
// - userId (unique)
// - status + currentPeriodEnd
```

#### 4. `prizes` Collection (New)

```dart
// Document ID: auto-generated
{
  'prizeId': 'prize_id',
  'userId': 'user_id',
  'competitionId': 'competition_id',
  'competitionType': 'monthly_premium' | 'seasonal' | 'special_event',

  // Prize details
  'prizeType': 'subscription_extension' | 'br_currency' | 'premium_trial',
  'prizeValue': 23.88,               // double - for tax reporting
  'description': '12-month premium extension',

  // For subscription extensions
  'extensionMonths': 12,             // int or null

  // For BR prizes
  'brAmount': 0,                     // int or 0

  // Status
  'status': 'pending' | 'claimed' | 'forfeited' | 'revoked',
  'awardedDate': Timestamp,
  'claimedDate': null,               // Timestamp or null
  'expiryDate': Timestamp,           // 14 days after awarded

  // Verification
  'verificationRequired': false,
  'verificationStatus': 'none' | 'pending' | 'approved' | 'rejected',
  'verificationDocuments': [],

  // Tax tracking
  'taxableValue': 23.88,
  'taxYear': 2025,
  'includedIn1099': false,

  // Metadata
  'rank': 1,                         // placement in competition
  'score': 45.5,                     // user's score
  'totalParticipants': 150,

  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}

// Indexes needed:
// - userId + taxYear
// - userId + status + awardedDate
// - competitionId + rank
```

#### 5. `competitions` Collection (New)

```dart
// Document ID: competition_id (e.g., 'premium_2025_01')
{
  'competitionId': 'premium_2025_01',
  'name': 'January 2025 Premium Challenge',
  'type': 'monthly_premium' | 'seasonal' | 'special_event',

  // Eligibility
  'eligibility': {
    'requiresPremium': true,
    'minimumPicks': 10,              // minimum pools to qualify
    'ageRestriction': 18,
  },

  // Timing
  'startDate': Timestamp,
  'endDate': Timestamp,
  'winnerAnnouncementDate': Timestamp,

  // Prizes
  'prizes': [
    {
      'rank': 1,
      'prizeType': 'subscription_extension',
      'extensionMonths': 12,
      'value': 23.88,
      'description': '1st Place: 12-month premium extension',
    },
    {
      'rank': 2,
      'prizeType': 'subscription_extension',
      'extensionMonths': 6,
      'value': 11.94,
      'description': '2nd Place: 6-month premium extension',
    },
    // ... more prizes
  ],

  // Status
  'status': 'upcoming' | 'active' | 'ended' | 'winners_announced' | 'prizes_distributed',

  // Participants
  'totalParticipants': 0,
  'qualifiedParticipants': 0,        // met minimum requirements

  // Winners
  'winners': [
    {
      'userId': 'user_id',
      'rank': 1,
      'score': 45.5,
      'prizeId': 'prize_id',
      'notificationSent': true,
      'prizeClaimed': false,
    }
  ],

  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}

// Indexes needed:
// - type + status + endDate
// - startDate + endDate
```

#### 6. `leaderboards` Collection (New)

```dart
// Document ID: {competitionId}_{userId}
{
  'competitionId': 'premium_2025_01',
  'userId': 'user_id',
  'username': 'user_display_name',

  // Performance
  'score': 45.5,
  'totalPicks': 25,
  'correctPicks': 18,
  'accuracy': 0.72,
  'poolsEntered': 15,
  'rank': 1,                         // current rank
  'rankLastUpdated': Timestamp,

  // Qualification
  'qualifies': true,                 // meets minimum requirements
  'disqualified': false,
  'disqualificationReason': null,

  // Timestamps
  'lastPickDate': Timestamp,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}

// Indexes needed:
// - competitionId + score (descending)
// - competitionId + qualifies + score (descending)
// - userId + competitionId
```

#### 7. `achievements` Collection (New)

```dart
// Document ID: auto-generated
{
  'achievementId': 'first_win',
  'name': 'First Victory',
  'description': 'Win your first pool',
  'icon': 'trophy',
  'category': 'wins' | 'streaks' | 'accuracy' | 'participation',

  // Rewards
  'brReward': 100,
  'badgeIcon': 'url_to_badge',

  // Requirements
  'requirement': {
    'type': 'pool_wins',
    'count': 1,
  },

  // Visibility
  'active': true,
  'displayOrder': 1,

  'createdAt': FieldValue.serverTimestamp(),
}

// User achievements tracking in users/{userId}/achievements subcollection
{
  'achievementId': 'first_win',
  'unlockedDate': Timestamp,
  'progress': 1,
  'total': 1,
  'claimed': true,                   // has user claimed BR reward
}
```

---

## Phase 1: Free Tier Implementation

### 1.1 Gate Odds Behind Subscription Status (Permanent Implementation)

**File:** `lib/services/game_odds_enrichment_service.dart`

```dart
import 'subscription_service.dart'; // Add this import

class GameOddsEnrichmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OddsApiService _oddsService = OddsApiService();
  final PoolAutoGenerator _poolGenerator = PoolAutoGenerator();
  final FreeOddsService _freeOddsService = FreeOddsService();
  final SubscriptionService _subscriptionService = SubscriptionService(); // Add this

  // ... existing code

  /// Enrich a game with odds data and create pools
  /// Only premium/prize users get odds
  Future<void> enrichGameWithOdds(GameModel game, {String? userId}) async {
    try {
      // PREMIUM GATE - Only premium users get odds
      if (userId != null) {
        final isPremium = await _subscriptionService.isPremium(userId);
        if (!isPremium) {
          debugPrint('⏸️ User not premium - odds restricted to premium tier');
          return;
        }
      }

      // ALL EXISTING ODDS CODE UNCHANGED
      debugPrint('🎲 ========== ENRICH GAME WITH ODDS CALLED ==========');
      // ... rest stays the same
    } catch (e) {
      debugPrint('Error enriching game with odds: $e');
    }
  }
}
```

**Note:** Build SubscriptionService first (Phase 2), then add this gate.

---

### 1.2 Implement Simple Scoring for All Sports

**File:** `lib/services/simple_pick_scoring.dart` (Update existing)

```dart
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

/// Enhanced simple pick scoring with record-based underdog bonuses
class SimplePickScoring {
  /// Calculate user's score for simple picks with underdog bonuses
  static double calculateScore({
    required List<SimplePick> picks,
    required List<GameResult> results,
  }) {
    double totalScore = 0;

    for (final pick in picks) {
      final result = results.firstWhere(
        (r) => r.gameId == pick.gameId,
        orElse: () => GameResult.empty(),
      );

      // Skip if game not completed
      if (!result.isCompleted) continue;

      // Check if pick was correct
      if (pick.pickedTeam == result.winningTeam) {
        // Base point for correct pick
        double score = 1.0;

        // Apply confidence multiplier (1-5 stars)
        if (pick.confidence != null) {
          // Formula: 0.9x to 1.3x based on confidence
          final confidenceMultiplier = 0.8 + (pick.confidence! * 0.1);
          score *= confidenceMultiplier;
        }

        // Apply underdog bonus (NEW)
        if (result.underdogBonus != null) {
          score += result.underdogBonus!;
        }

        totalScore += score;
      }
    }

    return totalScore;
  }

  /// Calculate underdog bonus from team records
  static double calculateUnderdogBonus({
    required String pickedTeam,
    required String opponentTeam,
    required GameModel game,
  }) {
    // Determine which team was picked
    final pickedHome = pickedTeam == game.homeTeam;

    // Get team records (wins-losses)
    final pickedRecord = pickedHome ? game.homeTeamRecord : game.awayTeamRecord;
    final opponentRecord = pickedHome ? game.awayTeamRecord : game.homeTeamRecord;

    if (pickedRecord == null || opponentRecord == null) {
      return 0.0; // No record data available
    }

    // Parse records (e.g., "10-5" -> 10 wins, 5 losses)
    final pickedWins = _parseWins(pickedRecord);
    final opponentWins = _parseWins(opponentRecord);

    if (pickedWins == null || opponentWins == null) {
      return 0.0; // Couldn't parse records
    }

    // Underdog bonus formula: (opponentWins - pickedWins) / 20
    // Example: Picking 3-7 team over 8-2 team = (8 - 3) / 20 = 0.25 bonus
    // Example: Picking 8-2 team over 3-7 team = (3 - 8) / 20 = -0.25 (capped at 0)
    final bonus = (opponentWins - pickedWins) / 20.0;

    // Cap bonus at 0 (no penalty for picking favorite)
    return bonus > 0 ? bonus : 0.0;
  }

  /// Parse win count from record string (e.g., "10-5" -> 10)
  static int? _parseWins(String record) {
    try {
      final parts = record.split('-');
      if (parts.isEmpty) return null;
      return int.parse(parts[0].trim());
    } catch (e) {
      debugPrint('Error parsing record: $record');
      return null;
    }
  }

  /// Calculate payouts for simple pick pools (unchanged)
  static Map<String, int> distributePrizePool({
    required List<UserScore> rankings,
    required int totalPool,
    required int minPayout,
  }) {
    // ... existing implementation
  }
}

// Update GameResult class to include underdog bonus
class GameResult {
  final String gameId;
  final String? winningTeam;
  final bool isCompleted;
  final double? underdogBonus;  // NEW

  GameResult({
    required this.gameId,
    this.winningTeam,
    required this.isCompleted,
    this.underdogBonus,
  });

  factory GameResult.empty() => GameResult(
    gameId: '',
    isCompleted: false,
  );

  factory GameResult.fromGameModel(GameModel game, String pickedTeam) {
    // Determine winner
    String? winner;
    if (game.homeScore != null && game.awayScore != null) {
      if (game.homeScore! > game.awayScore!) {
        winner = game.homeTeam;
      } else if (game.awayScore! > game.homeScore!) {
        winner = game.awayTeam;
      }
    }

    // Calculate underdog bonus
    final bonus = SimplePickScoring.calculateUnderdogBonus(
      pickedTeam: pickedTeam,
      opponentTeam: pickedTeam == game.homeTeam ? game.awayTeam : game.homeTeam,
      game: game,
    );

    return GameResult(
      gameId: game.id,
      winningTeam: winner,
      isCompleted: game.status == 'final',
      underdogBonus: bonus,
    );
  }
}
```

**Add team record fields to GameModel:**

**File:** `lib/models/game_model.dart`

```dart
class GameModel {
  // ... existing fields

  final String? homeTeamRecord;  // e.g., "10-5"
  final String? awayTeamRecord;  // e.g., "8-7"
  final int? homeTeamRanking;    // optional: AP/Coach poll ranking
  final int? awayTeamRanking;

  GameModel({
    // ... existing parameters
    this.homeTeamRecord,
    this.awayTeamRecord,
    this.homeTeamRanking,
    this.awayTeamRanking,
  });

  // Update fromMap and toMap methods
}
```

---

### 1.3 Implement BR Currency System

**Create:** `lib/services/br_currency_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BRCurrencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int DAILY_LOGIN_BONUS = 50;
  static const int REFERRAL_BONUS = 200;
  static const int VIDEO_AD_BONUS = 25;
  static const int VIDEO_AD_DAILY_LIMIT = 5;
  static const int WEEKLY_STREAK_BONUS = 100;

  /// Get user's current BR balance
  Future<int> getBalance(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data()?['brBalance'] ?? 0;
  }

  /// Check if user can claim daily bonus
  Future<bool> canClaimDailyBonus(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final lastClaimed = userDoc.data()?['lastBonusClaimed'] as Timestamp?;

    if (lastClaimed == null) return true;

    final now = DateTime.now();
    final lastClaimedDate = lastClaimed.toDate();

    // Check if it's a new day
    return now.day != lastClaimedDate.day ||
           now.month != lastClaimedDate.month ||
           now.year != lastClaimedDate.year;
  }

  /// Claim daily login bonus
  Future<int> claimDailyBonus(String userId) async {
    if (!await canClaimDailyBonus(userId)) {
      throw Exception('Daily bonus already claimed today');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final userData = userDoc.data()!;

    final currentBalance = userData['brBalance'] ?? 0;
    final lastLoginDate = (userData['lastLoginDate'] as Timestamp?)?.toDate();
    final currentStreak = userData['loginStreak'] ?? 0;

    // Calculate new streak
    int newStreak = 1;
    if (lastLoginDate != null) {
      final daysSinceLastLogin = DateTime.now().difference(lastLoginDate).inDays;
      if (daysSinceLastLogin == 1) {
        // Consecutive day
        newStreak = currentStreak + 1;
      }
    }

    // Base bonus
    int bonusAmount = DAILY_LOGIN_BONUS;

    // Weekly streak bonus (7 days)
    if (newStreak >= 7 && newStreak % 7 == 0) {
      bonusAmount += WEEKLY_STREAK_BONUS;
      debugPrint('🔥 Weekly streak bonus! +$WEEKLY_STREAK_BONUS BR');
    }

    final newBalance = currentBalance + bonusAmount;

    // Update user document
    await userRef.update({
      'brBalance': newBalance,
      'brLifetimeEarned': FieldValue.increment(bonusAmount),
      'lastLoginDate': FieldValue.serverTimestamp(),
      'lastBonusClaimed': FieldValue.serverTimestamp(),
      'loginStreak': newStreak,
    });

    // Record transaction
    await _recordTransaction(
      userId: userId,
      type: 'earn',
      amount: bonusAmount,
      balanceAfter: newBalance,
      source: 'daily_login',
      metadata: {
        'description': 'Daily login bonus',
        'streak': newStreak,
      },
    );

    debugPrint('✅ Daily bonus claimed: +$bonusAmount BR (Streak: $newStreak)');
    return bonusAmount;
  }

  /// Watch video ad for BR
  Future<int> claimVideoAdBonus(String userId) async {
    // Check daily limit
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final adsWatchedToday = await _firestore
        .collection('br_transactions')
        .where('userId', isEqualTo: userId)
        .where('source', isEqualTo: 'video_ad')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    if (adsWatchedToday.docs.length >= VIDEO_AD_DAILY_LIMIT) {
      throw Exception('Daily video ad limit reached (5/day)');
    }

    return await _addBR(
      userId: userId,
      amount: VIDEO_AD_BONUS,
      source: 'video_ad',
      description: 'Watched video advertisement',
    );
  }

  /// Referral bonus (when referred friend completes profile)
  Future<int> claimReferralBonus(String userId, String referredUserId) async {
    return await _addBR(
      userId: userId,
      amount: REFERRAL_BONUS,
      source: 'referral',
      sourceId: referredUserId,
      description: 'Friend referral bonus',
    );
  }

  /// Achievement unlock bonus
  Future<int> claimAchievementBonus(
    String userId,
    String achievementId,
    int brAmount,
  ) async {
    return await _addBR(
      userId: userId,
      amount: brAmount,
      source: 'achievement',
      sourceId: achievementId,
      description: 'Achievement unlocked',
    );
  }

  /// Spend BR (for pool entry)
  Future<bool> spendBR({
    required String userId,
    required int amount,
    required String poolId,
  }) async {
    final currentBalance = await getBalance(userId);

    if (currentBalance < amount) {
      throw Exception('Insufficient BR balance');
    }

    final newBalance = currentBalance - amount;

    // Update balance
    await _firestore.collection('users').doc(userId).update({
      'brBalance': newBalance,
      'brLifetimeSpent': FieldValue.increment(amount),
    });

    // Record transaction
    await _recordTransaction(
      userId: userId,
      type: 'spend',
      amount: -amount,
      balanceAfter: newBalance,
      source: 'pool_entry',
      sourceId: poolId,
      metadata: {
        'description': 'Pool entry fee',
        'poolId': poolId,
      },
    );

    debugPrint('💸 Spent $amount BR on pool $poolId');
    return true;
  }

  /// Purchase BR with real money (handled by IAP, this just records it)
  Future<int> recordBRPurchase({
    required String userId,
    required int brAmount,
    required double purchaseAmount,
    required String transactionId,
    required String platform,
  }) async {
    return await _addBR(
      userId: userId,
      amount: brAmount,
      source: 'purchase',
      sourceId: transactionId,
      description: 'BR purchase',
      metadata: {
        'purchaseAmount': purchaseAmount,
        'platform': platform,
        'transactionId': transactionId,
      },
      isPurchase: true,
    );
  }

  /// Helper: Add BR to user's balance
  Future<int> _addBR({
    required String userId,
    required int amount,
    required String source,
    String? sourceId,
    String? description,
    Map<String, dynamic>? metadata,
    bool isPurchase = false,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();

    final currentBalance = userDoc.data()?['brBalance'] ?? 0;
    final newBalance = currentBalance + amount;

    // Update balance
    final updateData = {
      'brBalance': newBalance,
    };

    if (isPurchase) {
      updateData['brLifetimePurchased'] = FieldValue.increment(amount);
    } else {
      updateData['brLifetimeEarned'] = FieldValue.increment(amount);
    }

    await userRef.update(updateData);

    // Record transaction
    await _recordTransaction(
      userId: userId,
      type: isPurchase ? 'purchase' : 'earn',
      amount: amount,
      balanceAfter: newBalance,
      source: source,
      sourceId: sourceId,
      metadata: metadata ?? {'description': description},
    );

    return newBalance;
  }

  /// Record transaction to br_transactions collection
  Future<void> _recordTransaction({
    required String userId,
    required String type,
    required int amount,
    required int balanceAfter,
    required String source,
    String? sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    await _firestore.collection('br_transactions').add({
      'userId': userId,
      'type': type,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'source': source,
      'sourceId': sourceId,
      'metadata': metadata ?? {},
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory(
    String userId, {
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('br_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
```

---

### 1.4 Update Pool Generation

**File:** `lib/services/pool_auto_generator.dart`

```dart
// Update generateGamePools method to ALWAYS use simple scoring

Future<void> generateGamePools({required GameModel game}) async {
  try {
    // Check if pools already exist
    final existingPools = await _firestore
        .collection('pools')
        .where('gameId', isEqualTo: game.id)
        .limit(1)
        .get();

    if (existingPools.docs.isNotEmpty) {
      debugPrint('⏭️ Pools already exist for ${game.gameTitle}');
      return;
    }

    // ALWAYS generate simple pick pools (no odds requirement)
    debugPrint('🎯 Generating simple pick pools for ${game.gameTitle}');
    await _generateSimplePickPools(game);

  } catch (e) {
    debugPrint('❌ Error generating pools: $e');
  }
}

// _generateSimplePickPools already exists, ensure metadata is set correctly
```

---

### 1.5 Update UI to Remove Odds Display

**File:** `lib/widgets/neon_game_card.dart`

```dart
// Replace odds display with record display

// OLD: Display moneyline odds
// if (game.odds != null) {
//   Text('${game.homeTeamOdds}'),
// }

// NEW: Display team records
if (game.homeTeamRecord != null) {
  Text(
    game.homeTeamRecord!,
    style: TextStyle(fontSize: 12, color: Colors.grey),
  ),
}

// Show "UNDERDOG" badge instead of odds
if (_isUnderdog(game, isHomeTeam: true)) {
  Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orange,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'UNDERDOG',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
    ),
  ),
}
```

---

### 1.6 Testing Checklist for Phase 1

- [ ] Verify odds API is NOT being called (check logs)
- [ ] Create new user account
- [ ] Claim daily bonus (should receive 50 BR)
- [ ] Enter a pool with BR (should deduct from balance)
- [ ] Check transaction history shows earn and spend
- [ ] Log in consecutive days (verify streak tracking)
- [ ] Verify underdog bonus calculation with test games
- [ ] Check that all pools show "Simple Pick" scoring type
- [ ] Confirm no errors in Firebase logs

---

## Phase 2: Premium Tier Implementation

### 2.1 Subscription Management Service

**Create:** `lib/services/subscription_service.dart`

```dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Product IDs (must match App Store Connect / Google Play Console)
  static const String MONTHLY_PRODUCT_ID = 'com.braggingrights.premium.monthly';
  static const String ANNUAL_PRODUCT_ID = 'com.braggingrights.premium.annual';

  // Subscription status
  Stream<SubscriptionStatus> subscriptionStatusStream(String userId) {
    return _firestore
        .collection('subscriptions')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return SubscriptionStatus.free();
      }

      final data = doc.data()!;
      return SubscriptionStatus.fromFirestore(data);
    });
  }

  /// Check if user is premium
  Future<bool> isPremium(String userId) async {
    final subDoc = await _firestore.collection('subscriptions').doc(userId).get();

    if (!subDoc.exists) return false;

    final data = subDoc.data()!;
    final status = data['status'] as String;

    if (status == 'active' || status == 'trial') {
      // Check if not expired
      final endDate = (data['currentPeriodEnd'] as Timestamp).toDate();
      return endDate.isAfter(DateTime.now());
    }

    return false;
  }

  /// Initialize IAP and load products
  Future<List<ProductDetails>> loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('IAP not available on this device');
    }

    const productIds = {MONTHLY_PRODUCT_ID, ANNUAL_PRODUCT_ID};
    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception('Failed to load products: ${response.error}');
    }

    return response.productDetails;
  }

  /// Start free trial or purchase subscription
  Future<bool> subscribe({
    required String userId,
    required String productId,
    bool isTrial = false,
  }) async {
    final products = await loadProducts();
    final product = products.firstWhere((p) => p.id == productId);

    final purchaseParam = PurchaseParam(productDetails: product);

    // Start purchase flow
    final purchaseResult = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

    // Listen for purchase updates
    _iap.purchaseStream.listen((purchases) {
      _handlePurchases(purchases, userId);
    });

    return true;
  }

  /// Handle purchase updates
  Future<void> _handlePurchases(
    List<PurchaseDetails> purchases,
    String userId,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        // Verify purchase with backend (important for security)
        await _verifyAndActivate(userId, purchase);

        // Complete the purchase
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase error: ${purchase.error}');
      }
    }
  }

  /// Verify purchase and activate subscription
  Future<void> _verifyAndActivate(
    String userId,
    PurchaseDetails purchase,
  ) async {
    // TODO: Implement receipt verification with Apple/Google
    // For now, trust the IAP library

    final isTrial = purchase.productID.contains('trial'); // Adjust based on your setup
    final isAnnual = purchase.productID.contains('annual');

    final now = DateTime.now();
    final endDate = isAnnual
        ? now.add(Duration(days: 365))
        : now.add(Duration(days: 30));

    // Create or update subscription document
    await _firestore.collection('subscriptions').doc(userId).set({
      'userId': userId,
      'tier': 'premium',
      'status': isTrial ? 'trial' : 'active',
      'currentPeriodStart': Timestamp.fromDate(now),
      'currentPeriodEnd': Timestamp.fromDate(endDate),
      'autoRenew': true,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'google',
      'productId': purchase.productID,
      'originalTransactionId': purchase.purchaseID,
      'latestReceiptData': purchase.verificationData.serverVerificationData,
      'billingCycle': isAnnual ? 'annual' : 'monthly',
      'priceAtPurchase': 1.99, // TODO: Get from ProductDetails
      'currency': 'USD',
      'extensionMonths': 0,
      'subscriptionHistory': FieldValue.arrayUnion([
        {
          'action': isTrial ? 'started_trial' : 'started',
          'timestamp': FieldValue.serverTimestamp(),
          'reason': 'user_action',
          'metadata': {
            'productId': purchase.productID,
            'transactionId': purchase.purchaseID,
          },
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update user document
    await _firestore.collection('users').doc(userId).update({
      'subscriptionTier': 'premium',
      'subscriptionStatus': isTrial ? 'trial' : 'active',
      'subscriptionStartDate': FieldValue.serverTimestamp(),
      'subscriptionEndDate': Timestamp.fromDate(endDate),
      'subscriptionPlatform': defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'google',
      'subscriptionProductId': purchase.productID,
      'trialUsed': isTrial ? true : FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Subscription activated for $userId');
  }

  /// Cancel subscription (stops auto-renewal)
  Future<void> cancelSubscription(String userId) async {
    // Note: Actual cancellation happens through App Store/Play Store
    // We just update our records

    await _firestore.collection('subscriptions').doc(userId).update({
      'autoRenew': false,
      'subscriptionHistory': FieldValue.arrayUnion([
        {
          'action': 'cancelled',
          'timestamp': FieldValue.serverTimestamp(),
          'reason': 'user_action',
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(userId).update({
      'subscriptionStatus': 'cancelled',
    });

    debugPrint('❌ Subscription cancelled for $userId (active until period end)');
  }

  /// Restore purchases (for device transfers)
  Future<void> restorePurchases(String userId) async {
    await _iap.restorePurchases();
    // Purchases will flow through purchaseStream
  }

  /// Apply prize extension to subscription
  Future<void> applyPrizeExtension({
    required String userId,
    required int months,
    required String prizeId,
  }) async {
    final subRef = _firestore.collection('subscriptions').doc(userId);
    final subDoc = await subRef.get();

    if (!subDoc.exists) {
      throw Exception('No subscription found for user');
    }

    final data = subDoc.data()!;
    final currentEndDate = (data['currentPeriodEnd'] as Timestamp).toDate();
    final newEndDate = DateTime(
      currentEndDate.year,
      currentEndDate.month + months,
      currentEndDate.day,
    );

    await subRef.update({
      'currentPeriodEnd': Timestamp.fromDate(newEndDate),
      'extensionMonths': FieldValue.increment(months),
      'extensionAppliedDate': FieldValue.serverTimestamp(),
      'extensionExpiryDate': Timestamp.fromDate(newEndDate),
      'subscriptionHistory': FieldValue.arrayUnion([
        {
          'action': 'extended',
          'timestamp': FieldValue.serverTimestamp(),
          'reason': 'prize',
          'metadata': {
            'months': months,
            'prizeId': prizeId,
            'newEndDate': newEndDate.toIso8601String(),
          },
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(userId).update({
      'subscriptionEndDate': Timestamp.fromDate(newEndDate),
    });

    debugPrint('🎁 Applied $months month extension to $userId');
  }
}

class SubscriptionStatus {
  final String tier;
  final String status;
  final DateTime? endDate;
  final bool autoRenew;
  final int extensionMonths;

  SubscriptionStatus({
    required this.tier,
    required this.status,
    this.endDate,
    required this.autoRenew,
    this.extensionMonths = 0,
  });

  factory SubscriptionStatus.free() => SubscriptionStatus(
    tier: 'free',
    status: 'none',
    autoRenew: false,
  );

  factory SubscriptionStatus.fromFirestore(Map<String, dynamic> data) {
    return SubscriptionStatus(
      tier: data['tier'] ?? 'free',
      status: data['status'] ?? 'none',
      endDate: (data['currentPeriodEnd'] as Timestamp?)?.toDate(),
      autoRenew: data['autoRenew'] ?? false,
      extensionMonths: data['extensionMonths'] ?? 0,
    );
  }

  bool get isPremium => tier == 'premium' &&
      (status == 'active' || status == 'trial') &&
      (endDate?.isAfter(DateTime.now()) ?? false);

  bool get isTrial => status == 'trial';

  String get displayStatus {
    if (!isPremium) return 'Free';
    if (isTrial) return 'Trial';
    if (!autoRenew) return 'Cancelled (active until ${endDate?.toString().split(' ')[0]})';
    return 'Premium';
  }
}
```

---

### 2.2 Odds Already Gated (Done in Phase 1)

**Already implemented in Phase 1.1** - Odds are gated behind `isPremium()` check.

Premium/prize users get odds automatically once SubscriptionService is working.

**Update pool generation to create both free and premium pools:**

**File:** `lib/services/pool_auto_generator.dart`

```dart
Future<void> generateGamePools({required GameModel game}) async {
  // Generate FREE simple pick pools (always)
  await _generateSimplePickPools(game);

  // Generate PREMIUM odds-based pools (if odds available)
  if (game.odds != null && game.odds!.isNotEmpty) {
    await _generatePremiumOddsBasedPools(game);
  }
}

Future<void> _generatePremiumOddsBasedPools(GameModel game) async {
  // Similar to _generateSimplePickPools but:
  // - Mark requiresPremium: true in metadata
  // - Use odds-based scoring
  // - Higher BR entry fees
  // - Larger prize pools
}
```

---

### 2.3 Feature Flag System

**Create:** `lib/services/feature_flags.dart`

```dart
class FeatureFlags {
  static Future<Map<String, bool>> getFlags(String userId) async {
    final isPremium = await SubscriptionService().isPremium(userId);

    return {
      'simple_scoring': true,                    // All users
      'odds_based_scoring': isPremium,           // Premium only
      'real_time_odds': isPremium,               // Premium only
      'edge_intelligence': isPremium,            // Premium only
      'historical_trends': isPremium,            // Premium only
      'line_shopping': isPremium,                // Premium only
      'ad_free': isPremium,                      // Premium only
      'priority_support': isPremium,             // Premium only
      'early_access_pools': isPremium,           // Premium only
      'premium_competitions': isPremium,         // Premium only
    };
  }
}
```

---

### 2.4 Testing Checklist for Phase 2

- [ ] Purchase premium subscription (test IAP sandbox)
- [ ] Verify subscription status updates in Firestore
- [ ] Confirm premium features unlock
- [ ] Check odds API is called for premium users
- [ ] Verify free trial flow (7 days)
- [ ] Test subscription cancellation
- [ ] Test restore purchases on new device
- [ ] Confirm annual subscription pricing
- [ ] Verify feature flags work correctly

---

## Phase 3: Competition System

### 3.1 Competition Service

**Create:** `lib/services/competition_service.dart`

```dart
// Full implementation would go here
// Key methods:
// - createCompetition()
// - updateLeaderboard()
// - calculateWinners()
// - awardPrizes()
// - notifyWinners()
```

**(Due to length constraints, this would be a separate detailed implementation document)**

---

## Testing Requirements

### Unit Tests

**Create:** `test/services/br_currency_service_test.dart`
**Create:** `test/services/subscription_service_test.dart`
**Create:** `test/services/simple_pick_scoring_test.dart`

### Integration Tests

- End-to-end flow: New user → daily bonus → pool entry → scoring
- Subscription flow: Free → trial → premium → cancel
- Competition flow: Enter → compete → win → claim prize

---

## Deployment Checklist

### Before Launch

- [ ] All feature flags set correctly
- [ ] Official Rules posted publicly
- [ ] Terms of Service updated
- [ ] Privacy Policy updated
- [ ] Age gate implemented (18+)
- [ ] IAP products created in app stores
- [ ] Firebase indexes created
- [ ] Security rules updated
- [ ] Legal review completed ($3,000-5,000)
- [ ] Load testing completed

### App Store Submission

**Apple:**
- [ ] Age rating: 17+ (unrestricted web access + competitions)
- [ ] IAP configured and tested
- [ ] Screenshots show no gambling references
- [ ] Description emphasizes skill-based gameplay

**Google:**
- [ ] Age rating: Teen
- [ ] IAP configured and tested
- [ ] Data safety form completed

---

## Next Steps After This Document

1. **Review and approve** this technical implementation plan
2. **Prioritize** Phase 1 tasks
3. **Assign** development resources
4. **Create** detailed tickets for each task
5. **Begin implementation** starting with odds API disable
6. **Schedule** weekly progress reviews

---

**Document Version:** 1.0
**Last Updated:** 2025-01-06
**Status:** Ready for Development

---

Would you like me to elaborate on any specific section or create additional implementation details?
