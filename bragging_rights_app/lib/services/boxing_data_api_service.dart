import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/boxing_event_model.dart';
import '../models/boxing_fighter_model.dart';
import '../models/boxing_fight_model.dart';

class BoxingDataApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Read from Firestore cache only - no direct API calls
  // All API calls are made by Cloud Functions

  Future<List<BoxingEvent>> getCachedEvents() async {
    try {
      final snapshot = await _firestore
          .collection('boxing_events')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => BoxingEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching cached boxing events: $e');
      return [];
    }
  }

  Future<BoxingEvent?> getCachedEvent(String eventId) async {
    try {
      final doc = await _firestore
          .collection('boxing_events')
          .doc(eventId)
          .get();

      if (!doc.exists) return null;
      return BoxingEvent.fromFirestore(doc);
    } catch (e) {
      print('Error fetching cached event: $e');
      return null;
    }
  }

  Future<List<BoxingFight>> getCachedFights(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('boxing_fights')
          .where('eventId', isEqualTo: eventId)
          .orderBy('cardPosition')
          .get();

      return snapshot.docs
          .map((doc) => BoxingFight.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching cached fights: $e');
      return [];
    }
  }

  Future<BoxingFighter?> getCachedFighter(String fighterId) async {
    try {
      final doc = await _firestore
          .collection('boxing_fighters')
          .doc(fighterId)
          .get();

      if (!doc.exists) return null;
      return BoxingFighter.fromFirestore(doc);
    } catch (e) {
      print('Error fetching cached fighter: $e');
      return null;
    }
  }

  Future<List<BoxingFighter>> getCachedTopFighters({int limit = 10}) async {
    try {
      // Get champions first
      final championsSnapshot = await _firestore
          .collection('boxing_fighters')
          .where('titles', isNotEqualTo: [])
          .limit(limit ~/ 2)
          .get();

      // Get top rated fighters
      final topRatedSnapshot = await _firestore
          .collection('boxing_fighters')
          .orderBy('stats.wins', descending: true)
          .limit(limit ~/ 2)
          .get();

      // Combine and deduplicate
      final fighterMap = <String, BoxingFighter>{};

      for (var doc in championsSnapshot.docs) {
        final fighter = BoxingFighter.fromFirestore(doc);
        fighterMap[fighter.id] = fighter;
      }

      for (var doc in topRatedSnapshot.docs) {
        final fighter = BoxingFighter.fromFirestore(doc);
        fighterMap.putIfAbsent(fighter.id, () => fighter);
      }

      return fighterMap.values.take(limit).toList();
    } catch (e) {
      print('Error fetching top fighters: $e');
      return [];
    }
  }

  Stream<List<BoxingEvent>> streamCachedEvents() {
    return _firestore
        .collection('boxing_events')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BoxingEvent.fromFirestore(doc))
            .toList());
  }

  Future<bool> isCacheValid() async {
    try {
      final metadata = await _firestore
          .doc('boxing_cache/metadata')
          .get();

      if (!metadata.exists) return false;

      final data = metadata.data()!;
      final lastUpdated = (data['lastUpdated'] as Timestamp).toDate();
      final hoursSinceUpdate = DateTime.now().difference(lastUpdated).inHours;

      // Cache is valid if updated within last 24 hours
      return hoursSinceUpdate < 24;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }
}