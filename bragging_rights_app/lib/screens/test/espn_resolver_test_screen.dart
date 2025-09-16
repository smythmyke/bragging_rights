import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/game_model.dart';
import '../../services/espn_id_resolver_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EspnResolverTestScreen extends StatefulWidget {
  const EspnResolverTestScreen({Key? key}) : super(key: key);

  @override
  State<EspnResolverTestScreen> createState() => _EspnResolverTestScreenState();
}

class _EspnResolverTestScreenState extends State<EspnResolverTestScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _resolver = EspnIdResolverService();

  String _output = '';
  bool _isRunning = false;
  GameModel? _testGame;
  String? _resolvedEspnId;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
  }

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _output = '';
    });

    _log('=== ESPN ID RESOLVER TEST ===\n');

    // Step 1: Find an MLB game with Odds API ID
    await _findTestGame();

    // Step 2: Test the resolver
    if (_testGame != null) {
      await _testResolver();
    }

    // Step 3: Verify ESPN API works
    if (_resolvedEspnId != null) {
      await _verifyEspnApi();
    }

    // Step 4: Show cached mappings
    await _showCachedMappings();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _findTestGame() async {
    _log('STEP 1: Finding MLB Game with Odds API ID');
    _log('-' * 40);

    try {
      // Query for MLB games
      final snapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: 'MLB')
          .limit(10)
          .get();

      _log('Found ${snapshot.docs.length} MLB games in Firestore\n');

      // Find a game with Odds API ID format
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = doc.id;

        // Check if it's an Odds API ID (32 char hex)
        if (id.length == 32 && RegExp(r'^[a-f0-9]+$').hasMatch(id)) {
          _testGame = GameModel.fromFirestore(doc);

          _log('✅ Found game with Odds API ID:');
          _log('  ID: $id');
          _log('  Teams: ${_testGame!.awayTeam} @ ${_testGame!.homeTeam}');
          _log('  ESPN ID: ${_testGame!.espnId ?? "NULL"}');
          _log('  Game Time: ${_testGame!.gameTime}');
          break;
        }
      }

      if (_testGame == null) {
        _log('❌ No games with Odds API IDs found');
        _log('All games might already have ESPN IDs');
      }
    } catch (e) {
      _log('❌ Error: $e');
    }

    _log('');
  }

  Future<void> _testResolver() async {
    _log('STEP 2: Testing ESPN ID Resolver');
    _log('-' * 40);

    if (_testGame == null) {
      _log('❌ No test game available');
      return;
    }

    _log('Resolving ESPN ID for game...');
    _log('  Current ESPN ID: ${_testGame!.espnId ?? "NULL"}');

    try {
      final startTime = DateTime.now();
      _resolvedEspnId = await _resolver.resolveEspnId(_testGame!);
      final duration = DateTime.now().difference(startTime);

      if (_resolvedEspnId != null) {
        _log('\n✅ ESPN ID RESOLVED!');
        _log('  ESPN ID: $_resolvedEspnId');
        _log('  Resolution time: ${duration.inMilliseconds}ms');
      } else {
        _log('\n❌ Could not resolve ESPN ID');
        _log('Possible reasons:');
        _log('  - Game not on today\'s ESPN scoreboard');
        _log('  - Team names don\'t match');
        _log('  - Game postponed/cancelled');
      }
    } catch (e) {
      _log('❌ Error: $e');
    }

    _log('');
  }

  Future<void> _verifyEspnApi() async {
    _log('STEP 3: Verifying ESPN API with Resolved ID');
    _log('-' * 40);

    if (_resolvedEspnId == null) {
      _log('❌ No ESPN ID to verify');
      return;
    }

    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=$_resolvedEspnId';
      _log('Testing: $url\n');

      final response = await http.get(Uri.parse(url));
      _log('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _log('✅ ESPN API call successful!');
        _log('\nAvailable data:');

        // List available sections
        for (final key in data.keys) {
          if (data[key] != null) {
            _log('  ✓ $key');
          }
        }

        // Check for box score
        if (data['boxscore'] != null) {
          final teams = data['boxscore']['teams'] as List? ?? [];
          _log('\nBox Score Teams:');
          for (final team in teams) {
            _log('  - ${team['team']['displayName']}');
          }
        }
      } else {
        _log('❌ ESPN API failed');
        _log('Response: ${response.body.substring(0, 200)}...');
      }
    } catch (e) {
      _log('❌ Error: $e');
    }

    _log('');
  }

  Future<void> _showCachedMappings() async {
    _log('STEP 4: Cached ID Mappings');
    _log('-' * 40);

    try {
      final snapshot = await _firestore
          .collection('id_mappings')
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        _log('No cached mappings found yet');
      } else {
        _log('Found ${snapshot.docs.length} cached mappings:\n');

        for (final doc in snapshot.docs) {
          final data = doc.data();
          _log('Mapping:');
          _log('  Odds API ID: ${data['oddsApiId']}');
          _log('  ESPN ID: ${data['espnId']}');
          _log('  Sport: ${data['sport']}');
          _log('  Teams: ${data['awayTeam']} @ ${data['homeTeam']}');
          _log('');
        }
      }
    } catch (e) {
      _log('Error checking mappings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESPN ID Resolver Test'),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runTest,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _resolver.clearCache();
              setState(() {
                _output = 'Cache cleared!\n';
              });
            },
            tooltip: 'Clear Cache',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRunning) const LinearProgressIndicator(),

          // Test Results
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Summary',
                  style: TextStyle(
                    color: Colors.yellow[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (_testGame != null) ...[
                  Text(
                    'Test Game: ${_testGame!.awayTeam} @ ${_testGame!.homeTeam}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Odds API ID: ${_testGame!.id.substring(0, 8)}...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_resolvedEspnId != null)
                    Text(
                      'ESPN ID: $_resolvedEspnId ✅',
                      style: const TextStyle(color: Colors.green),
                    )
                  else
                    const Text(
                      'ESPN ID: Not resolved ❌',
                      style: TextStyle(color: Colors.red),
                    ),
                ] else
                  const Text(
                    'No test game found',
                    style: TextStyle(color: Colors.orange),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}