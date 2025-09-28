import 'package:flutter/foundation.dart';
import 'odds_api_service.dart';
import 'boxing_data_cache_service.dart';
import '../models/boxing_event_model.dart';
import '../models/boxing_fight_model.dart';

/// Boxing Odds Service - Integrates The Odds API for real boxing data
/// Enhanced with Boxing Data API cache for fighter profiles and event details
/// Provides live boxing events with fighter names, dates, odds, records, and images
class BoxingOddsService {
  final OddsApiService _oddsApi = OddsApiService();
  final BoxingDataCacheService _cacheService = BoxingDataCacheService();

  // Singleton instance
  static final BoxingOddsService _instance = BoxingOddsService._internal();
  factory BoxingOddsService() => _instance;
  BoxingOddsService._internal();

  // Cache
  List<BoxingEvent>? _cachedEvents;
  DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Popular boxer images mapping - Expanded list
  static final Map<String, String> boxerImageUrls = {
    // Current Champions & Stars
    'canelo alvarez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3930.png',
    'tyson fury': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4926.png',
    'oleksandr usyk': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4749.png',
    'anthony joshua': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4682.png',
    'deontay wilder': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3039.png',
    'gervonta davis': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4474.png',
    'ryan garcia': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4795.png',
    'errol spence jr': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/2991.png',
    'terence crawford': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/2358.png',
    'jaron ennis': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4875.png',
    // Additional prominent fighters from your logs
    'david benavidez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/2985.png',
    'anthony yarde': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4646.png',
    'devin haney': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4840.png',
    'jesse rodriguez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4900.png',
    'brian norman jr': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5025.png',
    'fernando daniel martinez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4980.png',
    'abdullah mason': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5150.png',
    'sam noakes': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5100.png',
    // More champions and contenders
    'shakur stevenson': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4864.png',
    'vasily lomachenko': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3956.png',
    'naoya inoue': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4590.png',
    'dmitry bivol': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4655.png',
    'artur beterbiev': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3937.png',
    'jermell charlo': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/2991.png',
    'jermall charlo': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/2990.png',
    // Additional fighters from recent events
    'jesse rodriguez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4900.png',
    'jesse bam rodriguez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4900.png',
    'pedro guevara': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4925.png',
    'gilberto ramirez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3870.png',
    'chris billam-smith': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4736.png',
    'chris billam smith': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4736.png',
    'zurdo ramirez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/3870.png',
    'cristian gonzalez': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5050.png',
    'kevin salgado': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5075.png',
    'martin bakole': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4850.png',
    'agit kabayel': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4765.png',
    'fabio wardley': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4950.png',
    'frazer clarke': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4975.png',
    'moses itauma': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5200.png',
    'demsey mckean': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4800.png',
    'isaac lowe': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4600.png',
    'lee mcgregor': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/4650.png',
    'rhiannon dixon': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5225.png',
    'karen elizabeth carabajal': 'https://a.espncdn.com/combiner/i?img=/i/headshots/boxing/players/full/5250.png',
  };

  /// Fetch upcoming boxing events from The Odds API
  Future<List<BoxingEvent>> getUpcomingEventsFromOdds({bool forceRefresh = false}) async {
    try {
      // Check cache
      if (!forceRefresh && _cachedEvents != null && _lastFetch != null) {
        if (DateTime.now().difference(_lastFetch!) < _cacheExpiry) {
          debugPrint('🥊 Returning cached boxing events from Odds API: ${_cachedEvents!.length}');
          return _cachedEvents!;
        }
      }

      debugPrint('🥊 Fetching boxing events from The Odds API...');
      await _oddsApi.ensureInitialized();

      // Fetch boxing data
      final oddsData = await _oddsApi.getSportOdds(
        sport: 'boxing',
        markets: 'h2h,totals',
      );

      if (oddsData == null || oddsData.isEmpty) {
        debugPrint('❌ No boxing data from Odds API');
        return _cachedEvents ?? [];
      }

      debugPrint('✅ Received ${oddsData.length} boxing events');

      // Convert to BoxingEvent models
      final events = await _parseOddsDataToEvents(oddsData);

      // Cache the results
      _cachedEvents = events;
      _lastFetch = DateTime.now();

      return events;
    } catch (e) {
      debugPrint('❌ Error fetching boxing from Odds API: $e');
      return _cachedEvents ?? [];
    }
  }

