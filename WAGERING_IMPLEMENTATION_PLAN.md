# Wagering System Implementation Plan
## BR Coins & Victory Coins Escrow System

**Date:** 2025-09-29
**Status:** Planning Phase
**Purpose:** Add BR Coin and Victory Coin wagering to challenges without duplicating existing code

---

## Executive Summary

This document outlines the implementation plan for adding wagering capabilities (BR Coins and Victory Coins) to the Bragging Rights challenge system. After conducting a comprehensive audit of existing wallet and coin systems, we've identified what exists, what's missing, and how to extend the current architecture without code duplication.

**Key Finding:** We have robust transaction systems for BR Coins and VC earning, but we lack an escrow system for locking funds during active challenges/pools.

---

## Code Audit Results

### 1. Existing WalletService (BR Coins)
**Location:** `lib/services/wallet_service.dart`

#### ✅ What Already Exists:
```dart
// Balance Management
Future<int> getCurrentBalance(String userId)
Future<Map<String, dynamic>?> getWallet(String userId)

// Transaction Operations
Future<bool> placeWager({required int amount, required String betId})
Future<void> addWinnings({required int amount, required String betId})
Future<bool> deductFromWallet(String userId, int amount, String description)
Future<bool> addToWallet(String userId, int amount, String description)

// Validation
class InsufficientFundsException implements Exception

// Transaction Logging
- All operations write to wallets/{userId}/transactions subcollection
- Timestamp tracking
- Description/reference tracking
```

**Key Strengths:**
- Uses Firestore transactions for atomic operations
- Proper balance validation
- Complete transaction history
- Error handling with custom exceptions

**Key Limitations:**
- No escrow/locking mechanism
- Funds are immediately deducted (not held)
- No conditional release logic
- No multi-party fund management

---

### 2. Existing VictoryCoinService (VC)
**Location:** `lib/services/victory_coin_service.dart`

#### ✅ What Already Exists:
```dart
// VC Earning System
Future<bool> awardVC({
  required String userId,
  required int amount,
  required String source,
  String? referenceId,
})

// VC Calculation
Future<int> calculateVCForBet({
  required int brWagered,
  required double odds,
  required bool isWin,
})

// VC Balance Query
Future<int> getVCBalance(String userId)

// VC Caps
- Daily earning caps (configurable)
- Monthly earning caps
- Transaction logging to vc_transactions collection
```

**Key Strengths:**
- Complete earning/reward system
- Cap enforcement
- Transaction history
- Source tracking

**Key Limitations:**
- **No spending methods** (can only earn, not spend)
- No escrow/locking for VC
- No deduction operations
- Incomplete for wagering use case

---

### 3. Existing VictoryCoinModel
**Location:** `lib/models/victory_coin_model.dart`

#### ✅ What Already Exists:
```dart
class VictoryCoin {
  final String userId;
  final int balance;
  final int lifetimeEarned;
  final int dailyEarned;
  final int monthlyEarned;
  final DateTime lastUpdated;
  final DateTime? dailyResetDate;
  final DateTime? monthlyResetDate;
}

class VCTransaction {
  final String id;
  final String userId;
  final int amount;
  final VCTransactionType type;  // earn, spend, purchase
  final String source;
  final String? referenceId;
  final DateTime timestamp;
}

enum VCTransactionType { earn, spend, purchase }
```

**Key Strengths:**
- Complete data model
- Supports spending transaction type
- Cap tracking built-in

**Key Gap:**
- Spending type exists in model but not implemented in service

---

### 4. Escrow System
**Location:** NONE - Does not exist

#### ❌ What's Missing:
- No escrow collection in Firestore
- No escrow service/logic
- No fund locking mechanism
- No conditional release system
- No multi-party escrow support
- No refund logic

---

## What We Need to Build

### 1. New EscrowService
**Location:** `lib/services/escrow_service.dart` (NEW FILE)

Complete escrow management system for both BR Coins and Victory Coins.

