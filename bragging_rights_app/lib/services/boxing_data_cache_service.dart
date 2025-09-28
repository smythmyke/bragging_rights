import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Boxing Data Cache Service - Reads from Firestore cache populated by Cloud Functions
/// No API calls are made from the client - all data comes from cached Firestore
class BoxingDataCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final BoxingDataCacheService _instance = BoxingDataCacheService._internal();
  factory BoxingDataCacheService() => _instance;
  BoxingDataCacheService._internal();

  /// Get cached boxing event with poster and full details
  Future<Map<String, dynamic>?> getCachedEvent(String eventId) async {
    try {
      final doc = await _firestore
          .collection('boxing_events')
          .doc(eventId)
          .get();

      if (!doc.exists) {
        debugPrint('❌ No cached data for event: $eventId');
        return null;
      }

      final data = doc.data()!;

      // Check if cache is still valid
      if (data['cacheExpiry'] != null) {
        final expiry = (data['cacheExpiry'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiry)) {
          debugPrint('⏰ Cache expired for event: $eventId');
          return null;
        }
      }

      debugPrint('✅ Cache hit for event: $eventId');
      return data;
    } catch (e) {
      debugPrint('Error reading event cache: $e');
      return null;
    }
  }

  /// Get cached fighter profile with record and image
  Future<Map<String, dynamic>?> getCachedFighter(String fighterName) async {
    try {
      // Normalize fighter name for cache key
      final cacheKey = fighterName.toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll("'", '')
          .replaceAll('.', '');

      final doc = await _firestore
          .collection('boxing_fighters')
          .doc(cacheKey)
          .get();

      if (!doc.exists) {
        debugPrint('❌ No cached data for fighter: $fighterName');
        return null;
      }

      final data = doc.data()!;
      debugPrint('✅ Cache hit for fighter: $fighterName');
      return data;
    } catch (e) {
      debugPrint('Error reading fighter cache: $e');
      return null;
    }
  }

  /// Get cached fights for an event
  Future<List<Map<String, dynamic>>> getCachedFights(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('boxing_fights')
          .where('eventId', isEqualTo: eventId)
          .orderBy('cardPosition')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('❌ No cached fights for event: $eventId');
        return [];
      }

      debugPrint('✅ Found ${snapshot.docs.length} cached fights for event: $eventId');
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error reading fights cache: $e');
      return [];
    }
  }

  /// Get current API usage statistics
  Future<Map<String, dynamic>?> getApiUsageStats() async {
    try {
      final doc = await _firestore
          .doc('boxing_cache/metadata')
          .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      debugPrint('Error reading API usage stats: $e');
      return null;
    }
  }

  /// Check if we have cached data for a fighter
  Future<bool> hasCachedFighter(String fighterName) async {
    final cacheKey = fighterName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '')
        .replaceAll('.', '');

    final doc = await _firestore
        .collection('boxing_fighters')
        .doc(cacheKey)
        .get();

    return doc.exists;
  }

  /// Get multiple fighters in batch (more efficient)
  Future<Map<String, Map<String, dynamic>>> getCachedFightersBatch(
    List<String> fighterNames,
  ) async {
    final results = <String, Map<String, dynamic>>{};

    // Process in batches of 10 (Firestore limit)
    for (var i = 0; i < fighterNames.length; i += 10) {
      final batch = fighterNames.skip(i).take(10).toList();
      final cacheKeys = batch.map((name) =>
        name.toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll("'", '')
            .replaceAll('.', '')
      ).toList();

      try {
        // Get multiple documents at once
        final futures = cacheKeys.map((key) =>
          _firestore.collection('boxing_fighters').doc(key).get()
        ).toList();

        final docs = await Future.wait(futures);

        for (var j = 0; j < docs.length; j++) {
          if (docs[j].exists) {
            results[batch[j]] = docs[j].data()!;
          }
        }
      } catch (e) {
        debugPrint('Error in batch fetch: $e');
      }
    }

    debugPrint('📊 Batch cache results: ${results.length}/${fighterNames.length} found');
    return results;
  }

  /// Listen to API usage changes
  Stream<Map<String, dynamic>> watchApiUsage() {
    return _firestore
        .doc('boxing_cache/metadata')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  /// Get enrichment data for a boxing event from Odds API
  Future<BoxingEventEnrichment?> getEventEnrichment(
    String eventTitle,
    List<String> fighterNames,
  ) async {
    try {
      // Try to find matching event in cache by title similarity
      final eventsSnapshot = await _firestore
          .collection('boxing_events')
          .where('cacheExpiry', isGreaterThan: DateTime.now())
          .get();

      for (final doc in eventsSnapshot.docs) {
        final data = doc.data();
        final cachedTitle = (data['title'] ?? '').toLowerCase();
        final searchTitle = eventTitle.toLowerCase();

        // Check if titles match (fuzzy matching)
        if (_titlesMatch(cachedTitle, searchTitle)) {
          debugPrint('🎯 Found matching event: ${data['title']}');

          // Get fighter data
          final fighterData = await getCachedFightersBatch(fighterNames);

          return BoxingEventEnrichment(
            eventId: doc.id,
            posterUrl: data['poster_image_url'],
            venue: data['venue'],
            location: data['location'],
            promotion: data['promotion'],
            broadcasters: List<String>.from(data['broadcasters'] ?? []),
            fighterProfiles: fighterData,
          );
        }
      }

      // No matching event, try to get just fighter data
      final fighterData = await getCachedFightersBatch(fighterNames);
      if (fighterData.isNotEmpty) {
        return BoxingEventEnrichment(
          fighterProfiles: fighterData,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error getting event enrichment: $e');
      return null;
    }
  }

  /// Check if two titles match (fuzzy matching)
  bool _titlesMatch(String title1, String title2) {
    // Direct match
    if (title1 == title2) return true;

    // Check if both contain same fighter names
    final words1 = title1.split(RegExp(r'[\s\-vs\.]+'));
    final words2 = title2.split(RegExp(r'[\s\-vs\.]+'));

    int matches = 0;
    for (final word1 in words1) {
      if (word1.length < 3) continue; // Skip short words
      for (final word2 in words2) {
        if (word2.length < 3) continue;
        if (word1.contains(word2) || word2.contains(word1)) {
          matches++;
          break;
        }
      }
    }

    // If at least 2 significant words match, consider it a match
    return matches >= 2;
  }
}

/// Enrichment data for a boxing event
class BoxingEventEnrichment {
  final String? eventId;
  final String? posterUrl;
  final String? venue;
  final String? location;
  final String? promotion;
  final List<String>? broadcasters;
  final Map<String, Map<String, dynamic>> fighterProfiles;

  BoxingEventEnrichment({
    this.eventId,
    this.posterUrl,
    this.venue,
    this.location,
    this.promotion,
    this.broadcasters,
    this.fighterProfiles = const {},
  });

  /// Get fighter record (e.g., "32-2-1")
  String? getFighterRecord(String fighterName) {
    final profile = fighterProfiles[fighterName];
    if (profile == null) return null;

    final wins = profile['wins'] ?? 0;
    final losses = profile['losses'] ?? 0;
    final draws = profile['draws'] ?? 0;

    if (wins == 0 && losses == 0) return null;

    return '$wins-$losses${draws > 0 ? '-$draws' : ''}';
  }

  /// Get fighter image URL
  String? getFighterImage(String fighterName) {
    final profile = fighterProfiles[fighterName];
    return profile?['image_url'] ?? profile?['imageUrl'];
  }

  /// Get fighter ranking
  String? getFighterRanking(String fighterName) {
    final profile = fighterProfiles[fighterName];
    final ranking = profile?['ranking'];
    if (ranking == null) return null;
    return '#$ranking';
  }

  /// Check if fighter is a champion
  bool isFighterChampion(String fighterName) {
    final profile = fighterProfiles[fighterName];
    final titles = profile?['titles'] as List?;
    return titles != null && titles.isNotEmpty;
  }

  /// Get fighter's titles
  List<String> getFighterTitles(String fighterName) {
    final profile = fighterProfiles[fighterName];
    final titles = profile?['titles'] as List?;
    if (titles == null) return [];
    return titles.map((t) => t.toString()).toList();
  }

  /// Get fighter's weight class
  String? getFighterWeightClass(String fighterName) {
    final profile = fighterProfiles[fighterName];
    return profile?['weight_class'] ?? profile?['division'];
  }
}