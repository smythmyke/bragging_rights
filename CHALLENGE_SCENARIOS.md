# Challenge & Pool Scenarios Specification

## Version 1.0.0
**Last Updated:** September 2025
**Status:** Design Phase

---

## Table of Contents
1. [Overview](#overview)
2. [Scenario 1: Pool Invitation](#scenario-1-pool-invitation)
3. [Scenario 2: User-to-User Challenge](#scenario-2-user-to-user-challenge)
4. [Scenario 3: Expandable Challenge](#scenario-3-expandable-challenge)
5. [Scenario 4: Private Pool Creation](#scenario-4-private-pool-creation)
6. [Wagering Options](#wagering-options)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Technical Architecture](#technical-architecture)

---

## Overview

This document outlines four distinct ways users can compete with friends in Bragging Rights, each serving different use cases and social dynamics.

### Four Competition Methods

| Method | Use Case | Entry Fee | Participants | Can Grow |
|--------|----------|-----------|--------------|----------|
| **Pool Invitation** | Join existing competition | Yes | Many | No |
| **User Challenge** | Quick 1-on-1 competition | Optional | 2-10 | No |
| **Expandable Challenge** | Start small, grow organically | Optional | 2-∞ | Yes |
| **Private Pool** | Organized group competition | Yes | Many | No |

---

## Scenario 1: Pool Invitation

### Description
User wants to invite friends to join an **existing pool** they're already participating in.

### User Story
> "I joined the UFC 295 pool and it's great! I want to invite my friends to join the same pool and compete with everyone for the prize."

### User Flow
```
User in Pool → [INVITE TO POOL] → Select Friends → Share Link
→ Friend Receives Link → Clicks Link → Views Pool Details
→ Pays Entry Fee → Makes Picks → Competes with ALL Pool Members
```

### UI Components

#### Pool Screen Addition
```dart
// In enhanced_pool_screen.dart or fight_card_grid_screen.dart
Widget _buildPoolInviteButton() {
  return ElevatedButton.icon(
    icon: Icon(Icons.person_add),
    label: Text('INVITE TO POOL'),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryCyan,
    ),
    onPressed: _hasJoined ? _inviteFriendToPool : null,
  );
}
```

#### Invitation Modal
```dart
class PoolInvitationSheet extends StatelessWidget {
  final Pool pool;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Invite Friends to Pool', style: AppTheme.neonText(fontSize: 20)),

          // Pool details
          _buildPoolSummary(),

          // Entry fee notice
          Text('Entry Fee: \$${pool.entryFee.toStringAsFixed(2)}'),
          Text('Current Prize Pool: \$${pool.prizePool.toStringAsFixed(2)}'),

          // Friend selector
          FriendSelector(
            onFriendsSelected: (friends) => _generateInviteLink(friends),
          ),

          // Share options
          Row(
            children: [
              _ShareButton(icon: Icons.message, label: 'SMS'),
              _ShareButton(icon: Icons.chat, label: 'WhatsApp'),
              _ShareButton(icon: Icons.copy, label: 'Copy Link'),
            ],
          ),
        ],
      ),
    );
  }
}
```

### Data Structure

```javascript
// Existing pools collection - add invitations tracking
pools/{poolId} {
  // Existing fields
  creator: "user_a",
  members: ["user_a", "user_b"],
  entryFee: 10.00,
  prizePool: 20.00,

  // NEW: Invitation tracking
  invitations: [{
    invitedBy: "user_a",
    invitedUserId: "friend_x",
    invitedAt: timestamp,
    status: "pending" | "accepted" | "declined",
    acceptedAt: timestamp?,
  }],

  // NEW: Invitation stats
  invitationStats: {
    sent: 5,
    accepted: 3,
    declined: 1,
    pending: 1,
  }
}
```

### Implementation Notes

- Uses **existing pool infrastructure**
- Friend must pay entry fee
- Friend competes with ALL pool members
- No separate challenge document created
- Pool invitation link expires when pool closes

---

## Scenario 2: User-to-User Challenge

### Description
User wants to challenge one or more friends to a **simple, independent competition** without involving pools or entry fees.

### User Story
> "I want to challenge my friend to see who can pick more fights correctly. No money involved, just bragging rights!"

### Status
✅ **FULLY IMPLEMENTED** (September 2025)

### User Flow
```
User Makes Picks → [CHALLENGE] Button → Select Friends
→ Create Challenge → Friends Receive Notification
→ Friends Accept → Friends Make Picks
→ Event Happens → Compare Results (Just Participants)
```

### Features

**Current Implementation:**
- ✅ 1-on-1 challenges
- ✅ Group challenges (multiple friends)
- ✅ Open challenges (shareable link)
- ✅ SMS/WhatsApp sharing
- ✅ No entry fees (free to participate)
- ✅ Independent of pools
- ✅ Sport-agnostic (works for all sports)

**NEW: Optional Wagering**
- [ ] Add BR Coins wagering option
- [ ] Add Victory Coins (VC) wagering option
- [ ] Winner takes all
- [ ] No house cut (peer-to-peer)

### UI Enhancement

#### Challenge Creation Options
```dart
class ChallengeOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Challenge Type'),

        // Friend selection
        FriendSelector(),

        // NEW: Wager options
        ExpansionTile(
          title: Text('Add Wager (Optional)'),
          children: [
            RadioListTile(
              title: Text('No Wager'),
              subtitle: Text('Free - just for fun'),
              value: WagerType.none,
            ),
            RadioListTile(
              title: Text('BR Coins'),
              subtitle: Text('In-app currency'),
              value: WagerType.brCoins,
            ),
            RadioListTile(
              title: Text('Victory Coins'),
              subtitle: Text('Premium currency'),
              value: WagerType.vcCoins,
            ),
          ],
        ),

        // If wager selected, show amount
        if (selectedWager != WagerType.none)
          TextField(
            decoration: InputDecoration(
              labelText: 'Wager Amount',
              hintText: '100',
              suffix: Text(selectedWager == WagerType.brCoins ? 'BR' : 'VC'),
            ),
          ),

        ElevatedButton(
          onPressed: _createChallenge,
          child: Text('CREATE CHALLENGE'),
        ),
      ],
    );
  }
}
```

### Data Structure Enhancement

```javascript
challenges/{challengeId} {
  // Existing fields
  challengerId: "user_a",
  eventId: "ufc_295",
  sportType: "mma",
  type: "friend" | "group" | "open",
  picks: { /* picks */ },
  participants: [...],

  // NEW: Wagering fields
  wager: {
    enabled: boolean,
    type: "br_coins" | "vc_coins" | null,
    amount: number,

    // Escrow system
    escrow: {
      "user_a": { amount: 100, status: "locked" },
      "friend_x": { amount: 100, status: "locked" }
    },

    // Payout
    winner: "user_a" | "friend_x" | "tie",
    payout: {
      "user_a": 200,  // Winner gets all
      "friend_x": 0
    },

    // Tie handling
    tieRule: "refund" | "split" | "rollover"
  }
}
```

### Wager Flow

```
1. User A creates challenge with 100 BR wager
2. 100 BR locked from User A's wallet (escrow)
3. Friend B accepts challenge
4. 100 BR locked from Friend B's wallet (escrow)
5. Both make picks
6. Event completes
7. System determines winner
8. Winner receives 200 BR
9. Loser gets 0 BR
10. If tie: Both get 100 BR back (refund)
```

---

## Scenario 3: Expandable Challenge

### Description
User creates a challenge that **starts small** but can **grow into a larger competition** as participants invite others.

### User Story
> "I want to challenge my friend, but if they want to invite more people to make it a bigger competition, that should be easy!"

### User Flow
```
User Creates Challenge → Selects "Expandable" → Invites Initial Friend(s)
→ Friend Accepts → Friend Sees "Invite More" Option
→ Friend Invites Additional People → Challenge Grows
→ When 5+ People Join → Converts to Pool → Prize Pool Forms
```

### Challenge Types

```dart
enum ChallengeType {
  friend,      // Fixed: 1-on-1, cannot grow
  group,       // Fixed: Specific friends, cannot grow
  open,        // Public link, anyone can join, no limit
  expandable,  // NEW: Can grow, converts to pool at threshold
}
```

### UI Flow

#### Step 1: Challenge Creation
```dart
class ExpandableChallengeSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Create Challenge'),

        // Challenge type selector
        SegmentedButton(
          segments: [
            ButtonSegment(
              value: ChallengeType.friend,
              label: Text('1-on-1'),
              icon: Icon(Icons.person),
            ),
            ButtonSegment(
              value: ChallengeType.expandable,
              label: Text('Expandable'),
              icon: Icon(Icons.group_add),
            ),
          ],
        ),

        // If expandable selected
        if (selectedType == ChallengeType.expandable) ...[
          Divider(),
          Text('Expandable Challenge Settings'),

          // Max participants
          TextField(
            decoration: InputDecoration(
              labelText: 'Max Participants',
              hintText: '10',
              helperText: 'Leave empty for unlimited',
            ),
          ),

          // Wager options
          ExpansionTile(
            title: Text('Wager Settings'),
            children: [
              RadioListTile(
                title: Text('No Wager'),
                subtitle: Text('Free competition'),
                value: WagerType.none,
              ),
              RadioListTile(
                title: Text('BR Coins'),
                value: WagerType.brCoins,
              ),
              RadioListTile(
                title: Text('Victory Coins'),
                value: WagerType.vcCoins,
              ),
            ],
          ),

          if (wagerType != WagerType.none)
            TextField(
              decoration: InputDecoration(
                labelText: 'Entry Amount',
                suffix: Text(wagerType == WagerType.brCoins ? 'BR' : 'VC'),
              ),
            ),

          // Conversion threshold
          SwitchListTile(
            title: Text('Auto-convert to Pool'),
            subtitle: Text('Convert to pool when 5+ people join'),
            value: autoConvertToPool,
            onChanged: (value) => setState(() => autoConvertToPool = value),
          ),
        ],
      ],
    );
  }
}
```

#### Step 2: Participant Invitation
```dart
class ChallengeAcceptanceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Challenge info
        Text('${challenge.challengerName} challenged you!'),
        Text('${challenge.participants.length} people competing'),

        // Make picks
        PicksWidget(event: challenge.event),

        // If expandable, show invite option
        if (challenge.type == ChallengeType.expandable) ...[
          Divider(),
          Card(
            child: Column(
              children: [
                Icon(Icons.group_add, size: 48),
                Text('Want to make it bigger?'),
                Text('Invite more friends to join the competition!'),

                ElevatedButton.icon(
                  icon: Icon(Icons.person_add),
                  label: Text('INVITE FRIENDS'),
                  onPressed: () => _inviteMorePeople(),
                ),

                Text(
                  'Spots remaining: ${challenge.maxParticipants - challenge.participants.length}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        // Accept button
        ElevatedButton(
          onPressed: () => _acceptChallenge(),
          child: Text('ACCEPT CHALLENGE'),
        ),
      ],
    );
  }
}
```

### Data Structure

```javascript
challenges/{challengeId} {
  // Standard fields
  challengerId: "user_a",
  eventId: "ufc_295",
  sportType: "mma",
  type: "expandable",  // NEW type
  picks: { /* user_a picks */ },

  // Expandable settings
  expandableSettings: {
    allowGrowth: true,
    maxParticipants: 10,  // null for unlimited
    invitationCascade: true,  // Allow participants to invite

    // Conversion rules
    convertToPoolAt: 5,  // Convert when 5+ people join
    autoConvert: true,
    convertedToPoolId: null,  // Populated after conversion
  },

  // Wager settings
  wager: {
    enabled: true,
    type: "br_coins",
    entryAmount: 100,  // Each person pays 100 BR

    escrow: {
      "user_a": { amount: 100, status: "locked" },
      "friend_x": { amount: 100, status: "locked" }
    },

    // Prize distribution
    distribution: {
      type: "winner_take_all" | "top_3" | "proportional",
      percentages: {
        "1st": 70,
        "2nd": 20,
        "3rd": 10
      }
    }
  },

  // Participants with invitation chain
  participants: [{
    userId: "friend_x",
    invitedBy: "user_a",
    acceptedAt: timestamp,
    picks: { /* picks */ },
    canInvite: true,

    invitationsSent: [{
      userId: "friend_y",
      status: "pending"
    }]
  }],

  // Growth tracking
  growthMetrics: {
    totalInvited: 10,
    totalAccepted: 5,
    invitationLevels: 3,  // How many degrees of separation
    viralCoefficient: 2.5  // Avg invites per participant
  }
}
```

### Conversion Logic

#### When to Convert to Pool
```dart
class ChallengeToPoolConverter {
  Future<void> checkConversion(String challengeId) async {
    final challenge = await _challengeService.getChallenge(challengeId);

    // Check conversion criteria
    final shouldConvert =
      challenge.expandableSettings.autoConvert &&
      challenge.participants.length >= challenge.expandableSettings.convertToPoolAt;

    if (!shouldConvert) return;

    // Convert to pool
    final pool = await _convertToPool(challenge);

    // Update challenge document
    await _challengeService.updateChallenge(challengeId, {
      'expandableSettings.convertedToPoolId': pool.id,
      'status': 'converted_to_pool',
    });

    // Notify all participants
    await _notifyParticipants(challenge, pool);
  }

  Future<Pool> _convertToPool(Challenge challenge) async {
    return await PoolService().createPool(
      type: 'challenge_pool',
      createdFrom: challenge.id,
      creator: challenge.challengerId,

      eventId: challenge.eventId,
      sportType: challenge.sportType,

      // Transfer participants
      members: challenge.participants.map((p) => p.userId).toList(),

      // Transfer wager settings
      entryFee: challenge.wager.entryAmount,
      currency: challenge.wager.type,

      // Calculate prize pool
      prizePool: challenge.wager.entryAmount * challenge.participants.length,

      // Distribution rules
      payoutStructure: challenge.wager.distribution,

      // Keep it private
      visibility: 'private',
      allowNewMembers: challenge.expandableSettings.allowGrowth,
      maxMembers: challenge.expandableSettings.maxParticipants,
    );
  }
}
```

### Notification Flow

```dart
// When challenge converts to pool
class ConversionNotification {
  Future<void> notifyParticipants(Challenge challenge, Pool pool) async {
    for (final participant in challenge.participants) {
      await _sendNotification(
        userId: participant.userId,
        title: 'Challenge Upgraded! 🎉',
        body: 'Your challenge grew into a pool with ${pool.members.length} people! Prize pool: ${pool.prizePool} ${pool.currency}',
        data: {
          'type': 'challenge_converted',
          'challengeId': challenge.id,
          'poolId': pool.id,
        },
      );
    }
  }
}
```

---

## Scenario 4: Private Pool Creation

### Description
User creates a **private, invite-only pool** from scratch for an organized group competition.

### User Story
> "I want to create a private pool for my fantasy league friends. Only invited people can join, and I want to set an entry fee."

### Status
✅ **EXISTING FEATURE** - Enhance with challenge button integration

### User Flow
```
User Selects Event → [CREATE PRIVATE POOL] → Set Pool Rules
→ Set Entry Fee (BR/VC/Cash) → Invite Friends → Friends Join
→ Everyone Makes Picks → Compete for Prize Pool
```

### UI Enhancement

#### Add to Challenge Options
```dart
Future<void> _showChallengeOptions() async {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      children: [
        Text('Competition Options', style: AppTheme.neonText(fontSize: 20)),

        // Option 1: Simple Challenge (Existing)
        _OptionCard(
          icon: Icons.people,
          title: 'Quick Challenge',
          subtitle: '1-on-1 or small group, optional wager',
          onTap: () => _createSimpleChallenge(),
        ),

        // Option 2: Expandable Challenge (New)
        _OptionCard(
          icon: Icons.group_add,
          title: 'Expandable Challenge',
          subtitle: 'Start small, let it grow organically',
          badge: 'NEW',
          onTap: () => _createExpandableChallenge(),
        ),

        // Option 3: Private Pool (Enhanced)
        _OptionCard(
          icon: Icons.lock,
          title: 'Private Pool',
          subtitle: 'Organized competition with entry fee',
          onTap: () => _createPrivatePool(),
        ),

        // Option 4: Join/Invite to Pool (Existing)
        if (_hasJoinedPool)
          _OptionCard(
            icon: Icons.person_add,
            title: 'Invite to Pool',
            subtitle: 'Invite friends to your current pool',
            onTap: () => _inviteToCurrentPool(),
          ),
      ],
    ),
  );
}
```

#### Private Pool Creation Form
```dart
class PrivatePoolCreationSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Create Private Pool'),

        // Pool name
        TextField(
          decoration: InputDecoration(
            labelText: 'Pool Name',
            hintText: 'Fantasy League UFC 295',
          ),
        ),

        // Entry fee type
        SegmentedButton(
          segments: [
            ButtonSegment(value: 'br_coins', label: Text('BR Coins')),
            ButtonSegment(value: 'vc_coins', label: Text('Victory Coins')),
            ButtonSegment(value: 'cash', label: Text('Cash')),
          ],
        ),

        // Entry amount
        TextField(
          decoration: InputDecoration(
            labelText: 'Entry Fee',
            prefix: Text(selectedCurrency == 'cash' ? '\$' : ''),
          ),
        ),

        // Max participants
        TextField(
          decoration: InputDecoration(
            labelText: 'Max Participants',
            hintText: '20',
          ),
        ),

        // Prize distribution
        ExpansionTile(
          title: Text('Prize Distribution'),
          children: [
            RadioListTile(
              title: Text('Winner Take All'),
              subtitle: Text('1st place gets 100%'),
              value: 'winner_take_all',
            ),
            RadioListTile(
              title: Text('Top 3'),
              subtitle: Text('1st: 60%, 2nd: 30%, 3rd: 10%'),
              value: 'top_3',
            ),
            RadioListTile(
              title: Text('Custom'),
              value: 'custom',
            ),
          ],
        ),

        // Privacy settings
        SwitchListTile(
          title: Text('Private Pool'),
          subtitle: Text('Only invited friends can join'),
          value: isPrivate,
        ),

        SwitchListTile(
          title: Text('Allow Friends to Invite'),
          subtitle: Text('Members can invite their friends'),
          value: allowMemberInvites,
        ),

        // Create button
        ElevatedButton(
          onPressed: _createPool,
          child: Text('CREATE POOL'),
        ),
      ],
    );
  }
}
```

### Data Structure

```javascript
pools/{poolId} {
  // Standard pool fields
  creator: "user_a",
  type: "private_pool",
  visibility: "private",

  eventId: "ufc_295",
  sportType: "mma",

  // Entry fee configuration
  entryFee: {
    amount: 100,
    currency: "br_coins" | "vc_coins" | "cash",

    // For BR/VC coins
    escrow: {
      "user_a": { amount: 100, status: "locked" }
    }
  },

  // Members
  members: ["user_a", "friend_x", "friend_y"],
  maxMembers: 20,

  // Invitation control
  inviteSettings: {
    allowMemberInvites: true,
    requireApproval: false,  // Creator must approve new members
    inviteCode: "ABC123",    // Optional invite code
  },

  // Prize pool
  prizePool: {
    total: 500,  // 5 people × 100 BR
    currency: "br_coins",

    distribution: {
      type: "top_3",
      payouts: {
        "1st": { percentage: 60, amount: 300 },
        "2nd": { percentage: 30, amount: 150 },
        "3rd": { percentage: 10, amount: 50 }
      }
    }
  },

  // Picks
  picks: {
    "user_a": { /* picks */ },
    "friend_x": { /* picks */ }
  },

  // Status
  status: "open" | "closed" | "in_progress" | "completed",
  closeTime: timestamp,
}
```

---

## Wagering Options

### Supported Currencies

```dart
enum WagerCurrency {
  none,      // Free competition
  brCoins,   // BR Coins (in-app currency)
  vcCoins,   // Victory Coins (premium currency)
  cash,      // Real money (via pool system)
}
```

### BR Coins (Bragging Rights Coins)

**What They Are:**
- In-app currency earned through gameplay
- Free to earn, can be purchased
- Used for challenges and small wagers

**Use Cases:**
- Small friendly wagers (10-500 BR)
- Practice competitions
- Daily challenges

**Implementation:**
```dart
class BRCoinWager {
  Future<void> lockCoins(String userId, double amount) async {
    // Check balance
    final balance = await _walletService.getBRBalance(userId);
    if (balance < amount) throw InsufficientFundsException();

    // Lock coins in escrow
    await _walletService.transferToEscrow(
      userId: userId,
      amount: amount,
      currency: 'br_coins',
      reason: 'challenge_wager',
      challengeId: challengeId,
    );
  }

  Future<void> payoutWinner(String winnerId, double amount) async {
    await _walletService.transferFromEscrow(
      userId: winnerId,
      amount: amount,
      currency: 'br_coins',
      reason: 'challenge_payout',
    );
  }
}
```

### Victory Coins (VC)

**What They Are:**
- Premium in-app currency
- Purchased with real money
- Higher value, used for serious competitions

**Use Cases:**
- Competitive challenges (10-100 VC)
- Tournament entry fees
- High-stakes competitions

**Conversion:**
- 1 VC ≈ $1 USD equivalent value
- Cannot be converted back to cash (per app store rules)

**Implementation:**
```dart
class VCWager {
  Future<void> lockVC(String userId, double amount) async {
    // Check VC balance
    final vcBalance = await _walletService.getVCBalance(userId);
    if (vcBalance < amount) throw InsufficientVCException();

    // Lock VC in escrow
    await _walletService.lockVC(
      userId: userId,
      amount: amount,
      reason: 'challenge_wager',
      challengeId: challengeId,
    );
  }
}
```

### Wager Rules

#### Escrow System
```javascript
// All wagers held in escrow until event completes
escrow_transactions/{transactionId} {
  challengeId: "challenge_123",
  userId: "user_a",
  amount: 100,
  currency: "br_coins",
  status: "locked",
  lockedAt: timestamp,

  // Released after event
  releaseConditions: {
    eventCompleted: false,
    resultsVerified: false,
    disputeResolved: true
  }
}
```

#### Tie Handling
```dart
enum TieRule {
  refund,     // Everyone gets money back
  split,      // Prize pool split among tied players
  rollover,   // Roll into next challenge
}
```

#### House Rules
```dart
class WagerRules {
  // BR Coins
  static const brMinWager = 10.0;
  static const brMaxWager = 5000.0;
  static const brHouseCut = 0.0;  // No house cut for BR

  // Victory Coins
  static const vcMinWager = 1.0;
  static const vcMaxWager = 100.0;
  static const vcHouseCut = 0.0;  // No house cut for VC

  // Peer-to-peer, no platform fees
  static const platformFee = 0.0;
}
```

---

## Implementation Roadmap

### Phase 1: Enhanced User Challenge (Current + Wagers)
**Timeline:** 1-2 weeks
**Status:** In Progress

**Features:**
- [x] Basic 1-on-1 challenge (DONE)
- [x] Group challenges (DONE)
- [x] Open challenges (DONE)
- [ ] Add BR Coin wagering
- [ ] Add Victory Coin wagering
- [ ] Escrow system
- [ ] Winner payout automation

**Files to Modify:**
```
lib/models/challenge.dart (add wager fields)
lib/services/challenge_service.dart (add escrow logic)
lib/services/wallet_service.dart (BR/VC locking)
lib/widgets/challenge/friend_selection_sheet.dart (add wager UI)
```

### Phase 2: Pool Invitations
**Timeline:** 1 week
**Status:** Not Started

**Features:**
- [ ] Invite friends to existing pools
- [ ] Pool invitation links
- [ ] Invitation tracking
- [ ] SMS/WhatsApp share integration

**Files to Create:**
```
lib/widgets/pool/pool_invitation_sheet.dart
lib/services/pool_invitation_service.dart
```

**Files to Modify:**
```
lib/screens/pools/enhanced_pool_screen.dart
lib/services/pool_service.dart
```

### Phase 3: Expandable Challenges
**Timeline:** 2-3 weeks
**Status:** Design Phase

**Features:**
- [ ] Expandable challenge type
- [ ] Invitation cascading
- [ ] Challenge-to-pool conversion
- [ ] Auto-conversion at threshold
- [ ] Participant invitation permissions

**Files to Create:**
```
lib/models/expandable_challenge.dart
lib/services/expandable_challenge_service.dart
lib/widgets/challenge/expandable_challenge_sheet.dart
lib/services/challenge_to_pool_converter.dart
```

### Phase 4: Private Pool Enhancement
**Timeline:** 1 week
**Status:** Enhancement of Existing Feature

**Features:**
- [ ] Add to challenge flow
- [ ] BR/VC coin entry fees
- [ ] Enhanced privacy controls
- [ ] Member invitation permissions

**Files to Modify:**
```
lib/screens/pools/pool_creation_screen.dart
lib/services/pool_service.dart (add BR/VC support)
```

---

## Technical Architecture

### Service Layer

```dart
// Core services
challenge_service.dart          // Handles all challenge types
pool_service.dart              // Handles all pool types
wallet_service.dart            // BR/VC coin management
escrow_service.dart            // Wager locking/release

// Specialized services
pool_invitation_service.dart   // Pool invites
expandable_challenge_service.dart  // Expandable logic
challenge_to_pool_converter.dart   // Conversion logic
```

### Data Flow

```
User Action → Service Layer → Firestore
                ↓
          Wallet Service (if wager)
                ↓
          Escrow Service (lock funds)
                ↓
          Challenge/Pool Document Created
                ↓
          Notifications Sent
```

### Firestore Collections

```
/challenges           // All challenge documents
/pools               // All pool documents
/escrow_transactions // Locked wagers
/wallets            // User BR/VC balances
/pool_invitations   // Pool invite tracking
/challenge_notifications  // Challenge alerts
```

### Security Rules

```javascript
// Challenges with wagers
match /challenges/{challengeId} {
  allow create: if isAuthenticated() &&
    request.resource.data.challengerId == request.auth.uid &&
    validateWagerBalance(request.auth.uid, request.resource.data.wager);
}

// Escrow transactions
match /escrow_transactions/{transactionId} {
  allow read: if isAuthenticated() &&
    resource.data.userId == request.auth.uid;
  allow create: if isAuthenticated() &&
    hasRequiredBalance(request.auth.uid, request.resource.data);
  allow update: if false;  // Only cloud functions can release
}

// BR/VC wallets
match /wallets/{userId} {
  allow read: if isAuthenticated() &&
    request.auth.uid == userId;
  allow update: if isAuthenticated() &&
    request.auth.uid == userId &&
    validateBalanceChange();
}
```

---

## User Experience Examples

### Example 1: Simple Challenge with BR Wager

```
👤 User A: "I'll bet you 100 BR I pick more fights right!"
   Creates challenge → Selects Friend B → Sets 100 BR wager

💰 System: Locks 100 BR from User A's wallet

📱 Friend B: Gets notification → "User A challenged you for 100 BR"
   Accepts → System locks 100 BR from Friend B's wallet

🥊 Event Happens: User A gets 8/10, Friend B gets 6/10

🏆 System: User A wins! → Releases 200 BR to User A
   Final: User A gained 100 BR, Friend B lost 100 BR
```

### Example 2: Expandable Challenge Grows

```
👤 User A: "Let's start a small competition"
   Creates expandable challenge → Invites Friend B → No entry fee

👤 Friend B: Accepts → "Want to invite more?" → Invites C and D
👤 Friend C: Accepts → Invites E and F

📊 Challenge Status: 6 people now competing

🔄 System: "5+ people joined, converting to pool!"
   Creates private pool → All participants auto-joined

👥 Pool: 6 people competing, winner take all bragging rights
```

### Example 3: Private Pool with VC

```
👤 User A: "Creating Fantasy League pool for 50 VC"
   Sets up private pool → Entry: 50 VC → Max: 20 people
   Distribution: 60% / 30% / 10%

📨 Invites Friends: B, C, D, E, F (via SMS/WhatsApp)

💰 Friends Join: Each pays 50 VC → Prize pool: 350 VC

🥊 Event Happens: Scores calculated

🏆 Payouts:
   1st place (User C): 210 VC (60%)
   2nd place (User A): 105 VC (30%)
   3rd place (Friend B): 35 VC (10%)
```

---

## Analytics & Metrics

### Key Metrics to Track

**Challenge Metrics:**
```dart
- challenges_created (by type)
- challenges_accepted_rate
- average_time_to_accept
- wager_enabled_percentage
- average_wager_amount (by currency)
- challenge_completion_rate
```

**Pool Metrics:**
```dart
- private_pools_created
- pool_invitation_acceptance_rate
- average_pool_size
- total_prize_pools (by currency)
```

**Expandable Challenge Metrics:**
```dart
- expandable_challenges_created
- average_growth_rate
- conversion_to_pool_rate
- viral_coefficient (invites per person)
- max_participants_reached
```

**Wagering Metrics:**
```dart
- total_br_wagered
- total_vc_wagered
- average_wager_size
- wager_win_rate_by_user
- escrow_lock_duration
```

---

## Support & FAQ

### For Users

**Q: What's the difference between a challenge and a pool?**
A: Challenges are quick competitions between friends. Pools are organized competitions with entry fees and prize payouts.

**Q: Can I challenge someone without wagering?**
A: Yes! All challenges are free by default. Wagering is completely optional.

**Q: What are BR Coins and Victory Coins?**
A: BR Coins are in-app currency you earn by playing. Victory Coins are premium currency you purchase. Both can be used for wagers.

**Q: What happens if there's a tie?**
A: By default, everyone gets their wager back. You can also split the prize or roll it to the next challenge.

**Q: Can I cancel a challenge?**
A: Yes, before anyone accepts. Once accepted, both parties must agree to cancel, and all wagers are refunded.

---

## Future Enhancements

### Phase 5+: Advanced Features

**Tournament Mode:**
- Multi-round challenges
- Bracket-style elimination
- Championship prizes

**Leaderboards:**
- Challenge win/loss records
- Most BR/VC won
- Longest win streaks

**Achievements:**
- "First Blood" - Win first challenge
- "Underdog" - Win against higher ranked player
- "Streak Master" - 10 challenge win streak

**Social Features:**
- Challenge replays
- Trash talk comments
- Victory celebrations

---

## Conclusion

This specification outlines four distinct ways users can compete:

1. **Pool Invitations** - Join organized competitions
2. **User Challenges** - Quick 1-on-1 or small group battles
3. **Expandable Challenges** - Organic growth competitions
4. **Private Pools** - Structured group competitions

Each serves a unique purpose and can include optional wagering with BR Coins or Victory Coins, creating a complete social competition ecosystem.

**Next Steps:**
1. Implement BR/VC wagering for existing challenges
2. Add pool invitation feature
3. Design and build expandable challenges
4. Enhance private pool creation

---

**Document Version:** 1.0.0
**Last Updated:** September 29, 2025
**Status:** Living Document - Subject to Updates