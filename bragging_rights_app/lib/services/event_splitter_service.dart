import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_state_model.dart';

// Base class for all competition types
abstract class Competition {
  final String id;
  final String eventId;
  final String title;
  final DateTime startTime;
  final CompetitionStatus status;
  final Map<String, dynamic> metadata;

  Competition({
    required this.id,
    required this.eventId,
    required this.title,
    required this.startTime,
    required this.status,
    required this.metadata,
  });
}

enum CompetitionStatus {
  scheduled,
  live,
  final,
  cancelled,
}

// UFC/MMA Fight
class UFCFight extends Competition {
  final String fighter1;
  final String fighter2;
  final String weightClass;
  final int scheduledRounds;
  final bool isMainEvent;
  final bool isTitleFight;
  final int? currentRound;
  final String? roundTime;
  final FightResult? result;

  UFCFight({
    required String id,
    required String eventId,
    required DateTime startTime,
    required CompetitionStatus status,
    required this.fighter1,
    required this.fighter2,
    required this.weightClass,
    required this.scheduledRounds,
    required this.isMainEvent,
    required this.isTitleFight,
    this.currentRound,
    this.roundTime,
    this.result,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id,
    eventId: eventId,
    title: '$fighter1 vs $fighter2',
    startTime: startTime,
    status: status,
    metadata: metadata ?? {},
  );
}

class FightResult {
  final String winner;
  final String method; // KO, TKO, SUB, DEC, NC, DQ
  final int round;
  final String? time;

  FightResult({
    required this.winner,
    required this.method,
    required this.round,
    this.time,
  });
}

// Tennis Match
class TennisMatch extends Competition {
  final String player1;
  final String player2;
  final String round; // "Round of 128", "Quarter-Final", "Final"
  final String surface; // "Hard", "Clay", "Grass"
  final int setsToWin;
  final List<SetScore>? sets;
  final String? currentServer;
  final MatchResult? result;

  TennisMatch({
    required String id,
    required String eventId,
    required DateTime startTime,
    required CompetitionStatus status,
    required this.player1,
    required this.player2,
    required this.round,
    required this.surface,
    required this.setsToWin,
    this.sets,
    this.currentServer,
    this.result,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id,
    eventId: eventId,
    title: '$player1 vs $player2',
    startTime: startTime,
    status: status,
    metadata: metadata ?? {},
  );
}

class MatchResult {
  final String winner;
  final String score; // "6-4, 6-3, 7-5"
  final bool isRetirement;
  final bool isWalkover;

  MatchResult({
    required this.winner,
    required this.score,
    this.isRetirement = false,
    this.isWalkover = false,
  });
}

// Boxing Bout
class BoxingBout extends Competition {
  final String fighter1;
  final String fighter2;
  final String weightClass;
  final int scheduledRounds;
  final bool isTitleFight;
  final int? currentRound;
  final BoutResult? result;

  BoxingBout({
    required String id,
    required String eventId,
    required DateTime startTime,
    required CompetitionStatus status,
    required this.fighter1,
    required this.fighter2,
    required this.weightClass,
    required this.scheduledRounds,
    required this.isTitleFight,
    this.currentRound,
    this.result,
    Map<String, dynamic>? metadata,
  }) : super(
    id: id,
    eventId: eventId,
    title: '$fighter1 vs $fighter2',
    startTime: startTime,
    status: status,
    metadata: metadata ?? {},
  );
}

class BoutResult {
  final String winner;
  final String method; // KO, TKO, UD, SD, MD, DQ, NC
  final int? round;
  final String? time;

  BoutResult({
    required this.winner,
    required this.method,
    this.round,
    this.time,
  });
}

// Main Event Splitter Service
class EventSplitterService {
  static EventSplitterService? _instance;
  factory EventSplitterService() {
    _instance ??= EventSplitterService._internal();
    return _instance!;
  }
  EventSplitterService._internal();

