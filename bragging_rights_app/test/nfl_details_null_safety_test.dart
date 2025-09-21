import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/screens/game/game_details_screen.dart';
import 'package:bragging_rights_app/models/game_model.dart';
import 'package:bragging_rights_app/theme/app_theme.dart';

void main() {
  group('NFL Details Page Null Safety Tests', () {
    testWidgets('Should handle missing boxscore data gracefully', (WidgetTester tester) async {
      // Create a minimal game model for NFL
      final testGame = GameModel(
        id: 'test-nfl-game-1',
        sport: 'NFL',
        homeTeam: 'Dallas Cowboys',
        awayTeam: 'Philadelphia Eagles',
        gameTime: DateTime.now().add(const Duration(hours: 24)),
        status: 'scheduled',
        venue: 'AT&T Stadium',
        odds: {},
      );

      // Build the widget with minimal data
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GameDetailsScreen(
            gameId: testGame.id,
            sport: 'NFL',
            gameData: testGame,
          ),
        ),
      );

      // Initial load
      await tester.pump();

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After some time, should show the screen without crashing
      await tester.pump(const Duration(seconds: 2));

      // Should not crash and should show fallback UI elements
      expect(find.text('Dallas Cowboys'), findsAny);
      expect(find.text('Philadelphia Eagles'), findsAny);
    });

    testWidgets('Should display fallback UI when eventDetails is null', (WidgetTester tester) async {
      final testGame = GameModel(
        id: 'test-nfl-game-2',
        sport: 'NFL',
        homeTeam: 'New England Patriots',
        awayTeam: 'Buffalo Bills',
        gameTime: DateTime.now(),
        status: 'in_progress',
        venue: 'Gillette Stadium',
        odds: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GameDetailsScreen(
            gameId: testGame.id,
            sport: 'NFL',
            gameData: testGame,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should show tabs even without data
      expect(find.text('Overview'), findsAny);
      expect(find.text('Stats'), findsAny);
      expect(find.text('Plays'), findsAny);
    });

    testWidgets('Should handle missing weather data for outdoor venues', (WidgetTester tester) async {
      final testGame = GameModel(
        id: 'test-nfl-game-3',
        sport: 'NFL',
        homeTeam: 'Green Bay Packers',
        awayTeam: 'Chicago Bears',
        gameTime: DateTime.now(),
        status: 'scheduled',
        venue: 'Lambeau Field', // Outdoor venue
        odds: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GameDetailsScreen(
            gameId: testGame.id,
            sport: 'NFL',
            gameData: testGame,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should not crash even without weather data
      expect(tester.takeException(), isNull);
    });

    testWidgets('Should handle missing leaders data', (WidgetTester tester) async {
      final testGame = GameModel(
        id: 'test-nfl-game-4',
        sport: 'NFL',
        homeTeam: 'Kansas City Chiefs',
        awayTeam: 'Las Vegas Raiders',
        gameTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'final',
        venue: 'Arrowhead Stadium',
        odds: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GameDetailsScreen(
            gameId: testGame.id,
            sport: 'NFL',
            gameData: testGame,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Should not crash even without leaders data
      expect(tester.takeException(), isNull);
    });

    test('NFL game model should handle null ESPN ID', () {
      final game = GameModel(
        id: 'test-game',
        sport: 'NFL',
        homeTeam: 'Team A',
        awayTeam: 'Team B',
        gameTime: DateTime.now(),
        status: 'scheduled',
        espnId: null, // Explicitly null ESPN ID
      );

      expect(game.espnId, isNull);
      expect(game.sport, equals('NFL'));
      expect(() => game.toJson(), returnsNormally);
    });

    test('NFL game model should serialize with missing optional fields', () {
      final game = GameModel(
        id: 'minimal-game',
        sport: 'NFL',
        homeTeam: 'Home',
        awayTeam: 'Away',
        gameTime: DateTime.now(),
        status: 'scheduled',
        // No venue, odds, or other optional fields
      );

      final json = game.toJson();
      expect(json['id'], equals('minimal-game'));
      expect(json['sport'], equals('NFL'));
      expect(json['venue'], isNull);
      expect(json['odds'], isEmpty);
    });
  });
}