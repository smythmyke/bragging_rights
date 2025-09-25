import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mma_scoring_config.dart';
import '../models/mma_event_model.dart';
import '../models/fight_card_model.dart';
import '../models/fight_card_scoring.dart';

class MMAScoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Score a user's picks for an MMA event
  Future<List<MMAPickScore>> scorePicks({
    required String userId,
    required String poolId,
    required String eventId,
    required List<MMAExtendedPick> userPicks,
    required MMAEvent event,
  }) async {
    final scores = <MMAPickScore>[];

    for (final pick in userPicks) {
      // Find the corresponding fight
      final fight = event.fights.firstWhere(
        (f) => f.id == pick.fightId || f.espnCompetitionId == pick.fightId,
        orElse: () => throw Exception('Fight not found: ${pick.fightId}'),
      );

      // Determine if the pick was correct
      final correctWinner = _isCorrectWinner(pick, fight);
      final correctMethod = _isCorrectMethod(pick, fight);
      final correctRound = _isCorrectRound(pick, fight);

      // Get card position
      final position = _getCardPosition(fight, event);

      // Calculate base points
      int basePoints = 0;
      if (correctWinner) {
        basePoints = MMAScoringConfig.CORRECT_WINNER;
        if (correctMethod) {
          basePoints += MMAScoringConfig.CORRECT_METHOD;
        }
        if (correctRound) {
          basePoints += MMAScoringConfig.CORRECT_ROUND;
        }
      }

      // Get position multiplier
      final multiplier = MMAScoringConfig.positionMultipliers[position] ?? 1.0;

      // Calculate total points with confidence
      final totalPoints = (basePoints * multiplier * pick.confidence).round();

      // Create score record
      final score = MMAPickScore(
        pickId: pick.id,
        fightId: pick.fightId,
        userId: userId,
        poolId: poolId,
        correctWinner: correctWinner,
        correctMethod: correctMethod,
        correctRound: correctRound,
        position: position,
        basePoints: basePoints,
        multiplier: multiplier,
        totalPoints: totalPoints,
        scoredAt: DateTime.now(),
        metadata: {
          'eventId': eventId,
          'eventName': event.eventName,
          'fightResult': {
            'winner': fight.winnerId,
            'method': fight.method,
            'round': fight.round,
          },
          'userPick': {
            'fighter': pick.pickedFighterId,
            'method': pick.predictedMethod?.toString(),
            'round': pick.predictedRound,
          },
        },
      );

      scores.add(score);
    }

    // Save scores to Firestore
    await _saveScores(scores);

    return scores;
  }

  /// Check if the user picked the correct winner
  bool _isCorrectWinner(MMAExtendedPick pick, MMAFight fight) {
    return fight.winnerId != null && fight.winnerId == pick.pickedFighterId;
  }

  /// Check if the user predicted the correct method
  bool _isCorrectMethod(MMAExtendedPick pick, MMAFight fight) {
    if (pick.predictedMethod == null || fight.method == null) {
      return false;
    }

    final actualMethod = MMAScoringConfig.getMethodFromResult(fight.method);
    return actualMethod == pick.predictedMethod;
  }

  /// Check if the user predicted the correct round
  bool _isCorrectRound(MMAExtendedPick pick, MMAFight fight) {
    if (pick.predictedRound == null || fight.round == null) {
      return false;
    }

    return pick.predictedRound == fight.round;
  }

  /// Get card position for a fight
  CardPosition _getCardPosition(MMAFight fight, MMAEvent event) {
    // Check if it's main event
    if (fight.isMainEvent == true) {
      return CardPosition.mainEvent;
    }

    // Check if it's co-main (second fight on main card)
    final mainCardFights = event.mainCard;
    if (mainCardFights.isNotEmpty && mainCardFights.length >= 2) {
      if (mainCardFights[1].id == fight.id) {
        return CardPosition.coMain;
      }
    }

    // Check which card the fight is on
    if (event.mainCard.any((f) => f.id == fight.id)) {
      return CardPosition.mainCard;
    } else if (event.prelims.any((f) => f.id == fight.id)) {
      return CardPosition.prelims;
    } else if (event.earlyPrelims.any((f) => f.id == fight.id)) {
      return CardPosition.earlyPrelims;
    }

    // Default to prelims if not found
    return CardPosition.prelims;
  }

  /// Save scores to Firestore
  Future<void> _saveScores(List<MMAPickScore> scores) async {
    final batch = _firestore.batch();

    for (final score in scores) {
      final docRef = _firestore
          .collection('mmaScores')
          .doc('${score.poolId}_${score.userId}_${score.fightId}');

      batch.set(docRef, score.toFirestore());
    }

    await batch.commit();
  }

  /// Get user's total score for a pool
  Future<int> getUserPoolScore({
    required String userId,
    required String poolId,
  }) async {
    final snapshot = await _firestore
        .collection('mmaScores')
        .where('userId', isEqualTo: userId)
        .where('poolId', isEqualTo: poolId)
        .get();

    int totalScore = 0;
    for (final doc in snapshot.docs) {
      final score = MMAPickScore.fromFirestore(doc.data());
      totalScore += score.totalPoints;
    }

    return totalScore;
  }

  /// Get leaderboard for a pool
  Future<List<PoolLeaderboardEntry>> getPoolLeaderboard({
    required String poolId,
    int limit = 100,
  }) async {
    // Get all scores for this pool
    final snapshot = await _firestore
        .collection('mmaScores')
        .where('poolId', isEqualTo: poolId)
        .get();

    // Group scores by user
    final userScores = <String, int>{};
    for (final doc in snapshot.docs) {
      final score = MMAPickScore.fromFirestore(doc.data());
      userScores[score.userId] = (userScores[score.userId] ?? 0) + score.totalPoints;
    }

    // Sort by total score
    final sortedEntries = userScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Create leaderboard entries
    final leaderboard = <PoolLeaderboardEntry>[];
    for (int i = 0; i < sortedEntries.length && i < limit; i++) {
      leaderboard.add(PoolLeaderboardEntry(
        userId: sortedEntries[i].key,
        rank: i + 1,
        totalScore: sortedEntries[i].value,
        userName: '', // Will be populated by the UI
      ));
    }

    return leaderboard;
  }

  /// Submit MMA picks with extended information
  Future<void> submitMMAPicksWithScoring({
    required String userId,
    required String poolId,
    required String eventId,
    required List<MMAExtendedPick> picks,
  }) async {
    final batch = _firestore.batch();

    for (final pick in picks) {
      final docRef = _firestore
          .collection('mmaPicks')
          .doc('${userId}_${poolId}_${pick.fightId}');

      batch.set(docRef, pick.toFirestore());
    }

    await batch.commit();
  }

  /// Get user's MMA picks for a pool
  Future<List<MMAExtendedPick>> getUserMMAPickss({
    required String userId,
    required String poolId,
  }) async {
    final snapshot = await _firestore
        .collection('mmaPicks')
        .where('userId', isEqualTo: userId)
        .where('poolId', isEqualTo: poolId)
        .get();

    return snapshot.docs
        .map((doc) => MMAExtendedPick.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Calculate potential points for a pick (preview)
  int calculatePotentialPoints({
    required CardPosition position,
    required FinishMethod? predictedMethod,
    required int? predictedRound,
    double confidence = 1.0,
  }) {
    int basePoints = MMAScoringConfig.CORRECT_WINNER;

    // Add potential bonus points
    if (predictedMethod != null) {
      basePoints += MMAScoringConfig.CORRECT_METHOD;
    }

    if (predictedRound != null) {
      basePoints += MMAScoringConfig.CORRECT_ROUND;
    }

    // Apply position multiplier
    final multiplier = MMAScoringConfig.positionMultipliers[position] ?? 1.0;

    // Calculate total with confidence
    return (basePoints * multiplier * confidence).round();
  }

  /// Get detailed scoring breakdown for a user's picks
  Future<Map<String, dynamic>> getScoringBreakdown({
    required String userId,
    required String poolId,
  }) async {
    final scores = await _firestore
        .collection('mmaScores')
        .where('userId', isEqualTo: userId)
        .where('poolId', isEqualTo: poolId)
        .get();

    int totalPoints = 0;
    int correctWinners = 0;
    int correctMethods = 0;
    int correctRounds = 0;
    final breakdown = <String, dynamic>{};

    for (final doc in scores.docs) {
      final score = MMAPickScore.fromFirestore(doc.data());
      totalPoints += score.totalPoints;

      if (score.correctWinner) correctWinners++;
      if (score.correctMethod) correctMethods++;
      if (score.correctRound) correctRounds++;
    }

    breakdown['totalPoints'] = totalPoints;
    breakdown['correctWinners'] = correctWinners;
    breakdown['correctMethods'] = correctMethods;
    breakdown['correctRounds'] = correctRounds;
    breakdown['totalPicks'] = scores.docs.length;
    breakdown['accuracy'] = scores.docs.isNotEmpty
        ? (correctWinners / scores.docs.length * 100).toStringAsFixed(1)
        : '0.0';

    return breakdown;
  }
}

/// Leaderboard entry for MMA pools
class PoolLeaderboardEntry {
  final String userId;
  final int rank;
  final int totalScore;
  final String userName;

  PoolLeaderboardEntry({
    required this.userId,
    required this.rank,
    required this.totalScore,
    required this.userName,
  });
}