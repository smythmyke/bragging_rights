import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/head_to_head_model.dart';
import '../models/fight_card_model.dart';
import '../models/user_model.dart';
import 'fight_card_service.dart';

/// Service for managing head-to-head challenges
class HeadToHeadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FightCardService _fightService = FightCardService();
  
  /// Create a new H2H challenge
  Future<String> createChallenge({
    required HeadToHeadChallenge challenge,
  }) async {
    try {
      final docRef = _firestore.collection('h2h_challenges').doc();
      final challengeWithId = HeadToHeadChallenge(
        id: docRef.id,
        eventId: challenge.eventId,
        eventName: challenge.eventName,
        sport: challenge.sport,
        type: challenge.type,
        challengerId: challenge.challengerId,
        challengerName: challenge.challengerName,
        opponentId: challenge.opponentId,
        opponentName: challenge.opponentName,
        entryFee: challenge.entryFee,
        status: ChallengeStatus.open,
        createdAt: DateTime.now(),
        eventData: challenge.eventData,
        requiredFightIds: challenge.requiredFightIds,
        isFullCard: challenge.isFullCard,
      );
      
      await docRef.set(challengeWithId.toFirestore());
      
      // If it's a direct challenge, notify the opponent
      if (challenge.type == ChallengeType.direct && challenge.opponentId != null) {
        await _notifyDirectChallenge(challengeWithId);
      }
      
      // If it's auto-match, try to find a match immediately
      if (challenge.type == ChallengeType.auto) {
        await _attemptAutoMatch(challengeWithId);
      }
      
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      rethrow;
    }
  }
  
  /// Accept an open or direct challenge
  Future<void> acceptChallenge({
    required String challengeId,
    required String userId,
    required String userName,
  }) async {
    try {
      final challengeDoc = await _firestore
          .collection('h2h_challenges')
          .doc(challengeId)
          .get();
      
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }
      
      final challenge = HeadToHeadChallenge.fromFirestore(challengeDoc);
      
      // Validate challenge can be accepted
      if (challenge.status != ChallengeStatus.open) {
        throw Exception('Challenge is no longer open');
      }
      
      if (challenge.challengerId == userId) {
        throw Exception('Cannot accept your own challenge');
      }
      
      if (challenge.type == ChallengeType.direct && 
          challenge.opponentId != userId) {
        throw Exception('This challenge is for another user');
      }
      
      // Update challenge with opponent
      await _firestore.collection('h2h_challenges').doc(challengeId).update({
        'opponentId': userId,
        'opponentName': userName,
        'status': ChallengeStatus.matched.toString().split('.').last,
        'matchedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      // Create pick documents for both users
      await _createPickDocuments(challengeId, challenge.challengerId, userId);
      
      // Deduct entry fee from opponent's BR
      await _deductEntryFee(userId, challenge.entryFee);
      
    } catch (e) {
      debugPrint('Error accepting challenge: $e');
      rethrow;
    }
  }
  
  /// Auto-match system for finding opponents
  Future<void> _attemptAutoMatch(HeadToHeadChallenge challenge) async {
    try {
      // Find other open auto-match challenges for same event
      final matchQuery = await _firestore
          .collection('h2h_challenges')
          .where('eventId', isEqualTo: challenge.eventId)
          .where('type', isEqualTo: ChallengeType.auto.toString().split('.').last)
          .where('status', isEqualTo: ChallengeStatus.open.toString().split('.').last)
          .where('entryFee', isEqualTo: challenge.entryFee)
          .where('isFullCard', isEqualTo: challenge.isFullCard)
          .limit(10)
          .get();
      
      for (final doc in matchQuery.docs) {
        final otherChallenge = HeadToHeadChallenge.fromFirestore(doc);
        
        // Don't match with self
        if (otherChallenge.id == challenge.id) continue;
        if (otherChallenge.challengerId == challenge.challengerId) continue;
        
        // Check if requirements match
        if (_challengesMatch(challenge, otherChallenge)) {
          // Match found! Update both challenges
          final batch = _firestore.batch();
          
          // Update first challenge
          batch.update(
            _firestore.collection('h2h_challenges').doc(challenge.id),
            {
              'opponentId': otherChallenge.challengerId,
              'opponentName': otherChallenge.challengerName,
              'status': ChallengeStatus.matched.toString().split('.').last,
              'matchedAt': Timestamp.fromDate(DateTime.now()),
            },
          );
          
          // Update second challenge
          batch.update(
            _firestore.collection('h2h_challenges').doc(otherChallenge.id),
            {
              'opponentId': challenge.challengerId,
              'opponentName': challenge.challengerName,
              'status': ChallengeStatus.matched.toString().split('.').last,
              'matchedAt': Timestamp.fromDate(DateTime.now()),
            },
          );
          
          await batch.commit();
          
          // Create pick documents
          await _createPickDocuments(
            challenge.id,
            challenge.challengerId,
            otherChallenge.challengerId,
          );
          
          await _createPickDocuments(
            otherChallenge.id,
            otherChallenge.challengerId,
            challenge.challengerId,
          );
          
          debugPrint('Auto-match successful: ${challenge.id} <-> ${otherChallenge.id}');
          return;
        }
      }
      
      debugPrint('No auto-match found for challenge ${challenge.id}');
    } catch (e) {
      debugPrint('Error in auto-match: $e');
    }
  }
  
  /// Check if two challenges match for auto-pairing
  bool _challengesMatch(
    HeadToHeadChallenge c1,
    HeadToHeadChallenge c2,
  ) {
    // Must be same event and entry fee
    if (c1.eventId != c2.eventId) return false;
    if (c1.entryFee != c2.entryFee) return false;
    
    // Check fight requirements match
    if (c1.isFullCard != c2.isFullCard) return false;
    
    // Check required fights if specified
    if (c1.requiredFightIds != null && c2.requiredFightIds != null) {
      final fights1 = Set<String>.from(c1.requiredFightIds!);
      final fights2 = Set<String>.from(c2.requiredFightIds!);
      return fights1.difference(fights2).isEmpty;
    }
    
    return true;
  }
  
  /// Submit picks for H2H challenge
  Future<void> submitPicks({
    required String challengeId,
    required String userId,
    required H2HPicks picks,
  }) async {
    try {
      // Validate challenge exists and user is participant
      final challengeDoc = await _firestore
          .collection('h2h_challenges')
          .doc(challengeId)
          .get();
      
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }
      
      final challenge = HeadToHeadChallenge.fromFirestore(challengeDoc);
      
      if (challenge.challengerId != userId && challenge.opponentId != userId) {
        throw Exception('Not a participant in this challenge');
      }
      
      // Save picks
      await _firestore
          .collection('h2h_picks')
          .doc('${challengeId}_$userId')
          .set(picks.toFirestore());
      
      // Check if both users have submitted
      await _checkAndLockChallenge(challengeId);
      
    } catch (e) {
      debugPrint('Error submitting picks: $e');
      rethrow;
    }
  }
  
  /// Check if both users submitted and lock challenge
  Future<void> _checkAndLockChallenge(String challengeId) async {
    try {
      final challengeDoc = await _firestore
          .collection('h2h_challenges')
          .doc(challengeId)
          .get();
      
      final challenge = HeadToHeadChallenge.fromFirestore(challengeDoc);
      
      // Get both pick documents
      final pick1 = await _firestore
          .collection('h2h_picks')
          .doc('${challengeId}_${challenge.challengerId}')
          .get();
      
      final pick2 = await _firestore
          .collection('h2h_picks')
          .doc('${challengeId}_${challenge.opponentId}')
          .get();
      
      // If both submitted, lock the challenge
      if (pick1.exists && pick2.exists) {
        await _firestore.collection('h2h_challenges').doc(challengeId).update({
          'status': ChallengeStatus.locked.toString().split('.').last,
        });
        
        debugPrint('Challenge $challengeId locked - both users submitted');
      }
    } catch (e) {
      debugPrint('Error checking challenge lock: $e');
    }
  }
  
  /// Get user's active challenges
  Future<List<HeadToHeadChallenge>> getUserChallenges({
    required String userId,
    bool includeCompleted = false,
  }) async {
    try {
      final challenges = <HeadToHeadChallenge>[];
      
      // Get challenges where user is challenger
      var query1 = _firestore
          .collection('h2h_challenges')
          .where('challengerId', isEqualTo: userId);
      
      if (!includeCompleted) {
        query1 = query1.where('status', whereIn: [
          ChallengeStatus.open.toString().split('.').last,
          ChallengeStatus.matched.toString().split('.').last,
          ChallengeStatus.locked.toString().split('.').last,
          ChallengeStatus.live.toString().split('.').last,
        ]);
      }
      
      final results1 = await query1.get();
      challenges.addAll(
        results1.docs.map((doc) => HeadToHeadChallenge.fromFirestore(doc)),
      );
      
      // Get challenges where user is opponent
      var query2 = _firestore
          .collection('h2h_challenges')
          .where('opponentId', isEqualTo: userId);
      
      if (!includeCompleted) {
        query2 = query2.where('status', whereIn: [
          ChallengeStatus.matched.toString().split('.').last,
          ChallengeStatus.locked.toString().split('.').last,
          ChallengeStatus.live.toString().split('.').last,
        ]);
      }
      
      final results2 = await query2.get();
      challenges.addAll(
        results2.docs.map((doc) => HeadToHeadChallenge.fromFirestore(doc)),
      );
      
      // Sort by creation date
      challenges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return challenges;
    } catch (e) {
      debugPrint('Error getting user challenges: $e');
      return [];
    }
  }
  
  /// Get open challenges for an event
  Future<List<HeadToHeadChallenge>> getOpenChallenges({
    required String eventId,
    int? entryFee,
  }) async {
    try {
      var query = _firestore
          .collection('h2h_challenges')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: ChallengeStatus.open.toString().split('.').last)
          .where('type', whereIn: [
            ChallengeType.open.toString().split('.').last,
            ChallengeType.auto.toString().split('.').last,
          ]);
      
      if (entryFee != null) {
        query = query.where('entryFee', isEqualTo: entryFee);
      }
      
      final results = await query.limit(50).get();
      
      return results.docs
          .map((doc) => HeadToHeadChallenge.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting open challenges: $e');
      return [];
    }
  }
  
  /// Process completed event and determine winners
  Future<void> processCompletedEvent({
    required String eventId,
    required List<Fight> results,
  }) async {
    try {
      // Get all locked/live challenges for this event
      final challengeQuery = await _firestore
          .collection('h2h_challenges')
          .where('eventId', isEqualTo: eventId)
          .where('status', whereIn: [
            ChallengeStatus.locked.toString().split('.').last,
            ChallengeStatus.live.toString().split('.').last,
          ])
          .get();
      
      for (final doc in challengeQuery.docs) {
        final challenge = HeadToHeadChallenge.fromFirestore(doc);
        await _processChallengeResult(challenge, results);
      }
      
    } catch (e) {
      debugPrint('Error processing completed event: $e');
    }
  }
  
  /// Process individual challenge result
  Future<void> _processChallengeResult(
    HeadToHeadChallenge challenge,
    List<Fight> results,
  ) async {
    try {
      // Get both users' picks
      final pick1Doc = await _firestore
          .collection('h2h_picks')
          .doc('${challenge.id}_${challenge.challengerId}')
          .get();
      
      final pick2Doc = await _firestore
          .collection('h2h_picks')
          .doc('${challenge.id}_${challenge.opponentId}')
          .get();
      
      if (!pick1Doc.exists || !pick2Doc.exists) {
        debugPrint('Missing picks for challenge ${challenge.id}');
        return;
      }
      
      final picks1 = H2HPicks.fromFirestore(pick1Doc);
      final picks2 = H2HPicks.fromFirestore(pick2Doc);
      
      // Calculate scores
      int score1 = 0;
      int score2 = 0;
      
      if (picks1.fightPicks != null && picks2.fightPicks != null) {
        for (final result in results) {
          final pick1 = picks1.fightPicks![result.id];
          final pick2 = picks2.fightPicks![result.id];
          
          if (pick1 != null && pick1.winnerId == result.winnerId) {
            score1++;
          }
          if (pick2 != null && pick2.winnerId == result.winnerId) {
            score2++;
          }
        }
      }
      
      // Determine winner
      String? winnerId;
      String? winnerName;
      
      if (score1 > score2) {
        winnerId = challenge.challengerId;
        winnerName = challenge.challengerName;
      } else if (score2 > score1) {
        winnerId = challenge.opponentId;
        winnerName = challenge.opponentName;
      } else {
        // Tie - split the pot
        await _handleTie(challenge);
        return;
      }
      
      // Update challenge
      await _firestore.collection('h2h_challenges').doc(challenge.id).update({
        'status': ChallengeStatus.completed.toString().split('.').last,
        'completedAt': Timestamp.fromDate(DateTime.now()),
        'winnerId': winnerId,
      });
      
      // Pay out winner (full pot, no house cut)
      await _payoutWinner(winnerId, challenge.totalPot);
      
      // Create result record
      final result = H2HResult(
        challengeId: challenge.id,
        winnerId: winnerId,
        winnerName: winnerName!,
        loserId: winnerId == challenge.challengerId 
            ? challenge.opponentId! 
            : challenge.challengerId,
        loserName: winnerId == challenge.challengerId 
            ? challenge.opponentName! 
            : challenge.challengerName,
        winnerCorrectPicks: winnerId == challenge.challengerId ? score1 : score2,
        loserCorrectPicks: winnerId == challenge.challengerId ? score2 : score1,
        totalPicks: results.length,
        payout: challenge.totalPot,
        completedAt: DateTime.now(),
      );
      
      await _firestore.collection('h2h_results').add({
        'challengeId': result.challengeId,
        'winnerId': result.winnerId,
        'winnerName': result.winnerName,
        'loserId': result.loserId,
        'loserName': result.loserName,
        'winnerCorrectPicks': result.winnerCorrectPicks,
        'loserCorrectPicks': result.loserCorrectPicks,
        'totalPicks': result.totalPicks,
        'payout': result.payout,
        'completedAt': Timestamp.fromDate(result.completedAt),
      });
      
    } catch (e) {
      debugPrint('Error processing challenge result: $e');
    }
  }
  
  /// Handle tie by splitting pot
  Future<void> _handleTie(HeadToHeadChallenge challenge) async {
    try {
      final halfPot = challenge.totalPot ~/ 2;
      
      // Return half to each player
      await _payoutWinner(challenge.challengerId, halfPot);
      await _payoutWinner(challenge.opponentId!, halfPot);
      
      // Update challenge
      await _firestore.collection('h2h_challenges').doc(challenge.id).update({
        'status': ChallengeStatus.completed.toString().split('.').last,
        'completedAt': Timestamp.fromDate(DateTime.now()),
        'winnerId': null,  // No winner in tie
      });
      
      debugPrint('Challenge ${challenge.id} ended in tie - pot split');
    } catch (e) {
      debugPrint('Error handling tie: $e');
    }
  }
  
  /// Cancel an open challenge
  Future<void> cancelChallenge({
    required String challengeId,
    required String userId,
  }) async {
    try {
      final challengeDoc = await _firestore
          .collection('h2h_challenges')
          .doc(challengeId)
          .get();
      
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }
      
      final challenge = HeadToHeadChallenge.fromFirestore(challengeDoc);
      
      // Validate user can cancel
      if (challenge.challengerId != userId) {
        throw Exception('Only challenger can cancel');
      }
      
      if (challenge.status != ChallengeStatus.open) {
        throw Exception('Can only cancel open challenges');
      }
      
      // Update status
      await _firestore.collection('h2h_challenges').doc(challengeId).update({
        'status': ChallengeStatus.cancelled.toString().split('.').last,
      });
      
      // Refund entry fee
      await _refundEntryFee(userId, challenge.entryFee);
      
    } catch (e) {
      debugPrint('Error cancelling challenge: $e');
      rethrow;
    }
  }
  
  /// Helper methods for BR transactions
  Future<void> _deductEntryFee(String userId, int amount) async {
    // Implementation would deduct BR from user's balance
    debugPrint('Deducting $amount BR from user $userId');
  }
  
  Future<void> _payoutWinner(String userId, int amount) async {
    // Implementation would add BR to user's balance
    debugPrint('Paying out $amount BR to user $userId');
  }
  
  Future<void> _refundEntryFee(String userId, int amount) async {
    // Implementation would refund BR to user's balance
    debugPrint('Refunding $amount BR to user $userId');
  }
  
  Future<void> _notifyDirectChallenge(HeadToHeadChallenge challenge) async {
    // Implementation would send push notification to opponent
    debugPrint('Notifying ${challenge.opponentId} of direct challenge');
  }
  
  Future<void> _createPickDocuments(
    String challengeId,
    String user1Id,
    String user2Id,
  ) async {
    // Create empty pick documents for both users
    final batch = _firestore.batch();
    
    batch.set(
      _firestore.collection('h2h_picks').doc('${challengeId}_$user1Id'),
      {
        'challengeId': challengeId,
        'userId': user1Id,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      },
    );
    
    batch.set(
      _firestore.collection('h2h_picks').doc('${challengeId}_$user2Id'),
      {
        'challengeId': challengeId,
        'userId': user2Id,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      },
    );
    
    await batch.commit();
  }
  
  /// Stream updates for a challenge
  Stream<HeadToHeadChallenge?> streamChallenge(String challengeId) {
    return _firestore
        .collection('h2h_challenges')
        .doc(challengeId)
        .snapshots()
        .map((snap) {
          if (snap.exists) {
            return HeadToHeadChallenge.fromFirestore(snap);
          }
          return null;
        });
  }
  
  /// Get challenge statistics for a user
  Future<Map<String, dynamic>> getUserH2HStats(String userId) async {
    try {
      // Get completed challenges
      final results = await _firestore
          .collection('h2h_results')
          .where('winnerId', isEqualTo: userId)
          .get();
      
      final losses = await _firestore
          .collection('h2h_results')
          .where('loserId', isEqualTo: userId)
          .get();
      
      final wins = results.docs.length;
      final totalLosses = losses.docs.length;
      final totalGames = wins + totalLosses;
      
      // Calculate total earnings
      int totalEarnings = 0;
      for (final doc in results.docs) {
        totalEarnings += (doc.data()['payout'] as int?) ?? 0;
      }
      
      // Calculate total losses
      int totalLost = 0;
      for (final doc in losses.docs) {
        // Half of payout was their entry fee
        totalLost += ((doc.data()['payout'] as int?) ?? 0) ~/ 2;
      }
      
      return {
        'totalGames': totalGames,
        'wins': wins,
        'losses': totalLosses,
        'winRate': totalGames > 0 ? (wins / totalGames * 100).round() : 0,
        'netEarnings': totalEarnings - totalLost,
        'totalWon': totalEarnings,
        'totalLost': totalLost,
      };
    } catch (e) {
      debugPrint('Error getting H2H stats: $e');
      return {
        'totalGames': 0,
        'wins': 0,
        'losses': 0,
        'winRate': 0,
        'netEarnings': 0,
        'totalWon': 0,
        'totalLost': 0,
      };
    }
  }
}