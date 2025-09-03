import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Get wallet balance stream
  Stream<int> getBalanceStream() {
    if (_userId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('wallet')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      return (doc.data()?['balance'] ?? 0) as int;
    });
  }

  // Get current balance
  Future<int> getCurrentBalance() async {
    if (_userId == null) return 0;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('wallet')
        .doc('current')
        .get();

    if (!doc.exists) return 0;
    return (doc.data()?['balance'] ?? 0) as int;
  }
  
  // Get balance for specific user (for pool service)
  Future<int> getBalance(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .doc('current')
        .get();

    if (!doc.exists) return 0;
    return (doc.data()?['balance'] ?? 0) as int;
  }

  // Update balance (add or subtract)
  Future<bool> updateBalance(int amount) async {
    if (_userId == null) throw Exception('User not logged in');
    
    try {
      return await _firestore.runTransaction((transaction) async {
        final walletRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('wallet')
            .doc('current');

        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0) as int;
        final newBalance = currentBalance + amount;

        if (newBalance < 0) {
          throw InsufficientFundsException(
            'Insufficient BR. Current balance: $currentBalance, Trying to deduct: ${-amount}',
          );
        }

        transaction.update(walletRef, {
          'balance': newBalance,
          'lastTransaction': FieldValue.serverTimestamp(),
        });

        // Create transaction record
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': _userId,
          'type': amount > 0 ? 'credit' : 'debit',
          'amount': amount,
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return true;
      });
    } catch (e) {
      print('Balance update failed: $e');
      rethrow;
    }
  }

  // Place a wager (deduct BR)
  Future<bool> placeWager({
    required int amount,
    required String betId,
    required String description,
  }) async {
    if (_userId == null) throw Exception('User not logged in');
    if (amount <= 0) throw Exception('Invalid wager amount');

    try {
      return await _firestore.runTransaction((transaction) async {
        // Get wallet reference
        final walletRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('wallet')
            .doc('current');

        // Get current balance
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0) as int;

        // Check sufficient funds
        if (currentBalance < amount) {
          throw InsufficientFundsException(
            'Insufficient BR. Current balance: $currentBalance, Required: $amount',
          );
        }

        // Update wallet balance
        final newBalance = currentBalance - amount;
        transaction.update(walletRef, {
          'balance': newBalance,
          'lifetimeWagered': FieldValue.increment(amount),
          'lastTransaction': FieldValue.serverTimestamp(),
        });

        // Create transaction record
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': _userId,
          'type': 'wager',
          'amount': -amount, // Negative for deductions
          'description': description,
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'relatedId': betId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return true;
      });
    } catch (e) {
      print('Wager placement failed: $e');
      rethrow;
    }
  }

  // Generic deduct from wallet method (for pool service)
  Future<bool> deductFromWallet(
    String userId,
    int amount,
    String description, {
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) throw Exception('Invalid amount');

    try {
      return await _firestore.runTransaction((transaction) async {
        final walletRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .doc('current');

        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0) as int;

        if (currentBalance < amount) {
          throw InsufficientFundsException(
            'Insufficient BR. Current balance: $currentBalance, Required: $amount',
          );
        }

        final newBalance = currentBalance - amount;
        transaction.update(walletRef, {
          'balance': newBalance,
          'lifetimeWagered': FieldValue.increment(amount),
          'lastTransaction': FieldValue.serverTimestamp(),
        });

        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': userId,
          'type': 'pool_entry',
          'amount': -amount,
          'description': description,
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'metadata': metadata,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return true;
      });
    } catch (e) {
      print('Deduction failed: $e');
      return false;
    }
  }
  
  // Generic add to wallet method (for pool service)
  Future<bool> addToWallet(
    String userId,
    int amount,
    String description, {
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) throw Exception('Invalid amount');

    try {
      return await _firestore.runTransaction((transaction) async {
        final walletRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .doc('current');

        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0) as int;
        final newBalance = currentBalance + amount;
        
        transaction.update(walletRef, {
          'balance': newBalance,
          'lifetimeEarned': FieldValue.increment(amount),
          'lastTransaction': FieldValue.serverTimestamp(),
        });

        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': userId,
          'type': 'pool_refund',
          'amount': amount,
          'description': description,
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'metadata': metadata,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return true;
      });
    } catch (e) {
      print('Add to wallet failed: $e');
      return false;
    }
  }

  // Add winnings
  Future<void> addWinnings({
    required int amount,
    required String betId,
    required String description,
  }) async {
    if (_userId == null) throw Exception('User not logged in');
    if (amount <= 0) throw Exception('Invalid amount');

    try {
      await _firestore.runTransaction((transaction) async {
        // Get wallet reference
        final walletRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('wallet')
            .doc('current');

        // Get current balance
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0) as int;
        final newBalance = currentBalance + amount;

        // Update wallet
        transaction.update(walletRef, {
          'balance': newBalance,
          'lifetimeEarned': FieldValue.increment(amount),
          'lastTransaction': FieldValue.serverTimestamp(),
        });

        // Create transaction record
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': _userId,
          'type': 'payout',
          'amount': amount, // Positive for additions
          'description': description,
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'relatedId': betId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });
      });
    } catch (e) {
      print('Failed to add winnings: $e');
      rethrow;
    }
  }

  // Check and apply weekly allowance
  Future<bool> checkAndApplyWeeklyAllowance() async {
    if (_userId == null) throw Exception('User not logged in');

    try {
      return await _firestore.runTransaction((transaction) async {
        // Get wallet reference
        final walletRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('wallet')
            .doc('current');

        // Get wallet data
        final walletDoc = await transaction.get(walletRef);
        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final walletData = walletDoc.data()!;
        final lastAllowance = walletData['lastAllowance'] as Timestamp?;
        
        // Check if eligible for allowance
        if (lastAllowance != null) {
          final daysSinceAllowance = DateTime.now()
              .difference(lastAllowance.toDate())
              .inDays;
          
          if (daysSinceAllowance < 7) {
            return false; // Not eligible yet
          }
        }

        // Apply allowance
        final currentBalance = (walletData['balance'] ?? 0) as int;
        final allowanceAmount = 25;
        final newBalance = currentBalance + allowanceAmount;

        // Update wallet
        transaction.update(walletRef, {
          'balance': newBalance,
          'lastAllowance': FieldValue.serverTimestamp(),
          'lifetimeEarned': FieldValue.increment(allowanceAmount),
        });

        // Create transaction record
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': _userId,
          'type': 'allowance',
          'amount': allowanceAmount,
          'description': 'Weekly BR Allowance',
          'balanceBefore': currentBalance,
          'balanceAfter': newBalance,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return true;
      });
    } catch (e) {
      print('Failed to apply weekly allowance: $e');
      rethrow;
    }
  }

  // Get transaction history
  Stream<List<TransactionModel>> getTransactionHistory({int limit = 50}) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get wallet statistics
  Future<WalletStats> getWalletStats() async {
    if (_userId == null) {
      return WalletStats(
        balance: 0,
        lifetimeEarned: 0,
        lifetimeWagered: 0,
        netProfit: 0,
      );
    }

    final walletDoc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('wallet')
        .doc('current')
        .get();

    if (!walletDoc.exists) {
      return WalletStats(
        balance: 0,
        lifetimeEarned: 0,
        lifetimeWagered: 0,
        netProfit: 0,
      );
    }

    final data = walletDoc.data()!;
    final earned = (data['lifetimeEarned'] ?? 0) as int;
    final wagered = (data['lifetimeWagered'] ?? 0) as int;

    return WalletStats(
      balance: (data['balance'] ?? 0) as int,
      lifetimeEarned: earned,
      lifetimeWagered: wagered,
      netProfit: earned - wagered - 500, // Subtract initial bonus
    );
  }

  // Get wallet statistics stream (won, lost, pending)
  Stream<Map<String, int>> getWalletStatsStream() {
    if (_userId == null) return Stream.value({'won': 0, 'lost': 0, 'pending': 0});

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
        .snapshots()
        .map((snapshot) {
      int won = 0;
      int lost = 0;
      int pending = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0) as int;
        final type = data['type'] as String?;
        final status = data['status'] as String?;

        if (status == 'pending') {
          pending += amount.abs();
        } else if (type == 'winnings' || (type == 'pool_prize' && amount > 0)) {
          won += amount;
        } else if (type == 'wager' || type == 'pool_entry' || amount < 0) {
          lost += amount.abs();
        }
      }

      return {'won': won, 'lost': lost, 'pending': pending};
    });
  }
}

