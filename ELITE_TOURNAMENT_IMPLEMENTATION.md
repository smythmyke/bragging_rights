# Elite Tournament System Implementation Plan
## Free-to-Play Model with Premium Acceleration

**Date:** January 2025
**Status:** Planning Phase
**Business Model:** Free-to-play with optional BR purchases to accelerate VC earning
**Legal Status:** ✅ Fully compliant - No gambling, pure promotional rewards

---

## Executive Summary

This implementation converts the existing pool/tournament system into a tiered progression model where users earn Victory Coins (VC) through skill-based gameplay and use VC to unlock Elite Tournaments with real prizes (gift cards, merchandise, experiences). The system is designed to be **100% legal** across all 50 states as a promotional free-to-play game with optional in-app purchases.

**Key Changes:**
- Existing pools → Renamed and restructured into Open/Competitive/Elite tiers
- VC becomes tournament entry currency (not cash)
- Elite prizes = Gift cards and merchandise (not cash payouts)
- BR purchases accelerate VC earning but aren't required
- Clear progression system with educational UI throughout app

**Revenue Model:**
- Users buy BR coins to make more predictions
- More predictions = More chances to earn VC
- Faster VC earning = Faster access to Elite tournaments
- Target: 5-10% conversion, $1M-$3M annual revenue at 100k users

---

## Current System Analysis

### Existing Architecture ✅ (Keep These)

**1. Victory Coin Service** (`lib/services/victory_coin_service.dart`)
```dart
✅ VC earning system complete
✅ Conversion rates by bet type (15%-150%)
✅ Daily/weekly/monthly caps (500/2500/8000)
✅ Transaction logging
✅ Award/spend methods implemented

⚠️ NEEDS: Tournament entry spend logic
⚠️ NEEDS: Elite tier eligibility checks
```

**2. Pool System** (`lib/models/pool_model.dart`, `lib/services/pool_service.dart`)
```dart
✅ Pool types: quick, regional, private, tournament
✅ Pool tiers: beginner, standard, high, vip
✅ Buy-in logic with wallet integration
✅ Player tracking and prize pools
✅ Status management (open, closed, inProgress, completed)

🔄 NEEDS MODIFICATION:
- Add PoolTier.elite (new tier above vip)
- Add vcEntryFee field (separate from buyIn)
- Add prizeType: 'BR' | 'VC' | 'GIFT_CARD' | 'MERCHANDISE'
- Add requiredVCBalance field for eligibility
```

**3. Wallet Service** (`lib/services/wallet_service.dart`)
```dart
✅ BR balance management
✅ Transaction logging
✅ Wagering and winnings processing
✅ Weekly allowance system (25 BR)
✅ Initial bonus (500 BR)

⚠️ NEEDS: Integration with VC spending for tournament entry
```

**4. Pool Selection Screen** (`lib/screens/pools/pool_selection_screen.dart`)
```dart
✅ Tab-based interface (4 tabs currently)
✅ Pool filtering by type
✅ Wallet balance display
✅ Join pool flow with validation

🔄 NEEDS MODIFICATION:
- Rename tabs: Quick → Open, Tournament → Elite
- Add VC balance display alongside BR
- Add "Path to Elite" progress indicator
- Add Elite unlock requirements messaging
```

### What's Missing (Need to Build)

**1. Tournament Tier System**
- No concept of "Elite" tier currently
- No VC-based entry requirements
- No gift card/merchandise prize types

**2. VC Entry Logic**
- VC can be earned but not spent on entries yet
- Need spendVC() method in VictoryCoinService
- Need tournament entry flow using VC

**3. Elite Progress Tracking**
- No visual progress toward Elite access
- No milestone tracking (0 → 500 VC journey)
- No "time to Elite" calculations

**4. Prize Management**
- No gift card prize types
- No merchandise inventory
- No prize fulfillment system

**5. Educational UI**
- No "How to Earn VC" guides
- No Elite benefits explanation
- No conversion funnels for BR purchases

---

## Implementation Plan

### Phase 1: Backend Foundation (Week 1-2)

#### Task 1.1: Extend Pool Model
**File:** `lib/models/pool_model.dart`

**Changes:**
```dart
enum PoolTier {
  beginner,
  standard,
  high,
  vip,
  elite,        // NEW
  championship, // NEW - Invitation only
}

enum PrizeType {  // NEW ENUM
  brCoins,
  victoryCoins,
  giftCard,
  merchandise,
  experience,
}

class Pool {
  // Existing fields...

  // NEW FIELDS:
  final int? vcEntryFee;           // VC required to enter (null = BR entry)
  final int? requiredVCBalance;    // Minimum VC to be eligible
  final PrizeType prizeType;       // Type of prize awarded
  final Map<String, dynamic> prizes; // Prize structure with details
  final bool requiresInvitation;   // For championship tier
  final int? minAccuracy;          // Required win rate to enter

  // NEW METHODS:
  bool canUserEnter(int userVC, double userAccuracy);
  String getEntryRequirement();
  String getPrizeDescription();
}
```

