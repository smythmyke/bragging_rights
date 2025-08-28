// Test Edge APIs - Run with: flutter run lib/test_edge_apis.dart
import 'package:flutter/material.dart';
import 'services/edge/sports/espn_nba_service.dart';
import 'services/edge/news/news_api_service.dart';
import 'services/edge/social/reddit_service.dart';

void main() {
  runApp(EdgeApiTestApp());
}

class EdgeApiTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge API Test',
      theme: ThemeData.dark(),
      home: EdgeApiTestScreen(),
    );
  }
}

class EdgeApiTestScreen extends StatefulWidget {
  @override
  _EdgeApiTestScreenState createState() => _EdgeApiTestScreenState();
}

class _EdgeApiTestScreenState extends State<EdgeApiTestScreen> {
  final EspnNbaService _espnService = EspnNbaService();
  final NewsApiService _newsService = NewsApiService();
  final RedditService _redditService = RedditService();
  
  String _testResults = 'Press button to test APIs...';
  bool _testing = false;

  Future<void> _testApis() async {
    setState(() {
      _testing = true;
      _testResults = 'Testing APIs...\n';
    });
    
    String results = '🏀 Edge Real Data Integration Test\n\n';
    
    // Test ESPN
    results += '1. ESPN NBA API:\n';
    try {
      final scoreboard = await _espnService.getTodaysGames();
      if (scoreboard != null && scoreboard.events.isNotEmpty) {
        results += '   ✅ Working! Found ${scoreboard.events.length} games\n';
        final firstGame = scoreboard.events.first;
        results += '   Game ID: ${firstGame['id']}\n';
      } else {
        results += '   ⚠️ No games today\n';
      }
    } catch (e) {
      results += '   ❌ Error: $e\n';
    }
    
    // Test NewsAPI
    results += '\n2. NewsAPI:\n';
    try {
      final news = await _newsService.getTeamNews(
        query: 'NBA Lakers',
        pageSize: 3,
      );
      if (news != null && news.articles.isNotEmpty) {
        results += '   ✅ Working! Found ${news.articles.length} articles\n';
        results += '   Latest: ${news.articles.first.title}\n';
      } else {
        results += '   ⚠️ No news found\n';
      }
    } catch (e) {
      results += '   ❌ Error: $e\n';
    }
    
    // Test Reddit
    results += '\n3. Reddit API:\n';
    try {
      final sentiment = await _redditService.getTeamSentiment(
        teamName: 'Lakers',
        limit: 5,
      );
      if (sentiment.isNotEmpty) {
        results += '   ✅ Working!\n';
        results += '   Sentiment: ${sentiment['overall'] ?? 'unknown'}\n';
      } else {
        results += '   ⚠️ No Reddit data\n';
      }
    } catch (e) {
      results += '   ❌ Error: $e\n';
    }
    
    results += '\n✨ Test Complete!';
    
    setState(() {
      _testing = false;
      _testResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edge API Integration Test'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _testing ? null : _testApis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(_testing ? 'Testing...' : 'Test All APIs'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.purple),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white,
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