// Transaction model
class TransactionModel {
  final String id;
  final String userId;
  final String type;
  final int amount;
  final String description;
  final int balanceBefore;
  final int balanceAfter;
  final DateTime timestamp;
  final String status;
  final String? relatedId;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.timestamp,
    required this.status,
    this.relatedId,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      amount: data['amount'] ?? 0,
      description: data['description'] ?? '',
      balanceBefore: data['balanceBefore'] ?? 0,
      balanceAfter: data['balanceAfter'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'completed',
      relatedId: data['relatedId'],
    );
  }

  // Get icon for transaction type
  String getIcon() {
    switch (type) {
      case 'wager':
        return '🎲';
      case 'payout':
        return '💰';
      case 'allowance':
        return '🎁';
      case 'initial_bonus':
        return '🎉';
      case 'bonus':
        return '🌟';
      default:
        return '💵';
    }
  }

  // Get color for amount (red for negative, green for positive)
  bool isPositive() => amount > 0;
}

// Wallet statistics
class WalletStats {
  final int balance;
  final int lifetimeEarned;
  final int lifetimeWagered;
  final int netProfit;

  WalletStats({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeWagered,
    required this.netProfit,
  });

  double get roi {
    if (lifetimeWagered == 0) return 0;
    return (netProfit / lifetimeWagered) * 100;
  }
}

// Custom exception for insufficient funds
class InsufficientFundsException implements Exception {
  final String message;
  InsufficientFundsException(this.message);

  @override
  String toString() => message;
}