**Implementation:**
- Add new fields to Pool class
- Update fromFirestore/toFirestore methods
- Add validation methods for eligibility
- Backward compatible with existing pools

---

#### Task 1.2: Add VC Spending to VictoryCoinService
**File:** `lib/services/victory_coin_service.dart`

**New Methods:**
```dart
// Spend VC for tournament entry
Future<bool> spendVC({
  required String userId,
  required int amount,
  required String purpose,
  Map<String, dynamic>? metadata,
}) async {
  final userVC = await getUserVC(userId);
  if (userVC == null || userVC.balance < amount) {
    return false; // Insufficient VC
  }

  await _firestore.collection('victory_coins').doc(userId).update({
    'balance': FieldValue.increment(-amount),
    'lifetimeSpent': FieldValue.increment(amount),
    'lastSpent': FieldValue.serverTimestamp(),
  });

  await _logVCTransaction(
    userId: userId,
    type: 'spent',
    amount: amount,
    source: purpose,
    metadata: metadata ?? {},
  );

  return true;
}

// Check if user can afford tournament
Future<bool> canAffordEntry(String userId, int vcCost) async {
  final vc = await getUserVC(userId);
  return vc != null && vc.balance >= vcCost;
}

// Get VC needed for specific tier
int getVCRequirementForTier(PoolTier tier) {
  switch (tier) {
    case PoolTier.elite:
      return 500;
    case PoolTier.championship:
      return 1000;
    default:
      return 0;
  }
}
```

**Testing:**
- Unit test VC spending with insufficient balance
- Test transaction logging
- Test concurrent spend attempts

---

#### Task 1.3: Create Elite Tournament Service
**New File:** `lib/services/elite_tournament_service.dart`

**Purpose:** Manage Elite-specific logic

```dart
class EliteTournamentService {
  // Check eligibility for Elite
  Future<EliteEligibility> checkEligibility(String userId);

  // Get user's progress to Elite
  Future<EliteProgress> getEliteProgress(String userId);

  // Calculate time to Elite at current pace
  Future<Duration> estimateTimeToElite(String userId);

  // Create Elite tournament
  Future<Pool> createEliteTournament({
    required String eventId,
    required String eventName,
    required Map<String, dynamic> prizes,
  });

  // Handle prize fulfillment
  Future<void> awardPrize(String userId, Prize prize);
}

class EliteEligibility {
  final bool eligible;
  final int currentVC;
  final int requiredVC;
  final String? blockReason;
}

class EliteProgress {
  final int currentVC;
  final int targetVC;
  final double percentage;
  final int vcEarnedThisWeek;
  final double avgVCPerEvent;
  final Duration estimatedTimeRemaining;
}
```

---

#### Task 1.4: Prize Management System
**New File:** `lib/models/prize_model.dart`

```dart
enum PrizeCategory {
  giftCard,
  merchandise,
  experience,
  vcBonus,
}

class Prize {
  final String id;
  final PrizeCategory category;
  final String name;
  final String description;
  final double value;           // USD value
  final String? giftCardCode;   // For digital gift cards
  final String? trackingNumber; // For physical items
  final PrizeStatus status;
  final DateTime? fulfilledAt;
}

enum PrizeStatus {
  pending,
  processing,
  fulfilled,
  failed,
}
```

**New File:** `lib/services/prize_service.dart`

```dart
class PrizeService {
  // Award prize to winner
  Future<void> awardPrize({
    required String userId,
    required Prize prize,
    required String tournamentId,
  });

  // Generate gift card codes (integrate with provider)
  Future<String> generateGiftCard(String provider, double amount);

  // Track prize delivery
  Future<void> updatePrizeStatus(String prizeId, PrizeStatus status);

  // Get user's prize history
  Future<List<Prize>> getUserPrizes(String userId);
}
```

---

### Phase 2: UI Foundation (Week 3-4)

#### Task 2.1: Tournament Tier Indicator Widget
**New File:** `lib/widgets/tournament_tier_badge.dart`

**Purpose:** Visual badge showing tournament tier

```dart
class TournamentTierBadge extends StatelessWidget {
  final PoolTier tier;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: _getTierGradient(tier),
        borderRadius: BorderRadius.circular(20),
        border: locked ? Border.all(color: Colors.grey) : null,
        boxShadow: locked ? null : AppTheme.neonGlow(
          color: _getTierColor(tier),
          intensity: 0.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getTierIcon(tier), size: 16),
          SizedBox(width: 4),
          Text(
            _getTierName(tier),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: locked ? Colors.grey : Colors.white,
            ),
          ),
          if (locked) ...[
            SizedBox(width: 4),
            Icon(Icons.lock, size: 14, color: Colors.grey),
          ],
        ],
      ),
    );
  }
}
```