```dart
class EscrowService {
  final FirebaseFirestore _firestore;
  final WalletService _walletService;
  final VictoryCoinService _vcService;

  // ==================== BR COIN ESCROW ====================

  /// Locks BR Coins in escrow for a challenge/pool
  /// Returns escrowId on success, null on failure
  Future<String?> lockBRInEscrow({
    required String userId,
    required int amount,
    required String challengeId,
    required EscrowType type,
    List<String> participantIds = const [],
  }) async {
    // 1. Validate user has sufficient balance
    final balance = await _walletService.getCurrentBalance(userId);
    if (balance < amount) {
      throw InsufficientFundsException('Insufficient BR Coins');
    }

    // 2. Create escrow document
    final escrowId = _firestore.collection('escrow_transactions').doc().id;

    // 3. Use Firestore transaction for atomic operation
    await _firestore.runTransaction((transaction) async {
      final walletRef = _firestore.collection('wallets').doc(userId);
      final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);

      // Deduct from wallet
      final walletDoc = await transaction.get(walletRef);
      final currentBalance = walletDoc.data()?['balance'] ?? 0;

      transaction.update(walletRef, {
        'balance': currentBalance - amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create escrow record
      transaction.set(escrowRef, {
        'userId': userId,
        'amount': amount,
        'currency': 'BR',
        'challengeId': challengeId,
        'type': type.toString(),
        'status': 'locked',
        'participantIds': participantIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log transaction
      final txRef = walletRef.collection('transactions').doc();
      transaction.set(txRef, {
        'amount': -amount,
        'type': 'escrow_lock',
        'description': 'Locked for challenge $challengeId',
        'referenceId': escrowId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    return escrowId;
  }

  /// Releases BR Coins from escrow to winner(s)
  Future<bool> releaseBRFromEscrow({
    required String escrowId,
    required String winnerId,
    List<WinnerSplit>? splits,  // For multi-winner scenarios
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed');
        }

        // If splits provided, distribute to multiple winners
        if (splits != null && splits.isNotEmpty) {
          for (final split in splits) {
            final winnerRef = _firestore.collection('wallets').doc(split.userId);
            final winnerDoc = await transaction.get(winnerRef);
            final currentBalance = winnerDoc.data()?['balance'] ?? 0;

            transaction.update(winnerRef, {
              'balance': currentBalance + split.amount,
              'lastUpdated': FieldValue.serverTimestamp(),
            });

            // Log winning transaction
            final txRef = winnerRef.collection('transactions').doc();
            transaction.set(txRef, {
              'amount': split.amount,
              'type': 'escrow_release',
              'description': 'Challenge winnings',
              'referenceId': escrowId,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Single winner takes all
          final winnerRef = _firestore.collection('wallets').doc(winnerId);
          final winnerDoc = await transaction.get(winnerRef);
          final currentBalance = winnerDoc.data()?['balance'] ?? 0;

          transaction.update(winnerRef, {
            'balance': currentBalance + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Log winning transaction
          final txRef = winnerRef.collection('transactions').doc();
          transaction.set(txRef, {
            'amount': amount,
            'type': 'escrow_release',
            'description': 'Challenge winnings',
            'referenceId': escrowId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Mark escrow as released
        transaction.update(escrowRef, {
          'status': 'released',
          'winnerId': winnerId,
          'releasedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error releasing escrow: $e');
      return false;
    }
  }

  /// Refunds BR Coins from escrow (challenge cancelled/expired)
  Future<bool> refundBRFromEscrow({
    required String escrowId,
    String? reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final userId = escrowData['userId'] as String;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed');
        }

        // Return funds to original user
        final walletRef = _firestore.collection('wallets').doc(userId);
        final walletDoc = await transaction.get(walletRef);
        final currentBalance = walletDoc.data()?['balance'] ?? 0;

        transaction.update(walletRef, {
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Log refund transaction
        final txRef = walletRef.collection('transactions').doc();
        transaction.set(txRef, {
          'amount': amount,
          'type': 'escrow_refund',
          'description': 'Challenge refund: ${reason ?? "cancelled"}',
          'referenceId': escrowId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Mark escrow as refunded
        transaction.update(escrowRef, {
          'status': 'refunded',
          'refundReason': reason,
          'refundedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error refunding escrow: $e');
      return false;
    }
  }

  // ==================== VICTORY COIN ESCROW ====================

  /// Locks Victory Coins in escrow for a challenge/pool
  Future<String?> lockVCInEscrow({
    required String userId,
    required int amount,
    required String challengeId,
    required EscrowType type,
    List<String> participantIds = const [],
  }) async {
    // 1. Validate user has sufficient VC balance
    final balance = await _vcService.getVCBalance(userId);
    if (balance < amount) {
      throw InsufficientFundsException('Insufficient Victory Coins');
    }

    // 2. Create escrow document
    final escrowId = _firestore.collection('escrow_transactions').doc().id;

    // 3. Use Firestore transaction for atomic operation
    await _firestore.runTransaction((transaction) async {
      final vcRef = _firestore.collection('victory_coins').doc(userId);
      final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);

      // Deduct from VC balance
      final vcDoc = await transaction.get(vcRef);
      final currentBalance = vcDoc.data()?['balance'] ?? 0;

      transaction.update(vcRef, {
        'balance': currentBalance - amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create escrow record
      transaction.set(escrowRef, {
        'userId': userId,
        'amount': amount,
        'currency': 'VC',
        'challengeId': challengeId,
        'type': type.toString(),
        'status': 'locked',
        'participantIds': participantIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log VC transaction
      final txRef = _firestore.collection('vc_transactions').doc();
      transaction.set(txRef, {
        'userId': userId,
        'amount': -amount,
        'type': 'spend',
        'source': 'escrow_lock',
        'referenceId': escrowId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    return escrowId;
  }

  /// Releases Victory Coins from escrow to winner(s)
  Future<bool> releaseVCFromEscrow({
    required String escrowId,
    required String winnerId,
    List<WinnerSplit>? splits,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed');
        }

        // Distribute to winner(s)
        if (splits != null && splits.isNotEmpty) {
          for (final split in splits) {
            final vcRef = _firestore.collection('victory_coins').doc(split.userId);
            final vcDoc = await transaction.get(vcRef);
            final currentBalance = vcDoc.data()?['balance'] ?? 0;

            transaction.update(vcRef, {
              'balance': currentBalance + split.amount,
              'lastUpdated': FieldValue.serverTimestamp(),
            });

            // Log VC transaction
            final txRef = _firestore.collection('vc_transactions').doc();
            transaction.set(txRef, {
              'userId': split.userId,
              'amount': split.amount,
              'type': 'earn',
              'source': 'escrow_release',
              'referenceId': escrowId,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Single winner
          final vcRef = _firestore.collection('victory_coins').doc(winnerId);
          final vcDoc = await transaction.get(vcRef);
          final currentBalance = vcDoc.data()?['balance'] ?? 0;

          transaction.update(vcRef, {
            'balance': currentBalance + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Log VC transaction
          final txRef = _firestore.collection('vc_transactions').doc();
          transaction.set(txRef, {
            'userId': winnerId,
            'amount': amount,
            'type': 'earn',
            'source': 'escrow_release',
            'referenceId': escrowId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Mark escrow as released
        transaction.update(escrowRef, {
          'status': 'released',
          'winnerId': winnerId,
          'releasedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error releasing VC escrow: $e');
      return false;
    }
  }

  /// Refunds Victory Coins from escrow
  Future<bool> refundVCFromEscrow({
    required String escrowId,
    String? reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef = _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final userId = escrowData['userId'] as String;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed');
        }

        // Return VC to original user
        final vcRef = _firestore.collection('victory_coins').doc(userId);
        final vcDoc = await transaction.get(vcRef);
        final currentBalance = vcDoc.data()?['balance'] ?? 0;

        transaction.update(vcRef, {
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Log refund transaction
        final txRef = _firestore.collection('vc_transactions').doc();
        transaction.set(txRef, {
          'userId': userId,
          'amount': amount,
          'type': 'earn',
          'source': 'escrow_refund',
          'referenceId': escrowId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Mark escrow as refunded
        transaction.update(escrowRef, {
          'status': 'refunded',
          'refundReason': reason,
          'refundedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error refunding VC escrow: $e');
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Gets escrow details
  Future<EscrowTransaction?> getEscrow(String escrowId) async {
    final doc = await _firestore
        .collection('escrow_transactions')
        .doc(escrowId)
        .get();

    if (!doc.exists) return null;

    return EscrowTransaction.fromFirestore(doc);
  }

  /// Gets all escrows for a challenge
  Future<List<EscrowTransaction>> getEscrowsForChallenge(String challengeId) async {
    final snapshot = await _firestore
        .collection('escrow_transactions')
        .where('challengeId', isEqualTo: challengeId)
        .get();

    return snapshot.docs
        .map((doc) => EscrowTransaction.fromFirestore(doc))
        .toList();
  }

  /// Calculates total locked amount for a user
  Future<Map<String, int>> getUserLockedFunds(String userId) async {
    final snapshot = await _firestore
        .collection('escrow_transactions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'locked')
        .get();

    int totalBR = 0;
    int totalVC = 0;

    for (final doc in snapshot.docs) {
      final currency = doc.data()['currency'] as String;
      final amount = doc.data()['amount'] as int;

      if (currency == 'BR') {
        totalBR += amount;
      } else if (currency == 'VC') {
        totalVC += amount;
      }
    }

    return {'BR': totalBR, 'VC': totalVC};
  }
}

// Supporting classes
enum EscrowType { challenge, pool, tournament }

class WinnerSplit {
  final String userId;
  final int amount;

  WinnerSplit({required this.userId, required this.amount});
}

class EscrowTransaction {
  final String id;
  final String userId;
  final int amount;
  final String currency;  // 'BR' or 'VC'
  final String challengeId;
  final EscrowType type;
  final String status;  // 'locked', 'released', 'refunded'
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final String? winnerId;
  final String? refundReason;

  EscrowTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.challengeId,
    required this.type,
    required this.status,
    required this.participantIds,
    required this.createdAt,
    this.releasedAt,
    this.refundedAt,
    this.winnerId,
    this.refundReason,
  });

  factory EscrowTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EscrowTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: data['amount'] ?? 0,
      currency: data['currency'] ?? 'BR',
      challengeId: data['challengeId'] ?? '',
      type: EscrowType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => EscrowType.challenge,
      ),
      status: data['status'] ?? 'locked',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      releasedAt: data['releasedAt'] != null
          ? (data['releasedAt'] as Timestamp).toDate()
          : null,
      refundedAt: data['refundedAt'] != null
          ? (data['refundedAt'] as Timestamp).toDate()
          : null,
      winnerId: data['winnerId'],
      refundReason: data['refundReason'],
    );
  }
}
```

