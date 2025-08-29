import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/cloud_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(CloudFunctionTestApp());
}

class CloudFunctionTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Functions Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final CloudApiService _cloudApi = CloudApiService();
  final List<String> _results = [];
  bool _isLoading = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _results.add('🔐 Signing in...');
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _user = userCredential.user;
        _results.add('✅ Authenticated as: ${_user!.uid}');
        _isLoading = false;
      });
      _runTests();
    } catch (e) {
      setState(() {
        _results.add('❌ Authentication failed: $e');
        _isLoading = false;
      });
    }
  }

  Future<void> _runTests() async {
    setState(() => _isLoading = true);

    // Test NBA API
    await _testNBA();
    
    // Test NHL API
    await _testNHL();
    
    // Test ESPN API
    await _testESPN();
    
    // Test Odds API
    await _testOdds();
    
    // Test News API
    await _testNews();

    setState(() {
      _isLoading = false;
      _results.add('\n✅ All tests complete!');
    });
  }

  Future<void> _testNBA() async {
    setState(() => _results.add('\n🏀 Testing NBA API...'));
    try {
      final games = await _cloudApi.getNBAGames(season: 2024, perPage: 5);
      setState(() {
        _results.add('✅ NBA: Found ${games['meta']?['total_count']} games');
      });
    } catch (e) {
      setState(() => _results.add('❌ NBA failed: $e'));
    }
  }

  Future<void> _testNHL() async {
    setState(() => _results.add('\n🏒 Testing NHL API...'));
    try {
      final schedule = await _cloudApi.getNHLSchedule();
      setState(() {
        _results.add('✅ NHL: Schedule retrieved');
      });
    } catch (e) {
      setState(() => _results.add('❌ NHL failed: $e'));
    }
  }

  Future<void> _testESPN() async {
    setState(() => _results.add('\n🏈 Testing ESPN API...'));
    try {
      final scoreboard = await _cloudApi.getESPNScoreboard(sport: 'nfl');
      final events = scoreboard['events'] ?? [];
      setState(() {
        _results.add('✅ ESPN: Found ${events.length} NFL games');
      });
    } catch (e) {
      setState(() => _results.add('❌ ESPN failed: $e'));
    }
  }

  Future<void> _testOdds() async {
    setState(() => _results.add('\n💰 Testing Odds API...'));
    try {
      final oddsData = await _cloudApi.getOdds(sport: 'basketball_nba');
      final odds = oddsData['odds'] as List;
      final quota = oddsData['quota'];
      setState(() {
        _results.add('✅ Odds: ${odds.length} games');
        _results.add('   Quota: ${quota['used']} used, ${quota['remaining']} remaining');
      });
    } catch (e) {
      setState(() => _results.add('❌ Odds failed: $e'));
    }
  }

  Future<void> _testNews() async {
    setState(() => _results.add('\n📰 Testing News API...'));
    try {
      final news = await _cloudApi.getSportsNews(sport: 'NBA', query: 'Lakers');
      final articles = news['articles'] as List;
      setState(() {
        _results.add('✅ News: Found ${articles.length} articles');
        if (articles.isNotEmpty) {
          _results.add('   Latest: ${articles[0]['title']}');
        }
      });
    } catch (e) {
      setState(() => _results.add('❌ News failed: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cloud Functions Test'),
        actions: [
          if (_user != null)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                Color? color;
                if (result.contains('✅')) color = Colors.green;
                if (result.contains('❌')) color = Colors.red;
                if (result.contains('🏀') || result.contains('🏒') || 
                    result.contains('🏈') || result.contains('💰') || 
                    result.contains('📰')) color = Colors.blue;
                
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontWeight: result.contains('\n') ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () {
          setState(() => _results.clear());
          _runTests();
        },
        child: Icon(Icons.refresh),
        tooltip: 'Run Tests Again',
      ),
    );
  }
}