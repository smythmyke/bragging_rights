import 'package:flutter/foundation.dart';
import 'odds_api_service.dart';
import '../models/boxing_event_model.dart';
import '../models/boxing_fight_model.dart';
import '../models/boxing_fighter_model.dart';

/// Boxing Odds Service - Integrates The Odds API for real boxing data
/// Provides live boxing events with fighter names, dates, and odds
class BoxingOddsService {
  final OddsApiService _oddsApi = OddsApiService();

  // Singleton instance
  static final BoxingOddsService _instance = BoxingOddsService._internal();
  factory BoxingOddsService() => _instance;
  BoxingOddsService._internal();

  // Cache
  List<BoxingEvent>? _cachedEvents;
  DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Popular boxer images mapping
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
    // Add more as needed
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
      final events = _parseOddsDataToEvents(oddsData);

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
  List<BoxingEvent> _parseOddsDataToEvents(List<Map<String, dynamic>> oddsData) {
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

        // Create event title from main fighters
        final eventTitle = '$fighter1Name vs $fighter2Name';
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

        // Create fighter info
        final fighterInfo1 = BoxingFighterInfo(
          id: _generateFighterId(fighter1Name),
          name: fighter1Name,
          fullName: fighter1Name,
          record: '', // Not available from Odds API
        );

        final fighterInfo2 = BoxingFighterInfo(
          id: _generateFighterId(fighter2Name),
          name: fighter2Name,
          fullName: fighter2Name,
          record: '', // Not available from Odds API
        );

        // Create fight
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
          cardPosition: bookmakers.length >= 7 ? 1 : 99, // 1 = main event
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
        // Sort fights - main events last
        fights.sort((a, b) {
          if (a.isMainEvent && !b.isMainEvent) return 1;
          if (!a.isMainEvent && b.isMainEvent) return -1;
          return 0;
        });

        // Get date from first fight
        final dateParts = dateKey.split('-');
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        // Main event determines the event title
        final mainFight = fights.lastWhere(
          (f) => f.isMainEvent,
          orElse: () => fights.last,
        );

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

    return events;
  }

  /// Get boxer image URL
  String _getBoxerImageUrl(String fighterName) {
    final normalized = fighterName.toLowerCase().trim();

    // Check for known boxer
    if (boxerImageUrls.containsKey(normalized)) {
      return boxerImageUrls[normalized]!;
    }

    // Check partial matches
    for (final entry in boxerImageUrls.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
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

// DataSource.oddsApi is now defined in the enum itself