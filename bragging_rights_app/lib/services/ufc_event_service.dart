import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/fight_card_model.dart';
import '../models/game_model.dart';

/// Service for fetching and processing UFC/MMA events with full fight card details
class UfcEventService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/mma';
  
  /// Fetch a complete UFC event with all fights on the card
  Future<FightCardEventModel?> fetchCompleteUfcEvent(String eventId) async {
    try {
      // First try to get the specific event details
      final eventUrl = '$baseUrl/ufc/event/$eventId';
      final response = await http.get(Uri.parse(eventUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseUfcEvent(data);
      }
    } catch (e) {
      print('Error fetching complete UFC event: $e');
    }
    return null;
  }
  
  /// Fetch upcoming UFC events with full card details
  Future<List<FightCardEventModel>> fetchUpcomingUfcEvents({int days = 60}) async {
    final events = <FightCardEventModel>[];
    
    try {
      final now = DateTime.now();
      final endDate = now.add(Duration(days: days));
      final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
      
      final url = '$baseUrl/ufc/scoreboard?dates=$startStr-$endStr';
      print('Fetching UFC events from: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final eventsList = data['events'] ?? [];
        
        for (final eventData in eventsList) {
          final event = _parseUfcEventFromScoreboard(eventData);
          if (event != null) {
            events.add(event);
          }
        }
      }
    } catch (e) {
      print('Error fetching UFC events: $e');
    }
    
    return events;
  }
  
  /// Parse UFC event from full event endpoint
  FightCardEventModel? _parseUfcEvent(Map<String, dynamic> data) {
    try {
      final event = data['event'] ?? data;
      final competitions = event['competitions'] ?? [];
      
      // Extract event name and details
      String fullEventName = event['name'] ?? 'UFC Event';
      String eventId = event['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Extract proper UFC event name
      String eventName = 'UFC Event';
      
      // Check if it's a full event name like "UFC Fight Night: Imavov vs. Borralho"
      if (fullEventName.contains('UFC Fight Night:') || fullEventName.contains('UFC ') && fullEventName.contains(':')) {
        // Use the full event name up to the colon
        final colonIndex = fullEventName.indexOf(':');
        if (colonIndex > 0) {
          eventName = fullEventName.substring(0, colonIndex).trim();
        }
      } else {
        // Fallback to regex for other formats
        final eventMatch = RegExp(r'UFC\s+(\d+|Fight Night|on ESPN|on ABC)').firstMatch(fullEventName);
        if (eventMatch != null) {
          eventName = eventMatch.group(0) ?? 'UFC Event';
        }
      }
      
      // Parse all fights on the card
      final fights = <Fight>[];
      int fightOrder = 0;
      
      for (final competition in competitions) {
        final fight = _parseFight(competition, fightOrder);
        if (fight != null) {
          fights.add(fight);
          fightOrder++;
        }
      }
      
      // Update fight positions based on total count (last fight is main event)
      if (fights.isNotEmpty) {
        final totalFights = fights.length;
        for (int i = 0; i < fights.length; i++) {
          final reversedIndex = totalFights - i - 1; // Reverse the order
          final fight = fights[i];
          
          String position;
          int rounds = 3;
          
          if (reversedIndex == 0) {
            position = 'Main Event';
            rounds = 5;
          } else if (reversedIndex == 1) {
            position = 'Co-Main Event';
            rounds = 3;
          } else if (reversedIndex < 5) {
            position = 'Main Card';
            rounds = 3;
          } else if (reversedIndex < 9) {
            position = 'Preliminary Card';
            rounds = 3;
          } else {
            position = 'Early Prelims';
            rounds = 3;
          }
          
          // Update the fight with correct position and rounds
          fights[i] = Fight(
            id: fight.id,
            eventId: fight.eventId,
            fighter1Id: fight.fighter1Id,
            fighter2Id: fight.fighter2Id,
            fighter1Name: fight.fighter1Name,
            fighter2Name: fight.fighter2Name,
            fighter1Record: fight.fighter1Record,
            fighter2Record: fight.fighter2Record,
            fighter1Country: fight.fighter1Country,
            fighter2Country: fight.fighter2Country,
            weightClass: fight.weightClass,
            rounds: rounds,
            cardPosition: position.toLowerCase().contains('main') ? 'main' : 
                         position.toLowerCase().contains('prelim') ? 'prelim' : 'early',
            fightOrder: reversedIndex + 1,
          );
        }
      }
      
      // Determine card structure
      String cardStructure = 'PPV';
      if (eventName.contains('Fight Night')) {
        cardStructure = 'Fight Night';
      } else if (eventName.contains('on ESPN') || eventName.contains('on ABC')) {
        cardStructure = 'ESPN';
      }
      
      // Get event time
      final eventDate = event['date'] != null 
        ? DateTime.parse(event['date']).toLocal()
        : DateTime.now();
      
      // Get venue information
      String? venue;
      String? location;
      if (competitions.isNotEmpty) {
        final comp = competitions[0];
        venue = comp['venue']?['fullName'];
        location = comp['venue']?['address']?['city'];
      }
      
      // Get main event title (main event is the LAST fight on the card)
      final mainEventTitle = fights.isNotEmpty 
        ? '${fights.last.fighter1Name} vs ${fights.last.fighter2Name}'
        : 'TBD vs TBD';
      
      return FightCardEventModel(
        id: eventId,
        gameTime: eventDate,
        status: event['status']?['type']?['name'] ?? 'scheduled',
        eventName: eventName,
        promotion: 'UFC',
        totalFights: fights.length,
        mainEventTitle: mainEventTitle,
        fights: fights,
        venue: venue,
        location: location,
      );
    } catch (e) {
      print('Error parsing UFC event: $e');
      return null;
    }
  }
  
  /// Parse UFC event from scoreboard endpoint
  FightCardEventModel? _parseUfcEventFromScoreboard(Map<String, dynamic> eventData) {
    try {
      final eventName = eventData['name'] ?? '';
      final eventId = eventData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Extract UFC event name (e.g., "UFC 310", "UFC Fight Night")
      String ufcEventName = 'UFC Event';
      
      // Check if it's a full event name like "UFC Fight Night: Imavov vs. Borralho"
      if (eventName.contains('UFC Fight Night:') || eventName.contains('UFC ') && eventName.contains(':')) {
        // Use the full event name up to the colon
        final colonIndex = eventName.indexOf(':');
        if (colonIndex > 0) {
          ufcEventName = eventName.substring(0, colonIndex).trim();
        }
      } else {
        // Fallback to regex for other formats
        final eventMatch = RegExp(r'UFC\s+(\d+|Fight Night|on ESPN|on ABC)').firstMatch(eventName);
        if (eventMatch != null) {
          ufcEventName = eventMatch.group(0) ?? 'UFC Event';
        }
      }
      
      // Parse main event fight from name
      final fights = <Fight>[];
      
      // Extract main event fighters from event name
      if (eventName.contains(' vs ')) {
        final parts = eventName.split(' vs ');
        if (parts.length >= 2) {
          // Remove UFC prefix from fighter names if present
          String fighter1 = parts[0].replaceAll(RegExp(r'UFC\s+\d+:\s*'), '').trim();
          String fighter2 = parts[1].trim();
          
          // Create main event fight
          final mainEvent = Fight(
            id: '${eventId}_main',
            eventId: eventId,
            fighter1Id: fighter1.toLowerCase().replaceAll(' ', '_'),
            fighter2Id: fighter2.toLowerCase().replaceAll(' ', '_'),
            fighter1Name: fighter1,
            fighter2Name: fighter2,
            fighter1Record: 'TBD',
            fighter2Record: 'TBD',
            fighter1Country: 'TBD',
            fighter2Country: 'TBD',
            weightClass: 'Main Event',
            rounds: 5,
            cardPosition: 'main',
            fightOrder: 1,
          );
          
          fights.add(mainEvent);
        }
      }
      
      // Get competition data for more fight details
      final competitions = eventData['competitions'] ?? [];
      if (competitions.isNotEmpty) {
        final competition = competitions[0];
        
        // Try to get additional fight details from competitors
        final competitors = competition['competitors'] ?? [];
        if (competitors.length >= 2 && fights.isEmpty) {
          // Create fight from competitors if we haven't already
          final fighter1Data = competitors[0]['athlete'] ?? {};
          final fighter2Data = competitors[1]['athlete'] ?? {};
          
          final fight = Fight(
            id: '${eventId}_main',
            eventId: eventId,
            fighter1Id: fighter1Data['id']?.toString() ?? '',
            fighter2Id: fighter2Data['id']?.toString() ?? '',
            fighter1Name: fighter1Data['displayName'] ?? 'TBD',
            fighter2Name: fighter2Data['displayName'] ?? 'TBD',
            fighter1Record: fighter1Data['record'] ?? 'TBD',
            fighter2Record: fighter2Data['record'] ?? 'TBD',
            fighter1Country: 'TBD',
            fighter2Country: 'TBD',
            weightClass: competition['notes']?[0]?['text'] ?? 'Main Event',
            rounds: 5,
            cardPosition: 'main',
            fightOrder: 1,
          );
          
          fights.add(fight);
        }
      }
      
      // Get event time
      final eventDate = eventData['date'] != null 
        ? DateTime.parse(eventData['date']).toLocal()
        : DateTime.now();
      
      // Get venue
      String? venue;
      if (competitions.isNotEmpty) {
        venue = competitions[0]['venue']?['fullName'];
      }
      
      // Create display name with event name and main event
      // For display, we want "UFC 310: Fighter1 vs Fighter2"
      // But for GameModel compatibility, store fighters separately
      final fighter1 = fights.isNotEmpty ? fights.first.fighter1Name : 'TBD';
      final fighter2 = fights.isNotEmpty ? fights.first.fighter2Name : 'TBD';
      
      // Get main event title
      final mainEventTitle = '$fighter1 vs $fighter2';
      
      return FightCardEventModel(
        id: eventId,
        gameTime: eventDate,
        status: eventData['status']?['type']?['name'] ?? 'scheduled',
        eventName: ufcEventName,
        promotion: 'UFC',
        totalFights: fights.length,
        mainEventTitle: mainEventTitle,
        fights: fights,
        venue: venue,
      );
    } catch (e) {
      print('Error parsing UFC event from scoreboard: $e');
      return null;
    }
  }
  
  /// Parse individual fight from competition data
  Fight? _parseFight(Map<String, dynamic> competition, int fightOrder) {
    try {
      final competitors = competition['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      final fighter1Data = competitors[0];
      final fighter2Data = competitors[1];
      
      final fighter1 = fighter1Data['athlete'] ?? {};
      final fighter2 = fighter2Data['athlete'] ?? {};
      
      // Note: Card position will be determined later when we know total fight count
      // For now, just set defaults - these will be updated after all fights are parsed
      String cardPosition = 'TBD';
      int rounds = 3;
      
      // Get weight class
      final weightClass = competition['notes']?[0]?['text'] ?? 
                         competition['displayName']?.split(' - ').last ?? 
                         'Catchweight';
      
      return Fight(
        id: competition['id']?.toString() ?? '${fightOrder}',
        eventId: '',  // Will be set by parent
        fighter1Id: fighter1['id']?.toString() ?? '',
        fighter2Id: fighter2['id']?.toString() ?? '',
        fighter1Name: fighter1['displayName'] ?? 'TBD',
        fighter2Name: fighter2['displayName'] ?? 'TBD',
        fighter1Record: fighter1['record'] ?? 'TBD',
        fighter2Record: fighter2['record'] ?? 'TBD',
        fighter1Country: 'TBD',
        fighter2Country: 'TBD',
        weightClass: weightClass,
        rounds: rounds,
        cardPosition: cardPosition.toLowerCase().contains('main') ? 'main' : 
                      cardPosition.toLowerCase().contains('prelim') ? 'prelim' : 'early',
        fightOrder: fightOrder + 1,  // Fight order starts at 1
      );
    } catch (e) {
      print('Error parsing fight: $e');
      return null;
    }
  }
  
  /// Convert UFC events to GameModel format for compatibility
  List<GameModel> convertToGameModels(List<FightCardEventModel> ufcEvents) {
    return ufcEvents.map((event) {
      // Extract the main event fighters (last fight on the card)
      final mainFight = event.fights.isNotEmpty ? event.fights.last : null;
      String fighter1 = mainFight?.fighter1Name ?? 'TBD';
      String fighter2 = mainFight?.fighter2Name ?? 'TBD';
      
      // Format for proper display: "UFC Fight Night: Fighter1 vs Fighter2"
      // Store the full title in awayTeam and empty/vs in homeTeam
      String displayTitle = '${event.eventName}: $fighter1 vs $fighter2';
      
      return GameModel(
        id: event.id,
        sport: 'MMA',  // Use MMA as the sport category
        homeTeam: fighter2,  // Second fighter
        awayTeam: displayTitle,  // Full event title with fighters
        gameTime: event.gameTime,
        status: event.status,
        venue: event.venue,
        league: event.promotion,  // UFC, Bellator, PFL, etc.
      );
    }).toList();
  }
}