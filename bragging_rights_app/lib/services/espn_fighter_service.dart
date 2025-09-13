import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fighter_model.dart';

class ESPNFighterService {
  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';

  Future<FighterModel?> getFighterDetails(String fighterId, String sport) async {
    if (fighterId.isEmpty) {
      return _createBasicFighter(fighterId, 'Unknown Fighter');
    }

    try {
      // Determine the correct endpoint based on sport
      String endpoint;
      if (sport.toUpperCase() == 'MMA' || sport.toUpperCase().contains('UFC')) {
        endpoint = '$_baseUrl/mma/ufc/athletes/$fighterId';
      } else if (sport.toUpperCase() == 'BOXING') {
        endpoint = '$_baseUrl/boxing/athletes/$fighterId';
      } else {
        // Default to MMA for combat sports
        endpoint = '$_baseUrl/mma/ufc/athletes/$fighterId';
      }

      print('Fetching fighter details from: $endpoint');
      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final athlete = data['athlete'] ?? {};

        print('Fighter data received: ${athlete['displayName']}');

        // Parse the fighter data
        final fighterData = {
          'id': athlete['id']?.toString() ?? fighterId,
          'displayName': athlete['displayName'] ?? 'Unknown Fighter',
          'nickname': athlete['nickname'],
          'height': _parseHeight(athlete),
          'weight': _parseWeight(athlete),
          'reach': _parseReach(athlete),
          'stance': athlete['stance'],
          'age': athlete['age'],
          'dateOfBirth': athlete['dateOfBirth'],
          'birthCountry': athlete['birthPlace']?['country'],
          'flag': athlete['flag']?['href'],
          'headshot': athlete['headshot'],
          'division': athlete['position']?['displayName'] ?? athlete['weightClass'],
        };

        // Try to get statistics
        if (athlete['statistics'] != null) {
          final stats = athlete['statistics'];
          fighterData['record'] = stats['record'];
          fighterData['wins'] = stats['wins'];
          fighterData['losses'] = stats['losses'];
          fighterData['draws'] = stats['draws'];
          fighterData['knockouts'] = stats['knockouts'];
          fighterData['submissions'] = stats['submissions'];
          fighterData['decisions'] = stats['decisions'];
        } else if (athlete['record'] != null) {
          fighterData['record'] = athlete['record'];
        }

        // Try to get recent fights
        fighterData['recentFights'] = await _getRecentFights(fighterId, sport);

        return FighterModel.fromJson(fighterData);
      } else if (response.statusCode == 404) {
        print('Fighter not found, creating basic profile');
        return _createBasicFighter(fighterId, 'Fighter #$fighterId');
      }
    } catch (e) {
      print('Error fetching fighter details: $e');
    }

    // Return basic fighter if API fails
    return _createBasicFighter(fighterId, 'Fighter');
  }

  FighterModel _createBasicFighter(String id, String name) {
    return FighterModel(
      id: id,
      name: name,
      record: 'Record not available',
    );
  }

  String? _parseHeight(Map<String, dynamic> athlete) {
    if (athlete['height'] != null) {
      final height = athlete['height'];
      if (height is String) return height;
      if (height is num) {
        // Convert inches to feet and inches
        final feet = height ~/ 12;
        final inches = height % 12;
        return "$feet'$inches\"";
      }
    }
    return null;
  }

  String? _parseWeight(Map<String, dynamic> athlete) {
    if (athlete['weight'] != null) {
      final weight = athlete['weight'];
      if (weight is String) return weight;
      if (weight is num) return '$weight lbs';
    }
    return null;
  }

  String? _parseReach(Map<String, dynamic> athlete) {
    if (athlete['reach'] != null) {
      final reach = athlete['reach'];
      if (reach is String) return reach;
      if (reach is num) return '$reach"';
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> _getRecentFights(String fighterId, String sport) async {
    try {
      // Try to get event log for recent fights
      String endpoint;
      if (sport.toUpperCase() == 'MMA' || sport.toUpperCase().contains('UFC')) {
        endpoint = '$_baseUrl/mma/ufc/athletes/$fighterId/eventlog';
      } else if (sport.toUpperCase() == 'BOXING') {
        endpoint = '$_baseUrl/boxing/athletes/$fighterId/eventlog';
      } else {
        return null;
      }

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? [];

        final recentFights = <Map<String, dynamic>>[];

        for (var i = 0; i < events.length && i < 5; i++) {
          final event = events[i];
          final competition = event['competition'];

          if (competition != null) {
            final competitors = competition['competitors'] ?? [];

            // Find opponent
            String? opponent;
            String? result;
            String? method;

            for (final comp in competitors) {
              final athleteId = comp['athlete']?['id']?.toString();
              if (athleteId != fighterId) {
                opponent = comp['athlete']?['displayName'];
              } else {
                // Determine result based on winner
                if (comp['winner'] == true) {
                  result = 'W';
                } else if (comp['winner'] == false) {
                  result = 'L';
                } else {
                  result = 'D';
                }
              }
            }

            // Try to get fight details
            final status = competition['status'];
            if (status != null) {
              method = status['type']?['description'];
            }

            recentFights.add({
              'opponent': opponent ?? 'Unknown',
              'result': result ?? 'N',
              'method': method ?? 'Decision',
              'round': competition['status']?['period']?.toString() ?? 'R3',
              'date': event['date']?.split('T')[0] ?? '',
              'event': event['name'],
            });
          }
        }

        return recentFights.isEmpty ? null : recentFights;
      }
    } catch (e) {
      print('Error fetching recent fights: $e');
    }

    return null;
  }
}