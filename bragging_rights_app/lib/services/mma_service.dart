import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mma_event_model.dart';
import '../models/mma_fighter_model.dart';

class MMAService {
  static const String UFC_SCOREBOARD = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
  static const String EVENT_BASE = 'http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/';
  static const String ATHLETE_BASE = 'http://sports.core.api.espn.com/v2/sports/mma/athletes/';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache durations
  static const Duration EVENT_CACHE_DURATION = Duration(hours: 24);
  static const Duration FIGHTER_CACHE_DURATION = Duration(days: 7);
  static const Duration IMAGE_CACHE_DURATION = Duration(days: 30);

  /// Get upcoming MMA events
  Future<List<MMAEvent>> getUpcomingEvents({String promotion = 'ufc'}) async {
    try {
      // Check cache first
      final cacheKey = 'mma_events_$promotion';
      try {
        final doc = await _firestore
            .collection('mma_cache')
            .doc(cacheKey)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final timestamp = data?['timestamp'];
          if (timestamp != null) {
            final cachedTime = DateTime.parse(timestamp);
            if (DateTime.now().difference(cachedTime) < EVENT_CACHE_DURATION) {
              return (data!['events'] as List)
                  .map((e) => MMAEvent.fromESPN(e))
                  .toList();
            }
          }
        }
      } catch (e) {
        print('Cache read error: $e');
      }

      // Fetch from ESPN API
      final url = _getScoreboardUrl(promotion);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = <MMAEvent>[];

        if (data['events'] != null) {
          for (final eventData in data['events']) {
            try {
              final event = MMAEvent.fromESPN(eventData);
              events.add(event);
            } catch (e) {
              print('Error parsing event: $e');
            }
          }
        }

        // Cache the results
        await _firestore
            .collection('mma_cache')
            .doc(cacheKey)
            .set({
          'events': events.map((e) => e.toJson()).toList(),
          'timestamp': DateTime.now().toIso8601String(),
        });

        return events;
      }