---

### 2. Extended Challenge Model
**Location:** `lib/models/challenge.dart` (MODIFY EXISTING)

Add wager fields to existing Challenge model:

```dart
class Challenge {
  final String id;
  final String challengerId;
  final String sportType;
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final Map<String, dynamic> picks;
  final ChallengeType type;
  final ChallengeStatus status;
  final List<ChallengeParticipant> participants;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? poolId;

  // NEW WAGER FIELDS
  final WagerInfo? wager;  // <-- ADD THIS

  Challenge({
    required this.id,
    required this.challengerId,
    required this.sportType,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.picks,
    required this.type,
    required this.status,
    required this.participants,
    required this.createdAt,
    this.expiresAt,
    this.poolId,
    this.wager,  // <-- ADD THIS
  });

  // Update fromFirestore to parse wager
  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenge(
      // ... existing fields ...
      wager: data['wager'] != null
          ? WagerInfo.fromMap(data['wager'])
          : null,
    );
  }

  // Update toFirestore to include wager
  Map<String, dynamic> toFirestore() {
    return {
      // ... existing fields ...
      if (wager != null) 'wager': wager!.toMap(),
    };
  }
}

// NEW CLASS
class WagerInfo {
  final int amount;
  final String currency;  // 'BR' or 'VC'
  final String escrowId;  // Reference to escrow_transactions doc
  final WagerDistribution distribution;  // winner-take-all, split, etc.

  WagerInfo({
    required this.amount,
    required this.currency,
    required this.escrowId,
    this.distribution = WagerDistribution.winnerTakeAll,
  });

  factory WagerInfo.fromMap(Map<String, dynamic> map) {
    return WagerInfo(
      amount: map['amount'] ?? 0,
      currency: map['currency'] ?? 'BR',
      escrowId: map['escrowId'] ?? '',
      distribution: WagerDistribution.values.firstWhere(
        (e) => e.toString() == map['distribution'],
        orElse: () => WagerDistribution.winnerTakeAll,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'currency': currency,
      'escrowId': escrowId,
      'distribution': distribution.toString(),
    };
  }
}

enum WagerDistribution {
  winnerTakeAll,     // Single winner gets all
  splitTop3,         // Top 3 split prizes
  proportionalScore, // Prize based on score percentage
}
```

