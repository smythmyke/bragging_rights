import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/intel_card_model.dart';
import '../models/injury_model.dart';
import 'injury_service.dart';
import 'wallet_service.dart';

class IntelCardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();
  final InjuryService _injuryService = InjuryService();

  /// Generate available Intel Cards for a game
  /// Only generates cards if injuries actually exist
  Future<List<IntelCard>> generateGameIntelCards({
    required String gameId,
    required String sport,
    required DateTime gameTime,
    required String homeTeamId,
    required String awayTeamId,
  }) async {
    // Only generate injury Intel Cards for sports that support injury data
    if (!_injuryService.sportSupportsInjuries(sport)) {
      return [];
    }

    // Check if game has any injuries before generating card
    final hasInjuries = await _injuryService.gameHasInjuries(
      sport: sport,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
    );

    // Only show card if at least one team has injuries
    if (!hasInjuries) {
      print('No injuries for game $gameId - skipping Intel Card');
      return [];
    }

    return [
      IntelCard(
        id: '${gameId}_game_intel',
        type: IntelCardType.gameInjuryReport,
        title: 'Game Injury Intel',
        description: 'Complete injury reports for both teams',
        brCost: 50,
        gameId: gameId,
        expiresAt: gameTime,
        sport: sport,
      ),
    ];
  }

  /// Check if user already owns a specific Intel Card
  Future<bool> userOwnsIntelCard({
    required String userId,
    required String cardId,
  }) async {
    final existing = await _firestore
        .collection('user_intel_cards')
        .where('userId', isEqualTo: userId)
        .where('cardId', isEqualTo: cardId)
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }

  /// Get user's purchased Intel Card for a specific card
  Future<UserIntelCard?> getUserIntelCard({
    required String userId,
    required String cardId,
  }) async {
    final snapshot = await _firestore
        .collection('user_intel_cards')
        .where('userId', isEqualTo: userId)
        .where('cardId', isEqualTo: cardId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return UserIntelCard.fromFirestore(snapshot.docs.first);
  }

  /// Purchase Intel Card with BR
  Future<IntelCardPurchaseResult> purchaseIntelCard({
    required String userId,
    required IntelCard card,
  }) async {
    try {
      // Check if card is expired
      if (card.isExpired) {
        return IntelCardPurchaseResult.failure(
          'This Intel Card has expired',
        );
      }

      // Check if user already owns this card
      final alreadyOwned = await userOwnsIntelCard(
        userId: userId,
        cardId: card.id,
      );

      if (alreadyOwned) {
        return IntelCardPurchaseResult.failure(
          'You already own this Intel Card',
        );
      }

      // Deduct BR from wallet
      final success = await _walletService.deductFromWallet(
        userId,
        card.brCost,
        'Intel Card: Game Injury Intel',
        metadata: {
          'type': 'intel_card_purchase',
          'cardId': card.id,
          'cardType': card.type.toString(),
          'gameId': card.gameId,
        },
      );

      if (!success) {
        return IntelCardPurchaseResult.failure(
          'Insufficient BR balance. You need ${card.brCost} BR.',
        );
      }

      // Create user Intel Card
      final userCardId =
          '${userId}_${card.id}_${DateTime.now().millisecondsSinceEpoch}';

      final userCard = UserIntelCard(
        id: userCardId,
        userId: userId,
        cardId: card.id,
        cardType: card.type,
        purchasedAt: DateTime.now(),
        brSpent: card.brCost,
        gameId: card.gameId,
        teamId: card.teamId,
        athleteId: card.athleteId,
        expiresAt: card.expiresAt,
      );

      await _firestore
          .collection('user_intel_cards')
          .doc(userCardId)
          .set(userCard.toFirestore());

      // Log purchase for analytics
      await _logIntelCardPurchase(userId, card);

      return IntelCardPurchaseResult.success(
        message: 'Intel Card purchased successfully!',
        userCardId: userCardId,
        userCard: userCard,
      );
    } catch (e) {
      print('Error purchasing Intel Card: $e');
      return IntelCardPurchaseResult.failure(
        'Failed to purchase Intel Card. Please try again.',
      );
    }
  }

  /// Get user's purchased Intel Cards
  Future<List<UserIntelCard>> getUserIntelCards(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_intel_cards')
          .where('userId', isEqualTo: userId)
          .orderBy('purchasedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => UserIntelCard.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching user Intel Cards: $e');
      return [];
    }
  }

  /// Fetch injury data for purchased Intel Card
  Future<GameInjuryReport?> getIntelCardData({
    required UserIntelCard userCard,
    required String homeTeamId,
    required String homeTeamName,
    String? homeTeamLogo,
    required String awayTeamId,
    required String awayTeamName,
    String? awayTeamLogo,
    required String sport,
  }) async {
    try {
      if (userCard.cardType == IntelCardType.gameInjuryReport) {
        // Fetch injury reports for both teams
        final report = await _injuryService.getGameInjuries(
          sport: sport,
          homeTeamId: homeTeamId,
          homeTeamName: homeTeamName,
          homeTeamLogo: homeTeamLogo,
          awayTeamId: awayTeamId,
          awayTeamName: awayTeamName,
          awayTeamLogo: awayTeamLogo,
        );

        // Update user card with cached data
        if (report != null) {
          await _firestore.collection('user_intel_cards').doc(userCard.id).update({
            'injuryData': report.toJson(),
            'viewed': true,
            'viewedAt': FieldValue.serverTimestamp(),
          });
        }

        return report;
      }

      return null;
    } catch (e) {
      print('Error fetching Intel Card data: $e');
      return null;
    }
  }

  /// Mark Intel Card as viewed
  Future<void> markAsViewed(String userCardId) async {
    try {
      await _firestore.collection('user_intel_cards').doc(userCardId).update({
        'viewed': true,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking Intel Card as viewed: $e');
    }
  }

  /// Log Intel Card purchase for analytics
  Future<void> _logIntelCardPurchase(String userId, IntelCard card) async {
    try {
      await _firestore.collection('analytics_intel_purchases').add({
        'userId': userId,
        'cardId': card.id,
        'cardType': card.type.toString(),
        'brCost': card.brCost,
        'sport': card.sport,
        'gameId': card.gameId,
        'teamId': card.teamId,
        'athleteId': card.athleteId,
        'purchasedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging Intel Card purchase: $e');
    }
  }

  /// Get Intel Card purchase analytics
  Future<Map<String, dynamic>> getIntelCardAnalytics() async {
    try {
      final snapshot =
          await _firestore.collection('analytics_intel_purchases').get();

      final totalPurchases = snapshot.docs.length;
      final totalBRSpent = snapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc.data()['brCost'] as int? ?? 0),
      );

      final purchasesByType = <String, int>{};
      for (final doc in snapshot.docs) {
        final type = doc.data()['cardType'] as String?;
        if (type != null) {
          purchasesByType[type] = (purchasesByType[type] ?? 0) + 1;
        }
      }

      return {
        'totalPurchases': totalPurchases,
        'totalBRSpent': totalBRSpent,
        'purchasesByType': purchasesByType,
      };
    } catch (e) {
      print('Error fetching Intel Card analytics: $e');
      return {
        'totalPurchases': 0,
        'totalBRSpent': 0,
        'purchasesByType': {},
      };
    }
  }

  /// Clean up expired Intel Cards
  Future<void> cleanupExpiredCards() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('user_intel_cards')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} expired Intel Cards');
    } catch (e) {
      print('Error cleaning up expired cards: $e');
    }
  }
}
