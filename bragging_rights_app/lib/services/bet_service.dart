import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wallet_service.dart';

class BetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WalletService _walletService = WalletService();

  String? get _userId => _auth.currentUser?.uid;

  // Place a bet for a game
  Future<String> placeBet({
    required String gameId,
    required String gameTitle,
    required String sport,
    required String poolName,
    required List<BetDetail> bets,
    required int wagerAmount,
    required double totalOdds,
    required int potentialPayout,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    try {
      // First, deduct the wager from wallet
      final betId = _firestore.collection('bets').doc().id;
      
      await _walletService.placeWager(
        amount: wagerAmount,
        betId: betId,
        description: 'Bet on $gameTitle',
      );

      // Create the bet document
      await _firestore.collection('bets').doc(betId).set({
        'userId': _userId,
        'gameId': gameId,
        'gameTitle': gameTitle,
        'sport': sport,
        'poolName': poolName,
        'bets': bets.map((b) => b.toMap()).toList(),
        'wagerAmount': wagerAmount,
        'totalOdds': totalOdds,
        'potentialPayout': potentialPayout,
        'status': 'pending', // pending, won, lost, cancelled
        'placedAt': FieldValue.serverTimestamp(),
        'isParlay': bets.length > 1,
      });

      // Update user's bet history
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bets')
          .doc(betId)
          .set({
        'betId': betId,
        'gameId': gameId,
        'gameTitle': gameTitle,
        'placedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Mark game as having a bet
      await _markGameAsHavingBet(gameId, gameTitle);

      return betId;
    } catch (e) {
      throw Exception('Failed to place bet: $e');
    }
  }

  // Mark a game as having a bet placed
  Future<void> _markGameAsHavingBet(String gameId, String gameTitle) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('gamesWithBets')
        .doc(gameId)
        .set({
      'gameId': gameId,
      'gameTitle': gameTitle,
      'betPlacedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user has placed a bet on a game
  Future<bool> hasPlacedBet(String gameId) async {
    if (_userId == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('gamesWithBets')
        .doc(gameId)
        .get();

    return doc.exists;
  }

  // Get all games with bets for current user
  Stream<List<String>> getGamesWithBets() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('gamesWithBets')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get user's bet history
  Stream<List<BetModel>> getUserBets({int limit = 50}) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('bets')
        .where('userId', isEqualTo: _userId)
        .orderBy('placedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BetModel.fromFirestore(doc))
            .toList());
  }

  // Cancel a pending bet (if allowed)
  Future<void> cancelBet(String betId) async {
    if (_userId == null) throw Exception('User not logged in');

    final betDoc = await _firestore.collection('bets').doc(betId).get();
    if (!betDoc.exists) throw Exception('Bet not found');

    final betData = betDoc.data()!;
    if (betData['userId'] != _userId) {
      throw Exception('Unauthorized to cancel this bet');
    }
    if (betData['status'] != 'pending') {
      throw Exception('Can only cancel pending bets');
    }

    // Refund the wager
    await _walletService.addWinnings(
      amount: betData['wagerAmount'],
      betId: betId,
      description: 'Bet cancelled - refund',
    );

    // Update bet status
    await _firestore.collection('bets').doc(betId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}

// Bet detail for each selection
class BetDetail {
  final String title;
  final String selection;
  final String odds;
  final String type;
  final String? line; // For spread/totals

  BetDetail({
    required this.title,
    required this.selection,
    required this.odds,
    required this.type,
    this.line,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'selection': selection,
      'odds': odds,
      'type': type,
      if (line != null) 'line': line,
    };
  }

  factory BetDetail.fromMap(Map<String, dynamic> map) {
    return BetDetail(
      title: map['title'],
      selection: map['selection'],
      odds: map['odds'],
      type: map['type'],
      line: map['line'],
    );
  }
}

// Bet model
class BetModel {
  final String id;
  final String userId;
  final String gameId;
  final String gameTitle;
  final String sport;
  final String poolName;
  final List<BetDetail> bets;
  final int wagerAmount;
  final double totalOdds;
  final int potentialPayout;
  final String status;
  final DateTime placedAt;
  final bool isParlay;

  BetModel({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.poolName,
    required this.bets,
    required this.wagerAmount,
    required this.totalOdds,
    required this.potentialPayout,
    required this.status,
    required this.placedAt,
    required this.isParlay,
  });

  factory BetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return BetModel(
      id: doc.id,
      userId: data['userId'],
      gameId: data['gameId'],
      gameTitle: data['gameTitle'],
      sport: data['sport'],
      poolName: data['poolName'],
      bets: (data['bets'] as List)
          .map((b) => BetDetail.fromMap(b))
          .toList(),
      wagerAmount: data['wagerAmount'],
      totalOdds: (data['totalOdds'] is double) ? data['totalOdds'] : (data['totalOdds'] as num).toDouble(),
      potentialPayout: data['potentialPayout'],
      status: data['status'],
      placedAt: (data['placedAt'] as Timestamp).toDate(),
      isParlay: data['isParlay'] ?? false,
    );
  }
}