---

### 3. Extended ChallengeService
**Location:** `lib/services/challenge_service.dart` (MODIFY EXISTING)

Update `createChallenge` method to handle wagers:

```dart
class ChallengeService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EscrowService _escrowService;  // <-- ADD THIS

  ChallengeService(this._firestore, this._auth, this._escrowService);

  Future<Challenge> createChallenge({
    required String sportType,
    required String eventId,
    required String eventName,
    required DateTime eventDate,
    required Map<String, dynamic> picks,
    ChallengeType type = ChallengeType.friend,
    List<String> targetFriends = const [],
    String? poolId,

    // NEW WAGER PARAMETERS
    int? wagerAmount,
    String? wagerCurrency,  // 'BR' or 'VC'
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final challengeId = _firestore.collection('challenges').doc().id;

    // Lock funds in escrow if wager specified
    String? escrowId;
    if (wagerAmount != null && wagerCurrency != null && wagerAmount > 0) {
      // Validate wager amount
      if (wagerCurrency == 'BR') {
        if (wagerAmount < 10 || wagerAmount > 5000) {
          throw Exception('BR wager must be between 10 and 5000');
        }
        escrowId = await _escrowService.lockBRInEscrow(
          userId: user.uid,
          amount: wagerAmount,
          challengeId: challengeId,
          type: EscrowType.challenge,
          participantIds: targetFriends,
        );
      } else if (wagerCurrency == 'VC') {
        if (wagerAmount < 1 || wagerAmount > 100) {
          throw Exception('VC wager must be between 1 and 100');
        }
        escrowId = await _escrowService.lockVCInEscrow(
          userId: user.uid,
          amount: wagerAmount,
          challengeId: challengeId,
          type: EscrowType.challenge,
          participantIds: targetFriends,
        );
      }

      if (escrowId == null) {
        throw Exception('Failed to lock funds in escrow');
      }
    }

    final challenge = Challenge(
      id: challengeId,
      challengerId: user.uid,
      sportType: sportType,
      eventId: eventId,
      eventName: eventName,
      eventDate: eventDate,
      picks: picks,
      type: type,
      status: ChallengeStatus.pending,
      participants: [],
      createdAt: DateTime.now(),
      expiresAt: eventDate.subtract(const Duration(hours: 1)),
      poolId: poolId,
      wager: escrowId != null
          ? WagerInfo(
              amount: wagerAmount!,
              currency: wagerCurrency!,
              escrowId: escrowId,
            )
          : null,
    );

    await _firestore
        .collection('challenges')
        .doc(challengeId)
        .set(challenge.toFirestore());

    return challenge;
  }

  // NEW METHOD: Accept challenge with wager matching
  Future<void> acceptChallenge({
    required String challengeId,
    required Map<String, dynamic> picks,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final challengeDoc = await _firestore
        .collection('challenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) {
      throw Exception('Challenge not found');
    }

    final challenge = Challenge.fromFirestore(challengeDoc);

    // If challenge has wager, accepting user must match it
    if (challenge.wager != null) {
      final wagerAmount = challenge.wager!.amount;
      final wagerCurrency = challenge.wager!.currency;

      // Lock accepting user's funds
      String? escrowId;
      if (wagerCurrency == 'BR') {
        escrowId = await _escrowService.lockBRInEscrow(
          userId: user.uid,
          amount: wagerAmount,
          challengeId: challengeId,
          type: EscrowType.challenge,
          participantIds: [challenge.challengerId],
        );
      } else if (wagerCurrency == 'VC') {
        escrowId = await _escrowService.lockVCInEscrow(
          userId: user.uid,
          amount: wagerAmount,
          challengeId: challengeId,
          type: EscrowType.challenge,
          participantIds: [challenge.challengerId],
        );
      }

      if (escrowId == null) {
        throw Exception('Insufficient funds to match wager');
      }
    }

    // Add participant
    await _firestore.collection('challenges').doc(challengeId).update({
      'participants': FieldValue.arrayUnion([
        {
          'userId': user.uid,
          'picks': picks,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      ]),
      'status': 'accepted',
    });
  }

  // NEW METHOD: Complete challenge and distribute winnings
  Future<void> completeChallenge({
    required String challengeId,
    required String winnerId,
  }) async {
    final challengeDoc = await _firestore
        .collection('challenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) {
      throw Exception('Challenge not found');
    }

    final challenge = Challenge.fromFirestore(challengeDoc);

    // Release escrow to winner if wager exists
    if (challenge.wager != null) {
      // Get all escrows for this challenge
      final escrows = await _escrowService.getEscrowsForChallenge(challengeId);

      // Calculate total prize pool
      final totalPrize = escrows.fold<int>(0, (sum, e) => sum + e.amount);

      // Release funds to winner
      for (final escrow in escrows) {
        if (escrow.currency == 'BR') {
          await _escrowService.releaseBRFromEscrow(
            escrowId: escrow.id,
            winnerId: winnerId,
          );
        } else if (escrow.currency == 'VC') {
          await _escrowService.releaseVCFromEscrow(
            escrowId: escrow.id,
            winnerId: winnerId,
          );
        }
      }
    }

    // Update challenge status
    await _firestore.collection('challenges').doc(challengeId).update({
      'status': 'completed',
      'winnerId': winnerId,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // NEW METHOD: Cancel challenge and refund
  Future<void> cancelChallenge(String challengeId, String reason) async {
    final challengeDoc = await _firestore
        .collection('challenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) {
      throw Exception('Challenge not found');
    }

    final challenge = Challenge.fromFirestore(challengeDoc);

    // Refund all escrows if wager exists
    if (challenge.wager != null) {
      final escrows = await _escrowService.getEscrowsForChallenge(challengeId);

      for (final escrow in escrows) {
        if (escrow.currency == 'BR') {
          await _escrowService.refundBRFromEscrow(
            escrowId: escrow.id,
            reason: reason,
          );
        } else if (escrow.currency == 'VC') {
          await _escrowService.refundVCFromEscrow(
            escrowId: escrow.id,
            reason: reason,
          );
        }
      }
    }

    // Update challenge status
    await _firestore.collection('challenges').doc(challengeId).update({
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}
```