---

#### Task 2.2: Elite Progress Widget
**New File:** `lib/widgets/elite_progress_card.dart`

**Purpose:** Show user's progress toward Elite access

```dart
class EliteProgressCard extends StatelessWidget {
  final int currentVC;
  final int requiredVC;
  final Function() onAccelerate;

  @override
  Widget build(BuildContext context) {
    final percentage = (currentVC / requiredVC).clamp(0.0, 1.0);
    final remaining = requiredVC - currentVC;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: AppTheme.warningAmber),
                SizedBox(width: 8),
                Text('Path to Elite', style: AppTheme.neonText(fontSize: 18)),
              ],
            ),

            SizedBox(height: 16),

            // Progress bar
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan),
              minHeight: 12,
            ),

            SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$currentVC VC', style: TextStyle(fontSize: 12)),
                Text('${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                    )),
                Text('$requiredVC VC', style: TextStyle(fontSize: 12)),
              ],
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need $remaining more VC to unlock Elite',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Elite prizes: Gift cards up to \$500',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),

            SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: onAccelerate,
              icon: Icon(Icons.flash_on),
              label: Text('Accelerate to Elite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningAmber,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### Task 2.3: Update Pool Selection Screen
**File:** `lib/screens/pools/pool_selection_screen.dart`

**Changes:**

1. **Update Tab Controller** (line 55):
```dart
_tabController = TabController(length: 5, vsync: this); // Was 4, now 5
```

2. **Add VC Balance Display** (after line 85):
```dart
Future<VictoryCoinModel?> _vcBalance;

