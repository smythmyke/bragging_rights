import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/boxing_event_model.dart';
import '../models/boxing_fight_model.dart';
import '../models/boxing_fighter_model.dart';
import 'boxing_data_api_service.dart';
import 'espn_boxing_service.dart';
import 'boxing_odds_service.dart';

class BoxingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BoxingDataApiService _boxingDataApi = BoxingDataApiService();
  final ESPNBoxingService _espnApi = ESPNBoxingService();
  final BoxingOddsService _oddsApi = BoxingOddsService();

  static const int CACHE_HOURS = 24;

  Future<List<BoxingEvent>> getUpcomingEvents() async {
    try {
      // PRIMARY: Try The Odds API first (live data)
      print('Boxing: Fetching from The Odds API...');
      final oddsEvents = await _oddsApi.getUpcomingEventsFromOdds();

      if (oddsEvents.isNotEmpty) {
        print('Boxing: Using ${oddsEvents.length} events from The Odds API');
        return oddsEvents;
      }

      // SECONDARY: Try Firestore cache (Boxing Data API cached data)
      final cacheData = await _getEventsFromCache();

      if (cacheData.isNotEmpty && await _isCacheFresh()) {
        print('Boxing: Using cached Boxing Data API events');
        return cacheData;
      }

      // TERTIARY: Fallback to ESPN if all else fails
      print('Boxing: Trying ESPN API as last resort');
      final espnEvents = await _espnApi.getBoxingEvents();

      if (espnEvents.isEmpty) {
        // Return stale cache if everything fails
        print('Boxing: All APIs failed, returning stale cache');
        return cacheData;
      }

      return espnEvents;
    } catch (e) {
      print('Error fetching boxing events: $e');
      // Try The Odds API one more time
      try {
        final oddsEvents = await _oddsApi.getUpcomingEventsFromOdds(forceRefresh: true);
        if (oddsEvents.isNotEmpty) return oddsEvents;
      } catch (_) {}

      // Return cached data as last resort
      return await _getEventsFromCache();
    }
  }

  Future<List<BoxingEvent>> _getEventsFromCache() async {
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
      print('Error reading boxing cache: $e');
      return [];
    }
  }

  Future<BoxingEvent?> getEventDetails(String eventId, DataSource source) async {
    try {
      if (source == DataSource.boxingData) {
        // Get full data from cache
        final doc = await _firestore
            .collection('boxing_events')
            .doc(eventId)
            .get();

        if (doc.exists) {
          return BoxingEvent.fromFirestore(doc);
        }
      }

      // Fallback to ESPN for basic data
      return await _espnApi.getEventDetails(eventId);
    } catch (e) {
      print('Error fetching event details: $e');
      return null;
    }
  }

  Future<List<BoxingFight>?> getFightCard(String eventId) async {
    // Only available from Boxing Data cache
    try {
      final fights = await _firestore
          .collection('boxing_fights')
          .where('eventId', isEqualTo: eventId)
          .orderBy('cardPosition')
          .get();

      if (fights.docs.isEmpty) {
        print('No fights found for event $eventId');
        return null;
      }

      return fights.docs
          .map((doc) => BoxingFight.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching fight card: $e');
      return null;
    }
  }

  Future<BoxingFighter?> getFighter(String fighterId) async {
    try {
      // Try cache first
      final doc = await _firestore
          .collection('boxing_fighters')
          .doc(fighterId)
          .get();

      if (doc.exists) {
        return BoxingFighter.fromFirestore(doc);
      }

      // No ESPN fallback for individual fighters
      return null;
    } catch (e) {
      print('Error fetching fighter: $e');
      return null;
    }
  }

  Future<List<BoxingFighter>> getTopFighters({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('boxing_fighters')
          .where('titles', isNotEqualTo: [])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BoxingFighter.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching top fighters: $e');
      return [];
    }
  }

  Future<bool> _isCacheFresh() async {
    try {
      final metadata = await _firestore
          .doc('boxing_cache/metadata')
          .get();

      if (!metadata.exists) return false;

      final lastUpdated = metadata.data()?['lastUpdated'] as Timestamp?;
      if (lastUpdated == null) return false;

      final hoursSinceUpdate = DateTime.now()
          .difference(lastUpdated.toDate())
          .inHours;

      return hoursSinceUpdate < CACHE_HOURS;
    } catch (e) {
      print('Error checking cache freshness: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCacheMetadata() async {
    try {
      final doc = await _firestore
          .doc('boxing_cache/metadata')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching cache metadata: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>> watchCacheMetadata() {
    return _firestore
        .doc('boxing_cache/metadata')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  // Admin function to manually refresh cache
  Future<void> manualRefresh({String? eventId}) async {
    // This would trigger a Cloud Function
    // Implementation depends on your Cloud Function setup
    print('Manual refresh requested for event: $eventId');
  }
}