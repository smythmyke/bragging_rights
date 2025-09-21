import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/models/game_model.dart';

void main() {
  group('NFL Details Unit Tests', () {
    test('GameModel should handle null ESPN ID gracefully', () {
      final game = GameModel(
        id: 'test-nfl-game',
        sport: 'NFL',
        homeTeam: 'Dallas Cowboys',
        awayTeam: 'Philadelphia Eagles',
        gameTime: DateTime.now(),
        status: 'scheduled',
        espnId: null, // Explicitly null
      );

      expect(game.espnId, isNull);
      expect(game.sport, equals('NFL'));
      expect(game.id, equals('test-nfl-game'));
    });

    test('GameModel should serialize with missing optional fields', () {
      final game = GameModel(
        id: 'minimal-nfl-game',
        sport: 'NFL',
        homeTeam: 'Patriots',
        awayTeam: 'Bills',
        gameTime: DateTime(2024, 1, 15, 13, 0),
        status: 'scheduled',
        odds: {}, // Provide empty map for odds
      );

      final json = game.toJson();

      // Required fields should be present
      expect(json['id'], equals('minimal-nfl-game'));
      expect(json['sport'], equals('NFL'));
      expect(json['homeTeam'], equals('Patriots'));
      expect(json['awayTeam'], equals('Bills'));
      expect(json['status'], equals('scheduled'));

      // Optional fields should handle null gracefully
      expect(json['venue'], isNull); // venue is null when not provided
      expect(json['espnId'], equals('minimal-nfl-game')); // espnId defaults to id when null
      expect(json['odds'], isA<Map>()); // Should have map (now explicitly empty)
    });

    test('GameModel should deserialize with missing data', () {
      final minimalJson = {
        'id': 'from-json-game',
        'sport': 'NFL',
        'homeTeam': 'Chiefs',
        'awayTeam': 'Raiders',
        'gameTime': DateTime.now().toIso8601String(),
        'status': 'in_progress',
      };

      final game = GameModel.fromMap(minimalJson);

      expect(game.id, equals('from-json-game'));
      expect(game.sport, equals('NFL'));
      expect(game.venue, isNull); // venue is null when not provided in JSON
      expect(game.espnId, isNull);
      expect(game.odds, isNull); // odds can be null when not provided
    });

    test('NFL game should handle future game state', () {
      final futureGame = GameModel(
        id: 'future-game',
        sport: 'NFL',
        homeTeam: 'Packers',
        awayTeam: 'Bears',
        gameTime: DateTime.now().add(const Duration(days: 7)),
        status: 'scheduled',
      );

      expect(futureGame.isLive, isFalse);
      expect(futureGame.status, equals('scheduled'));

      // Future games won't have scores
      final json = futureGame.toJson();
      expect(json['homeScore'], isNull);
      expect(json['awayScore'], isNull);
    });

    test('NFL game should handle live game state', () {
      final liveGame = GameModel(
        id: 'live-game',
        sport: 'NFL',
        homeTeam: 'Dolphins',
        awayTeam: 'Jets',
        gameTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'live', // isLive checks for status == 'live'
        homeScore: 21,
        awayScore: 14,
      );

      expect(liveGame.isLive, isTrue);
      expect(liveGame.status, equals('live'));
      expect(liveGame.homeScore, equals(21));
      expect(liveGame.awayScore, equals(14));
    });

    test('NFL game should handle completed game state', () {
      final completedGame = GameModel(
        id: 'completed-game',
        sport: 'NFL',
        homeTeam: 'Ravens',
        awayTeam: 'Bengals',
        gameTime: DateTime.now().subtract(const Duration(hours: 4)),
        status: 'final',
        homeScore: 27,
        awayScore: 24,
      );

      expect(completedGame.isLive, isFalse);
      expect(completedGame.status, equals('final'));
      expect(completedGame.homeScore, equals(27));
      expect(completedGame.awayScore, equals(24));
    });

    test('Event details map should handle null boxscore safely', () {
      Map<String, dynamic>? eventDetails = {
        'header': {
          'competitions': [
            {
              'status': {
                'type': {
                  'detail': 'Final',
                  'completed': true
                }
              }
            }
          ]
        },
        'boxscore': null, // Explicitly null boxscore
      };

      // Safe access pattern used in the fixed code
      final boxscore = eventDetails['boxscore'] as Map<String, dynamic>?;
      expect(boxscore, isNull);

      // Should not throw when accessing nested properties safely
      final header = eventDetails['header'] as Map<String, dynamic>?;
      expect(header, isNotNull);

      final status = header?['competitions']?[0]?['status']?['type']?['detail'];
      expect(status, equals('Final'));
    });

    test('Event details should handle completely missing sections', () {
      Map<String, dynamic>? eventDetails = {
        'header': {
          'competitions': []
        },
        // No boxscore, leaders, weather, etc.
      };

      // All these should be null and not crash
      expect(eventDetails['boxscore'], isNull);
      expect(eventDetails['leaders'], isNull);
      expect(eventDetails['weather'], isNull);
      expect(eventDetails['lastFiveGames'], isNull);

      // Safe navigation should return null without crashing when array is empty
      final competitions = eventDetails['header']?['competitions'] as List?;
      expect(competitions, isEmpty);

      // This would return null safely without throwing
      final venue = competitions != null && competitions.isNotEmpty
          ? competitions[0]['venue']
          : null;
      expect(venue, isNull);
    });
  });
}