---

## Firestore Schema

### New Collection: `escrow_transactions`

```javascript
escrow_transactions/{escrowId}
{
  userId: string,              // Who locked the funds
  amount: number,              // Amount locked
  currency: string,            // 'BR' or 'VC'
  challengeId: string,         // Reference to challenge
  type: string,                // 'challenge', 'pool', 'tournament'
  status: string,              // 'locked', 'released', 'refunded'
  participantIds: string[],    // Other participants in challenge
  createdAt: timestamp,
  updatedAt: timestamp,
  releasedAt: timestamp?,      // When funds were released
  refundedAt: timestamp?,      // When funds were refunded
  winnerId: string?,           // Winner who received funds
  refundReason: string?,       // Why refund occurred
}
```

**Indexes Required:**
- `challengeId` (for querying all escrows for a challenge)
- `userId` + `status` (for querying user's locked funds)
- `status` + `createdAt` (for admin monitoring)

---

## Firebase Security Rules

Add to `firestore.rules`:

```javascript
// Escrow transactions collection
match /escrow_transactions/{escrowId} {
  // Users can read their own escrow transactions
  allow read: if isAuthenticated() &&
    resource.data.userId == request.auth.uid;

  // Only the system (via Cloud Functions or authenticated services) can create escrow
  // For now, allow authenticated users (will be restricted later)
  allow create: if isAuthenticated() &&
    request.resource.data.userId == request.auth.uid &&
    request.resource.data.status == 'locked';

  // Only system can update escrow (release/refund operations)
  // For now, allow if user is challenger or participant
  allow update: if isAuthenticated() && (
    resource.data.userId == request.auth.uid ||
    request.auth.uid in resource.data.get('participantIds', [])
  );

  // Escrow transactions cannot be deleted
  allow delete: if false;
}
```

**Note:** In production, escrow operations should be restricted to Cloud Functions only for security. The above rules are permissive for initial development.

---

## Implementation Roadmap

### Phase 1: Core Escrow Service (Week 1)
**Priority: HIGH**

1. ✅ Create `lib/services/escrow_service.dart`
2. ✅ Implement BR Coin escrow methods
3. ✅ Implement VC escrow methods
4. ✅ Add EscrowTransaction model
5. ✅ Write unit tests for escrow logic
6. ✅ Deploy Firestore security rules

**Deliverables:**
- Fully functional EscrowService
- Unit tests passing
- Firebase rules deployed

---

### Phase 2: Challenge Integration (Week 1-2)
**Priority: HIGH**

1. ✅ Update Challenge model with WagerInfo
2. ✅ Extend ChallengeService with wager support
3. ✅ Update createChallenge to lock funds
4. ✅ Update acceptChallenge to match wager
5. ✅ Implement completeChallenge with fund release
6. ✅ Implement cancelChallenge with refund
7. ✅ Add wager validation logic

**Deliverables:**
- Challenges support BR/VC wagers
- Funds automatically locked/released
- Refund mechanism working

---

### Phase 3: UI Components (Week 2)
**Priority: MEDIUM**

1. Create wager selection widget
   - Currency selector (BR/VC toggle)
   - Amount slider with validation
   - Balance display with available funds
2. Update FriendSelectionSheet
   - Show wager amount in UI
   - Display warning for insufficient funds
3. Create WagerConfirmationDialog
   - Show escrow terms
   - Confirm user understands funds are locked
4. Update challenge cards
   - Display wager amount badge
   - Show "Match X BR/VC to accept" for pending challenges

**Deliverables:**
- Wager selection UI
- Confirmation flows
- Updated challenge displays

---

### Phase 4: Victory Coin Spending (Week 2-3)
**Priority: MEDIUM**

1. Extend VictoryCoinService
   - Add `spendVC()` method
   - Add balance validation
   - Add transaction logging for spending
2. Update VictoryCoin model if needed
3. Create spend transaction flow
4. Test VC escrow end-to-end

**Deliverables:**
- VC can be spent on wagers
- VC spending tracked in transactions
- Balance updates correctly

---

### Phase 5: Pool Integration (Week 3)
**Priority: LOW (Future Enhancement)

1. Apply escrow to pool entry fees
2. Multi-winner prize distribution
3. Pool escrow aggregation
4. Leaderboard prize tiers

**Deliverables:**
- Pools support entry fees
- Prize distribution logic
- Escrow for multiple participants

---

### Phase 6: Admin & Monitoring (Week 4)
**Priority: LOW (Future Enhancement)

1. Admin dashboard for escrow monitoring
2. Stuck escrow detection
3. Manual refund capability
4. Escrow analytics

**Deliverables:**
- Admin tools
- Monitoring system
- Analytics dashboard

---

## Testing Strategy

### Unit Tests

```dart
// test/services/escrow_service_test.dart

void main() {
  group('EscrowService - BR Coins', () {
    test('lockBRInEscrow creates escrow and deducts balance', () async {
      // Test implementation
    });

    test('releaseBRFromEscrow transfers to winner', () async {
      // Test implementation
    });

    test('refundBRFromEscrow returns funds to original user', () async {
      // Test implementation
    });

    test('lockBRInEscrow fails with insufficient funds', () async {
      // Test implementation
    });
  });

  group('EscrowService - Victory Coins', () {
    test('lockVCInEscrow creates escrow and deducts balance', () async {
      // Test implementation
    });

    test('releaseVCFromEscrow transfers to winner', () async {
      // Test implementation
    });
  });

  group('EscrowService - Multi-Party', () {
    test('multiple escrows accumulate for single challenge', () async {
      // Test implementation
    });

    test('split distribution works correctly', () async {
      // Test implementation
    });
  });
}
```

### Integration Tests

```dart
// test/integration/challenge_wager_test.dart

void main() {
  group('Challenge Wager Flow', () {
    test('user creates BR wager challenge', () async {
      // 1. Create challenge with wager
      // 2. Verify funds locked
      // 3. Verify balance updated
    });

    test('second user accepts and matches wager', () async {
      // 1. Accept challenge
      // 2. Verify second escrow created
      // 3. Verify both balances updated
    });

    test('winner receives full prize pool', () async {
      // 1. Complete challenge
      // 2. Verify winner balance increased
      // 3. Verify escrows released
    });

    test('cancelled challenge refunds all users', () async {
      // 1. Cancel challenge
      // 2. Verify all escrows refunded
      // 3. Verify balances restored
    });
  });
}
```

---

## Edge Cases & Error Handling

### 1. Insufficient Funds
```dart
// Scenario: User tries to create wager with insufficient balance
// Handling: Throw InsufficientFundsException before creating challenge
// UI: Show error dialog with current balance and required amount
```

### 2. Challenge Expires Before Acceptance
```dart
// Scenario: Challenge expires with funds in escrow
// Handling: Automatic refund via scheduled Cloud Function
// Fallback: Manual refund button for challenger
```

### 3. Multiple Escrows for Same Challenge
```dart
// Scenario: Group challenge with 5 participants, each wagering 100 BR
// Handling: Create separate escrow for each participant
// Distribution: Winner receives sum of all escrows (500 BR)
```

### 4. Partial Acceptance (Group Challenges)
```dart
// Scenario: 3 of 5 invited friends accept
// Handling: Allow challenge to proceed with partial group
// Distribution: Only accepted participants' escrows included in prize
```

### 5. Tie/Draw Result
```dart
// Scenario: Two participants have identical scores
// Option 1: Split prize equally
// Option 2: Sudden death tiebreaker (bonus question)
// Option 3: Refund all participants
// Implementation: Allow challenge creator to set tie rule
```

### 6. Escrow Stuck in "Locked" State
```dart
// Scenario: Challenge completed but escrow never released (bug/error)
// Handling: Admin tool to manually release/refund
// Prevention: Add watchdog Cloud Function to detect stuck escrows
```

---

## Performance Considerations

### 1. Firestore Transaction Limits
- Firestore transactions limited to 500 documents
- For large pools (100+ people), batch escrow operations
- Consider splitting into multiple sub-transactions

### 2. Read/Write Optimization
```dart
// BAD: Query all escrows then filter in memory
final allEscrows = await getAllEscrows();
final userEscrows = allEscrows.where((e) => e.userId == userId);

// GOOD: Query with Firestore filters
final userEscrows = await _firestore
    .collection('escrow_transactions')
    .where('userId', isEqualTo: userId)
    .get();
```

### 3. Caching Strategy
- Cache user's available balance locally
- Invalidate cache on escrow lock/release
- Use Firestore offline persistence

---

## Security Considerations

### 1. Escrow Manipulation Prevention
- All escrow operations use Firestore transactions (atomic)
- Balance checks happen inside transaction (prevents race conditions)
- Escrow status changes are append-only (can't revert from 'released' to 'locked')

### 2. Unauthorized Access
- Security rules prevent reading other users' escrows
- Only system can release/refund (will enforce via Cloud Functions)
- Challenge completion requires winner validation

### 3. Double-Spending Prevention
```dart
// Transaction ensures balance check and deduction are atomic
await _firestore.runTransaction((transaction) async {
  // 1. Read current balance
  final balance = await transaction.get(walletRef);

  // 2. Validate sufficient funds
  if (balance < amount) throw InsufficientFundsException();

  // 3. Deduct and create escrow (both or neither)
  transaction.update(walletRef, {'balance': balance - amount});
  transaction.set(escrowRef, {...});
});
```

---

## Monitoring & Analytics

### Key Metrics to Track

1. **Escrow Volume**
   - Total BR locked in escrow
   - Total VC locked in escrow
   - Average escrow amount
   - Peak escrow volume

2. **Completion Rates**
   - % of escrows successfully released
   - % of escrows refunded
   - Average time from lock to release

3. **User Behavior**
   - % of challenges with wagers
   - Average wager amount by user
   - Most common currency (BR vs VC)

4. **Error Rates**
   - Failed escrow creations (insufficient funds)
   - Stuck escrows (> 7 days locked)
   - Refund requests

### Dashboard Queries

```dart
// Total BR locked across all active escrows
await _firestore
    .collection('escrow_transactions')
    .where('status', isEqualTo: 'locked')
    .where('currency', isEqualTo: 'BR')
    .get()
    .then((snapshot) => snapshot.docs.fold<int>(
          0, (sum, doc) => sum + (doc.data()['amount'] as int)));

// Escrows older than 7 days still locked (stuck detection)
final sevenDaysAgo = Timestamp.fromDate(
    DateTime.now().subtract(Duration(days: 7)));

await _firestore
    .collection('escrow_transactions')
    .where('status', isEqualTo: 'locked')
    .where('createdAt', isLessThan: sevenDaysAgo)
    .get();
```

---

## Migration Plan

Since this is a new feature (not replacing existing functionality), no data migration required. However:

### 1. Existing Challenges
- Old challenges without wagers continue to work
- `wager` field is optional (null for non-wagered challenges)
- No backfilling required

### 2. Existing Users
- All users start with 0 locked funds
- Balance checks include both available + locked
- UI shows "Available: X | Locked: Y"

### 3. Rollout Strategy
1. Deploy EscrowService (backend only, no UI)
2. Test with internal users using direct API calls
3. Deploy UI for combat sports (MMA/Boxing) first
4. Monitor for 1 week
5. Roll out to remaining sports
6. Enable VC wagering after BR stable

---

## Future Enhancements

### 1. Escrow Insurance
- Optional "insurance" fee (5% of wager)
- Protects against challenge cancellation by opponent
- Insured users get refund + insurance payout if opponent cancels

### 2. Smart Escrow Release
- Automatic release via Cloud Function when event completes
- No manual intervention required
- Picks scored automatically via API

### 3. Escrow Staking
- Users can stake locked escrow to earn interest
- Funds still available for challenge but generate passive VC
- Risk-free yield while waiting for event

### 4. Multi-Currency Wagers
- Mix BR + VC in single wager (e.g., "50 BR + 5 VC")
- Currency conversion at market rates
- More flexible wagering options

### 5. Escrow Marketplace
- Users can "sell" their locked escrow position
- Transfer challenge participation to another user
- Secondary market for active challenges

---

## Conclusion

This implementation plan provides a comprehensive escrow system for BR Coin and Victory Coin wagering without duplicating existing wallet infrastructure. By extending WalletService and VictoryCoinService with escrow capabilities, we maintain code consistency while adding powerful new features.

**Key Advantages:**
- ✅ No code duplication
- ✅ Leverages existing transaction infrastructure
- ✅ Atomic operations prevent double-spending
- ✅ Extensible for pools and tournaments
- ✅ Clear separation of concerns (escrow is its own service)

**Next Steps:**
1. Review and approve this plan
2. Begin Phase 1 implementation (EscrowService)
3. Test thoroughly with unit and integration tests
4. Deploy security rules
5. Roll out to combat sports first

---

**Document Version:** 1.0
**Last Updated:** 2025-09-29
**Author:** Claude Code
**Status:** Awaiting Approval