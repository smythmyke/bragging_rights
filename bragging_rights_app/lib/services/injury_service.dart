import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/injury_model.dart';

class InjuryService {
  static const String _baseUrl = 'http://sports.core.api.espn.com/v2/sports';

  /// Fetch team injuries from ESPN API
  Future<List<Injury>> getTeamInjuries({
    required String sport,
    required String league,
    required String teamId,
  }) async {
    try {
      final url = '$_baseUrl/$sport/leagues/$league/teams/$teamId/injuries';
      print('Fetching injuries from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Injury API returned ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);

      if (data['items'] == null || (data['items'] as List).isEmpty) {
        print('No injuries found for team $teamId');
        return [];
      }

      final injuries = <Injury>[];

      // Fetch each injury reference
      for (final item in data['items']) {
        final injuryUrl = item['\$ref'];
        if (injuryUrl == null) continue;

        try {
          final injuryResponse = await http.get(Uri.parse(injuryUrl));

          if (injuryResponse.statusCode == 200) {
            final injuryData = json.decode(injuryResponse.body);

            // Fetch athlete name if we have athlete reference
            if (injuryData['athlete']?['\$ref'] != null) {
              final athleteUrl = injuryData['athlete']['\$ref'];
              try {
                final athleteResponse = await http.get(Uri.parse(athleteUrl));
                if (athleteResponse.statusCode == 200) {
                  final athleteData = json.decode(athleteResponse.body);
                  injuryData['athlete'] = athleteData;
                }
              } catch (e) {
                print('Error fetching athlete data: $e');
              }
            }

            injuries.add(Injury.fromESPN(injuryData));
          }
        } catch (e) {
          print('Error fetching injury details: $e');
          continue;
        }
      }

      print('Found ${injuries.length} injuries for team $teamId');
      return injuries;
    } catch (e) {
      print('Error fetching team injuries: $e');
      return [];
    }
  }

  /// Get injuries for a specific game (both teams)
  Future<GameInjuryReport?> getGameInjuries({
    required String sport,
    required String homeTeamId,
    required String homeTeamName,
    String? homeTeamLogo,
    required String awayTeamId,
    required String awayTeamName,
    String? awayTeamLogo,
  }) async {
    try {
      final league = _getLeague(sport);

      print('Fetching game injuries for $awayTeamName @ $homeTeamName');

      // Fetch injuries for both teams in parallel
      final results = await Future.wait([
        getTeamInjuries(sport: sport, league: league, teamId: homeTeamId),
        getTeamInjuries(sport: sport, league: league, teamId: awayTeamId),
      ]);

      final homeInjuries = results[0];
      final awayInjuries = results[1];

      return GameInjuryReport(
        homeTeamId: homeTeamId,
        homeTeamName: homeTeamName,
        homeTeamLogo: homeTeamLogo,
        awayTeamId: awayTeamId,
        awayTeamName: awayTeamName,
        awayTeamLogo: awayTeamLogo,
        homeInjuries: homeInjuries,
        awayInjuries: awayInjuries,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error fetching game injuries: $e');
      return null;
    }
  }

  /// Convert sport name to ESPN league code
  String _getLeague(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball':
        return 'nba';
      case 'football':
        return 'nfl';
      case 'baseball':
        return 'mlb';
      case 'hockey':
        return 'nhl';
      case 'soccer':
        return 'usa.1'; // MLS
      default:
        return sport.toLowerCase();
    }
  }

  /// Check if a sport supports injury data
  bool sportSupportsInjuries(String sport) {
    final supportedSports = [
      'basketball',
      'football',
      'baseball',
      'hockey',
      'soccer'
    ];
    return supportedSports.contains(sport.toLowerCase());
  }

  /// Quick check if game has any injuries (without fetching full details)
  /// Returns true if at least one team has injuries
  Future<bool> gameHasInjuries({
    required String sport,
    required String homeTeamId,
    required String awayTeamId,
  }) async {
    try {
      final league = _getLeague(sport);

      // Check both teams in parallel
      final results = await Future.wait([
        _teamHasInjuries(sport: sport, league: league, teamId: homeTeamId),
        _teamHasInjuries(sport: sport, league: league, teamId: awayTeamId),
      ]);

      // Return true if either team has injuries
      return results[0] || results[1];
    } catch (e) {
      print('Error checking game injuries: $e');
      return false; // Don't show card if check fails
    }
  }

  /// Check if a single team has injuries
  Future<bool> _teamHasInjuries({
    required String sport,
    required String league,
    required String teamId,
  }) async {
    try {
      final url = '$_baseUrl/$sport/leagues/$league/teams/$teamId/injuries';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return false;
      }

      final data = json.decode(response.body);
      final items = data['items'] as List?;

      // Return true if there are any injury items
      return items != null && items.isNotEmpty;
    } catch (e) {
      print('Error checking team injuries: $e');
      return false;
    }
  }

  /// Get injury data freshness indicator
  String getDataFreshness(DateTime fetchedAt) {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);

    if (difference.inMinutes < 5) {
      return 'Just updated';
    } else if (difference.inMinutes < 30) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 2) {
      return '${difference.inHours} hour ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
