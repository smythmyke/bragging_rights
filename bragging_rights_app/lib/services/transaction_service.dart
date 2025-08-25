import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Comprehensive transaction history and BR balance tracking service
class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Get user's transaction history
  Stream<List<Transaction>> getTransactionHistory({
    int limit = 50,
    TransactionType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (_userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId);

    // Apply filters
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Transaction.fromFirestore(doc))
            .toList());
  }

  /// Get paginated transaction history
  Future<TransactionPage> getTransactionPage({
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
    TransactionType? type,
  }) async {
    if (_userId == null) {
      return TransactionPage(transactions: [], hasMore: false);
    }

    Query query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId);

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    query = query.orderBy('timestamp', descending: true).limit(pageSize + 1);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final hasMore = docs.length > pageSize;
    final transactions = docs
        .take(pageSize)
        .map((doc) => Transaction.fromFirestore(doc))
        .toList();

    return TransactionPage(
      transactions: transactions,
      hasMore: hasMore,
      lastDocument: docs.isNotEmpty ? docs.last : null,
    );
  }

  /// Get transaction summary for a period
  Future<TransactionSummary> getTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_userId == null) {
      return TransactionSummary.empty();
    }

    Query query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId);

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snapshot = await query.get();

    int totalDeposits = 0;
    int totalWagers = 0;
    int totalWinnings = 0;
    int totalRefunds = 0;
    int totalWithdrawals = 0;
    int transactionCount = snapshot.docs.length;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = data['amount'] ?? 0;
      final type = data['type'];

      switch (type) {
        case 'deposit':
        case 'weekly_allowance':
        case 'signup_bonus':
          totalDeposits += amount as int;
          break;
        case 'wager':
          totalWagers += (amount as int).abs();
          break;
        case 'winnings':
          totalWinnings += amount as int;
          break;
        case 'refund':
          totalRefunds += amount as int;
          break;
        case 'withdrawal':
          totalWithdrawals += (amount as int).abs();
          break;
      }
    }

    final netChange = totalDeposits + totalWinnings + totalRefunds - totalWagers - totalWithdrawals;

    return TransactionSummary(
      totalDeposits: totalDeposits,
      totalWagers: totalWagers,
      totalWinnings: totalWinnings,
      totalRefunds: totalRefunds,
      totalWithdrawals: totalWithdrawals,
      netChange: netChange,
      transactionCount: transactionCount,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get balance history for charts
  Future<List<BalancePoint>> getBalanceHistory({
    int days = 30,
  }) async {
    if (_userId == null) return [];

    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final transactions = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('timestamp')
        .get();

    List<BalancePoint> balancePoints = [];
    
    // Get starting balance
    final walletDoc = await _firestore.collection('wallets').doc(_userId).get();
    int currentBalance = walletDoc.data()?['balance'] ?? 0;

    // Work backwards to find starting balance
    for (final doc in transactions.docs.reversed) {
      final data = doc.data();
      final amount = data['amount'] ?? 0;
      currentBalance -= amount as int;
    }

    // Now build forward
    int runningBalance = currentBalance;
    for (final doc in transactions.docs) {
      final data = doc.data();
      final amount = data['amount'] ?? 0;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      
      runningBalance += amount as int;
      
      balancePoints.add(BalancePoint(
        balance: runningBalance,
        timestamp: timestamp,
      ));
    }

    // Add current balance as final point
    if (balancePoints.isEmpty || balancePoints.last.balance != currentBalance) {
      balancePoints.add(BalancePoint(
        balance: walletDoc.data()?['balance'] ?? 0,
        timestamp: DateTime.now(),
      ));
    }

    return balancePoints;
  }

  /// Export transactions to CSV format
  Future<String> exportTransactions({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
  }) async {
    if (_userId == null) return '';

    Query query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId);

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snapshot = await query.orderBy('timestamp', descending: true).get();

    // Build CSV
    StringBuffer csv = StringBuffer();
    csv.writeln('Date,Time,Type,Description,Amount,Balance After,Transaction ID');

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final date = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      final type = data['type'];
      final description = data['description'] ?? '';
      final amount = data['amount'] ?? 0;
      final balanceAfter = data['balanceAfter'] ?? 0;
      final id = doc.id;

      csv.writeln('$date,$time,$type,"$description",$amount,$balanceAfter,$id');
    }

    return csv.toString();
  }

  /// Search transactions
  Future<List<Transaction>> searchTransactions(String query) async {
    if (_userId == null || query.isEmpty) return [];

    // Search in description field
    final snapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    final searchLower = query.toLowerCase();
    
    return snapshot.docs
        .map((doc) => Transaction.fromFirestore(doc))
        .where((transaction) {
          return transaction.description.toLowerCase().contains(searchLower) ||
                 transaction.type.name.toLowerCase().contains(searchLower);
        })
        .toList();
  }

  /// Get transaction details
  Future<Transaction?> getTransaction(String transactionId) async {
    final doc = await _firestore
        .collection('transactions')
        .doc(transactionId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    if (data['userId'] != _userId) return null; // Security check

    return Transaction.fromFirestore(doc);
  }

  /// Create audit log entry
  Future<void> createAuditLog({
    required String action,
    required Map<String, dynamic> details,
  }) async {
    if (_userId == null) return;

    await _firestore.collection('audit_logs').add({
      'userId': _userId,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'ip': 'client', // Would get actual IP in production
      'userAgent': 'mobile_app',
    });
  }

  /// Admin function: Adjust user balance
  Future<bool> adjustBalance({
    required String targetUserId,
    required int amount,
    required String reason,
    required String adminId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // Get wallet
        final walletDoc = await transaction.get(
          _firestore.collection('wallets').doc(targetUserId),
        );

        if (!walletDoc.exists) {
          throw Exception('Wallet not found');
        }

        final currentBalance = walletDoc.data()!['balance'] ?? 0;
        final newBalance = currentBalance + amount;

        if (newBalance < 0) {
          throw Exception('Balance cannot go negative');
        }

        // Update wallet
        transaction.update(walletDoc.reference, {
          'balance': newBalance,
        });

        // Create transaction record
        final transactionId = _firestore.collection('transactions').doc().id;
        transaction.set(
          _firestore.collection('transactions').doc(transactionId),
          {
            'id': transactionId,
            'userId': targetUserId,
            'type': 'admin_adjustment',
            'amount': amount,
            'description': 'Admin adjustment: $reason',
            'balanceBefore': currentBalance,
            'balanceAfter': newBalance,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'adminId': adminId,
              'reason': reason,
            },
          },
        );

        // Create audit log
        await createAuditLog(
          action: 'balance_adjustment',
          details: {
            'targetUserId': targetUserId,
            'amount': amount,
            'reason': reason,
            'adminId': adminId,
          },
        );

        return true;
      });
    } catch (e) {
      print('Balance adjustment error: $e');
      return false;
    }
  }

  /// Detect suspicious activity
  Future<FraudDetectionResult> detectFraudulentActivity() async {
    if (_userId == null) {
      return FraudDetectionResult(isSuspicious: false);
    }

    // Check for suspicious patterns
    final recentTransactions = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .where('timestamp', isGreaterThanOrEqualTo: 
            Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
        .get();

    int rapidTransactions = recentTransactions.docs.length;
    int largeTransactions = 0;
    int failedTransactions = 0;

    for (final doc in recentTransactions.docs) {
      final amount = (doc.data()['amount'] ?? 0).abs();
      if (amount > 1000) largeTransactions++;
      
      final status = doc.data()['status'];
      if (status == 'failed') failedTransactions++;
    }

    // Flag if suspicious
    bool isSuspicious = false;
    List<String> flags = [];

    if (rapidTransactions > 50) {
      isSuspicious = true;
      flags.add('High transaction volume: $rapidTransactions in 24 hours');
    }

    if (largeTransactions > 5) {
      isSuspicious = true;
      flags.add('Multiple large transactions: $largeTransactions');
    }

    if (failedTransactions > 10) {
      isSuspicious = true;
      flags.add('High failed transaction rate: $failedTransactions');
    }

    return FraudDetectionResult(
      isSuspicious: isSuspicious,
      flags: flags,
      userId: _userId!,
      checkedAt: DateTime.now(),
    );
  }
}

