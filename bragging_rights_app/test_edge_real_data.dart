import 'package:flutter/material.dart';
import 'lib/services/edge/sports/espn_nba_service.dart';
import 'lib/services/edge/news/news_api_service.dart';
import 'lib/services/edge/social/reddit_service.dart';

void main() async {
  print('🏀 Testing Edge Real Data Integration...\n');
  
  // Test ESPN NBA Service
  print('1. Testing ESPN NBA Service...');
  final espnService = EspnNbaService();
  try {
    final scoreboard = await espnService.getTodaysGames();
    if (scoreboard != null && scoreboard.events.isNotEmpty) {
      print('✅ ESPN API Working!');
      print('   Found ${scoreboard.events.length} games today');
      
      final firstGame = scoreboard.events.first;
      final competitions = firstGame['competitions'] as List? ?? [];
      if (competitions.isNotEmpty) {
        final competition = competitions.first;
        final competitors = competition['competitors'] as List? ?? [];
        
        for (final competitor in competitors) {
          final team = competitor['team'] ?? {};
          final isHome = competitor['homeAway'] == 'home';
          print('   ${isHome ? "Home" : "Away"}: ${team['displayName']} - Score: ${competitor['score'] ?? '0'}');
        }
      }
    } else {
      print('⚠️  No games found today (might be off-season)');
    }
  } catch (e) {
    print('❌ ESPN Error: $e');
  }
  
  print('\n2. Testing NewsAPI Service...');
  final newsService = NewsApiService();
  try {
    final news = await newsService.getTeamNews(
      query: 'Lakers NBA',
      pageSize: 5,
    );
    if (news != null && news.articles.isNotEmpty) {
      print('✅ NewsAPI Working!');
      print('   Found ${news.articles.length} articles');
      for (var i = 0; i < news.articles.take(3).length; i++) {
        print('   ${i + 1}. ${news.articles[i].title}');
      }
    } else {
      print('⚠️  No news found');
    }
  } catch (e) {
    print('❌ NewsAPI Error: $e');
  }
  
  print('\n3. Testing Reddit Service...');
  final redditService = RedditService();
  try {
    final sentiment = await redditService.getTeamSentiment(
      teamName: 'Lakers',
      limit: 5,
    );
    if (sentiment.isNotEmpty) {
      print('✅ Reddit API Working!');
      print('   Sentiment: ${sentiment['overall'] ?? 'unknown'}');
      print('   Posts analyzed: ${sentiment['posts']?.length ?? 0}');
    } else {
      print('⚠️  No Reddit data found');
    }
  } catch (e) {
    print('❌ Reddit Error: $e');
  }
  
  print('\n✨ Edge Real Data Integration Complete!');
  print('📱 The Edge screen should now display real-time data when opened.');
}