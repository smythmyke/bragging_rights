import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing escrow transactions for challenges and pools
/// Handles locking, releasing, and refunding of BR Coins and Victory Coins
class EscrowService {
  final FirebaseFirestore _firestore;

  EscrowService(this._firestore);

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
    try {
      // Validate amount
      if (amount < 10 || amount > 5000) {
        throw Exception('BR wager must be between 10 and 5000');
      }

      // Create escrow document ID
      final escrowId = _firestore.collection('escrow_transactions').doc().id;

      // Use Firestore transaction for atomic operation
      await _firestore.runTransaction((transaction) async {
        final walletRef = _firestore.collection('wallets').doc(userId);
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);

        // Read current balance
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw InsufficientFundsException('Wallet not found');
        }

        final currentBalance = walletDoc.data()?['balance'] ?? 0;

        // Validate sufficient funds
        if (currentBalance < amount) {
          throw InsufficientFundsException(
              'Insufficient BR Coins. Have: $currentBalance, Need: $amount');
        }

        // Deduct from wallet
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
          'type': type.toString().split('.').last,
          'status': 'locked',
          'participantIds': participantIds,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Log transaction in wallet history
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
    } on InsufficientFundsException {
      rethrow;
    } catch (e) {
      print('Error locking BR in escrow: $e');
      return null;
    }
  }

  /// Releases BR Coins from escrow to winner(s)
  Future<bool> releaseBRFromEscrow({
    required String escrowId,
    required String winnerId,
    List<WinnerSplit>? splits,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed (status: $status)');
        }

        // If splits provided, distribute to multiple winners
        if (splits != null && splits.isNotEmpty) {
          for (final split in splits) {
            final winnerRef = _firestore.collection('wallets').doc(split.userId);
            final winnerDoc = await transaction.get(winnerRef);

            if (!winnerDoc.exists) {
              throw Exception('Winner wallet not found: ${split.userId}');
            }

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

          if (!winnerDoc.exists) {
            throw Exception('Winner wallet not found');
          }

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
      print('Error releasing BR from escrow: $e');
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
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final userId = escrowData['userId'] as String;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed (status: $status)');
        }

        // Return funds to original user
        final walletRef = _firestore.collection('wallets').doc(userId);
        final walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          throw Exception('Original wallet not found');
        }

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
      print('Error refunding BR from escrow: $e');
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
    try {
      // Validate amount
      if (amount < 1 || amount > 100) {
        throw Exception('VC wager must be between 1 and 100');
      }

      // Create escrow document ID
      final escrowId = _firestore.collection('escrow_transactions').doc().id;

      // Use Firestore transaction for atomic operation
      await _firestore.runTransaction((transaction) async {
        final vcRef = _firestore.collection('victory_coins').doc(userId);
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);

        // Read current balance
        final vcDoc = await transaction.get(vcRef);
        if (!vcDoc.exists) {
          throw InsufficientFundsException('Victory Coins account not found');
        }

        final currentBalance = vcDoc.data()?['balance'] ?? 0;

        // Validate sufficient funds
        if (currentBalance < amount) {
          throw InsufficientFundsException(
              'Insufficient Victory Coins. Have: $currentBalance, Need: $amount');
        }

        // Deduct from VC balance
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
          'type': type.toString().split('.').last,
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
    } on InsufficientFundsException {
      rethrow;
    } catch (e) {
      print('Error locking VC in escrow: $e');
      return null;
    }
  }

  /// Releases Victory Coins from escrow to winner(s)
  Future<bool> releaseVCFromEscrow({
    required String escrowId,
    required String winnerId,
    List<WinnerSplit>? splits,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed (status: $status)');
        }

        // Distribute to winner(s)
        if (splits != null && splits.isNotEmpty) {
          for (final split in splits) {
            final vcRef = _firestore.collection('victory_coins').doc(split.userId);
            final vcDoc = await transaction.get(vcRef);

            // Create VC account if it doesn't exist
            if (!vcDoc.exists) {
              transaction.set(vcRef, {
                'userId': split.userId,
                'balance': split.amount,
                'lifetimeEarned': split.amount,
                'dailyEarned': 0,
                'monthlyEarned': 0,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            } else {
              final currentBalance = vcDoc.data()?['balance'] ?? 0;
              final lifetimeEarned = vcDoc.data()?['lifetimeEarned'] ?? 0;

              transaction.update(vcRef, {
                'balance': currentBalance + split.amount,
                'lifetimeEarned': lifetimeEarned + split.amount,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            }

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

          // Create VC account if it doesn't exist
          if (!vcDoc.exists) {
            transaction.set(vcRef, {
              'userId': winnerId,
              'balance': amount,
              'lifetimeEarned': amount,
              'dailyEarned': 0,
              'monthlyEarned': 0,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            final currentBalance = vcDoc.data()?['balance'] ?? 0;
            final lifetimeEarned = vcDoc.data()?['lifetimeEarned'] ?? 0;

            transaction.update(vcRef, {
              'balance': currentBalance + amount,
              'lifetimeEarned': lifetimeEarned + amount,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }

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
      print('Error releasing VC from escrow: $e');
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
        final escrowRef =
            _firestore.collection('escrow_transactions').doc(escrowId);
        final escrowDoc = await transaction.get(escrowRef);

        if (!escrowDoc.exists) {
          throw Exception('Escrow not found');
        }

        final escrowData = escrowDoc.data()!;
        final amount = escrowData['amount'] as int;
        final userId = escrowData['userId'] as String;
        final status = escrowData['status'] as String;

        if (status != 'locked') {
          throw Exception('Escrow already processed (status: $status)');
        }

        // Return VC to original user
        final vcRef = _firestore.collection('victory_coins').doc(userId);
        final vcDoc = await transaction.get(vcRef);

        if (!vcDoc.exists) {
          throw Exception('Original VC account not found');
        }

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
      print('Error refunding VC from escrow: $e');
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Gets escrow details
  Future<EscrowTransaction?> getEscrow(String escrowId) async {
    try {
      final doc = await _firestore
          .collection('escrow_transactions')
          .doc(escrowId)
          .get();

      if (!doc.exists) return null;

      return EscrowTransaction.fromFirestore(doc);
    } catch (e) {
      print('Error getting escrow: $e');
      return null;
    }
  }

  /// Gets all escrows for a challenge
  Future<List<EscrowTransaction>> getEscrowsForChallenge(
      String challengeId) async {
    try {
      final snapshot = await _firestore
          .collection('escrow_transactions')
          .where('challengeId', isEqualTo: challengeId)
          .get();

      return snapshot.docs
          .map((doc) => EscrowTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting escrows for challenge: $e');
      return [];
    }
  }

  /// Calculates total locked amount for a user
  Future<Map<String, int>> getUserLockedFunds(String userId) async {
    try {
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
    } catch (e) {
      print('Error getting user locked funds: $e');
      return {'BR': 0, 'VC': 0};
    }
  }
}

// ==================== SUPPORTING CLASSES ====================

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
  final String currency; // 'BR' or 'VC'
  final String challengeId;
  final EscrowType type;
  final String status; // 'locked', 'released', 'refunded'
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
        (e) => e.toString().split('.').last == data['type'],
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

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'challengeId': challengeId,
      'type': type.toString().split('.').last,
      'status': status,
      'participantIds': participantIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (releasedAt != null) 'releasedAt': Timestamp.fromDate(releasedAt!),
      if (refundedAt != null) 'refundedAt': Timestamp.fromDate(refundedAt!),
      if (winnerId != null) 'winnerId': winnerId,
      if (refundReason != null) 'refundReason': refundReason,
    };
  }
}

class InsufficientFundsException implements Exception {
  final String message;
  InsufficientFundsException(this.message);

  @override
  String toString() => message;
}