import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/optimized_games_service.dart';
import '../../models/game_model.dart';

class MlbDebugScreen extends StatefulWidget {
  const MlbDebugScreen({Key? key}) : super(key: key);

  @override
  State<MlbDebugScreen> createState() => _MlbDebugScreenState();
}

class _MlbDebugScreenState extends State<MlbDebugScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _optimizedService = OptimizedGamesService();

  String _debugOutput = 'Starting MLB Debug Tests...\n\n';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runAllTests();
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _debugOutput = 'Starting MLB Debug Tests...\n\n';
    });

    await _testFirestoreGames();
    await _testEspnApi();
    await _testCacheClear();
    await _testFreshFetch();

    _addOutput('\n=== TEST COMPLETE ===\n');

    setState(() {
      _isRunning = false;
    });
  }

  void _addOutput(String text) {
    setState(() {
      _debugOutput += text;
    });
  }

  Future<void> _testFirestoreGames() async {
    _addOutput('TEST 1: Check Firestore MLB Games\n');
    _addOutput('-' * 40 + '\n');

    try {
      // Query MLB games from Firestore
      final snapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: 'MLB')
          .limit(5)
          .get();

      _addOutput('Found ${snapshot.docs.length} MLB games in Firestore\n\n');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        _addOutput('Game ID: ${doc.id}\n');
        _addOutput('  ESPN ID: ${data['espnId'] ?? 'NULL'}\n');
        _addOutput('  Teams: ${data['awayTeam']} @ ${data['homeTeam']}\n');

        // Check ID format
        if (doc.id.startsWith('b57e') || doc.id.length == 32) {
          _addOutput('  ⚠️ OLD FORMAT ID DETECTED!\n');
        } else if (doc.id.contains('mlb_')) {
          _addOutput('  ✅ New format with ESPN ID\n');
        }

        _addOutput('\n');
      }
    } catch (e) {
      _addOutput('❌ Error: $e\n');
    }

    _addOutput('\n');
  }

  Future<void> _testEspnApi() async {
    _addOutput('TEST 2: ESPN API Direct Test\n');
    _addOutput('-' * 40 + '\n');

    try {
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        _addOutput('ESPN API returned ${events.length} games\n\n');

        if (events.isNotEmpty) {
          final firstGame = events[0];
          _addOutput('First game from ESPN:\n');
          _addOutput('  ESPN ID: ${firstGame['id']}\n');
          _addOutput('  Type: ${firstGame['id'].runtimeType}\n');
          _addOutput('  Name: ${firstGame['name']}\n\n');

          // Look for Braves vs Nationals
          for (final event in events) {
            final name = event['name'] ?? '';
            if (name.contains('Braves') && name.contains('Nationals')) {
              _addOutput('Found Braves vs Nationals:\n');
              _addOutput('  ESPN ID: ${event['id']}\n');
              _addOutput('  This should be used for API calls\n');
              break;
            }
          }
        }
      } else {
        _addOutput('❌ API returned status ${response.statusCode}\n');
      }
    } catch (e) {
      _addOutput('❌ Error: $e\n');
    }

    _addOutput('\n');
  }

  Future<void> _testCacheClear() async {
    _addOutput('TEST 3: Clear MLB Cache\n');
    _addOutput('-' * 40 + '\n');

    try {
      _addOutput('Clearing MLB cache...\n');
      await _optimizedService.clearSportCache('MLB');
      _addOutput('✅ Cache cleared successfully\n');

      // Check if games still exist
      final snapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: 'MLB')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _addOutput('✅ All MLB games removed from Firestore\n');
      } else {
        _addOutput('⚠️ ${snapshot.docs.length} games still in Firestore\n');
      }
    } catch (e) {
      _addOutput('❌ Error: $e\n');
    }

    _addOutput('\n');
  }

  Future<void> _testFreshFetch() async {
    _addOutput('TEST 4: Fetch Fresh MLB Games\n');
    _addOutput('-' * 40 + '\n');

    try {
      _addOutput('Fetching fresh games from ESPN...\n');
      final games = await _optimizedService.loadAllGamesForSport('MLB');

      _addOutput('Fetched ${games.length} MLB games\n\n');

      if (games.isNotEmpty) {
        final firstGame = games[0];
        _addOutput('First game details:\n');
        _addOutput('  Internal ID: ${firstGame.id}\n');
        _addOutput('  ESPN ID: ${firstGame.espnId ?? 'NULL'}\n');
        _addOutput('  Teams: ${firstGame.awayTeam} @ ${firstGame.homeTeam}\n');

        if (firstGame.espnId != null) {
          _addOutput('  ✅ ESPN ID is present!\n');
        } else {
          _addOutput('  ❌ ESPN ID is missing!\n');
        }

        // Check for Braves vs Nationals
        final bravesGame = games.firstWhere(
          (g) => g.homeTeam.contains('Nationals') && g.awayTeam.contains('Braves'),
          orElse: () => games[0],
        );

        if (bravesGame.homeTeam.contains('Nationals')) {
          _addOutput('\nBraves vs Nationals game:\n');
          _addOutput('  Internal ID: ${bravesGame.id}\n');
          _addOutput('  ESPN ID: ${bravesGame.espnId ?? 'NULL'}\n');
        }
      }
    } catch (e) {
      _addOutput('❌ Error: $e\n');
    }

    _addOutput('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLB Debug Test'),
        backgroundColor: Colors.red[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runAllTests,
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            if (_isRunning)
              const LinearProgressIndicator(
                backgroundColor: Colors.red,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _debugOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIAGNOSIS:',
                    style: TextStyle(
                      color: Colors.yellow[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Old IDs (b57e...) are from cached data\n'
                    '• ESPN returns numeric IDs (401697155)\n'
                    '• Solution: Clear cache and fetch fresh',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}