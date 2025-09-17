import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/game_model.dart';
import '../../services/espn_id_resolver_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SoccerResolverTestScreen extends StatefulWidget {
  const SoccerResolverTestScreen({Key? key}) : super(key: key);

  @override
  State<SoccerResolverTestScreen> createState() => _SoccerResolverTestScreenState();
}

class _SoccerResolverTestScreenState extends State<SoccerResolverTestScreen> {
  final _resolver = EspnIdResolverService();
  String _output = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
    print(message);
  }

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _output = '';
    });

    _log('=== SOCCER ESPN RESOLVER TEST ===\n');

    // Test 1: Check what ESPN has
    await _checkEspnGames();

    // Test 2: Test our specific game
    await _testSpecificGame();

    // Test 3: Test matching logic
    await _testMatchingLogic();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _checkEspnGames() async {
    _log('STEP 1: Checking ESPN Premier League Games');
    _log('-' * 40);

    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard';
      _log('Fetching: $url\n');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        _log('✅ Found ${events.length} games on ESPN\n');

        for (int i = 0; i < events.length && i < 5; i++) {
          final event = events[i];
          final competition = event['competitions']?[0];
          final competitors = competition?['competitors'] as List? ?? [];

          if (competitors.length >= 2) {
            final home = competitors.firstWhere(
              (c) => c['homeAway'] == 'home',
              orElse: () => competitors[0],
            );
            final away = competitors.firstWhere(
              (c) => c['homeAway'] == 'away',
              orElse: () => competitors[1],
            );

            final homeTeam = home['team']?['displayName'] ?? 'Unknown';
            final awayTeam = away['team']?['displayName'] ?? 'Unknown';
            final espnId = event['id'];
            final date = event['date'] ?? '';

            _log('Game ${i + 1}:');
            _log('  ESPN ID: $espnId');
            _log('  Match: $awayTeam @ $homeTeam');
            _log('  Date: $date\n');

            // Check for Tottenham vs Brighton
            if (homeTeam.contains('Tottenham') || awayTeam.contains('Tottenham')) {
              _log('  🎯 Found Tottenham game!');
              _log('  Home: $homeTeam');
              _log('  Away: $awayTeam\n');
            }
            if (homeTeam.contains('Brighton') || awayTeam.contains('Brighton')) {
              _log('  🎯 Found Brighton game!');
              _log('  Home: $homeTeam');
              _log('  Away: $awayTeam\n');
            }
          }
        }
      } else {
        _log('❌ ESPN API returned status: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ Error fetching ESPN games: $e');
    }
  }

  Future<void> _testSpecificGame() async {
    _log('\nSTEP 2: Testing Tottenham vs Brighton Game');
    _log('-' * 40);

    try {
      // Create a test game model matching what we see in logs
      final testGame = GameModel(
        id: '1b8d93208f4fcd71338da8ddb4e9449c',
        sport: 'SOCCER',
        homeTeam: 'Tottenham Hotspur',
        awayTeam: 'Brighton and Hove Albion',
        gameTime: DateTime.now().add(Duration(days: 1)),
        status: 'scheduled',
        league: 'Premier League',
      );

      _log('Testing game:');
      _log('  Home: ${testGame.homeTeam}');
      _log('  Away: ${testGame.awayTeam}');
      _log('  Sport: ${testGame.sport}\n');

      // Try to resolve
      _log('Attempting to resolve ESPN ID...');
      final espnId = await _resolver.resolveEspnId(testGame);

      if (espnId != null) {
        _log('✅ ESPN ID resolved: $espnId');
      } else {
        _log('❌ Could not resolve ESPN ID');

        // Try with reversed teams
        _log('\nTrying with reversed teams...');
        final reversedGame = GameModel(
          id: '1b8d93208f4fcd71338da8ddb4e9449c_reversed',
          sport: 'SOCCER',
          homeTeam: 'Brighton and Hove Albion',
          awayTeam: 'Tottenham Hotspur',
          gameTime: DateTime.now().add(Duration(days: 1)),
          status: 'scheduled',
          league: 'Premier League',
        );

        final reversedEspnId = await _resolver.resolveEspnId(reversedGame);
        if (reversedEspnId != null) {
          _log('✅ ESPN ID resolved with reversed teams: $reversedEspnId');
          _log('⚠️ Teams might be reversed in our data!');
        } else {
          _log('❌ Still could not resolve with reversed teams');
        }
      }
    } catch (e) {
      _log('❌ Error testing specific game: $e');
    }
  }

  Future<void> _testMatchingLogic() async {
    _log('\nSTEP 3: Testing Matching Logic');
    _log('-' * 40);

    // Test various team name formats
    final testCases = [
      ['Tottenham Hotspur', 'Tottenham'],
      ['Brighton and Hove Albion', 'Brighton'],
      ['Brighton & Hove Albion', 'Brighton'],
      ['Manchester United', 'Man United'],
      ['Manchester City', 'Man City'],
    ];

    for (final test in testCases) {
      final input = test[0];
      final expected = test[1];
      final normalized = _normalizeTeamName(input);

      _log('Input: "$input"');
      _log('Normalized: "$normalized"');
      _log('Expected match: "$expected"');
      _log('Contains: ${normalized.contains(expected.toLowerCase())}\n');
    }
  }

  String _normalizeTeamName(String team) {
    return team
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soccer Resolver Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runTest,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isRunning)
              const LinearProgressIndicator()
            else
              ElevatedButton(
                onPressed: _runTest,
                child: const Text('Run Test Again'),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}