void _loadVCBalance() {
  _vcBalance = VictoryCoinService().getUserVC(userId);
}
```

3. **Update Tab Bar**:
```dart
TabBar(
  controller: _tabController,
  tabs: [
    Tab(text: 'OPEN'),      // Was 'QUICK'
    Tab(text: 'COMPETITIVE'), // Was 'REGIONAL'
    Tab(text: 'PRIVATE'),
    Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 16),
          SizedBox(width: 4),
          Text('ELITE'),
        ],
      ),
    ),
    Tab(text: 'CHAMPIONSHIP'),  // NEW
  ],
)
```

4. **Add Elite Tab Content**:
```dart
// In TabBarView
FutureBuilder<VictoryCoinModel?>(
  future: _vcBalance,
  builder: (context, vcSnapshot) {
    if (!vcSnapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    final userVC = vcSnapshot.data!.balance;
    final requiredVC = 500;

    if (userVC < requiredVC) {
      return _buildEliteLockedView(userVC, requiredVC);
    }

    return _buildEliteTournaments();
  },
)
```

5. **Create Elite Locked View**:
```dart
Widget _buildEliteLockedView(int currentVC, int requiredVC) {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        EliteProgressCard(
          currentVC: currentVC,
          requiredVC: requiredVC,
          onAccelerate: _showAccelerateDialog,
        ),

        SizedBox(height: 24),

        Text('How to Unlock Elite', style: AppTheme.neonText(fontSize: 18)),
        SizedBox(height: 16),

        _buildHowToEarnVCCard(),

        SizedBox(height: 16),

        _buildElitePrizesPreview(),
      ],
    ),
  );
}
```

---

#### Task 2.4: Create "How to Earn VC" Guide
**New File:** `lib/widgets/how_to_earn_vc_card.dart`

```dart
class HowToEarnVCCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Earn Victory Coins', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),

            SizedBox(height: 16),

            _buildEarnMethod(
              icon: Icons.sports_mma,
              title: 'Win Predictions',
              subtitle: 'Earn 15-150% VC based on odds',
              vcExample: '+40 VC',
            ),

            _buildEarnMethod(
              icon: Icons.emoji_events,
              title: 'Win Tournaments',
              subtitle: 'Top finishers earn bonus VC',
              vcExample: '+100 VC',
            ),

            _buildEarnMethod(
              icon: Icons.local_fire_department,
              title: 'Build Streaks',
              subtitle: '3+ wins in a row = 2x VC',
              vcExample: '+80 VC',
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: AppTheme.warningAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy BR coins to make more predictions and earn VC faster',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Phase 3: Monetization & Conversion (Week 5-6)

#### Task 3.1: Accelerate to Elite Dialog
**New File:** `lib/widgets/dialogs/accelerate_elite_dialog.dart`

**Purpose:** Convert users to BR purchases

```dart
class AccelerateEliteDialog extends StatelessWidget {
  final int currentVC;
  final int requiredVC;

  @override
  Widget build(BuildContext context) {
    final remaining = requiredVC - currentVC;
    final eventsNeeded = (remaining / 40).ceil(); // Assume 40 VC avg/event
    final brNeeded = eventsNeeded * 100; // 100 BR per event entry

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on, size: 48, color: AppTheme.warningAmber),
            SizedBox(height: 16),

            Text('Fast Track to Elite',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current VC:'),
                      Text('$currentVC', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      )),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Need:'),
                      Text('$remaining VC', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningAmber,
                      )),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            Text('Recommended Path:', style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
            SizedBox(height: 8),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryCyan),
              ),
              child: Column(
                children: [
                  Text('Enter $eventsNeeded more events',
                      style: TextStyle(fontSize: 14)),
                  Text('Win 60%+ accuracy',
                      style: TextStyle(fontSize: 14)),
                  SizedBox(height: 8),
                  Text('= Unlock Elite',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      )),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Offer BR packages
            _buildBRPackageOption(
              '\$9.99 Pack',
              '1,100 BR',
              'Enter ~11 events',
              () => _purchaseBR(context, 9.99),
            ),

            SizedBox(height: 8),

            _buildBRPackageOption(
              '\$19.99 Pack',
              '2,400 BR',
              'Enter ~24 events',
              () => _purchaseBR(context, 19.99),
            ),

            SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Keep Free Path'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### Task 3.2: Post-Event VC Earning Celebration
**New File:** `lib/widgets/dialogs/vc_earned_dialog.dart`

**Purpose:** Celebrate VC earning and encourage more play

```dart
class VCEarnedDialog extends StatelessWidget {
  final int vcEarned;
  final int totalVC;
  final int eliteTarget;

  @override
  Widget build(BuildContext context) {
    final percentage = (totalVC / eliteTarget * 100).toInt();
    final remaining = eliteTarget - totalVC;

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration animation
            Lottie.asset('assets/animations/victory.json', height: 100),

            Text('Great Picks!', style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            )),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.secondaryCyan],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '+$vcEarned VC',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: 20),

            LinearProgressIndicator(
              value: totalVC / eliteTarget,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan),
              minHeight: 8,
            ),

            SizedBox(height: 8),

            Text('Elite Progress: $percentage%',
                style: TextStyle(fontSize: 14, color: Colors.white70)),

            SizedBox(height: 16),

            if (remaining > 0) ...[
              Text('Only $remaining VC until Elite!',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Keep winning to unlock \$500 prizes',
                  style: TextStyle(fontSize: 12, color: Colors.white60)),

              SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Show BR purchase or next event
                },
                icon: Icon(Icons.flash_on),
                label: Text('Keep the Streak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningAmber,
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ] else ...[
              Icon(Icons.emoji_events, size: 48, color: AppTheme.warningAmber),
              Text('🎉 Elite Unlocked! 🎉',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to Elite tournaments
                },
                child: Text('Enter Elite Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningAmber,
                  minimumSize: Size(double.infinity, 48),
                ),
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

#### Task 3.3: Elite Prize Display
**New File:** `lib/widgets/elite_prizes_card.dart`

```dart
class ElitePrizesCard extends StatelessWidget {
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: AppTheme.warningAmber),
                SizedBox(width: 8),
                Text('Elite Prizes', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),

            SizedBox(height: 16),

            _buildPrizeRow('🥇', '1st Place', '\$500 Gift Card'),
            _buildPrizeRow('🥈', '2nd Place', '\$250 Gift Card'),
            _buildPrizeRow('🥉', '3rd Place', '\$100 Gift Card'),
            _buildPrizeRow('🏆', 'Top 10', 'Exclusive Badge + 100 VC'),

            if (!unlocked) ...[
              SizedBox(height: 16),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[900]?.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Earn more VC to unlock Elite tournaments',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
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

### Phase 4: Elite Tournament Creation (Week 7)

#### Task 4.1: Elite Tournament Generator
**New File:** `lib/services/elite_tournament_generator.dart`

```dart
class EliteTournamentGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Elite tournament for major events
  Future<Pool> createEliteTournament({
    required String eventId,
    required String eventName,
    required String sport,
    required DateTime eventDate,
  }) async {

    final prizes = {
      '1st': {
        'type': 'gift_card',
        'provider': 'amazon',
        'amount': 500.0,
        'description': '\$500 Amazon Gift Card',
      },
      '2nd': {
        'type': 'gift_card',
        'provider': 'visa',
        'amount': 250.0,
        'description': '\$250 Visa Gift Card',
      },
      '3rd': {
        'type': 'gift_card',
        'provider': 'ufc_store',
        'amount': 100.0,
        'description': '\$100 UFC Store Credit',
      },
      'top10': {
        'type': 'vc_bonus',
        'amount': 100,
        'badge': 'elite_winner',
        'description': '100 VC + Elite Winner Badge',
      },
    };

    final pool = Pool(
      id: '${eventId}_elite_${DateTime.now().millisecondsSinceEpoch}',
      gameId: eventId,
      gameTitle: eventName,
      sport: sport,
      type: PoolType.tournament,
      tier: PoolTier.elite,
      status: PoolStatus.open,
      name: 'Elite Tournament - $eventName',
      buyIn: 0,                    // No BR cost
      vcEntryFee: 500,             // 500 VC required
      requiredVCBalance: 500,      // Must have 500+ VC
      minPlayers: 20,
      maxPlayers: 500,
      currentPlayers: 0,
      playerIds: [],
      startTime: eventDate.subtract(Duration(days: 3)),
      closeTime: eventDate.subtract(Duration(hours: 1)),
      prizePool: 850,              // Total prize value in USD
      prizeStructure: prizes,
      prizeType: PrizeType.giftCard,
      createdAt: DateTime.now(),
      createdBy: 'system',
      metadata: {
        'isElite': true,
        'requiresSkill': true,
        'promotional': true,
      },
    );

    await _firestore.collection('pools').doc(pool.id).set(pool.toFirestore());

    return pool;
  }
}
```

---

#### Task 4.2: Elite Entry Flow
**File:** `lib/services/pool_service.dart`

**Add Method:**
```dart
// Join Elite tournament with VC
Future<Map<String, dynamic>> joinElitePool(String poolId, int vcCost) async {
  final userId = _auth.currentUser?.uid;
  if (userId == null) {
    return {'success': false, 'message': 'User not logged in'};
  }

  try {
    // Check VC balance
    final vcBalance = await VictoryCoinService().getUserVC(userId);
    if (vcBalance == null || vcBalance.balance < vcCost) {
      return {
        'success': false,
        'message': 'Insufficient Victory Coins',
        'code': 'INSUFFICIENT_VC',
      };
    }

    // Check pool eligibility
    final poolDoc = await _firestore.collection('pools').doc(poolId).get();
    if (!poolDoc.exists) {
      return {'success': false, 'message': 'Pool not found'};
    }

    final pool = Pool.fromFirestore(poolDoc);

    // Elite-specific checks
    if (pool.tier == PoolTier.elite || pool.tier == PoolTier.championship) {
      // Check minimum VC balance requirement
      if (pool.requiredVCBalance != null &&
          vcBalance.balance < pool.requiredVCBalance!) {
        return {
          'success': false,
          'message': 'Need ${pool.requiredVCBalance} VC minimum to enter Elite',
          'code': 'INSUFFICIENT_VC_FOR_ELITE',
        };
      }
    }

    // Spend VC
    final spendSuccess = await VictoryCoinService().spendVC(
      userId: userId,
      amount: vcCost,
      purpose: 'elite_tournament_entry',
      metadata: {
        'poolId': poolId,
        'poolName': pool.name,
        'eventId': pool.gameId,
      },
    );

    if (!spendSuccess) {
      return {'success': false, 'message': 'Failed to spend VC'};
    }

    // Add user to pool
    await _firestore.runTransaction((transaction) async {
      final currentPoolDoc = await transaction.get(
        _firestore.collection('pools').doc(poolId),
      );

      final currentPool = Pool.fromFirestore(currentPoolDoc);

      if (currentPool.isFull) {
        throw Exception('Pool is full');
      }

      transaction.update(
        _firestore.collection('pools').doc(poolId),
        {
          'currentPlayers': FieldValue.increment(1),
          'playerIds': FieldValue.arrayUnion([userId]),
        },
      );
    });

    return {
      'success': true,
      'message': 'Successfully joined Elite tournament!',
      'vcSpent': vcCost,
    };

  } catch (e) {
    print('Error joining Elite pool: $e');
    return {'success': false, 'message': 'Failed to join: $e'};
  }
}
```

---

### Phase 5: Prize Fulfillment (Week 8)

#### Task 5.1: Prize Service Implementation
**File:** `lib/services/prize_service.dart`

```dart
class PrizeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Award prize to tournament winner
  Future<void> awardPrize({
    required String userId,
    required String tournamentId,
    required int placement,
    required Map<String, dynamic> prizeDetails,
  }) async {

    final prize = Prize(
      id: '${tournamentId}_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      category: _getCategoryFromType(prizeDetails['type']),
      name: prizeDetails['description'],
      description: 'Awarded for ${placement} place in tournament',
      value: prizeDetails['amount']?.toDouble() ?? 0.0,
      status: PrizeStatus.pending,
    );

    // Save prize record
    await _firestore.collection('prizes').doc(prize.id).set({
      'userId': userId,
      'tournamentId': tournamentId,
      'placement': placement,
      'category': prize.category.toString(),
      'name': prize.name,
      'description': prize.description,
      'value': prize.value,
      'status': prize.status.toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'details': prizeDetails,
    });

    // Process based on prize type
    switch (prizeDetails['type']) {
      case 'gift_card':
        await _processGiftCard(userId, prize.id, prizeDetails);
        break;
      case 'vc_bonus':
        await _processVCBonus(userId, prizeDetails);
        break;
      case 'merchandise':
        await _processMerchandise(userId, prize.id, prizeDetails);
        break;
    }

    // Send notification
    await _sendPrizeNotification(userId, prize);
  }

  // Process gift card (integrate with provider API)
  Future<void> _processGiftCard(
    String userId,
    String prizeId,
    Map<String, dynamic> details,
  ) async {
    // TODO: Integrate with gift card provider
    // For now, mark as pending manual fulfillment

    await _firestore.collection('prizes').doc(prizeId).update({
      'status': PrizeStatus.processing.toString(),
      'processingStarted': FieldValue.serverTimestamp(),
    });

    // Create admin task for manual processing
    await _firestore.collection('admin_tasks').add({
      'type': 'gift_card_fulfillment',
      'prizeId': prizeId,
      'userId': userId,
      'provider': details['provider'],
      'amount': details['amount'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Process VC bonus (automatic)
  Future<void> _processVCBonus(
    String userId,
    Map<String, dynamic> details,
  ) async {
    await VictoryCoinService().awardVC(
      userId: userId,
      amount: details['amount'],
      source: 'tournament_prize',
      metadata: {
        'prizeType': 'tournament_winner',
      },
    );
  }

  // Get user's prize history
  Future<List<Map<String, dynamic>>> getUserPrizes(String userId) async {
    final snapshot = await _firestore
        .collection('prizes')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
```

---

### Phase 6: Analytics & Optimization (Week 9-10)

#### Task 6.1: Conversion Tracking
**New File:** `lib/services/analytics/elite_analytics.dart`

```dart
class EliteAnalytics {
  // Track when user views Elite tab
  static void logEliteViewed(int userVC, int requiredVC) {
    FirebaseAnalytics.instance.logEvent(
      name: 'elite_viewed',
      parameters: {
        'user_vc': userVC,
        'required_vc': requiredVC,
        'progress_percentage': (userVC / requiredVC * 100).toInt(),
      },
    );
  }

  // Track when user clicks "Accelerate"
  static void logAccelerateClicked(int vcRemaining) {
    FirebaseAnalytics.instance.logEvent(
      name: 'accelerate_clicked',
      parameters: {
        'vc_remaining': vcRemaining,
      },
    );
  }

  // Track BR purchase from Elite funnel
  static void logBRPurchaseFromElite(double amount, int vcRemaining) {
    FirebaseAnalytics.instance.logEvent(
      name: 'br_purchase_elite_funnel',
      parameters: {
        'purchase_amount': amount,
        'vc_remaining': vcRemaining,
        'conversion_point': 'elite_unlock',
      },
    );
  }

  // Track Elite entry
  static void logEliteEntered(int vcSpent, String tournamentId) {
    FirebaseAnalytics.instance.logEvent(
      name: 'elite_entered',
      parameters: {
        'vc_spent': vcSpent,
        'tournament_id': tournamentId,
      },
    );
  }
}
```

---

#### Task 6.2: A/B Testing Framework
**New File:** `lib/services/ab_testing/elite_experiments.dart`

```dart
class EliteExperiments {
  // Test different VC requirements
  static int getEliteVCRequirement(String userId) {
    final experiment = _getUserExperiment(userId, 'elite_vc_requirement');

    switch (experiment) {
      case 'variant_a':
        return 400; // Lower barrier
      case 'variant_b':
        return 500; // Control
      case 'variant_c':
        return 600; // Higher barrier (more exclusive)
      default:
        return 500;
    }
  }

  // Test different messaging
  static String getEliteCallToAction(String userId) {
    final experiment = _getUserExperiment(userId, 'elite_cta');

    switch (experiment) {
      case 'variant_a':
        return 'Unlock Elite Prizes';
      case 'variant_b':
        return 'Accelerate to Elite';
      case 'variant_c':
        return 'Fast Track to \$500';
      default:
        return 'Accelerate to Elite';
    }
  }

  // Test different BR package recommendations
  static double getRecommendedBRPackage(String userId, int vcRemaining) {
    final experiment = _getUserExperiment(userId, 'br_package_rec');

    // Calculate based on VC needed
    final brNeeded = (vcRemaining / 0.4).ceil(); // Assume 40% avg conversion

    switch (experiment) {
      case 'variant_a':
        return 9.99;  // Always show cheapest
      case 'variant_b':
        return brNeeded < 1000 ? 9.99 : 19.99; // Dynamic
      case 'variant_c':
        return 19.99; // Always show best value
      default:
        return 9.99;
    }
  }
}
```

---

## Database Schema Changes

### New Collections

#### `elite_tournaments` (subset of pools with Elite metadata)
```javascript
elite_tournaments/{tournamentId} {
  eventId: string,
  eventName: string,
  sport: string,
  vcEntryFee: 500,
  requiredVCBalance: 500,
  prizePool: {
    first: { type: 'gift_card', provider: 'amazon', amount: 500 },
    second: { type: 'gift_card', provider: 'visa', amount: 250 },
    third: { type: 'gift_card', provider: 'ufc_store', amount: 100 },
    top10: { type: 'vc_bonus', amount: 100, badge: 'elite_winner' },
  },
  status: 'open' | 'closed' | 'completed',
  participants: number,
  startTime: timestamp,
  closeTime: timestamp,
  createdAt: timestamp,
}
```

#### `prizes` (prize tracking)
```javascript
prizes/{prizeId} {
  userId: string,
  tournamentId: string,
  placement: number,
  category: 'gift_card' | 'merchandise' | 'vc_bonus',
  name: string,
  description: string,
  value: number,
  status: 'pending' | 'processing' | 'fulfilled' | 'failed',
  giftCardCode: string?,      // For digital codes
  trackingNumber: string?,    // For physical items
  fulfilledAt: timestamp?,
  createdAt: timestamp,
  details: map,
}
```

#### `user_elite_progress` (progress tracking)
```javascript
user_elite_progress/{userId} {
  currentVC: number,
  eliteUnlockedAt: timestamp?,
  eliteEntriesCount: number,
  eliteWinsCount: number,
  totalVCEarned: number,
  totalVCSpent: number,
  avgVCPerEvent: number,
  lastEliteEntry: timestamp,
  prizesWon: array<prizeId>,
  milestones: {
    unlocked_100_vc: timestamp,
    unlocked_250_vc: timestamp,
    unlocked_500_vc: timestamp,
    first_elite_entry: timestamp,
    first_elite_win: timestamp,
  },
}
```

### Modified Collections

#### `pools` (add Elite fields)
```javascript
pools/{poolId} {
  // Existing fields...

  // NEW FIELDS:
  tier: 'beginner' | 'standard' | 'high' | 'vip' | 'elite' | 'championship',
  vcEntryFee: number?,           // VC cost to enter
  requiredVCBalance: number?,    // Min VC to be eligible
  prizeType: 'br' | 'vc' | 'gift_card' | 'merchandise' | 'experience',
  prizes: map,                   // Detailed prize structure
  requiresInvitation: boolean,   // For championship tier
  minAccuracy: number?,          // Required win rate %
}
```

#### `victory_coins` (add Elite tracking)
```javascript
victory_coins/{userId} {
  // Existing fields...

  // NEW FIELDS:
  eliteEligible: boolean,
  eliteUnlockedAt: timestamp?,
  lifetimeEliteEntries: number,
  lifetimeElitePrizes: number,
}
```

---

## Revenue Projections

### Conservative Scenario (100k Active Users)

**Assumptions:**
- 5% conversion to paying users
- Average purchase: $12/user/month
- Users buy 1-2 times to unlock Elite

**Monthly Revenue:**
```
100,000 users × 5% conversion = 5,000 paying users
5,000 paying users × $12 average = $60,000/month
Annual: $720,000/year
```

**Prize Costs:**
```
2 Elite tournaments/month × $850 prizes = $1,700/month
Annual prize costs: $20,400/year

Net Revenue: $720,000 - $20,400 = $699,600/year
```

---

### Optimistic Scenario (100k Active Users)

**Assumptions:**
- 10% conversion rate
- Average purchase: $18/user/month
- Subscription uptake: 2% at $9.99/month

**Monthly Revenue:**
```
BR Purchases:
100,000 × 10% = 10,000 paying users
10,000 × $18 = $180,000/month

Subscriptions:
100,000 × 2% = 2,000 subscribers
2,000 × $9.99 = $19,980/month

Total Monthly: $199,980
Annual: $2.4M/year
```

**Prize Costs:**
```
4 Elite tournaments/month × $850 = $3,400/month
Annual prize costs: $40,800/year

Net Revenue: $2.4M - $40,800 = $2.36M/year
```

---

### Best Case (500k Active Users - Viral Growth)

**Assumptions:**
- 8% conversion rate
- Average purchase: $15/user/month
- Subscription uptake: 3%
- Battle Pass: 5,000 sales/month at $9.99

**Monthly Revenue:**
```
BR Purchases:
500,000 × 8% = 40,000 paying users
40,000 × $15 = $600,000/month

Subscriptions:
500,000 × 3% = 15,000 subscribers
15,000 × $9.99 = $149,850/month

Battle Pass:
5,000 × $9.99 = $49,950/month

Total Monthly: $799,800
Annual: $9.6M/year
```

**Prize Costs:**
```
10 Elite tournaments/month × $1,500 avg = $15,000/month
Annual prize costs: $180,000/year

Net Revenue: $9.6M - $180,000 = $9.42M/year
```

---

## Testing Plan

### Unit Tests
- VC spending validation
- Elite eligibility checks
- Prize calculation logic
- Tournament entry flow

### Integration Tests
- End-to-end Elite entry with VC
- Prize fulfillment workflow
- Progress tracking accuracy
- Analytics event firing

### User Testing
- Elite unlock experience (5-10 users)
- Conversion funnel optimization
- Prize redemption process
- UI/UX feedback sessions

---

## Launch Checklist

### Pre-Launch (Week 10)
- [ ] All backend services deployed
- [ ] Database migrations completed
- [ ] Prize fulfillment process tested
- [ ] Analytics tracking verified
- [ ] Legal review of terms/conditions
- [ ] Gift card provider integration tested
- [ ] Admin dashboard for prize management

### Soft Launch (Week 11)
- [ ] Release to 10% of users
- [ ] Monitor conversion rates
- [ ] Track VC earning rates
- [ ] Monitor Elite entry rates
- [ ] Collect user feedback
- [ ] Fix any critical bugs

### Full Launch (Week 12)
- [ ] Release to 100% of users
- [ ] Launch marketing campaign
- [ ] Create "How to Unlock Elite" content
- [ ] Influencer partnerships
- [ ] Email campaign to existing users
- [ ] App store feature request

---

## Success Metrics

### Primary KPIs
- **Elite Unlock Rate:** % of users who reach 500 VC
- **Conversion Rate:** % of users who purchase BR
- **ARPU:** Average revenue per user
- **Elite Entry Rate:** % of eligible users who enter

### Secondary KPIs
- **Time to Elite:** Average days to reach 500 VC
- **VC Earning Rate:** Average VC earned per event
- **BR Purchase Frequency:** Average purchases per user
- **Elite Win Rate:** % distribution of Elite winners

### Target Metrics (Month 3)
- Elite Unlock Rate: 15-20%
- Conversion Rate: 5-10%
- ARPU: $1.50-$3.00/user/month
- Elite Entry Rate: 70%+ of eligible users

---

## Risk Mitigation

### Legal Risks
**Risk:** Regulators classify as gambling
**Mitigation:**
- Clear "promotional rewards" language
- No direct VC purchase
- Free path always available
- Gift cards (not cash)
- Legal review before launch

### Financial Risks
**Risk:** Prize costs exceed revenue
**Mitigation:**
- Cap Elite tournaments at 2-4/month
- Tiered prize structure (fewer big prizes)
- Sponsor partnerships for prizes
- Monitor prize-to-revenue ratio weekly

### User Experience Risks
**Risk:** Free path too slow, users quit
**Mitigation:**
- A/B test VC earning rates
- Bonus VC events for engagement
- Clear progress indicators
- Celebrate small milestones

### Technical Risks
**Risk:** VC spending bugs or exploits
**Mitigation:**
- Comprehensive unit tests
- Transaction logging
- Manual review for first month
- Rate limiting on VC transactions

---

## Next Steps

1. **Review and Approval** (This Week)
   - Review plan with team
   - Get legal sign-off on prize structure
   - Confirm budget for prizes
   - Finalize timeline

2. **Phase 1 Implementation** (Week 1-2)
   - Start backend foundation
   - Begin database schema updates
   - Create prize service framework

3. **UI Design** (Week 3)
   - Design mockups for Elite screens
   - Create progress indicator designs
   - Design prize display cards

4. **Development Sprints** (Week 4-10)
   - Follow implementation plan
   - Weekly sprint reviews
   - Continuous testing

5. **Launch Preparation** (Week 11-12)
   - Soft launch with monitoring
   - Gather feedback
   - Full launch with marketing

---

## Appendix

### File Structure
```
lib/
├── models/
│   ├── prize_model.dart (NEW)
│   └── pool_model.dart (MODIFIED - add Elite fields)
│
├── services/
│   ├── elite_tournament_service.dart (NEW)
│   ├── elite_tournament_generator.dart (NEW)
│   ├── prize_service.dart (NEW)
│   ├── victory_coin_service.dart (MODIFIED - add spendVC)
│   └── pool_service.dart (MODIFIED - add joinElitePool)
│
├── screens/
│   └── pools/
│       └── pool_selection_screen.dart (MODIFIED - add Elite tab)
│
├── widgets/
│   ├── tournament_tier_badge.dart (NEW)
│   ├── elite_progress_card.dart (NEW)
│   ├── how_to_earn_vc_card.dart (NEW)
│   ├── elite_prizes_card.dart (NEW)
│   └── dialogs/
│       ├── accelerate_elite_dialog.dart (NEW)
│       └── vc_earned_dialog.dart (NEW)
│
└── services/analytics/
    └── elite_analytics.dart (NEW)
```

### External Dependencies
```yaml
# pubspec.yaml additions
dependencies:
  lottie: ^3.0.0              # For celebration animations
  firebase_analytics: ^10.8.0 # Analytics tracking
  share_plus: ^7.2.0          # Share Elite achievements
```

### Marketing Assets Needed
- Elite tournament banner graphics
- Prize showcase images
- "How to Unlock Elite" video tutorial
- Social media templates
- Email campaign templates
- In-app tutorial flow

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Owner:** Product Team
**Status:** Ready for Implementation