/// Transaction types
enum TransactionType {
  deposit,
  withdrawal,
  wager,
  winnings,
  refund,
  weekly_allowance,
  signup_bonus,
  admin_adjustment,
  rollback,
  pool_entry,
  pool_refund,
}

/// Transaction model
class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final int amount;
  final String description;
  final int? balanceBefore;
  final int? balanceAfter;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    this.balanceBefore,
    this.balanceAfter,
    required this.timestamp,
    this.metadata,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Transaction(
      id: doc.id,
      userId: data['userId'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.deposit,
      ),
      amount: data['amount'] ?? 0,
      description: data['description'] ?? '',
      balanceBefore: data['balanceBefore'],
      balanceAfter: data['balanceAfter'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  String get formattedAmount {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix$amount BR';
  }

  String get typeDisplay {
    switch (type) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.wager:
        return 'Wager';
      case TransactionType.winnings:
        return 'Winnings';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.weekly_allowance:
        return 'Weekly Allowance';
      case TransactionType.signup_bonus:
        return 'Signup Bonus';
      case TransactionType.admin_adjustment:
        return 'Adjustment';
      case TransactionType.rollback:
        return 'Rollback';
      case TransactionType.pool_entry:
        return 'Pool Entry';
      case TransactionType.pool_refund:
        return 'Pool Refund';
    }
  }
}

/// Transaction page for pagination
class TransactionPage {
  final List<Transaction> transactions;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;

  TransactionPage({
    required this.transactions,
    required this.hasMore,
    this.lastDocument,
  });
}

/// Transaction summary
class TransactionSummary {
  final int totalDeposits;
  final int totalWagers;
  final int totalWinnings;
  final int totalRefunds;
  final int totalWithdrawals;
  final int netChange;
  final int transactionCount;
  final DateTime? startDate;
  final DateTime? endDate;

  TransactionSummary({
    required this.totalDeposits,
    required this.totalWagers,
    required this.totalWinnings,
    required this.totalRefunds,
    required this.totalWithdrawals,
    required this.netChange,
    required this.transactionCount,
    this.startDate,
    this.endDate,
  });

  factory TransactionSummary.empty() {
    return TransactionSummary(
      totalDeposits: 0,
      totalWagers: 0,
      totalWinnings: 0,
      totalRefunds: 0,
      totalWithdrawals: 0,
      netChange: 0,
      transactionCount: 0,
    );
  }

  double get roi {
    if (totalWagers == 0) return 0;
    return ((totalWinnings - totalWagers) / totalWagers) * 100;
  }

  double get winRate {
    if (totalWagers == 0) return 0;
    // This is simplified - would need actual win/loss counts
    return totalWinnings > 0 ? (totalWinnings / totalWagers) * 100 : 0;
  }
}

/// Balance point for charts
class BalancePoint {
  final int balance;
  final DateTime timestamp;

  BalancePoint({
    required this.balance,
    required this.timestamp,
  });
}

/// Fraud detection result
class FraudDetectionResult {
  final bool isSuspicious;
  final List<String> flags;
  final String? userId;
  final DateTime? checkedAt;

  FraudDetectionResult({
    required this.isSuspicious,
    this.flags = const [],
    this.userId,
    this.checkedAt,
  });
}