  /// Parse Odds API data into BoxingEvent models
  Future<List<BoxingEvent>> _parseOddsDataToEvents(List<Map<String, dynamic>> oddsData) async {
    final events = <BoxingEvent>[];
    final Map<String, List<BoxingFight>> eventFights = {};

    for (final data in oddsData) {
      try {
        final eventId = data['id'] ?? '';
        final fighter1Name = data['away_team'] ?? 'TBD';
        final fighter2Name = data['home_team'] ?? 'TBD';

        // Parse date
        DateTime date = DateTime.now();
        if (data['commence_time'] != null) {
          date = DateTime.parse(data['commence_time']);
        }

        // Create date key for grouping
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        // Group fights by date (multiple fights on same date = same event/card)
        if (!eventFights.containsKey(dateKey)) {
          eventFights[dateKey] = [];
        }

        // Parse odds data
        final bookmakers = data['bookmakers'] as List? ?? [];
        Map<String, dynamic>? bestOdds;

        if (bookmakers.isNotEmpty) {
          // Get odds from first bookmaker
          final firstBook = bookmakers[0];
          final markets = firstBook['markets'] as List? ?? [];

          for (final market in markets) {
            if (market['key'] == 'h2h') {
              final outcomes = market['outcomes'] as List? ?? [];
              bestOdds = {};

              for (final outcome in outcomes) {
                if (outcome['name'] == fighter1Name) {
                  bestOdds['fighter1_odds'] = outcome['price'];
                } else if (outcome['name'] == fighter2Name) {
                  bestOdds['fighter2_odds'] = outcome['price'];
                }
              }
            }
          }
        }

        // Create fighter info with static image URLs
        final fighterInfo1 = BoxingFighterInfo(
          id: _generateFighterId(fighter1Name),
          name: fighter1Name,
          fullName: fighter1Name,
          record: '', // Will be populated from cache if available
          imageUrl: getBoxerImageUrl(fighter1Name),  // Add static image
        );

        final fighterInfo2 = BoxingFighterInfo(
          id: _generateFighterId(fighter2Name),
          name: fighter2Name,
          fullName: fighter2Name,
          record: '', // Will be populated from cache if available
          imageUrl: getBoxerImageUrl(fighter2Name),  // Add static image
        );

        // Create fight - store the actual time for later sorting
        final fight = BoxingFight(
          id: eventId,
          title: '$fighter1Name vs $fighter2Name',
          eventId: dateKey,
          fighters: {
            'fighter1': fighterInfo1,
            'fighter2': fighterInfo2,
          },
          division: 'TBD', // Not provided by Odds API
          scheduledRounds: 12, // Default for championship
          titles: [], // Not available from Odds API
          cardPosition: 99, // Will be determined by time-slot sorting
          status: FightStatus.upcoming,
          date: date,
        );

        eventFights[dateKey]!.add(fight);
      } catch (e) {
        debugPrint('Error parsing odds data: $e');
      }
    }

    // Create events from grouped fights
    eventFights.forEach((dateKey, fights) {
      if (fights.isNotEmpty) {
        // Sort fights by time - latest time is main event (boxing convention)
        // Handle nullable dates
        fights.sort((a, b) {
          final dateA = a.date ?? DateTime.now();
          final dateB = b.date ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Assign card positions based on time order
        // First fight (latest time) = main event (position 1)
        for (int i = 0; i < fights.length; i++) {
          fights[i] = BoxingFight(
            id: fights[i].id,
            title: fights[i].title,
            eventId: fights[i].eventId,
            fighters: fights[i].fighters,
            division: fights[i].division,
            scheduledRounds: i == 0 ? 12 : 10, // Main event 12 rounds, others 10
            titles: fights[i].titles,
            cardPosition: i + 1, // 1 = main event, 2 = second fight, etc.
            status: fights[i].status,
            date: fights[i].date ?? DateTime.now(),
            odds: fights[i].odds,
          );
        }

        // Get date from first fight
        final dateParts = dateKey.split('-');
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        // First fight in sorted list is the main event (latest time)
        final mainFight = fights.first;

        final event = BoxingEventWithFights(
          id: dateKey,
          title: '${mainFight.fighters["fighter1"]!.name} vs ${mainFight.fighters["fighter2"]!.name}',
          date: date,
          venue: 'TBD',
          location: 'TBD',
          promotion: 'Boxing',
          broadcasters: [],
          fights: fights,
        );

        events.add(event);
      }
    });

    // Sort events by date
    events.sort((a, b) => a.date.compareTo(b.date));

    // Enrich events with cached data from Boxing Data API
    final enrichedEvents = await _enrichEventsWithCache(events);

    return enrichedEvents;
  }

  /// Enrich events with cached data from Boxing Data API
  Future<List<BoxingEvent>> _enrichEventsWithCache(List<BoxingEvent> events) async {
    final enrichedEvents = <BoxingEvent>[];

    for (final event in events) {
      if (event is BoxingEventWithFights) {
        // Get all unique fighter names from this event
        final fighterNames = <String>{};
        for (final fight in event.fights) {
          fighterNames.add(fight.fighters['fighter1']!.name);
          fighterNames.add(fight.fighters['fighter2']!.name);
        }

        // Get enrichment data from cache
        final enrichment = await _cacheService.getEventEnrichment(
          event.title,
          fighterNames.toList(),
        );

        if (enrichment != null) {
          // Update event with cached data
          final enrichedFights = <BoxingFight>[];
          for (final fight in event.fights) {
            final fighter1Name = fight.fighters['fighter1']!.name;
            final fighter2Name = fight.fighters['fighter2']!.name;

            // Update fighter info with cached data
            final updatedFighter1 = BoxingFighterInfo(
              id: fight.fighters['fighter1']!.id,
              name: fighter1Name,
              fullName: fighter1Name,
              record: enrichment.getFighterRecord(fighter1Name) ?? '',
              imageUrl: enrichment.getFighterImage(fighter1Name) ?? getBoxerImageUrl(fighter1Name),
              isChampion: enrichment.isFighterChampion(fighter1Name),
              ranking: enrichment.getFighterRanking(fighter1Name),
            );

            final updatedFighter2 = BoxingFighterInfo(
              id: fight.fighters['fighter2']!.id,
              name: fighter2Name,
              fullName: fighter2Name,
              record: enrichment.getFighterRecord(fighter2Name) ?? '',
              imageUrl: enrichment.getFighterImage(fighter2Name) ?? getBoxerImageUrl(fighter2Name),
              isChampion: enrichment.isFighterChampion(fighter2Name),
              ranking: enrichment.getFighterRanking(fighter2Name),
            );

            // Create updated fight with enriched data
            final enrichedFight = BoxingFight(
              id: fight.id,
              title: fight.title,
              eventId: fight.eventId,
              fighters: {
                'fighter1': updatedFighter1,
                'fighter2': updatedFighter2,
              },
              division: enrichment.getFighterWeightClass(fighter1Name) ?? fight.division,
              scheduledRounds: fight.scheduledRounds,
              titles: fight.titles,
              cardPosition: fight.cardPosition,
              status: fight.status,
              date: fight.date,
              odds: fight.odds,
            );

            enrichedFights.add(enrichedFight);
          }

          // Create enriched event
          final enrichedEvent = BoxingEventWithFightsAndPoster(
            id: event.id,
            title: event.title,
            date: event.date,
            venue: enrichment.venue ?? event.venue,
            location: enrichment.location ?? event.location,
            promotion: enrichment.promotion ?? event.promotion,
            broadcasters: enrichment.broadcasters ?? event.broadcasters,
            fights: enrichedFights,
            posterUrl: enrichment.posterUrl,
          );

          enrichedEvents.add(enrichedEvent);
          debugPrint('✅ Enriched event: ${event.title} with cache data');
        } else {
          // No cache data available, use original
          enrichedEvents.add(event);
          debugPrint('ℹ️ No cache data for event: ${event.title}');
        }
      } else {
        enrichedEvents.add(event);
      }
    }

    return enrichedEvents;
  }

  /// Get boxer image URL from static mapping (fallback)
  String getBoxerImageUrl(String fighterName) {
    final normalized = fighterName.toLowerCase().trim();

    // Check for exact match
    if (boxerImageUrls.containsKey(normalized)) {
      return boxerImageUrls[normalized]!;
    }

    // Check partial matches - more flexible matching
    for (final entry in boxerImageUrls.entries) {
      // Check if the fighter name contains the mapped name or vice versa
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }

      // Check last name match for common names (avoid short last names)
      final fighterParts = normalized.split(' ');
      final mappedParts = entry.key.split(' ');
      if (fighterParts.isNotEmpty && mappedParts.isNotEmpty) {
        final fighterLastName = fighterParts.last;
        final mappedLastName = mappedParts.last;
        if (fighterLastName == mappedLastName && fighterLastName.length > 4) {
          return entry.value;
        }
      }
    }

    // Return placeholder
    return 'https://via.placeholder.com/150x150.png?text=${fighterName.split(' ').map((s) => s[0]).join('')}';
  }

  /// Generate a fighter ID from name
  String _generateFighterId(String name) {
    return name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// Clear cache
  void clearCache() {
    _cachedEvents = null;
    _lastFetch = null;
  }
}

/// Extension to add fights to BoxingEvent
class BoxingEventWithFights extends BoxingEvent {
  final List<BoxingFight> fights;

  BoxingEventWithFights({
    required String id,
    required String title,
    required DateTime date,
    required String venue,
    required String location,
    required String promotion,
    required List<String> broadcasters,
    required this.fights,
  }) : super(
    id: id,
    title: title,
    date: date,
    venue: venue,
    location: location,
    promotion: promotion,
    broadcasters: broadcasters,
    source: DataSource.oddsApi,
    hasFullData: true,
  );

  List<BoxingFight> getFights() => fights;
}

/// Extension with fights and poster from cache
class BoxingEventWithFightsAndPoster extends BoxingEventWithFights {
  final String? posterUrl;

  BoxingEventWithFightsAndPoster({
    required String id,
    required String title,
    required DateTime date,
    required String venue,
    required String location,
    required String promotion,
    required List<String> broadcasters,
    required List<BoxingFight> fights,
    this.posterUrl,
  }) : super(
    id: id,
    title: title,
    date: date,
    venue: venue,
    location: location,
    promotion: promotion,
    broadcasters: broadcasters,
    fights: fights,
  );
}

// DataSource.oddsApi is now defined in the enum itself