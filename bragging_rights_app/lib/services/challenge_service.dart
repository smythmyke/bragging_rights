import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import 'escrow_service.dart';

class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final EscrowService _escrowService;

  /// Initialize the escrow service
  void init() {
    _escrowService = EscrowService(_firestore);
  }

  /// Create a new challenge
  Future<Challenge> createChallenge({
    required String sportType,
    required String eventId,
    required String eventName,
    required DateTime eventDate,
    required Map<String, dynamic> picks,
    ChallengeType type = ChallengeType.friend,
    List<String> targetFriends = const [],
    bool isPublic = false,
    String? poolId,
    int? wagerAmount,
    String? wagerCurrency, // 'BR' or 'VC'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? userData?['username'] ?? 'Anonymous';

      final challengeId = _firestore.collection('challenges').doc().id;

      // Calculate expiration (24 hours before event or 7 days, whichever is shorter)
      final now = DateTime.now();
      final eventMinus24Hours = eventDate.subtract(const Duration(hours: 24));
      final sevenDaysFromNow = now.add(const Duration(days: 7));
      final expiresAt = eventMinus24Hours.isBefore(sevenDaysFromNow)
          ? eventMinus24Hours
          : sevenDaysFromNow;

      // Lock funds in escrow if wager specified
      WagerInfo? wagerInfo;
      if (wagerAmount != null && wagerCurrency != null && wagerAmount > 0) {
        // Validate wager amount
        if (wagerCurrency == 'BR') {
          if (wagerAmount < 10 || wagerAmount > 5000) {
            throw Exception('BR wager must be between 10 and 5000');
          }
        } else if (wagerCurrency == 'VC') {
          if (wagerAmount < 1 || wagerAmount > 100) {
            throw Exception('VC wager must be between 1 and 100');
          }
        }

        // Lock funds in escrow
        String? escrowId;
        try {
          if (wagerCurrency == 'BR') {
            escrowId = await _escrowService.lockBRInEscrow(
              userId: user.uid,
              amount: wagerAmount,
              challengeId: challengeId,
              type: EscrowType.challenge,
              participantIds: targetFriends,
            );
          } else if (wagerCurrency == 'VC') {
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

          wagerInfo = WagerInfo(
            amount: wagerAmount,
            currency: wagerCurrency,
            escrowId: escrowId,
          );
        } on InsufficientFundsException catch (e) {
          throw Exception('Insufficient funds: ${e.message}');
        }
      }

      final challenge = Challenge(
        id: challengeId,
        challengerId: user.uid,
        challengerName: userName,
        challengerAvatar: user.photoURL,
        sportType: sportType,
        eventId: eventId,
        eventName: eventName,
        eventDate: eventDate,
        poolId: poolId,
        type: type,
        targetFriends: targetFriends,
        isPublic: isPublic,
        picks: picks,
        status: ChallengeStatus.pending,
        createdAt: now,
        expiresAt: expiresAt,
        participants: [],
        wager: wagerInfo,
      );

      // Save to Firestore
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .set(challenge.toMap());

      // Update user's challenge stats
      await _updateUserChallengeStats(user.uid, sent: 1);

      // Send notifications to target friends if applicable
      if (type == ChallengeType.friend && targetFriends.isNotEmpty) {
        await _sendChallengeNotifications(challengeId, targetFriends);
      }

      return challenge;
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  /// Accept a challenge
  Future<void> acceptChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get challenge first to check for wager
      final challengeDoc = await _firestore
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challenge = Challenge.fromMap(challengeId, challengeDoc.data()!);

      // Check if already accepted
      if (challenge.participants.any((p) => p.userId == user.uid)) {
        throw Exception('Already accepted this challenge');
      }

      // Check if challenge is expired
      if (challenge.expiresAt.isBefore(DateTime.now())) {
        throw Exception('Challenge has expired');
      }

      // If challenge has wager, accepting user must match it
      if (challenge.wager != null) {
        final wagerAmount = challenge.wager!.amount;
        final wagerCurrency = challenge.wager!.currency;

        // Lock accepting user's funds
        String? escrowId;
        try {
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
            throw InsufficientFundsException(
                'Failed to lock $wagerAmount $wagerCurrency in escrow');
          }
        } on InsufficientFundsException catch (e) {
          throw Exception(
              'Insufficient funds to match wager: ${e.message}');
        }
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? userData?['username'] ?? 'Anonymous';

      // Check if user is friends with challenger
      final friendIds = List<String>.from(userData?['friends'] ?? []);

      // Add participant
      final participant = ChallengeParticipant(
        userId: user.uid,
        userName: userName,
        userAvatar: user.photoURL,
        isFriend: friendIds.contains(challenge.challengerId),
        acceptedAt: DateTime.now(),
      );

      final updatedParticipants = [
        ...challenge.participants.map((p) => p.toMap()),
        participant.toMap(),
      ];

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.accepted.name,
        'participants': updatedParticipants,
      });

      // Update user's challenge stats
      await _updateUserChallengeStats(user.uid, received: 1);

      // TODO: Send notification to challenger about acceptance

    } catch (e) {
      throw Exception('Failed to accept challenge: $e');
    }
  }

  /// Get a specific challenge
  Future<Challenge> getChallenge(String challengeId) async {
    try {
      final doc = await _firestore.collection('challenges').doc(challengeId).get();

      if (!doc.exists) {
        throw Exception('Challenge not found');
      }

      // Increment view count
      await _firestore.collection('challenges').doc(challengeId).update({
        'viewCount': FieldValue.increment(1),
      });

      return Challenge.fromMap(challengeId, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get challenge: $e');
    }
  }

  /// Get user's created challenges
  Stream<List<Challenge>> getUserChallenges(String userId) {
    return _firestore
        .collection('challenges')
        .where('challengerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get challenges where user is a participant
  Stream<List<Challenge>> getAcceptedChallenges(String userId) {
    return _firestore
        .collection('challenges')
        .where('participants', arrayContains: {'userId': userId})
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get all challenges for a user (created + accepted)
  Stream<List<Challenge>> getAllUserChallenges(String userId) {
    return _firestore
        .collection('challenges')
        .where('challengerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final createdChallenges = snapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();

      // Also get challenges where user is a participant
      final participantSnapshot = await _firestore
          .collection('challenges')
          .where('participants', arrayContains: {'userId': userId})
          .orderBy('createdAt', descending: true)
          .get();

      final acceptedChallenges = participantSnapshot.docs
          .map((doc) => Challenge.fromMap(doc.id, doc.data()))
          .toList();

      // Combine and deduplicate
      final allChallenges = [...createdChallenges, ...acceptedChallenges];
      final uniqueChallenges = <String, Challenge>{};
      for (final challenge in allChallenges) {
        uniqueChallenges[challenge.id] = challenge;
      }

      final result = uniqueChallenges.values.toList();
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    });
  }

  /// Get challenges for a specific event
  Stream<List<Challenge>> getEventChallenges(String eventId) {
    return _firestore
        .collection('challenges')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Update challenge results
  Future<void> updateChallengeResults(
    String challengeId,
    ChallengeResults results,
  ) async {
    try {
      // Get challenge to check for wager
      final challenge = await getChallenge(challengeId);

      // Release escrow to winner if wager exists
      if (challenge.wager != null && results.winnerId != null) {
        // Get all escrows for this challenge
        final escrows = await _escrowService.getEscrowsForChallenge(challengeId);

        if (escrows.isNotEmpty) {
          // Release all escrow funds to winner
          for (final escrow in escrows) {
            bool success = false;
            if (escrow.currency == 'BR') {
              success = await _escrowService.releaseBRFromEscrow(
                escrowId: escrow.id,
                winnerId: results.winnerId!,
              );
            } else if (escrow.currency == 'VC') {
              success = await _escrowService.releaseVCFromEscrow(
                escrowId: escrow.id,
                winnerId: results.winnerId!,
              );
            }

            if (!success) {
              print('Warning: Failed to release escrow ${escrow.id}');
            }
          }
        }
      }

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': ChallengeStatus.completed.name,
        'results': results.toMap(),
      });

      // Update user stats based on results
      if (results.winnerId != null) {
        // Winner
        await _updateUserChallengeStats(
          results.winnerId!,
          won: 1,
          sportType: challenge.sportType,
        );

        // Loser(s)
        for (final participant in challenge.participants) {
          if (participant.userId != results.winnerId) {
            await _updateUserChallengeStats(
              participant.userId,
              lost: 1,
              sportType: challenge.sportType,
            );
          }
        }
      }

      // TODO: Send notifications about results

    } catch (e) {
      throw Exception('Failed to update challenge results: $e');
    }
  }

  /// Cancel a challenge and refund all escrows
  Future<void> cancelChallenge(String challengeId, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get challenge
      final challenge = await getChallenge(challengeId);

      // Verify user is the challenger
      if (challenge.challengerId != user.uid) {
        throw Exception('Only the challenger can cancel this challenge');
      }

      // Refund all escrows if wager exists
      if (challenge.wager != null) {
        final escrows = await _escrowService.getEscrowsForChallenge(challengeId);

        for (final escrow in escrows) {
          bool success = false;
          if (escrow.currency == 'BR') {
            success = await _escrowService.refundBRFromEscrow(
              escrowId: escrow.id,
              reason: reason,
            );
          } else if (escrow.currency == 'VC') {
            success = await _escrowService.refundVCFromEscrow(
              escrowId: escrow.id,
              reason: reason,
            );
          }

          if (!success) {
            print('Warning: Failed to refund escrow ${escrow.id}');
          }
        }
      }

      // Update challenge status
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // TODO: Send notifications about cancellation

    } catch (e) {
      throw Exception('Failed to cancel challenge: $e');
    }
  }

  /// Update user's challenge statistics
  Future<void> _updateUserChallengeStats(
    String userId, {
    int sent = 0,
    int received = 0,
    int won = 0,
    int lost = 0,
    int tied = 0,
    String? sportType,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};

      final currentStats = userData['challengeStats'] as Map<String, dynamic>? ?? {};

      final newSent = (currentStats['sent'] ?? 0) + sent;
      final newReceived = (currentStats['received'] ?? 0) + received;
      final newWon = (currentStats['won'] ?? 0) + won;
      final newLost = (currentStats['lost'] ?? 0) + lost;
      final newTied = (currentStats['tied'] ?? 0) + tied;

      final totalCompleted = newWon + newLost + newTied;
      final winRate = totalCompleted > 0 ? (newWon / totalCompleted * 100) : 0.0;

      final updatedStats = {
        'sent': newSent,
        'received': newReceived,
        'won': newWon,
        'lost': newLost,
        'tied': newTied,
        'winRate': winRate,
      };

      // Update sport-specific stats if sportType provided
      if (sportType != null && (won > 0 || lost > 0 || tied > 0)) {
        final bySport = Map<String, dynamic>.from(currentStats['bySport'] ?? {});
        final sportStats = Map<String, dynamic>.from(bySport[sportType] ?? {});

        sportStats['won'] = (sportStats['won'] ?? 0) + won;
        sportStats['lost'] = (sportStats['lost'] ?? 0) + lost;
        sportStats['tied'] = (sportStats['tied'] ?? 0) + tied;

        bySport[sportType] = sportStats;
        updatedStats['bySport'] = bySport;
      }

      await userRef.update({'challengeStats': updatedStats});
    } catch (e) {
      // If challengeStats doesn't exist, create it
      await _firestore.collection('users').doc(userId).set({
        'challengeStats': {
          'sent': sent,
          'received': received,
          'won': won,
          'lost': lost,
          'tied': tied,
          'winRate': 0.0,
          'bySport': sportType != null
              ? {
                  sportType: {
                    'won': won,
                    'lost': lost,
                    'tied': tied,
                  }
                }
              : {},
        }
      }, SetOptions(merge: true));
    }
  }

  /// Send challenge notifications to target users
  Future<void> _sendChallengeNotifications(
    String challengeId,
    List<String> targetUserIds,
  ) async {
    // TODO: Implement push notifications via Firebase Cloud Messaging
    // For now, we'll create notification documents in Firestore
    final batch = _firestore.batch();

    for (final userId in targetUserIds) {
      final notificationRef = _firestore.collection('challenge_notifications').doc();
      batch.set(notificationRef, {
        'userId': userId,
        'challengeId': challengeId,
        'type': 'challenge_received',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Increment share count
  Future<void> incrementShareCount(String challengeId) async {
    await _firestore.collection('challenges').doc(challengeId).update({
      'shareCount': FieldValue.increment(1),
    });
  }

  /// Delete a challenge
  Future<void> deleteChallenge(String challengeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify user is the challenger
      final challenge = await getChallenge(challengeId);
      if (challenge.challengerId != user.uid) {
        throw Exception('Only the challenger can delete this challenge');
      }

      // Can only delete if no one has accepted
      if (challenge.participants.isNotEmpty) {
        throw Exception('Cannot delete a challenge that has been accepted');
      }

      await _firestore.collection('challenges').doc(challengeId).delete();
    } catch (e) {
      throw Exception('Failed to delete challenge: $e');
    }
  }
}