import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mma_event_model.dart';
import '../models/mma_fighter_model.dart';
import 'api_call_tracker.dart';

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
      APICallTracker.logAPICall('ESPN', 'MMA Scoreboard', details: 'Fetching upcoming events');
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

  /// Get event with full fight card from ESPN only
  Future<MMAEvent?> getFullEventFromESPN(String eventId) async {
    print('🥊 Loading MMA event from ESPN: $eventId');

    try {
      // Check cache first
      final cacheKey = 'mma_event_full_$eventId';
      final cachedEvent = await _getEventFromCache(cacheKey);
      if (cachedEvent != null) {
        print('📦 Using cached event data');
        return cachedEvent;
      }

      // Fetch from ESPN API
      final event = await _fetchEventFromESPN(eventId);

      if (event != null) {
        // Cache the event
        await _cacheEvent(cacheKey, event);
      }

      return event;
    } catch (e) {
      print('❌ Error loading event: $e');
      return null;
    }
  }

  /// Get event with full fight card (legacy method for compatibility)
  Future<MMAEvent?> getEventWithFights(String eventId, {Map<String, dynamic>? gameData}) async {
    print('🥊 Loading MMA event: $eventId');

    try {
      // Check if this is a pseudo-ESPN ID (starts with '9')
      bool isPseudoId = eventId.startsWith('9');

      // If we have a pseudo-ID and game data with fights, use that directly
      if (isPseudoId && gameData != null && gameData['fights'] != null) {
        print('📦 Using provided game data for pseudo-ESPN ID: $eventId');
        return await _createEventFromGameData(eventId, gameData);
      }

      // Check if eventId looks like an ESPN ID (should be numeric)
      String espnEventId = eventId;
      if (!RegExp(r'^\d+$').hasMatch(eventId)) {
        print('⚠️ Invalid ESPN event ID format: $eventId');
        return null;
      }

      // Cache removed due to permission issues

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

        // First, collect all fighter URLs to batch fetch
        final fighterRefs = <String>[];
        final competitionData = <Map<String, dynamic>>[];

        // Fetch all competition data first
        for (final comp in eventData['competitions']) {
          try {
            String compUrl = comp['\$ref'];
            if (!compUrl.startsWith('http')) {
              compUrl = 'http:$compUrl';
            }

            final compResponse = await http.get(Uri.parse(compUrl));
            if (compResponse.statusCode == 200) {
              final compData = json.decode(compResponse.body);
              competitionData.add(compData);

              // Collect fighter refs - handle both List and Map structures
              if (compData['competitors'] != null) {
                final competitorsData = compData['competitors'];
                final competitors = competitorsData is List
                    ? competitorsData
                    : competitorsData is Map && competitorsData.containsKey('items')
                        ? competitorsData['items'] as List
                        : [];

                for (final competitor in competitors) {
                  final athleteRef = competitor['athlete']?['\$ref'];
                  if (athleteRef != null) {
                    fighterRefs.add(athleteRef);
                  }
                }
              }
            }
          } catch (e) {
            print('Error fetching competition: $e');
          }
        }

        // Batch fetch all fighters
        print('🎯 Batch fetching ${fighterRefs.length} fighters');
        final fighterMap = await _batchFetchFighters(fighterRefs);

        // Now process competitions with cached fighter data
        for (final compData in competitionData) {
          try {
            MMAFighter? fighter1;
            MMAFighter? fighter2;

            if (compData['competitors'] != null) {
              // Handle both List and Map structures
              final competitorsData = compData['competitors'];
              final competitors = competitorsData is List
                  ? competitorsData
                  : competitorsData is Map && competitorsData.containsKey('items')
                      ? competitorsData['items'] as List
                      : [];

              for (int i = 0; i < competitors.length && i < 2; i++) {
                final competitor = competitors[i];
                final athleteRef = competitor['athlete']?['\$ref'];

                if (athleteRef != null && fighterMap.containsKey(athleteRef)) {
                  if (i == 0) {
                    fighter1 = fighterMap[athleteRef];
                  } else {
                    fighter2 = fighterMap[athleteRef];
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
          } catch (e) {
            print('Error processing fight: $e');
          }
        }
      }

      // Reverse fights so main event is last
      final reversedFights = fights.reversed.toList();

      final event = MMAEvent.fromESPN(eventData, fights: reversedFights);
      print('✅ Created MMA event with ${fights.length} fights');

      // Cache removed due to permission issues

      return event;
    } catch (e) {
      print('Error fetching event with fights: $e');
      return null;
    }
  }

  /// Get event from cache
  Future<MMAEvent?> _getEventFromCache(String cacheKey) async {
    try {
      final doc = await _firestore
          .collection('mma_events_cache')
          .doc(cacheKey)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final timestamp = data?['timestamp'];
        if (timestamp != null) {
          final cachedTime = DateTime.parse(timestamp);
          if (DateTime.now().difference(cachedTime) < EVENT_CACHE_DURATION) {
            return MMAEvent.fromJson(data!['event']);
          }
        }
      }
    } catch (e) {
      print('Cache read error: $e');
    }
    return null;
  }

  /// Cache event data
  Future<void> _cacheEvent(String cacheKey, MMAEvent event) async {
    try {
      await _firestore
          .collection('mma_events_cache')
          .doc(cacheKey)
          .set({
        'event': event.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Cache write error: $e');
    }
  }

  /// Fetch event from ESPN API
  Future<MMAEvent?> _fetchEventFromESPN(String eventId) async {
    try {
      // Fetch main event data
      final eventUrl = '$EVENT_BASE$eventId';
      print('🌐 Fetching event from: $eventUrl');

      final response = await http.get(Uri.parse(eventUrl));
      if (response.statusCode != 200) {
        print('❌ ESPN API returned status: ${response.statusCode}');
        return null;
      }

      final eventData = json.decode(response.body);

      // Fetch competitions with proper ESPN IDs
      final fights = await _fetchEventCompetitions(eventData);

      // Create event with all ESPN data
      final event = MMAEvent(
        id: eventId,
        espnId: eventId,
        name: eventData['name'] ?? '',
        shortName: eventData['shortName'],
        date: DateTime.parse(eventData['date']),
        status: eventData['status']?['type']?['description'] ?? 'scheduled',
        venue: eventData['venue']?['fullName'],
        venueCity: eventData['venue']?['address']?['city'],
        venueCountry: eventData['venue']?['address']?['country'],
        promotion: _extractPromotion(eventData),
        fights: fights,
        mainEvent: fights.isNotEmpty ? fights.first : null,
      );

      return event;
    } catch (e) {
      print('Error fetching event from ESPN: $e');
      return null;
    }
  }

  /// Fetch all competitions (fights) for an event
  Future<List<MMAFight>> _fetchEventCompetitions(Map<String, dynamic> eventData) async {
    final fights = <MMAFight>[];

    if (eventData['competitions'] == null) return fights;

    for (final comp in eventData['competitions']) {
      try {
        String compUrl = comp['\$ref'];
        if (!compUrl.startsWith('http')) {
          compUrl = 'http:$compUrl';
        }

        final compResponse = await http.get(Uri.parse(compUrl));
        if (compResponse.statusCode == 200) {
          final compData = json.decode(compResponse.body);

          // Extract fighter ESPN IDs directly
          final competitors = compData['competitors'] ?? [];
          String? fighter1Id;
          String? fighter2Id;

          if (competitors.length >= 2) {
            fighter1Id = competitors[0]['id']?.toString();
            fighter2Id = competitors[1]['id']?.toString();
          }

          // Create fight with ESPN IDs
          final fight = MMAFight(
            id: compData['id']?.toString() ?? '',
            espnCompetitionId: compData['id']?.toString(),
            fighter1EspnId: fighter1Id,
            fighter2EspnId: fighter2Id,
            fighter1: await _getFighter(competitors[0]['athlete']?['\$ref']),
            fighter2: await _getFighter(competitors[1]['athlete']?['\$ref']),
            weightClass: compData['type']?['text'] ?? '',
            rounds: compData['format']?['regulation']?['periods'] ?? 3,
            isMainEvent: fights.isEmpty, // First fight is main event
            isCoMainEvent: fights.length == 1,
            isTitleFight: compData['notes']?.toString().contains('Title') ?? false,
            cardPosition: _determineCardPosition(fights.length),
            fightOrder: fights.length,
            status: compData['status']?['type']?['description'],
            isComplete: compData['status']?['type']?['completed'] ?? false,
          );

          fights.add(fight);
        }
      } catch (e) {
        print('Error processing competition: $e');
      }
    }

    return fights;
  }

  /// Determine card position based on fight order
  String _determineCardPosition(int fightOrder) {
    if (fightOrder == 0) return 'main';
    if (fightOrder <= 4) return 'main';
    if (fightOrder <= 8) return 'prelim';
    return 'early';
  }

  /// Extract promotion from event data
  String _extractPromotion(Map<String, dynamic> eventData) {
    final league = eventData['league']?['abbreviation'] ?? '';
    return league.toUpperCase();
  }

  /// Batch fetch fighters to reduce API calls
  Future<Map<String, MMAFighter>> _batchFetchFighters(List<String> fighterRefs) async {
    final fighterMap = <String, MMAFighter>{};

    // Process in parallel batches of 5 to avoid overwhelming the API
    const batchSize = 5;
    for (int i = 0; i < fighterRefs.length; i += batchSize) {
      final batch = fighterRefs.skip(i).take(batchSize).toList();
      final futures = batch.map((ref) => _getFighterSimple(ref));

      final results = await Future.wait(futures);

      for (int j = 0; j < batch.length; j++) {
        if (results[j] != null) {
          fighterMap[batch[j]] = results[j]!;
        }
      }
    }

    return fighterMap;
  }

  /// Get fighter with minimal API calls (no stats for initial load)
  Future<MMAFighter?> _getFighterSimple(String athleteRef) async {
    try {
      String url = athleteRef;
      if (!url.startsWith('http')) {
        url = 'http:$url';
      }

      print('    📡 Fetching fighter from: $url');

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ).timeout(Duration(seconds: 10));

        print('    📡 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('    📊 Fighter data received: ${data['displayName']} (ID: ${data['id']})');

          // Only fetch record, skip statistics for now
          final recordsRef = data['records']?['\$ref'];
          if (recordsRef != null) {
            try {
              String recordUrl = recordsRef;
              if (!recordUrl.startsWith('http')) {
                recordUrl = 'http:$recordUrl';
              }

              final recordResponse = await http.get(
                Uri.parse(recordUrl),
                headers: {'User-Agent': 'Mozilla/5.0'},
              ).timeout(Duration(seconds: 5));

              if (recordResponse.statusCode == 200) {
                data['records'] = json.decode(recordResponse.body);
              }
            } catch (e) {
              print('    ⚠️ Could not fetch record: $e');
            }
          }

          final fighter = MMAFighter.fromESPN(data);
          print('    ✅ Fighter object created: ${fighter.name} with ESPN ID: ${fighter.espnId}');
          return fighter;
        } else {
          print('    ❌ Failed to fetch fighter. Status code: ${response.statusCode}');
          print('    Response body: ${response.body.substring(0, 200 < response.body.length ? 200 : response.body.length)}');
        }
      } catch (e, stack) {
        print('    ❌ HTTP request error: $e');
        if (e.toString().contains('TimeoutException')) {
          print('    ⏱️ Request timed out');
        }
        print('    Stack: ${stack.toString().split('\n').take(3).join('\n')}');
      }
    } catch (e) {
      print('    ❌ Error in _getFighterSimple: $e');
    }
    return null;
  }

  /// Get fighter by ID directly
  Future<MMAFighter?> _getFighterById(String fighterId) async {
    try {
      print('\n📋 _getFighterById called with ID: $fighterId');

      // Skip placeholder IDs
      if (fighterId.startsWith('f1_') || fighterId.startsWith('f2_')) {
        print('  ⚠️ Skipping placeholder fighter ID: $fighterId');
        return null;
      }

      // Skip cache - removed due to permission issues

      // Build the URL directly for the fighter
      final url = '$ATHLETE_BASE$fighterId';
      print('  🌐 Fetching from URL: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        print('  ✅ API response received successfully');
        final data = json.decode(response.body);

        print('  📊 Fighter data keys: ${data.keys.toList().take(10)}');
        print('    - Name: ${data['displayName'] ?? data['fullName'] ?? 'Unknown'}');
        print('    - ID: ${data['id']}');

        // Parse fighter record if available
        final recordsRef = data['records']?['\$ref'];
        if (recordsRef != null) {
          try {
            String recordUrl = recordsRef;
            if (!recordUrl.startsWith('http')) {
              recordUrl = 'http:$recordUrl';
            }

            print('  🎯 Fetching record from: $recordUrl');
            final recordResponse = await http.get(Uri.parse(recordUrl));
            if (recordResponse.statusCode == 200) {
              final recordData = json.decode(recordResponse.body);
              data['records'] = recordData;
              print('  ✅ Record fetched: ${recordData['overall']?['summary'] ?? 'N/A'}');
            }
          } catch (e) {
            print('  ⚠️ Error fetching fighter record: $e');
          }
        }

        // Fetch fighter statistics if available
        final statsRef = data['statistics']?['\$ref'];
        if (statsRef != null) {
          try {
            String statsUrl = statsRef;
            if (!statsUrl.startsWith('http')) {
              statsUrl = 'http:$statsUrl';
            }

            print('  📊 Fetching statistics from: $statsUrl');
            final statsResponse = await http.get(Uri.parse(statsUrl));
            if (statsResponse.statusCode == 200) {
              final statsData = json.decode(statsResponse.body);

              // Parse statistics into our format
              if (statsData['splits'] != null && statsData['splits'].isNotEmpty) {
                final stats = statsData['splits'][0]['stats'] ?? {};

                // Extract striking statistics
                data['sigStrikesPerMinute'] = stats['significantStrikesLandedPerMinute']?.toDouble();
                data['strikeAccuracy'] = stats['significantStrikeAccuracy']?.toDouble();
                data['strikeDefense'] = stats['significantStrikeDefense']?.toDouble();

                // Extract grappling statistics
                data['takedownAverage'] = stats['takedownsLandedPer15Minutes']?.toDouble();
                data['takedownAccuracy'] = stats['takedownAccuracy']?.toDouble();
                data['takedownDefense'] = stats['takedownDefense']?.toDouble();
                data['submissionAverage'] = stats['submissionAttemptsPer15Minutes']?.toDouble();

                print('  ✅ Statistics fetched successfully');
                print('    - Sig Strikes/Min: ${data['sigStrikesPerMinute']}');
                print('    - Strike Accuracy: ${data['strikeAccuracy']}%');
                print('    - Takedown Avg: ${data['takedownAverage']}');
              }
            }
          } catch (e) {
            print('  ⚠️ Error fetching fighter statistics: $e');
          }
        }

        print('  🏗️ Creating MMAFighter object from ESPN data');
        final fighter = MMAFighter.fromESPN(data);
        print('  ✅ Fighter created: ${fighter.name}');
        print('    - Record: ${fighter.record}');
        print('    - Height: ${fighter.displayHeight ?? fighter.height ?? 'N/A'}');
        print('    - Weight: ${fighter.displayWeight ?? fighter.weight ?? 'N/A'}');
        print('    - Reach: ${fighter.displayReach ?? fighter.reach ?? 'N/A'}');

        // Cache removed due to permission issues

        return fighter;
      } else {
        print('  ❌ API request failed with status: ${response.statusCode}');
        print('  Response body: ${response.body}');
      }

      return null;
    } catch (e) {
      print('Error fetching fighter by ID: $e');
      return null;
    }
  }

  /// Get fighter details
  Future<MMAFighter?> _getFighter(String athleteRef) async {
    try {
      // Extract fighter ID from ref
      final regex = RegExp(r'/athletes/(\d+)');
      final match = regex.firstMatch(athleteRef);
      if (match == null) {
        print('❌ Could not extract fighter ID from: $athleteRef');
        return null;
      }

      final fighterId = match.group(1)!;
      print('🥊 Fetching fighter ID: $fighterId');

      // Check cache
      final cacheKey = 'fighter_$fighterId';
      try {
        final doc = await _firestore
            .collection('mma_fighters')
            .doc(cacheKey)
            .get();

        if (doc.exists && doc.data() != null) {
          print('✅ Fighter $fighterId loaded from cache');
          final cachedFighter = MMAFighter.fromJson(doc.data()!);
          _debugFighterData(cachedFighter);
          return cachedFighter;
        }
      } catch (e) {
        print('Cache read error: $e');
      }

      // Ensure URL is complete
      String url = athleteRef;
      if (!url.startsWith('http')) {
        url = 'http:$url';
      }
      print('🌐 Fetching fighter from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Raw fighter data received');

        // Debug log raw data structure
        print('📊 Fighter raw data keys: ${data.keys.toList()}');
        if (data['displayName'] != null) {
          print('  - Name: ${data['displayName']}');
        }

        // Check for physical attributes in various formats
        if (data['weight'] != null) {
          print('  - Weight raw: ${data['weight']} (type: ${data['weight'].runtimeType})');
        }
        if (data['height'] != null) {
          print('  - Height raw: ${data['height']} (type: ${data['height'].runtimeType})');
        }
        if (data['reach'] != null) {
          print('  - Reach raw: ${data['reach']} (type: ${data['reach'].runtimeType})');
        }
        if (data['displayHeight'] != null) {
          print('  - Display Height: ${data['displayHeight']}');
        }
        if (data['displayWeight'] != null) {
          print('  - Display Weight: ${data['displayWeight']}');
        }
        if (data['displayReach'] != null) {
          print('  - Display Reach: ${data['displayReach']}');
        }
        if (data['stance'] != null) {
          print('  - Stance raw: ${data['stance']} (type: ${data['stance'].runtimeType})');
        }
        if (data['age'] != null) {
          print('  - Age: ${data['age']}');
        }
        if (data['dateOfBirth'] != null) {
          print('  - Date of Birth: ${data['dateOfBirth']}');
        }

        // Check for alternate field names
        if (data['measurements'] != null) {
          print('  - Measurements found: ${data['measurements']}');
        }
        if (data['physicalAttributes'] != null) {
          print('  - Physical Attributes found: ${data['physicalAttributes']}');
        }

        // Parse fighter record if available
        final recordsRef = data['records']?['\$ref'];
        if (recordsRef != null) {
          try {
            String recordUrl = recordsRef;
            if (!recordUrl.startsWith('http')) {
              recordUrl = 'http:$recordUrl';
            }
            print('🎯 Fetching fighter record from: $recordUrl');

            final recordResponse = await http.get(Uri.parse(recordUrl));
            if (recordResponse.statusCode == 200) {
              final recordData = json.decode(recordResponse.body);
              data['records'] = recordData;
              print('✅ Fighter record fetched successfully');
              if (recordData['overall']?['summary'] != null) {
                print('  - Record: ${recordData['overall']['summary']}');
              }
            }
          } catch (e) {
            print('Error fetching fighter record: $e');
          }
        }

        // Fetch fighter statistics if available
        final statsRef = data['statistics']?['\$ref'];
        if (statsRef != null) {
          try {
            String statsUrl = statsRef;
            if (!statsUrl.startsWith('http')) {
              statsUrl = 'http:$statsUrl';
            }

            print('📊 Fetching statistics from: $statsUrl');
            final statsResponse = await http.get(Uri.parse(statsUrl));
            if (statsResponse.statusCode == 200) {
              final statsData = json.decode(statsResponse.body);

              // Parse statistics into our format
              if (statsData['splits'] != null && statsData['splits'].isNotEmpty) {
                final stats = statsData['splits'][0]['stats'] ?? {};

                // Extract striking statistics
                data['sigStrikesPerMinute'] = stats['significantStrikesLandedPerMinute']?.toDouble();
                data['strikeAccuracy'] = stats['significantStrikeAccuracy']?.toDouble();
                data['strikeDefense'] = stats['significantStrikeDefense']?.toDouble();

                // Extract grappling statistics
                data['takedownAverage'] = stats['takedownsLandedPer15Minutes']?.toDouble();
                data['takedownAccuracy'] = stats['takedownAccuracy']?.toDouble();
                data['takedownDefense'] = stats['takedownDefense']?.toDouble();
                data['submissionAverage'] = stats['submissionAttemptsPer15Minutes']?.toDouble();

                print('✅ Statistics fetched successfully');
                print('  - Sig Strikes/Min: ${data['sigStrikesPerMinute']}');
                print('  - Strike Accuracy: ${data['strikeAccuracy']}%');
                print('  - Takedown Avg: ${data['takedownAverage']}');
              }
            }
          } catch (e) {
            print('⚠️ Error fetching fighter statistics: $e');
          }
        }

        final fighter = MMAFighter.fromESPN(data);
        print('✅ Fighter object created: ${fighter.name}');
        _debugFighterData(fighter);

        // Cache removed due to permission issues

        return fighter;
      } else {
        print('❌ Failed to fetch fighter. Status: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('❌ Error fetching fighter: $e');
      return null;
    }
  }

  void _debugFighterData(MMAFighter fighter) {
    print('🔍 Fighter Details for ${fighter.name}:');
    print('  - Record: ${fighter.record}');
    print('  - Age: ${fighter.age ?? "N/A"}');
    print('  - Height: ${fighter.displayHeight ?? fighter.height ?? "N/A"}');
    print('  - Weight: ${fighter.displayWeight ?? fighter.weight ?? "N/A"}');
    print('  - Reach: ${fighter.displayReach ?? fighter.reach ?? "N/A"}');
    print('  - Stance: ${fighter.stance ?? "N/A"}');
    print('  - Camp: ${fighter.camp ?? "N/A"}');
    print('  - Country: ${fighter.country ?? "N/A"}');
    print('  - Nickname: ${fighter.nickname ?? "None"}');
    print('  - KOs: ${fighter.knockouts ?? "N/A"}');
    print('  - Submissions: ${fighter.submissions ?? "N/A"}');
    print('  - Decisions: ${fighter.decisions ?? "N/A"}');
  }

  /// Cache removed - deprecated method
  Future<void> _cacheFighterImage(String fighterId, String imageUrl) async {
    // Method no longer used
    return;
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

  /// Search for fighter by name using ESPN search API
  Future<MMAFighter?> searchFighterByName(String name) async {
    try {
      print('🔍 Searching for fighter: $name');

      // ESPN search API endpoint for MMA fighters (use 'player' not 'athlete')
      final searchUrl = 'https://site.web.api.espn.com/apis/search/v2?region=us&lang=en&section=mma&limit=5&page=1&query=${Uri.encodeComponent(name)}&type=player';
      print('  🌐 Search URL: $searchUrl');

      final response = await http.get(Uri.parse(searchUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if we have results - the structure is nested
        if (data['results'] != null && data['results'].isNotEmpty) {
          final results = data['results'] as List;

          // Find the player results section
          try {
            for (final section in results) {
              // Ensure section is a Map before accessing properties
              if (section == null || section is! Map<String, dynamic>) {
                continue;
              }

              if (section['type'] == 'player' && section['contents'] != null) {
                final contents = section['contents'];
                if (contents == null || contents is! List) {
                  continue;
                }

                print('  ✅ Found ${contents.length} player results');

                // Find MMA fighters (sport == 'mma')
                for (final player in contents) {
                  // Ensure player is a Map before accessing properties
                  if (player == null || player is! Map<String, dynamic>) {
                    continue;
                  }

                  if (player['sport'] == 'mma' && player['uid'] != null) {
                    // Extract ESPN ID from UID (format: "s:3301~a:2335639")
                    final uid = player['uid']?.toString();
                    if (uid == null) continue;

                    final idMatch = RegExp(r'a:(\d+)').firstMatch(uid);
                    if (idMatch != null) {
                      final athleteId = idMatch.group(1)!;
                      print('  🎯 Found MMA fighter: ${player['displayName']} (ID: $athleteId)');

                      // Fetch fighter data WITHOUT statistics for faster load
                      final fighterUrl = '$ATHLETE_BASE$athleteId';
                      print('  🔗 Fetching fighter from: $fighterUrl');
                      final fighter = await _getFighterSimple(fighterUrl);
                      if (fighter != null) {
                        print('  ✅ Fighter loaded successfully: ${fighter.name} (ESPN ID: ${fighter.espnId})');
                        return fighter;
                      } else {
                        print('  ❌ Failed to load fighter from URL: $fighterUrl');
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('  ❌ Error parsing search results: $e');
          }
          print('  ⚠️ No MMA fighters found in search results for: $name');
        } else {
          print('  ⚠️ No search results found for: $name');
        }
      } else {
        print('  ❌ Search API returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching for fighter by name: $e');
    }

    return null;
  }

  /// Get fighter by name (simplified without caching)
  Future<MMAFighter?> getFighterByName(String name) async {
    try {
      // Directly search for the fighter without cache
      return await searchFighterByName(name);
    } catch (e) {
      print('Error fetching fighter by name: $e');
      return null;
    }
  }

  /// Get event with progressive loading - returns immediately with basic data
  /// Then streams fighter updates as they load
  Stream<MMAEvent> getEventWithFightsProgressive(String eventId, {Map<String, dynamic>? gameData}) async* {
    print('🥊 Progressive loading MMA event: $eventId');
    print('🔧 Event starts with 9: ${eventId.startsWith('9')}');
    print('🔧 GameData provided: ${gameData != null}');
    print('🔧 GameData has fights: ${gameData?['fights'] != null}');

    try {
      // First, create event with minimal fighter data
      MMAEvent? baseEvent;

      bool isPseudoId = eventId.startsWith('9');
      if (isPseudoId && gameData != null && gameData['fights'] != null) {
        print('📦 Creating base event from game data');
        print('📦 Fights data: ${gameData['fights']}');

        baseEvent = await _createEventFromGameDataMinimal(eventId, gameData);

        if (baseEvent != null) {
          print('✅ Base event created with ${baseEvent.fights.length} fights');
          print('📤 Yielding initial event...');
          yield baseEvent;
          print('✅ Initial event yielded successfully');

          // Now progressively load fighter details
          print('🔄 Starting progressive fighter loading...');
          await for (final updatedEvent in _progressivelyLoadFighters(baseEvent)) {
            print('🔄 Yielding updated event with fighter data...');
            yield updatedEvent;
          }
          print('✅ Progressive loading completed');
        } else {
          print('❌ Failed to create base event from game data');
        }
      } else {
        print('📡 Loading regular ESPN event...');
        // Regular ESPN event loading
        final event = await getEventWithFights(eventId, gameData: gameData);
        if (event != null) {
          print('✅ ESPN event loaded, yielding...');
          yield event;
        } else {
          print('❌ Failed to load ESPN event');
        }
      }
    } catch (e) {
      print('❌ Error in progressive loading: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Create event with minimal fighter data for immediate display
  Future<MMAEvent?> _createEventFromGameDataMinimal(String eventId, Map<String, dynamic> gameData) async {
    try {
      print('🏗️ Creating minimal event from game data...');
      print('🏗️ EventId: $eventId');
      print('🏗️ GameData keys: ${gameData.keys}');

      // Create event structure immediately with minimal fighter objects
      // Handle both List and Map formats for fights data
      List<dynamic> fightDataList = [];

      if (gameData['fights'] != null) {
        if (gameData['fights'] is List) {
          fightDataList = gameData['fights'] as List;
        } else if (gameData['fights'] is Map) {
          // Convert Map to List (fights stored by ID in Firestore)
          final fightsMap = gameData['fights'] as Map<String, dynamic>;
          fightDataList = fightsMap.values.toList();
        }
      }

      print('🏗️ Found ${fightDataList.length} fights in data');

      final List<MMAFight> fights = [];

      for (int i = 0; i < fightDataList.length; i++) {
        final fightData = fightDataList[i] as Map<String, dynamic>;
        print('🏗️ Processing fight $i: ${fightData.keys}');

        // Safely get fighter names as strings
        final fighter1Name = fightData['fighter1']?.toString() ?? 'Fighter 1';
        final fighter2Name = fightData['fighter2']?.toString() ?? 'Fighter 2';
        print('🏗️ Fight $i: $fighter1Name vs $fighter2Name');

        // Create minimal fighters with just names
        final fighter1 = MMAFighter(
          id: 'temp_f1_$i',
          name: fighter1Name,
          displayName: fighter1Name,
          shortName: fighter1Name.split(' ').last,
          record: '',
        );

        final fighter2 = MMAFighter(
          id: 'temp_f2_$i',
          name: fighter2Name,
          displayName: fighter2Name,
          shortName: fighter2Name.split(' ').last,
          record: '',
        );

        // Main events and title fights are 5 rounds
        final isMainEvent = i == fightDataList.length - 1;
        final isTitleFight = fightData['isTitle'] == true;
        final defaultRounds = (isMainEvent || isTitleFight) ? 5 : 3;

        final fight = MMAFight(
          id: fightData['id']?.toString() ?? 'fight_$i',
          fighter1: fighter1,
          fighter2: fighter2,
          weightClass: fightData['weightClass']?.toString(),
          rounds: (fightData['rounds'] is int) ? fightData['rounds'] : defaultRounds,
          isTitleFight: isTitleFight,
          isMainEvent: isMainEvent,
          cardPosition: i >= fightDataList.length - 5 ? 'main' : 'prelim',
        );

        fights.add(fight);
        print('🏗️ Added fight: ${fight.id}');
      }

      print('🏗️ Creating MMAEvent with ${fights.length} fights');

      // Handle gameTime which could be either a timestamp or DateTime string
      DateTime eventDate;
      if (gameData['gameTime'] != null) {
        final gameTime = gameData['gameTime'];
        if (gameTime is int) {
          // It's a timestamp in milliseconds
          eventDate = DateTime.fromMillisecondsSinceEpoch(gameTime);
        } else if (gameTime is DateTime) {
          eventDate = gameTime;
        } else {
          // Try parsing as string
          try {
            eventDate = DateTime.parse(gameTime.toString());
          } catch (e) {
            // If parsing fails, try as timestamp string
            try {
              final timestamp = int.parse(gameTime.toString());
              eventDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } catch (e2) {
              print('⚠️ Could not parse gameTime: $gameTime, using current time');
              eventDate = DateTime.now();
            }
          }
        }
      } else {
        eventDate = DateTime.now();
      }

      // Determine the event name based on the data available
      String eventName;
      String? sportType = gameData['sport']?.toString().toUpperCase();
      final awayTeam = gameData['awayTeam']?.toString() ?? '';
      final homeTeam = gameData['homeTeam']?.toString() ?? '';
      final league = gameData['league']?.toString() ?? '';

      print('🎯 Event Name Debug:');
      print('  - sportType: $sportType');
      print('  - awayTeam: "$awayTeam"');
      print('  - homeTeam: "$homeTeam"');
      print('  - league: "$league"');
      print('  - Full gameData: ${gameData.keys.join(', ')}');

      // Check if the event name is provided by ESPN for major MMA promotions
      // ESPN provides full event names for UFC, Bellator, and PFL in the awayTeam field
      if (sportType == 'UFC' || sportType == 'MMA' || sportType == 'BELLATOR' || sportType == 'PFL') {
        // Check if we have a full event name in league field first
        if (league.contains('UFC') || league.contains('Bellator') || league.contains('PFL')) {
          eventName = league;
        } else if (awayTeam.contains('UFC') ||
            awayTeam.contains('Bellator') ||
            awayTeam.contains('PFL')) {
          eventName = awayTeam; // Use the full event name from ESPN
        } else if (fights.isNotEmpty && fights.last.fighter1 != null && fights.last.fighter2 != null) {
          // Create event name from main event fighters
          final mainFighter1 = fights.last.fighter1!.displayName ?? fights.last.fighter1!.name;
          final mainFighter2 = fights.last.fighter2!.displayName ?? fights.last.fighter2!.name;
          final promotion = _detectPromotion(league.isNotEmpty ? league : 'UFC');
          eventName = '$promotion: $mainFighter1 vs $mainFighter2';
        } else {
          // Fallback to combining available names
          if (homeTeam.isNotEmpty && awayTeam.isNotEmpty && homeTeam != awayTeam) {
            eventName = 'UFC: $awayTeam vs $homeTeam';
          } else {
            eventName = gameData['homeTeam']?.toString() ?? 'MMA Event';
          }
        }
      } else {
        // For other sports/promotions, use homeTeam
        eventName = gameData['homeTeam']?.toString() ?? 'MMA Event';
      }

      print('🎯 Final event name chosen: "$eventName"');
      print('🎯 Promotion detected: "${_detectPromotion(eventName)}"');

      final event = MMAEvent(
        id: eventId,
        name: eventName,
        shortName: _detectPromotion(eventName), // Use promotion as short name
        date: eventDate,
        promotion: _detectPromotion(eventName),
        fights: fights,
      );

      print('✅ Minimal event created successfully:');
      print('  - Event name: "${event.name}"');
      print('  - Event shortName: "${event.shortName}"');
      print('  - Event promotion: "${event.promotion}"');
      return event;
    } catch (e) {
      print('❌ Error creating minimal event: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Progressively load fighter details and yield updated events
  Stream<MMAEvent> _progressivelyLoadFighters(MMAEvent baseEvent) async* {
    try {
      for (int i = 0; i < baseEvent.fights.length; i++) {
        final fight = baseEvent.fights[i];

        // Load fighter 1
        if (fight.fighter1 != null) {
          final fighter1Data = await searchFighterByName(fight.fighter1!.name);
          if (fighter1Data != null) {
            baseEvent.fights[i] = fight.copyWith(fighter1: fighter1Data);
            yield baseEvent;
          }
        }

        // Load fighter 2
        if (fight.fighter2 != null) {
          final fighter2Data = await searchFighterByName(fight.fighter2!.name);
          if (fighter2Data != null) {
            baseEvent.fights[i] = fight.copyWith(fighter2: fighter2Data);
            yield baseEvent;
          }
        }
      }
    } catch (e) {
      print('Error loading fighter details: $e');
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

  /// Get promotion-specific broadcast information
  Map<String, String> _getPromotionBroadcasts(String promotion, {bool isPPV = false, String? eventName}) {
    // Check if it's a PPV event based on event name
    if (eventName != null) {
      isPPV = isPPV ||
             eventName.contains(RegExp(r'\d{3}')) || // UFC 307, etc.
             eventName.toLowerCase().contains('championship') ||
             eventName.toLowerCase().contains('ppv');
    }

    switch (promotion.toUpperCase()) {
      case 'PFL':
        return {
          'main': isPPV ? 'DAZN PPV' : 'DAZN',
          'prelim': 'PFL App',
        };
      case 'UFC':
        return {
          'main': isPPV ? 'ESPN+ PPV' : 'ESPN+',
          'prelim': 'ESPN',
          'early': 'ESPN+',
        };
      case 'BELLATOR':
        return {
          'main': 'MAX',
          'prelim': 'Bellator App',
        };
      case 'ONE':
      case 'ONE CHAMPIONSHIP':
        return {
          'main': 'Amazon Prime',
          'prelim': 'ONE App',
        };
      default:
        return {
          'main': isPPV ? 'PPV' : 'Streaming',
          'prelim': 'Streaming',
        };
    }
  }

  /// Generate fighter image URL
  String? _generateFighterImageUrl(String fighterId, String? fighterName) {
    // Skip if it's a placeholder ID - use a generic image
    if (fighterId.startsWith('f1_') || fighterId.startsWith('f2_')) {
      print('! Placeholder fighter ID: $fighterId - using default image');
      // Return a generic MMA fighter silhouette
      // Using a working placeholder image URL
      return 'https://a.espncdn.com/combiner/i?img=/i/headshots/mma/players/full/nophoto.png&w=350&h=254';
    }

    // ESPN MMA fighter headshot URL format
    return 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';
  }

  /// Create minimal fighter from basic data (when API search fails)
  MMAFighter _createMinimalFighter(String id, Map<String, dynamic> fighterData) {
    final name = fighterData['name'] ?? 'Unknown Fighter';
    final record = fighterData['record'] ?? '0-0';

    // Parse record if available
    int? wins, losses, draws;
    if (record != null && record != '0-0') {
      final parts = record.split('-');
      if (parts.isNotEmpty) wins = int.tryParse(parts[0]);
      if (parts.length > 1) losses = int.tryParse(parts[1]);
      if (parts.length > 2) draws = int.tryParse(parts[2]);
    }

    return MMAFighter(
      id: id,
      name: name,
      displayName: name,
      shortName: name.split(' ').last,
      record: record,
      wins: wins,
      losses: losses,
      draws: draws,
      nickname: fighterData['nickname'],
      height: fighterData['height']?.toDouble(),
      weight: fighterData['weight']?.toDouble(),
      reach: fighterData['reach']?.toDouble(),
      stance: fighterData['stance'],
      age: fighterData['age'],
      country: fighterData['country'],
      headshotUrl: _generateFighterImageUrl(id, name),
    );
  }

  /// Create MMA event from game data (for pseudo-ESPN IDs)
  Future<MMAEvent> _createEventFromGameData(String eventId, Map<String, dynamic> gameData) async {
    print('🎯 Creating MMA event from game data');
    print('📊 Game data keys: ${gameData.keys}');
    print('🥊 Fights data: ${gameData['fights']}');

    final fights = <MMAFight>[];

    // Handle both List and Map formats for fights data
    List<dynamic> fightDataList = [];
    if (gameData['fights'] != null) {
      if (gameData['fights'] is List) {
        fightDataList = gameData['fights'] as List;
      } else if (gameData['fights'] is Map) {
        final fightsMap = gameData['fights'] as Map<String, dynamic>;
        fightDataList = fightsMap.values.toList();
      }
    }

    // If no fights data, create a single main event from the game data
    if (fightDataList.isEmpty && gameData['homeTeam'] != null && gameData['awayTeam'] != null) {
      print('📋 No fights data, creating main event from homeTeam/awayTeam');
      fightDataList = [
        {
          'fighter1': gameData['awayTeam'],
          'fighter2': gameData['homeTeam'],
          'weightClass': 'Main Event',
          'isMainEvent': true,
        }
      ];
    }

    // BATCH PROCESSING: Collect all fighter names to search
    print('🎯 Collecting fighter names for batch processing...');
    final fighterSearches = <String, String>{}; // name -> placeholder ID
    final fighterDataMap = <String, Map<String, dynamic>>{}; // ID -> fight data

    for (int i = 0; i < fightDataList.length; i++) {
      final fightData = fightDataList[i] as Map<String, dynamic>;

      final fighterName1 = fightData['fighter1'] ?? fightData['awayTeam'] ?? 'Fighter 1';
      final fighterName2 = fightData['fighter2'] ?? fightData['homeTeam'] ?? 'Fighter 2';

      var fighter1Id = fightData['fighter1Id']?.toString() ?? '';
      var fighter2Id = fightData['fighter2Id']?.toString() ?? '';

      // Only search for fighters we don't have IDs for
      if (fighter1Id.isEmpty || fighter1Id.startsWith('f1_')) {
        fighter1Id = 'f1_$i';
        fighterSearches[fighterName1] = fighter1Id;
      }

      if (fighter2Id.isEmpty || fighter2Id.startsWith('f2_')) {
        fighter2Id = 'f2_$i';
        fighterSearches[fighterName2] = fighter2Id;
      }

      // Store fight data for later
      fighterDataMap[fighter1Id] = {
        'name': fighterName1,
        'record': fightData['fighter1Record'] ?? '',
        'nickname': fightData['fighter1Nickname'],
        'height': fightData['fighter1Height']?.toDouble(),
        'weight': fightData['fighter1Weight']?.toDouble(),
        'reach': fightData['fighter1Reach']?.toDouble(),
        'stance': fightData['fighter1Stance'],
        'age': fightData['fighter1Age'],
        'country': fightData['fighter1Country'],
      };

      fighterDataMap[fighter2Id] = {
        'name': fighterName2,
        'record': fightData['fighter2Record'] ?? '',
        'nickname': fightData['fighter2Nickname'],
        'height': fightData['fighter2Height']?.toDouble(),
        'weight': fightData['fighter2Weight']?.toDouble(),
        'reach': fightData['fighter2Reach']?.toDouble(),
        'stance': fightData['fighter2Stance'],
        'age': fightData['fighter2Age'],
        'country': fightData['fighter2Country'],
      };
    }

    // BATCH SEARCH: Search for all fighters in parallel
    print('🎯 Batch searching for ${fighterSearches.length} fighters...');
    final fighterMap = <String, MMAFighter>{}; // ID -> Fighter

    // Process in batches of 5 to avoid overwhelming the API
    const batchSize = 5;
    final searchEntries = fighterSearches.entries.toList();

    for (int i = 0; i < searchEntries.length; i += batchSize) {
      final batch = searchEntries.skip(i).take(batchSize).toList();
      final futures = batch.map((entry) async {
        final name = entry.key;
        final placeholderId = entry.value;

        if (name == 'Fighter 1' || name == 'Fighter 2') {
          return null; // Skip generic names
        }

        print('  🔍 Searching for: $name');
        final fighter = await searchFighterByName(name);

        if (fighter != null) {
          print('  ✅ Found: ${fighter.name}');
          fighterMap[placeholderId] = fighter;
          return fighter;
        } else {
          print('  ⚠️ Not found: $name');
          return null;
        }
      });

      await Future.wait(futures);
    }

    print('✅ Batch search complete. Found ${fighterMap.length} fighters');

    // Now create fights with the fetched fighter data
    for (int i = 0; i < fightDataList.length; i++) {
      final fightData = fightDataList[i] as Map<String, dynamic>;

      final fighter1Id = fightData['fighter1Id']?.toString() ?? 'f1_$i';
      final fighter2Id = fightData['fighter2Id']?.toString() ?? 'f2_$i';

      // Get fighters from our batch results or create minimal objects
      MMAFighter fighter1 = fighterMap[fighter1Id] ?? _createMinimalFighter(
        fighter1Id,
        fighterDataMap[fighter1Id] ?? {},
      );

      MMAFighter fighter2 = fighterMap[fighter2Id] ?? _createMinimalFighter(
        fighter2Id,
        fighterDataMap[fighter2Id] ?? {},
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

      print('🥊 Creating fight: ${fighter1.name} vs ${fighter2.name}');
      print('  - Weight class: ${fightData['weightClass'] ?? 'TBD'}');
      print('  - Card position: $cardPosition');
      print('  - Is main event: $isMainEvent');

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

    // Get promotion-specific broadcasts
    final broadcasts = _getPromotionBroadcasts(promotion, eventName: eventName);
    final broadcastList = broadcasts.values.toSet().toList(); // Unique list of all broadcasts

    return MMAEvent(
      id: eventId,
      name: eventName,
      date: eventDate,
      venueName: gameData['venue'],
      fights: fights,
      broadcasters: broadcastList.isNotEmpty ? broadcastList : null,
      broadcastByCard: broadcasts,  // Store structured broadcast info
      promotion: promotion,
      promotionLogoUrl: promotionLogo,
      espnEventId: eventId,
    );
  }

}