      return [];
    } catch (e) {
      print('Error fetching MMA events: $e');
      return [];
    }
  }

  /// Get event with full fight card
  Future<MMAEvent?> getEventWithFights(String eventId, {Map<String, dynamic>? gameData}) async {
    print('🥊 Loading MMA event: $eventId');

    try {
      // Check if this is a pseudo-ESPN ID (starts with '9')
      bool isPseudoId = eventId.startsWith('9');

      // If we have a pseudo-ID and game data with fights, use that directly
      if (isPseudoId && gameData != null && gameData['fights'] != null) {
        print('📦 Using provided game data for pseudo-ESPN ID: $eventId');
        return _createEventFromGameData(eventId, gameData);
      }

      // Check if eventId looks like an ESPN ID (should be numeric)
      String espnEventId = eventId;
      if (!RegExp(r'^\d+$').hasMatch(eventId)) {
        print('⚠️ Invalid ESPN event ID format: $eventId');
        return null;
      }

      // Check cache (with permission handling)
      final cacheKey = 'mma_event_$eventId';
      try {
        final doc = await _firestore
            .collection('mma_events')
            .doc(cacheKey)
            .get();

        if (doc.exists && doc.data() != null) {
          print('✅ Loaded event from cache');
          return MMAEvent.fromESPN(doc.data()!);
        }
      } catch (e) {
        print('⚠️ Cache read error (likely permissions): $e');
        // Continue to fetch from API
      }

      // Don't try to fetch pseudo-IDs from ESPN
      if (isPseudoId) {
        print('⚠️ Skipping ESPN API for pseudo-ID: $eventId');
        return null;
      }

      // Fetch event details
      final eventUrl = '$EVENT_BASE$espnEventId';
      print('🌐 Fetching from ESPN API: $eventUrl');
      final response = await http.get(Uri.parse(eventUrl));

      if (response.statusCode != 200) {
        print('❌ ESPN API returned status: ${response.statusCode}');
        return null;
      }

      final eventData = json.decode(response.body);
      print('✅ Received event data from ESPN');

      // Fetch competitions (fights)
      final fights = <MMAFight>[];
      if (eventData['competitions'] != null) {
        print('📊 Processing ${eventData['competitions'].length} fights');
        for (final comp in eventData['competitions']) {
          try {
            // Get competition details
            String compUrl = comp['\$ref'];
            if (!compUrl.startsWith('http')) {
              compUrl = 'http:$compUrl';
            }

            final compResponse = await http.get(Uri.parse(compUrl));
            if (compResponse.statusCode == 200) {
              final compData = json.decode(compResponse.body);

              // Get fighters for this competition
              MMAFighter? fighter1;
              MMAFighter? fighter2;

              if (compData['competitors'] != null) {
                final competitors = compData['competitors'] as List;

                for (int i = 0; i < competitors.length && i < 2; i++) {
                  final competitor = competitors[i];
                  final athleteRef = competitor['athlete']?['\$ref'];

                  if (athleteRef != null) {
                    final fighter = await _getFighter(athleteRef);
                    if (i == 0) {
                      fighter1 = fighter;
                    } else {
                      fighter2 = fighter;
                    }
                  }
                }
              }

              // Determine card position based on fight order
              final fightOrder = fights.length;
              String cardPosition = 'early'; // Default

              if (fightOrder == 0) {
                // Main event (last fight added)
                cardPosition = 'main';
              } else if (fightOrder <= 4) {
                // Main card (typically 4-5 fights)
                cardPosition = 'main';
              } else if (fightOrder <= 8) {
                // Prelims
                cardPosition = 'prelim';
              }

              final fight = MMAFight.fromESPN(
                compData,
                fighter1: fighter1,
                fighter2: fighter2,
              );

              // Update card position
              final updatedFight = MMAFight(
                id: fight.id,
                fighter1: fight.fighter1,
                fighter2: fight.fighter2,
                weightClass: fight.weightClass,
                rounds: fight.rounds,
                isMainEvent: fightOrder == 0,
                isCoMainEvent: fightOrder == 1,
                isTitleFight: fight.isTitleFight,
                cardPosition: cardPosition,
                fightOrder: fightOrder,
                fighter1Odds: fight.fighter1Odds,
                fighter2Odds: fight.fighter2Odds,
                winnerId: fight.winnerId,
                method: fight.method,
                methodDetails: fight.methodDetails,
                endRound: fight.endRound,
                endTime: fight.endTime,
                status: fight.status,
                isComplete: fight.isComplete,
                isCancelled: fight.isCancelled,
              );

              fights.add(updatedFight);
            }
          } catch (e) {
            print('Error processing fight: $e');
          }
        }
      }

      // Reverse fights so main event is last
      fights.reversed.toList();

      final event = MMAEvent.fromESPN(eventData, fights: fights);
      print('✅ Created MMA event with ${fights.length} fights');

      // Try to cache the event (but don't fail if permissions denied)
      try {
        await _firestore
            .collection('mma_events')
            .doc(cacheKey)
            .set(event.toJson());
        print('💾 Event cached successfully');
      } catch (e) {
        print('⚠️ Failed to cache event (permissions?): $e');
        // Continue without caching
      }

      return event;
    } catch (e) {
      print('Error fetching event with fights: $e');
      return null;
    }
  }

  /// Get fighter details
  Future<MMAFighter?> _getFighter(String athleteRef) async {
    try {
      // Extract fighter ID from ref
      final regex = RegExp(r'/athletes/(\d+)');
      final match = regex.firstMatch(athleteRef);
      if (match == null) return null;

      final fighterId = match.group(1)!;

      // Check cache
      final cacheKey = 'fighter_$fighterId';
      try {
        final doc = await _firestore
            .collection('mma_fighters')
            .doc(cacheKey)
            .get();

        if (doc.exists && doc.data() != null) {
          return MMAFighter.fromJson(doc.data()!);
        }
      } catch (e) {
        print('Cache read error: $e');
      }

      // Ensure URL is complete
      String url = athleteRef;
      if (!url.startsWith('http')) {
        url = 'http:$url';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse fighter record if available
        final recordsRef = data['records']?['\$ref'];
        if (recordsRef != null) {
          try {
            String recordUrl = recordsRef;
            if (!recordUrl.startsWith('http')) {
              recordUrl = 'http:$recordUrl';
            }

            final recordResponse = await http.get(Uri.parse(recordUrl));
            if (recordResponse.statusCode == 200) {
              final recordData = json.decode(recordResponse.body);
              data['records'] = recordData;
            }
          } catch (e) {
            print('Error fetching fighter record: $e');
          }
        }

        final fighter = MMAFighter.fromESPN(data);

        // Cache fighter data
        await _firestore
            .collection('mma_fighters')
            .doc(cacheKey)
            .set(fighter.toJson());

        // Cache fighter image separately for longer duration
        if (fighter.headshotUrl != null) {
          await _cacheFighterImage(fighterId, fighter.headshotUrl!);
        }

        return fighter;
      }

      return null;
    } catch (e) {
      print('Error fetching fighter: $e');
      return null;
    }
  }

  /// Cache fighter image URL
  Future<void> _cacheFighterImage(String fighterId, String imageUrl) async {
    try {
      await _firestore
          .collection('fighter_images')
          .doc(fighterId)
          .set({
        'url': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error caching fighter image: $e');
    }
  }

  /// Get cached fighter image URL
  Future<String?> getCachedFighterImage(String fighterId) async {
    try {
      final doc = await _firestore
          .collection('fighter_images')
          .doc(fighterId)
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['url'];
      }

      // Generate ESPN image URL as fallback
      return 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';
    } catch (e) {
      print('Error getting cached fighter image: $e');
      return null;
    }
  }

  /// Get fighter by name (simplified without ID resolver)
  Future<MMAFighter?> getFighterByName(String name) async {
    try {
      // For now, return null - would need to implement name search
      // This could be done via ESPN search API or cached fighter names
      return null;
    } catch (e) {
      print('Error fetching fighter by name: $e');
      return null;
    }
  }

  /// Clear old cache entries
  Future<void> clearOldCache() async {
    try {
      // Would need to implement batch delete for old documents
      // For now, just log
      print('Cache cleanup not implemented');
    } catch (e) {
      print('Error clearing old cache: $e');
    }
  }

  String _getScoreboardUrl(String promotion) {
    switch (promotion.toLowerCase()) {
      case 'ufc':
        return UFC_SCOREBOARD;
      case 'bellator':
        return 'https://site.api.espn.com/apis/site/v2/sports/mma/bellator/scoreboard';
      case 'pfl':
        return 'https://site.api.espn.com/apis/site/v2/sports/mma/pfl/scoreboard';
      default:
        return UFC_SCOREBOARD;
    }
  }

  /// Detect promotion from event name
  String _detectPromotion(String eventName) {
    final upperName = eventName.toUpperCase();

    if (upperName.contains('UFC')) {
      return 'UFC';
    } else if (upperName.contains('PFL')) {
      return 'PFL';
    } else if (upperName.contains('BELLATOR')) {
      return 'Bellator';
    } else if (upperName.contains('ONE') && (upperName.contains('CHAMPIONSHIP') || upperName.contains('FC'))) {
      return 'ONE Championship';
    }

    // Default to UFC
    return 'UFC';
  }

  /// Get promotion logo URL
  String? _getPromotionLogoUrl(String promotion) {
    switch (promotion) {
      case 'UFC':
        return 'https://a.espncdn.com/i/teamlogos/leagues/500/ufc.png';
      case 'PFL':
        return 'https://a.espncdn.com/i/teamlogos/leagues/500/pfl.png';
      case 'Bellator':
        // Using Bellator's official logo
        return 'https://www.bellator.com/themes/custom/bellator/assets/images/bellator-mma.svg';
      case 'ONE Championship':
        // Using ONE Championship's official logo
        return 'https://www.onefc.com/wp-content/themes/onefc/assets/images/logo.svg';
      default:
        // Default to UFC logo
        return 'https://a.espncdn.com/i/teamlogos/leagues/500/ufc.png';
    }
  }

  /// Generate fighter image URL
  String? _generateFighterImageUrl(String fighterId) {
    // Skip if it's a placeholder ID
    if (fighterId.startsWith('f1_') || fighterId.startsWith('f2_')) {
      return null;
    }

    // ESPN MMA fighter headshot URL format
    return 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';
  }

  /// Create MMA event from game data (for pseudo-ESPN IDs)
  MMAEvent _createEventFromGameData(String eventId, Map<String, dynamic> gameData) {
    print('🎯 Creating MMA event from game data');

    final fights = <MMAFight>[];
    final fightDataList = gameData['fights'] as List? ?? [];

    for (int i = 0; i < fightDataList.length; i++) {
      final fightData = fightDataList[i] as Map<String, dynamic>;

      // Create basic fighter objects from the fight data
      final fighterName1 = fightData['fighter1'] ?? fightData['awayTeam'] ?? 'Fighter 1';
      final fighter1Id = fightData['fighter1Id']?.toString() ?? 'f1_$i';
      final fighter1 = MMAFighter(
        id: fighter1Id,
        name: fighterName1,
        displayName: fighterName1,
        shortName: fighterName1.split(' ').last,
        record: fightData['fighter1Record'] ?? '0-0-0',
        nickname: null,
        headshotUrl: _generateFighterImageUrl(fighter1Id),
        espnId: fighter1Id,
      );

      final fighterName2 = fightData['fighter2'] ?? fightData['homeTeam'] ?? 'Fighter 2';
      final fighter2Id = fightData['fighter2Id']?.toString() ?? 'f2_$i';
      final fighter2 = MMAFighter(
        id: fighter2Id,
        name: fighterName2,
        displayName: fighterName2,
        shortName: fighterName2.split(' ').last,
        record: fightData['fighter2Record'] ?? '0-0-0',
        nickname: null,
        headshotUrl: _generateFighterImageUrl(fighter2Id),
        espnId: fighter2Id,
      );

      // Determine card position based on fight order
      String cardPosition = 'early';
      bool isMainEvent = false;
      bool isCoMainEvent = false;

      if (i == fightDataList.length - 1) {
        // Last fight is main event
        cardPosition = 'main';
        isMainEvent = true;
      } else if (i == fightDataList.length - 2) {
        // Second to last is co-main
        cardPosition = 'main';
        isCoMainEvent = true;
      } else if (i >= fightDataList.length - 5) {
        // Last 5 fights are main card
        cardPosition = 'main';
      } else if (i >= fightDataList.length - 8) {
        // Next 3-4 fights are prelims
        cardPosition = 'prelim';
      }

      // Extract odds if available
      Map<String, dynamic>? odds = fightData['odds'];
      double? fighter1Odds;
      double? fighter2Odds;

      if (odds != null && odds['moneyline'] != null) {
        fighter1Odds = odds['moneyline']['fighter1']?.toDouble();
        fighter2Odds = odds['moneyline']['fighter2']?.toDouble();
      }

      final fight = MMAFight(
        id: fightData['id']?.toString() ?? 'fight_$i',
        fighter1: fighter1,
        fighter2: fighter2,
        weightClass: fightData['weightClass'] ?? 'TBD',
        rounds: 3,  // Default, main events are usually 5
        isMainEvent: isMainEvent,
        isCoMainEvent: isCoMainEvent,
        isTitleFight: fightData['isTitleFight'] ?? false,
        cardPosition: cardPosition,
        fightOrder: i,
        fighter1Odds: fighter1Odds,
        fighter2Odds: fighter2Odds,
        winnerId: null,
        method: null,
        methodDetails: null,
        endRound: null,
        endTime: null,
        status: 'scheduled',
        isComplete: false,
        isCancelled: false,
      );

      fights.add(fight);
    }

    // Create the event
    // Handle gameTime which can be either DateTime or milliseconds (int)
    DateTime eventDate;
    if (gameData['gameTime'] is DateTime) {
      eventDate = gameData['gameTime'];
    } else if (gameData['gameTime'] is int) {
      eventDate = DateTime.fromMillisecondsSinceEpoch(gameData['gameTime']);
    } else {
      eventDate = DateTime.now();
    }

    final eventName = gameData['league'] ?? gameData['eventName'] ?? 'MMA Event';
    final promotion = _detectPromotion(eventName);
    final promotionLogo = _getPromotionLogoUrl(promotion);

    return MMAEvent(
      id: eventId,
      name: eventName,
      date: eventDate,
      venueName: gameData['venue'],
      fights: fights,
      broadcasters: gameData['broadcast'] != null ? [gameData['broadcast']] : [],
      promotion: promotion,
      promotionLogoUrl: promotionLogo,
      espnEventId: eventId,
    );
  }

}