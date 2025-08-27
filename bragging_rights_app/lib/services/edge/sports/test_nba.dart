import 'package:flutter/foundation.dart';
import 'nba_service.dart';

/// Test NBA API Integration
class TestNbaIntegration {
  final NbaService _nbaService = NbaService();

  /// Run all NBA tests
  Future<void> runTests() async {
    debugPrint('🏀 Starting NBA API Integration Tests...\n');
    
    await testTodaysGames();
    await testBoxScore();
    await testTeamStats();
    await testPlayerStats();
    await testStandings();
    await testGameIntelligence();
    
    debugPrint('\n✅ NBA API Integration Tests Complete!');
  }

  /// Test fetching today's games
  Future<void> testTodaysGames() async {
    debugPrint('📅 Testing Today\'s Games...');
    
    try {
      final games = await _nbaService.getTodaysGames();
      
      if (games != null) {
        debugPrint('✅ Found ${games.games.length} games today');
        
        for (final game in games.games) {
          debugPrint('  🏀 ${game.awayTeam['teamName']} @ ${game.homeTeam['teamName']}');
          debugPrint('     Status: ${game.gameStatus} - ${game.gameClock}');
          debugPrint('     Game ID: ${game.gameId}');
        }
      } else {
        debugPrint('⚠️ No games data returned');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test fetching box score
  Future<void> testBoxScore() async {
    debugPrint('\n📊 Testing Box Score...');
    
    try {
      // Use a sample game ID (you'll need a real one)
      const gameId = '0022400001';
      
      final boxScore = await _nbaService.getBoxScore(gameId);
      
      if (boxScore != null) {
        debugPrint('✅ Box Score retrieved for game: ${boxScore.gameId}');
        debugPrint('  Home Team Stats: ${boxScore.homeTeamStats['teamName']}');
        debugPrint('  Away Team Stats: ${boxScore.awayTeamStats['teamName']}');
        debugPrint('  Players tracked: ${boxScore.homePlayerStats.length + boxScore.awayPlayerStats.length}');
      } else {
        debugPrint('⚠️ No box score data (game may not have started)');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test fetching team stats
  Future<void> testTeamStats() async {
    debugPrint('\n📈 Testing Team Stats...');
    
    try {
      final stats = await _nbaService.getTeamStats();
      
      if (stats != null) {
        debugPrint('✅ Team stats retrieved');
        debugPrint('  Teams with data: ${stats.teams.length}');
        
        if (stats.teams.isNotEmpty) {
          final topTeam = stats.teams.first;
          debugPrint('  Top team data: $topTeam');
        }
      } else {
        debugPrint('⚠️ No team stats data');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test fetching player stats
  Future<void> testPlayerStats() async {
    debugPrint('\n👤 Testing Player Stats...');
    
    try {
      final stats = await _nbaService.getPlayerStats();
      
      if (stats != null) {
        debugPrint('✅ Player stats retrieved');
        debugPrint('  Players with data: ${stats.players.length}');
        
        if (stats.players.isNotEmpty) {
          final topPlayer = stats.players.first;
          debugPrint('  Top player data sample: $topPlayer');
        }
      } else {
        debugPrint('⚠️ No player stats data');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test fetching standings
  Future<void> testStandings() async {
    debugPrint('\n🏆 Testing Standings...');
    
    try {
      final standings = await _nbaService.getStandings();
      
      if (standings != null) {
        debugPrint('✅ Standings retrieved');
        debugPrint('  Teams in standings: ${standings.standings.length}');
        
        if (standings.standings.isNotEmpty) {
          final topTeam = standings.standings.first;
          debugPrint('  League leader: $topTeam');
        }
      } else {
        debugPrint('⚠️ No standings data');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test game intelligence generation
  Future<void> testGameIntelligence() async {
    debugPrint('\n🧠 Testing Game Intelligence...');
    
    try {
      // Sample game data
      final intelligence = await _nbaService.getGameIntelligence(
        gameId: '0022400001',
        homeTeam: 'Lakers',
        awayTeam: 'Warriors',
      );
      
      debugPrint('✅ Intelligence generated:');
      debugPrint('  Game ID: ${intelligence['gameId']}');
      debugPrint('  Analysis categories: ${intelligence['analysis'].keys.toList()}');
      debugPrint('  Key factors: ${intelligence['keyFactors'].length}');
      debugPrint('  Predictions available: ${intelligence['predictions'].isNotEmpty}');
      
      // Show key factors
      for (final factor in intelligence['keyFactors']) {
        debugPrint('  📌 ${factor['type']}: ${factor['insights']}');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Test with specific date
  Future<void> testSpecificDate(DateTime date) async {
    debugPrint('\n📅 Testing Games for ${date.toString().split(' ')[0]}...');
    
    try {
      final games = await _nbaService.getGamesForDate(date);
      
      if (games != null && games.games.isNotEmpty) {
        debugPrint('✅ Found ${games.games.length} games');
        
        for (final game in games.games) {
          debugPrint('  🏀 ${game.awayTeam['teamTricode']} @ ${game.homeTeam['teamTricode']}');
        }
      } else {
        debugPrint('⚠️ No games on this date');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }
}