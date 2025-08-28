import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// ESPN Boxing API Service
/// Provides comprehensive boxing data including fight cards, fighter profiles, and betting odds
class EspnBoxingService {
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/boxing';
  
  /// Get upcoming boxing events
  Future<EspnBoxingEvents?> getUpcomingEvents({String? promotion}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final cacheKey = promotion != null ? 'boxing_${promotion}_$today' : 'boxing_all_$today';
    
    return await _cache.getCachedData<EspnBoxingEvents>(
      collection: 'events',
      documentId: cacheKey,
      dataType: 'events',
      sport: 'boxing',
      gameState: {'source': 'espn', 'promotion': promotion},
      fetchFunction: () async {
        debugPrint('🥊 Fetching boxing events from ESPN...');
        
        // Build URL based on promotion if specified
        String url = _baseUrl;
        if (promotion != null) {
          // ESPN uses leagues for different promotions
          final leagueMap = {
            'pbc': 'pbc',      // Premier Boxing Champions
            'toprank': 'tr',   // Top Rank
            'dazn': 'dazn',    // DAZN
            'showtime': 'sho', // Showtime Boxing
          };
          final league = leagueMap[promotion.toLowerCase()];
          if (league != null) {
            url += '/leagues/$league';
          }
        }
        url += '/events';
        
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN Boxing data received: ${data['events']?.length ?? 0} events');
          return EspnBoxingEvents.fromJson(data);
        }
        throw Exception('ESPN Boxing API error: ${response.statusCode}');
      },
    );
  }

  /// Get detailed fight card for a specific event
  Future<EspnBoxingCard?> getFightCard(String eventId) async {
    return await _cache.getCachedData<EspnBoxingCard>(
      collection: 'events',
      documentId: 'boxing_card_$eventId',
      dataType: 'fightcard',
      sport: 'boxing',
      gameState: {'eventId': eventId},
      fetchFunction: () async {
        debugPrint('🥊 Fetching boxing fight card $eventId...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/events/$eventId'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return EspnBoxingCard.fromJson(data);
        }
        throw Exception('Failed to load fight card');
      },
    );
  }

  /// Get fighter profile and statistics
  Future<Map<String, dynamic>?> getFighterProfile(String fighterId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/athletes/$fighterId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseFighterProfile(data);
      }
    } catch (e) {
      debugPrint('Error fetching fighter profile: $e');
    }
    return null;
  }

  /// Get comprehensive boxing intelligence for Edge feature
  Future<Map<String, dynamic>> getBoxingIntelligence({
    required String fighter1,
    required String fighter2,
    Map<String, dynamic>? eventContext,
  }) async {
    debugPrint('🥊 Gathering boxing intelligence for $fighter1 vs $fighter2');
    
    final intelligence = <String, dynamic>{
      'mainEvent': {},
      'undercard': [],
      'fighterProfiles': {},
      'odds': {},
      'predictions': [],
      'judgeAnalysis': {},
      'venueAdvantage': {},
      'beltImplications': [],
    };

    try {
      // Get upcoming events to find this fight
      final events = await getUpcomingEvents();
      if (events != null) {
        final event = _findBoxingMatch(events, fighter1, fighter2);
        if (event != null) {
          intelligence['eventId'] = event['id'];
          intelligence['eventName'] = event['name'];
          intelligence['date'] = event['date'];
          
          // Parse fight card structure
          await _parseFightCard(event, intelligence, fighter1, fighter2);
          
          // Get detailed fight card if available
          final eventId = event['id'];
          final fightCard = await getFightCard(eventId);
          if (fightCard != null) {
            _enhanceFightCardData(fightCard, intelligence);
          }
        }
      }

      // Generate boxing-specific predictions
      intelligence['predictions'] = _generateBoxingPredictions(intelligence);
      
      // Analyze judge tendencies if championship fight
      if (eventContext?['isChampionship'] == true) {
        intelligence['judgeAnalysis'] = _analyzeJudgeTendencies(eventContext);
      }

    } catch (e) {
      debugPrint('Error gathering boxing intelligence: $e');
    }

    return intelligence;
  }

  /// Parse fighter profile from ESPN data
  Map<String, dynamic> _parseFighterProfile(Map<String, dynamic> data) {
    final athlete = data['athlete'] ?? {};
    final stats = athlete['statistics'] ?? [];
    
    // Parse record (wins-losses-draws)
    String record = 'N/A';
    int knockouts = 0;
    
    for (final stat in stats) {
      if (stat['name'] == 'record') {
        record = stat['displayValue'] ?? 'N/A';
      } else if (stat['name'] == 'ko') {
        knockouts = int.tryParse(stat['value']?.toString() ?? '0') ?? 0;
      }
    }
    
    return {
      'name': athlete['displayName'] ?? '',
      'record': record,
      'knockouts': knockouts,
      'koPercentage': _calculateKoPercentage(record, knockouts),
      'stance': athlete['stance'] ?? 'Unknown',
      'reach': athlete['reach'] ?? 'N/A',
      'height': athlete['height'] ?? 'N/A',
      'weight': athlete['weight'] ?? 'N/A',
      'age': athlete['age'] ?? 0,
      'birthplace': athlete['birthplace'] ?? {},
      'trainer': athlete['trainer'] ?? 'Unknown',
      'promoter': _extractPromoter(data),
      'titles': _extractTitles(data),
      'lastFight': athlete['lastFight'] ?? {},
    };
  }

  /// Calculate KO percentage from record
  double _calculateKoPercentage(String record, int knockouts) {
    final parts = record.split('-');
    if (parts.isNotEmpty) {
      final wins = int.tryParse(parts[0]) ?? 0;
      if (wins > 0) {
        return (knockouts / wins) * 100;
      }
    }
    return 0.0;
  }

  /// Extract promoter information
  String _extractPromoter(Map<String, dynamic> data) {
    // ESPN sometimes includes promoter in metadata
    final metadata = data['metadata'] ?? {};
    return metadata['promoter'] ?? 'Unknown';
  }

  /// Extract current titles held
  List<String> _extractTitles(Map<String, dynamic> data) {
    final titles = <String>[];
    final athlete = data['athlete'] ?? {};
    final championships = athlete['championships'] ?? [];
    
    for (final championship in championships) {
      final org = championship['organization'] ?? '';
      final weight = championship['weightClass'] ?? '';
      if (org.isNotEmpty) {
        titles.add('$org $weight');
      }
    }
    
    return titles;
  }

  /// Find specific boxing match in events
  Map<String, dynamic>? _findBoxingMatch(
    EspnBoxingEvents events,
    String fighter1,
    String fighter2,
  ) {
    for (final event in events.events) {
      final competitions = event['competitions'] ?? [];
      for (final competition in competitions) {
        final competitors = competition['competitors'] ?? [];
        if (competitors.length >= 2) {
          final athlete1 = competitors[0]['athlete']?['displayName'] ?? '';
          final athlete2 = competitors[1]['athlete']?['displayName'] ?? '';
          
          if ((_matcher.normalizeTeamName(athlete1) == _matcher.normalizeTeamName(fighter1) &&
               _matcher.normalizeTeamName(athlete2) == _matcher.normalizeTeamName(fighter2)) ||
              (_matcher.normalizeTeamName(athlete1) == _matcher.normalizeTeamName(fighter2) &&
               _matcher.normalizeTeamName(athlete2) == _matcher.normalizeTeamName(fighter1))) {
            return event;
          }
        }
      }
    }
    return null;
  }

  /// Parse fight card structure
  Future<void> _parseFightCard(
    Map<String, dynamic> event,
    Map<String, dynamic> intelligence,
    String fighter1,
    String fighter2,
  ) async {
    final competitions = event['competitions'] ?? [];
    
    for (int i = 0; i < competitions.length; i++) {
      final fight = competitions[i];
      final competitors = fight['competitors'] ?? [];
      
      if (competitors.length >= 2) {
        final fightData = {
          'fighter1': {
            'name': competitors[0]['athlete']?['displayName'] ?? '',
            'record': competitors[0]['records']?[0]?['summary'] ?? 'N/A',
            'odds': competitors[0]['odds'] ?? {},
          },
          'fighter2': {
            'name': competitors[1]['athlete']?['displayName'] ?? '',
            'record': competitors[1]['records']?[0]?['summary'] ?? 'N/A',
            'odds': competitors[1]['odds'] ?? {},
          },
          'rounds': fight['format']?['rounds'] ?? 10,
          'weightClass': fight['notes']?[0]?['headline'] ?? 'N/A',
          'status': fight['status']?['type']?['description'] ?? 'Scheduled',
        };
        
        // Check for title implications
        final notes = fight['notes'] ?? [];
        for (final note in notes) {
          final headline = note['headline']?.toString() ?? '';
          if (headline.toLowerCase().contains('title') ||
              headline.contains('WBA') ||
              headline.contains('WBC') ||
              headline.contains('IBF') ||
              headline.contains('WBO')) {
            fightData['titleFight'] = true;
            fightData['belts'] = _extractBelts(headline);
            intelligence['beltImplications'].add({
              'fight': '${fightData['fighter1']['name']} vs ${fightData['fighter2']['name']}',
              'belts': fightData['belts'],
            });
          }
        }
        
        // Categorize fight
        if (i == 0) {
          intelligence['mainEvent'] = fightData;
        } else if (i < 3) {
          intelligence['undercard'].add(fightData);
        }
        
        // Get fighter profiles for main event
        if (i == 0) {
          final fighter1Id = competitors[0]['athlete']?['id'];
          final fighter2Id = competitors[1]['athlete']?['id'];
          
          if (fighter1Id != null) {
            final profile = await getFighterProfile(fighter1Id);
            if (profile != null) {
              intelligence['fighterProfiles'][fightData['fighter1']['name']] = profile;
            }
          }
          
          if (fighter2Id != null) {
            final profile = await getFighterProfile(fighter2Id);
            if (profile != null) {
              intelligence['fighterProfiles'][fightData['fighter2']['name']] = profile;
            }
          }
        }
      }
    }
  }

  /// Extract belt organizations from headline
  List<String> _extractBelts(String headline) {
    final belts = <String>[];
    final organizations = ['WBA', 'WBC', 'IBF', 'WBO', 'IBO', 'WBA Super', 'Ring Magazine'];
    
    for (final org in organizations) {
      if (headline.contains(org)) {
        belts.add(org);
      }
    }
    
    if (headline.toLowerCase().contains('undisputed')) {
      return ['WBA', 'WBC', 'IBF', 'WBO']; // All four major belts
    }
    
    return belts.isNotEmpty ? belts : ['Title Fight'];
  }

  /// Enhance fight card with additional data
  void _enhanceFightCardData(EspnBoxingCard card, Map<String, dynamic> intelligence) {
    // Add venue information
    intelligence['venue'] = card.venue;
    intelligence['location'] = card.location;
    
    // Add broadcast information
    intelligence['broadcast'] = card.broadcast;
    
    // Parse additional fight details
    for (final fight in card.fights) {
      // Extract judge names if available
      if (fight['officials'] != null) {
        intelligence['officials'] = fight['officials'];
      }
      
      // Get detailed odds
      if (fight['odds'] != null) {
        intelligence['odds'] = {
          'moneyline': fight['odds']['moneyline'] ?? {},
          'methodOfVictory': fight['odds']['props']?['method'] ?? {},
          'roundBetting': fight['odds']['props']?['rounds'] ?? {},
          'overUnder': fight['odds']['overUnder'] ?? {},
        };
      }
    }
  }

  /// Generate boxing-specific predictions
  List<Map<String, dynamic>> _generateBoxingPredictions(Map<String, dynamic> intelligence) {
    final predictions = <Map<String, dynamic>>[];
    final mainEvent = intelligence['mainEvent'] ?? {};
    final profiles = intelligence['fighterProfiles'] ?? {};
    
    // KO probability based on fighter stats
    if (profiles.isNotEmpty) {
      for (final entry in profiles.entries) {
        final koRate = entry.value['koPercentage'] ?? 0.0;
        if (koRate > 60) {
          predictions.add({
            'type': 'ko_threat',
            'insight': '${entry.key} has ${koRate.toStringAsFixed(1)}% KO rate - expect fireworks',
            'confidence': 0.75,
          });
        }
      }
    }
    
    // Style matchup predictions
    final fighter1Profile = profiles.values.firstOrNull ?? {};
    final fighter2Profile = profiles.values.lastOrNull ?? {};
    
    if (fighter1Profile['stance'] != null && fighter2Profile['stance'] != null) {
      if (fighter1Profile['stance'] != fighter2Profile['stance']) {
        predictions.add({
          'type': 'style_matchup',
          'insight': 'Orthodox vs Southpaw matchup - expect awkward exchanges',
          'confidence': 0.70,
        });
      }
    }
    
    // Championship rounds prediction
    final rounds = mainEvent['rounds'] ?? 10;
    if (rounds == 12) {
      predictions.add({
        'type': 'championship_distance',
        'insight': '12-round championship bout - cardio will be crucial',
        'confidence': 0.80,
      });
    }
    
    // Age factor
    for (final profile in profiles.values) {
      final age = profile['age'] ?? 0;
      if (age > 35) {
        predictions.add({
          'type': 'age_factor',
          'insight': '${profile['name']} is $age years old - age could be a factor',
          'confidence': 0.65,
        });
      }
    }
    
    return predictions;
  }

  /// Analyze judge tendencies for championship fights
  Map<String, dynamic> _analyzeJudgeTendencies(Map<String, dynamic>? eventContext) {
    // This would typically query historical judge data
    // For now, return placeholder analysis
    return {
      'homeAdvantage': eventContext?['venue']?.contains('Las Vegas') ?? false
          ? 'Vegas judges tend to favor aggressive style'
          : 'Neutral venue',
      'scoringStyle': 'Power punches valued over volume',
      'controversialRisk': 'Low', // Would calculate based on judge history
    };
  }
}

/// Boxing Events Model
class EspnBoxingEvents {
  final List<dynamic> events;
  
  EspnBoxingEvents({required this.events});
  
  factory EspnBoxingEvents.fromJson(Map<String, dynamic> json) {
    return EspnBoxingEvents(
      events: json['events'] ?? [],
    );
  }
}

/// Boxing Fight Card Model
class EspnBoxingCard {
  final String eventId;
  final String eventName;
  final List<dynamic> fights;
  final String? venue;
  final String? location;
  final String? broadcast;
  
  EspnBoxingCard({
    required this.eventId,
    required this.eventName,
    required this.fights,
    this.venue,
    this.location,
    this.broadcast,
  });
  
  factory EspnBoxingCard.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? json;
    return EspnBoxingCard(
      eventId: event['id'] ?? '',
      eventName: event['name'] ?? '',
      fights: event['competitions'] ?? [],
      venue: event['venue']?['fullName'],
      location: event['venue']?['address']?['city'],
      broadcast: event['broadcasts']?[0]?['market'] ?? 'N/A',
    );
  }
}