  // Parse UFC/MMA Event into individual fights
  Future<List<UFCFight>> parseUFCEvent(String eventId) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/summary?event=$eventId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch UFC event');
      }
      
      final data = json.decode(response.body);
      final fights = <UFCFight>[];
      
      // UFC events have multiple competitions (fights)
      final competitions = data['competitions'] ?? [];
      
      for (int i = 0; i < competitions.length; i++) {
        final comp = competitions[i];
        final fight = _parseUFCFight(comp, eventId, i == 0); // First fight is main event
        if (fight != null) {
          fights.add(fight);
        }
      }
      
      // Reverse list so main event is last
      return fights.reversed.toList();
    } catch (e) {
      print('Error parsing UFC event $eventId: $e');
      return [];
    }
  }

  // Parse individual UFC fight
  UFCFight? _parseUFCFight(Map<String, dynamic> comp, String eventId, bool isMainEvent) {
    try {
      // Extract competitors
      final competitors = comp['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'Fighter 1';
      final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'Fighter 2';
      
      // Extract fight details
      final notes = comp['notes'] ?? [];
      String weightClass = 'Catchweight';
      if (notes.isNotEmpty && notes[0]['headline'] != null) {
        weightClass = notes[0]['headline'];
      }
      
      // Parse status
      final status = comp['status'] ?? {};
      final statusType = status['type']?['name'] ?? '';
      
      CompetitionStatus fightStatus = CompetitionStatus.scheduled;
      if (statusType == 'STATUS_FINAL') {
        fightStatus = CompetitionStatus.final;
      } else if (statusType == 'STATUS_IN_PROGRESS') {
        fightStatus = CompetitionStatus.live;
      }
      
      // Current round and time
      final currentRound = status['period'];
      final roundTime = status['displayClock'];
      
      // Check for title fight
      final isTitleFight = comp['notes']?.any((note) => 
        note['text']?.toLowerCase().contains('title') ?? false) ?? false;
      
      // Scheduled rounds (5 for main event/title, 3 for others)
      final scheduledRounds = (isMainEvent || isTitleFight) ? 5 : 3;
      
      // Parse result if fight is final
      FightResult? result;
      if (fightStatus == CompetitionStatus.final) {
        result = _parseFightResult(comp);
      }
      
      // Start time
      final startTime = DateTime.tryParse(comp['date'] ?? '') ?? DateTime.now();
      
      return UFCFight(
        id: '${eventId}_${comp['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        eventId: eventId,
        startTime: startTime,
        status: fightStatus,
        fighter1: fighter1,
        fighter2: fighter2,
        weightClass: weightClass,
        scheduledRounds: scheduledRounds,
        isMainEvent: isMainEvent,
        isTitleFight: isTitleFight,
        currentRound: currentRound,
        roundTime: roundTime,
        result: result,
        metadata: {
          'fightOrder': comp['order'] ?? 0,
          'broadcastInfo': comp['broadcasts']?.firstOrNull ?? {},
        },
      );
    } catch (e) {
      print('Error parsing UFC fight: $e');
      return null;
    }
  }

  // Parse fight result
  FightResult? _parseFightResult(Map<String, dynamic> comp) {
    try {
      // Check for winner
      final competitors = comp['competitors'] ?? [];
      String? winner;
      
      for (final competitor in competitors) {
        if (competitor['winner'] == true) {
          winner = competitor['athlete']?['displayName'];
          break;
        }
      }
      
      if (winner == null) return null;
      
      // Parse method and round from status or notes
      final status = comp['status'] ?? {};
      final statusDetail = status['type']?['detail'] ?? '';
      
      // Extract method (KO, TKO, SUB, DEC)
      String method = 'DEC'; // Default to decision
      int round = 3; // Default to final round
      String? time;
      
      if (statusDetail.contains('KO')) {
        method = 'KO';
      } else if (statusDetail.contains('TKO')) {
        method = 'TKO';
      } else if (statusDetail.contains('Submission')) {
        method = 'SUB';
      } else if (statusDetail.contains('Decision')) {
        method = 'DEC';
      } else if (statusDetail.contains('DQ')) {
        method = 'DQ';
      } else if (statusDetail.contains('No Contest')) {
        method = 'NC';
      }
      
      // Try to extract round and time from detail
      // Format often: "Fighter - KO (Punches) - Round 2, 3:45"
      final roundMatch = RegExp(r'Round (\d+)').firstMatch(statusDetail);
      if (roundMatch != null) {
        round = int.parse(roundMatch.group(1)!);
      }
      
      final timeMatch = RegExp(r'(\d+:\d+)').firstMatch(statusDetail);
      if (timeMatch != null) {
        time = timeMatch.group(1);
      }
      
      return FightResult(
        winner: winner,
        method: method,
        round: round,
        time: time,
      );
    } catch (e) {
      print('Error parsing fight result: $e');
      return null;
    }
  }

  // Parse Tennis Tournament into individual matches
  Future<List<TennisMatch>> parseTennisTournament(String tournamentId) async {
    try {
      // Tennis API endpoint varies by tour (ATP, WTA)
      final url = 'https://site.api.espn.com/apis/site/v2/sports/tennis/atp/scoreboard';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch tennis tournament');
      }
      
      final data = json.decode(response.body);
      final matches = <TennisMatch>[];
      
      final events = data['events'] ?? [];
      
      for (final event in events) {
        // Check if this event belongs to our tournament
        if (event['season']?['slug'] == tournamentId || 
            event['tournament']?['id'] == tournamentId) {
          final match = _parseTennisMatch(event, tournamentId);
          if (match != null) {
            matches.add(match);
          }
        }
      }
      
      return matches;
    } catch (e) {
      print('Error parsing tennis tournament $tournamentId: $e');
      return [];
    }
  }

  // Parse individual tennis match
  TennisMatch? _parseTennisMatch(Map<String, dynamic> event, String tournamentId) {
    try {
      final competitions = event['competitions'] ?? [];
      if (competitions.isEmpty) return null;
      
      final comp = competitions[0];
      final competitors = comp['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      // Extract players
      final player1 = competitors[0]['athlete']?['displayName'] ?? 'Player 1';
      final player2 = competitors[1]['athlete']?['displayName'] ?? 'Player 2';
      
      // Extract round
      final round = event['tournament']?['round']?['displayName'] ?? 'Unknown Round';
      
      // Surface type
      final surface = event['tournament']?['surface'] ?? 'Hard';
      
      // Match format (best of 3 or 5)
      final setsToWin = event['format']?['regulation']?['periods'] == 5 ? 3 : 2;
      
      // Parse status
      final status = comp['status'] ?? {};
      final statusType = status['type']?['name'] ?? '';
      
      CompetitionStatus matchStatus = CompetitionStatus.scheduled;
      if (statusType == 'STATUS_FINAL') {
        matchStatus = CompetitionStatus.final;
      } else if (statusType == 'STATUS_IN_PROGRESS') {
        matchStatus = CompetitionStatus.live;
      }
      
      // Parse sets if available
      List<SetScore>? sets;
      if (comp['score'] != null) {
        sets = _parseTennisSets(comp);
      }
      
      // Current server
      String? currentServer;
      if (matchStatus == CompetitionStatus.live && comp['situation'] != null) {
        final serverId = comp['situation']['server'];
        if (serverId != null) {
          currentServer = competitors.firstWhere(
            (c) => c['id'] == serverId,
            orElse: () => {},
          )['athlete']?['displayName'];
        }
      }
      
      // Parse result if match is final
      MatchResult? result;
      if (matchStatus == CompetitionStatus.final) {
        result = _parseMatchResult(comp, player1, player2);
      }
      
      // Start time
      final startTime = DateTime.tryParse(event['date'] ?? '') ?? DateTime.now();
      
      return TennisMatch(
        id: '${tournamentId}_${event['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        eventId: tournamentId,
        startTime: startTime,
        status: matchStatus,
        player1: player1,
        player2: player2,
        round: round,
        surface: surface,
        setsToWin: setsToWin,
        sets: sets,
        currentServer: currentServer,
        result: result,
        metadata: {
          'courtName': event['venue']?['fullName'] ?? '',
          'tournamentName': event['tournament']?['name'] ?? '',
        },
      );
    } catch (e) {
      print('Error parsing tennis match: $e');
      return null;
    }
  }

  // Parse tennis sets
  List<SetScore> _parseTennisSets(Map<String, dynamic> comp) {
    final sets = <SetScore>[];
    
    try {
      final competitors = comp['competitors'] ?? [];
      if (competitors.length < 2) return sets;
      
      // ESPN provides linescores for each set
      final linescores1 = competitors[0]['linescores'] ?? [];
      final linescores2 = competitors[1]['linescores'] ?? [];
      
      for (int i = 0; i < linescores1.length; i++) {
        if (i < linescores2.length) {
          sets.add(SetScore(
            player1Games: linescores1[i]['value'] ?? 0,
            player2Games: linescores2[i]['value'] ?? 0,
            isComplete: true, // TODO: Determine if set is complete
          ));
        }
      }
    } catch (e) {
      print('Error parsing tennis sets: $e');
    }
    
    return sets;
  }

  // Parse match result
  MatchResult? _parseMatchResult(Map<String, dynamic> comp, String player1, String player2) {
    try {
      // Find winner
      final competitors = comp['competitors'] ?? [];
      String? winner;
      
      for (final competitor in competitors) {
        if (competitor['winner'] == true) {
          winner = competitor['athlete']?['displayName'];
          break;
        }
      }
      
      if (winner == null) return null;
      
      // Build score string from sets
      final sets = _parseTennisSets(comp);
      final scoreStrings = sets.map((set) => 
        '${set.player1Games}-${set.player2Games}'
      ).toList();
      final score = scoreStrings.join(', ');
      
      // Check for retirement or walkover
      final status = comp['status'] ?? {};
      final statusDetail = status['type']?['detail'] ?? '';
      
      final isRetirement = statusDetail.toLowerCase().contains('retired');
      final isWalkover = statusDetail.toLowerCase().contains('walkover');
      
      return MatchResult(
        winner: winner,
        score: score,
        isRetirement: isRetirement,
        isWalkover: isWalkover,
      );
    } catch (e) {
      print('Error parsing match result: $e');
      return null;
    }
  }

  // Parse Boxing Event into individual bouts
  Future<List<BoxingBout>> parseBoxingEvent(String eventId) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/boxing/summary?event=$eventId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch boxing event');
      }
      
      final data = json.decode(response.body);
      final bouts = <BoxingBout>[];
      
      // Similar to UFC, boxing has multiple competitions (bouts)
      final competitions = data['competitions'] ?? [];
      
      for (int i = 0; i < competitions.length; i++) {
        final comp = competitions[i];
        final bout = _parseBoxingBout(comp, eventId, i == 0); // First bout is main event
        if (bout != null) {
          bouts.add(bout);
        }
      }
      
      return bouts.reversed.toList(); // Main event last
    } catch (e) {
      print('Error parsing boxing event $eventId: $e');
      return [];
    }
  }

  // Parse individual boxing bout
  BoxingBout? _parseBoxingBout(Map<String, dynamic> comp, String eventId, bool isMainEvent) {
    try {
      // Extract competitors
      final competitors = comp['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'Fighter 1';
      final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'Fighter 2';
      
      // Weight class
      final notes = comp['notes'] ?? [];
      String weightClass = 'Unknown';
      if (notes.isNotEmpty) {
        weightClass = notes[0]['headline'] ?? 'Unknown';
      }
      
      // Scheduled rounds (12 for championship, varies for others)
      final scheduledRounds = comp['format']?['regulation']?['periods'] ?? 10;
      
      // Check for title fight
      final isTitleFight = notes.any((note) => 
        note['text']?.toLowerCase().contains('title') ?? false);
      
      // Parse status
      final status = comp['status'] ?? {};
      final statusType = status['type']?['name'] ?? '';
      
      CompetitionStatus boutStatus = CompetitionStatus.scheduled;
      if (statusType == 'STATUS_FINAL') {
        boutStatus = CompetitionStatus.final;
      } else if (statusType == 'STATUS_IN_PROGRESS') {
        boutStatus = CompetitionStatus.live;
      }
      
      // Current round
      final currentRound = status['period'];
      
      // Parse result if bout is final
      BoutResult? result;
      if (boutStatus == CompetitionStatus.final) {
        result = _parseBoutResult(comp);
      }
      
      // Start time
      final startTime = DateTime.tryParse(comp['date'] ?? '') ?? DateTime.now();
      
      return BoxingBout(
        id: '${eventId}_${comp['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        eventId: eventId,
        startTime: startTime,
        status: boutStatus,
        fighter1: fighter1,
        fighter2: fighter2,
        weightClass: weightClass,
        scheduledRounds: scheduledRounds,
        isTitleFight: isTitleFight,
        currentRound: currentRound,
        result: result,
        metadata: {
          'isMainEvent': isMainEvent,
          'broadcastInfo': comp['broadcasts']?.firstOrNull ?? {},
        },
      );
    } catch (e) {
      print('Error parsing boxing bout: $e');
      return null;
    }
  }

  // Parse bout result
  BoutResult? _parseBoutResult(Map<String, dynamic> comp) {
    try {
      // Find winner
      final competitors = comp['competitors'] ?? [];
      String? winner;
      
      for (final competitor in competitors) {
        if (competitor['winner'] == true) {
          winner = competitor['athlete']?['displayName'];
          break;
        }
      }
      
      if (winner == null) return null;
      
      // Parse method from status detail
      final status = comp['status'] ?? {};
      final statusDetail = status['type']?['detail'] ?? '';
      
      String method = 'UD'; // Default to unanimous decision
      int? round;
      String? time;
      
      if (statusDetail.contains('KO')) {
        method = 'KO';
      } else if (statusDetail.contains('TKO')) {
        method = 'TKO';
      } else if (statusDetail.contains('UD') || statusDetail.contains('Unanimous')) {
        method = 'UD';
      } else if (statusDetail.contains('SD') || statusDetail.contains('Split')) {
        method = 'SD';
      } else if (statusDetail.contains('MD') || statusDetail.contains('Majority')) {
        method = 'MD';
      } else if (statusDetail.contains('DQ')) {
        method = 'DQ';
      } else if (statusDetail.contains('NC') || statusDetail.contains('No Contest')) {
        method = 'NC';
      }
      
      // Extract round if KO/TKO
      if (method == 'KO' || method == 'TKO') {
        final roundMatch = RegExp(r'Round (\d+)').firstMatch(statusDetail);
        if (roundMatch != null) {
          round = int.parse(roundMatch.group(1)!);
        }
        
        final timeMatch = RegExp(r'(\d+:\d+)').firstMatch(statusDetail);
        if (timeMatch != null) {
          time = timeMatch.group(1);
        }
      }
      
      return BoutResult(
        winner: winner,
        method: method,
        round: round,
        time: time,
      );
    } catch (e) {
      print('Error parsing bout result: $e');
      return null;
    }
  }

  // Identify event type and split accordingly
  Future<List<Competition>> splitEvent(String eventId, String sport) async {
    switch (sport.toLowerCase()) {
      case 'ufc':
      case 'mma':
        final fights = await parseUFCEvent(eventId);
        return fights.cast<Competition>();
        
      case 'tennis':
        final matches = await parseTennisTournament(eventId);
        return matches.cast<Competition>();
        
      case 'boxing':
        final bouts = await parseBoxingEvent(eventId);
        return bouts.cast<Competition>();
        
      default:
        // Single competition sports don't need splitting
        return [];
    }
  }
}