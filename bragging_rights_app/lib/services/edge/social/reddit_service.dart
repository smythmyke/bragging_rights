import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';

/// Reddit Service for Social Sentiment Analysis
/// Uses public Reddit JSON API (no auth required for read-only)
class RedditService {
  final EventMatcher _matcher = EventMatcher();
  
  static const String _baseUrl = 'https://www.reddit.com';
  
  // Sports subreddits
  static const Map<String, String> _sportsSubs = {
    'nba': 'nba',
    'nfl': 'nfl',
    'mlb': 'baseball',
    'nhl': 'hockey',
    'soccer': 'soccer',
    'mma': 'MMA',
    'ufc': 'ufc',
    'boxing': 'Boxing',
    'bellator': 'bellator',
    'onefc': 'ONEHQ',
    'pfl': 'PFLmma',
    'bkfc': 'bareknuckleboxing',
    'tennis': 'tennis',
  };

  // Team-specific subreddits
  static const Map<String, String> _teamSubs = {
    // NBA Teams
    'Los Angeles Lakers': 'lakers',
    'Boston Celtics': 'bostonceltics',
    'Golden State Warriors': 'warriors',
    'Brooklyn Nets': 'GoNets',
    'New York Knicks': 'NYKnicks',
    'Philadelphia 76ers': 'sixers',
    'Miami Heat': 'heat',
    'Milwaukee Bucks': 'MkeBucks',
    'Phoenix Suns': 'suns',
    'Denver Nuggets': 'denvernuggets',
    
    // NFL Teams
    'New England Patriots': 'Patriots',
    'Kansas City Chiefs': 'KansasCityChiefs',
    'Buffalo Bills': 'buffalobills',
    'Dallas Cowboys': 'cowboys',
    'Green Bay Packers': 'GreenBayPackers',
    
    // Add more teams as needed
  };

  /// Get game thread for a specific matchup
  Future<RedditGameThread?> getGameThread({
    required String homeTeam,
    required String awayTeam,
    required String sport,
    DateTime? gameDate,
  }) async {
    try {
      debugPrint('🔍 Searching for Reddit game thread: $homeTeam vs $awayTeam');
      
      final subreddit = _sportsSubs[sport.toLowerCase()] ?? 'sports';
      final searchQuery = _buildSearchQuery(homeTeam, awayTeam, gameDate);
      
      // Search for game thread
      final url = '$_baseUrl/r/$subreddit/search.json'
          '?q=$searchQuery&restrict_sr=on&sort=relevance&t=day&limit=5';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        // Find the most relevant game thread
        for (final post in posts) {
          final postData = post['data'];
          if (_isGameThread(postData, homeTeam, awayTeam)) {
            return await _analyzeGameThread(postData);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching game thread: $e');
    }
    return null;
  }

  /// Get sentiment from team subreddits
  Future<Map<String, dynamic>> getTeamSentiment({
    required String teamName,
    int limit = 25,
  }) async {
    try {
      final subreddit = _teamSubs[teamName] ?? _getTeamSubreddit(teamName);
      debugPrint('📊 Analyzing r/$subreddit sentiment...');
      
      final url = '$_baseUrl/r/$subreddit/hot.json?limit=$limit';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        return _analyzeSentiment(posts);
      }
    } catch (e) {
      debugPrint('Error fetching team sentiment: $e');
    }
    
    return {'sentiment': 'unknown', 'confidence': 0.0};
  }

  /// Get trending topics from sports subreddit
  Future<List<String>> getTrendingTopics(String sport) async {
    final topics = <String>[];
    
    try {
      final subreddit = _sportsSubs[sport.toLowerCase()] ?? 'sports';
      final url = '$_baseUrl/r/$subreddit/hot.json?limit=10';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        for (final post in posts) {
          final title = post['data']['title'] as String;
          final flair = post['data']['link_flair_text'] ?? '';
          
          if (flair.isNotEmpty && !topics.contains(flair)) {
            topics.add(flair);
          }
          
          // Extract key phrases from titles
          final keyPhrases = _extractKeyPhrases(title);
          topics.addAll(keyPhrases);
        }
      }
    } catch (e) {
      debugPrint('Error fetching trending topics: $e');
    }
    
    return topics.take(10).toList();
  }

  /// Get MMA/Combat sports fight card discussion
  Future<Map<String, dynamic>> getFightCardIntelligence({
    required String eventName,
    required String mainEvent,
    String? promotion,
  }) async {
    debugPrint('🥊 Gathering Reddit intelligence for $eventName');
    
    final intelligence = <String, dynamic>{
      'eventThread': null,
      'fighterSentiment': {},
      'predictions': [],
      'trendingTopics': [],
      'fanExcitement': 0.0,
      'keyDiscussions': [],
    };

    try {
      final subreddit = promotion != null 
          ? (_sportsSubs[promotion.toLowerCase()] ?? 'MMA')
          : 'MMA';
      
      // Search for event discussion
      final searchQuery = Uri.encodeComponent(eventName);
      final url = '$_baseUrl/r/$subreddit/search.json'
          '?q=$searchQuery&restrict_sr=on&sort=relevance&t=week&limit=10';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        // Analyze event discussions
        for (final post in posts) {
          final postData = post['data'];
          final title = postData['title'].toString().toLowerCase();
          
          if (title.contains('thread') || title.contains('discussion') ||
              title.contains('prediction') || title.contains('breakdown')) {
            intelligence['eventThread'] = {
              'title': postData['title'],
              'url': 'https://reddit.com${postData['permalink']}',
              'score': postData['score'],
              'comments': postData['num_comments'],
            };
            
            // Extract predictions and sentiment
            if (title.contains('prediction')) {
              intelligence['predictions'].add({
                'source': postData['title'],
                'upvotes': postData['score'],
              });
            }
          }
        }
        
        // Calculate fan excitement based on engagement
        int totalScore = 0;
        int totalComments = 0;
        for (final post in posts) {
          totalScore += (post['data']['score'] ?? 0) as int;
          totalComments += (post['data']['num_comments'] ?? 0) as int;
        }
        intelligence['fanExcitement'] = _calculateExcitement(totalScore, totalComments);
      }
      
      // Get fighter-specific sentiment
      final fighters = mainEvent.split(' vs ').map((f) => f.trim()).toList();
      if (fighters.length >= 2) {
        intelligence['fighterSentiment'] = await _getFighterSentiment(
          fighters[0], 
          fighters[1],
          subreddit,
        );
      }
      
      // Get MMA betting sentiment
      await _getMmaBettingSentiment(eventName, intelligence);
      
    } catch (e) {
      debugPrint('Error gathering fight card intelligence: $e');
    }
    
    return intelligence;
  }

  /// Get fighter-specific sentiment
  Future<Map<String, dynamic>> _getFighterSentiment(
    String fighter1,
    String fighter2,
    String subreddit,
  ) async {
    final sentiment = <String, dynamic>{
      fighter1: {'positive': 0, 'negative': 0, 'mentions': 0},
      fighter2: {'positive': 0, 'negative': 0, 'mentions': 0},
    };
    
    try {
      // Search for fighter discussions
      final searchQuery = Uri.encodeComponent('$fighter1 OR $fighter2');
      final url = '$_baseUrl/r/$subreddit/search.json'
          '?q=$searchQuery&restrict_sr=on&sort=new&t=week&limit=25';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        for (final post in posts) {
          final title = post['data']['title'].toString();
          final body = post['data']['selftext'].toString();
          final content = '$title $body'.toLowerCase();
          
          // Analyze sentiment for each fighter
          for (final fighter in [fighter1, fighter2]) {
            if (content.contains(fighter.toLowerCase())) {
              sentiment[fighter]['mentions']++;
              
              // Check for positive/negative sentiment
              if (_containsPositiveFightPrediction(content, fighter)) {
                sentiment[fighter]['positive']++;
              } else if (_containsNegativeFightPrediction(content, fighter)) {
                sentiment[fighter]['negative']++;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error analyzing fighter sentiment: $e');
    }
    
    return sentiment;
  }

  /// Get MMA betting subreddit sentiment
  Future<void> _getMmaBettingSentiment(
    String eventName,
    Map<String, dynamic> intelligence,
  ) async {
    try {
      final searchQuery = Uri.encodeComponent(eventName);
      final url = '$_baseUrl/r/mmabetting/search.json'
          '?q=$searchQuery&restrict_sr=on&sort=relevance&t=week&limit=10';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        final bettingInsights = <String>[];
        for (final post in posts) {
          final title = post['data']['title'] ?? '';
          if (title.toLowerCase().contains('parlay') ||
              title.toLowerCase().contains('pick') ||
              title.toLowerCase().contains('bet')) {
            bettingInsights.add(title);
          }
        }
        
        intelligence['bettingInsights'] = bettingInsights;
      }
    } catch (e) {
      debugPrint('Error fetching MMA betting sentiment: $e');
    }
  }

  /// Check for positive fight predictions
  bool _containsPositiveFightPrediction(String text, String fighter) {
    final fighterLower = fighter.toLowerCase();
    final positive = [
      '$fighterLower wins',
      '$fighterLower by',
      '$fighterLower ko',
      '$fighterLower tko',
      '$fighterLower submission',
      '$fighterLower decision',
      'bet on $fighterLower',
      '$fighterLower will win',
      '$fighterLower is going to',
    ];
    return positive.any((phrase) => text.contains(phrase));
  }

  /// Check for negative fight predictions
  bool _containsNegativeFightPrediction(String text, String fighter) {
    final fighterLower = fighter.toLowerCase();
    final negative = [
      '$fighterLower loses',
      '$fighterLower gets',
      'against $fighterLower',
      '$fighterLower is done',
      '$fighterLower will lose',
      'fade $fighterLower',
      '$fighterLower overrated',
    ];
    return negative.any((phrase) => text.contains(phrase));
  }

  /// Calculate excitement level
  double _calculateExcitement(int totalScore, int totalComments) {
    // Normalize scores to 0-1 range
    final scoreExcitement = (totalScore / 1000).clamp(0.0, 1.0);
    final commentExcitement = (totalComments / 500).clamp(0.0, 1.0);
    
    // Weight comments more heavily for fight cards
    return (scoreExcitement * 0.3 + commentExcitement * 0.7);
  }

  /// Get comprehensive Reddit intelligence for a game
  Future<Map<String, dynamic>> getGameIntelligence({
    required String homeTeam,
    required String awayTeam,
    required String sport,
    DateTime? gameDate,
  }) async {
    debugPrint('🔴 Gathering Reddit intelligence for $homeTeam vs $awayTeam');
    
    final intelligence = <String, dynamic>{
      'gameThread': null,
      'homeSentiment': {},
      'awaySentiment': {},
      'trendingTopics': [],
      'fanConfidence': {},
      'keyDiscussions': [],
    };

    // Fetch data in parallel
    final futures = <Future>[];

    // Get game thread
    futures.add(getGameThread(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      sport: sport,
      gameDate: gameDate,
    ).then((thread) {
      if (thread != null) {
        intelligence['gameThread'] = thread.toMap();
      }
    }));

    // Get team sentiments
    futures.add(getTeamSentiment(teamName: homeTeam).then((sentiment) {
      intelligence['homeSentiment'] = sentiment;
    }));

    futures.add(getTeamSentiment(teamName: awayTeam).then((sentiment) {
      intelligence['awaySentiment'] = sentiment;
    }));

    // Get trending topics
    futures.add(getTrendingTopics(sport).then((topics) {
      intelligence['trendingTopics'] = topics;
    }));

    await Future.wait(futures);

    // Calculate fan confidence
    intelligence['fanConfidence'] = _calculateFanConfidence(intelligence);

    return intelligence;
  }

  /// Build search query for game threads
  String _buildSearchQuery(String homeTeam, String awayTeam, DateTime? date) {
    final home = _getTeamAbbreviation(homeTeam);
    final away = _getTeamAbbreviation(awayTeam);
    
    String query = 'Game Thread $home $away OR "$homeTeam" "$awayTeam"';
    
    if (date != null) {
      final dateStr = '${date.month}/${date.day}';
      query += ' $dateStr';
    }
    
    return Uri.encodeComponent(query);
  }

  /// Check if post is a game thread
  bool _isGameThread(Map<String, dynamic> post, String home, String away) {
    final title = post['title'].toString().toLowerCase();
    final homeNorm = home.toLowerCase();
    final awayNorm = away.toLowerCase();
    
    // Check for game thread indicators
    final isThread = title.contains('game thread') ||
                     title.contains('game day') ||
                     title.contains('gamethread');
    
    // Check for team mentions
    final hasTeams = (title.contains(homeNorm) || 
                      title.contains(_getTeamAbbreviation(home).toLowerCase())) &&
                     (title.contains(awayNorm) || 
                      title.contains(_getTeamAbbreviation(away).toLowerCase()));
    
    return isThread || hasTeams;
  }

  /// Get tennis match discussion from Reddit
  Future<Map<String, dynamic>?> getTennisDiscussion({
    required String player1,
    required String player2,
  }) async {
    try {
      // Search r/tennis for discussion about this match
      final searchQuery = Uri.encodeComponent('$player1 $player2');
      final url = '$_baseUrl/r/tennis/search.json?q=$searchQuery&sort=relevance&t=week&limit=10';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );
      
      if (response.statusCode != 200) {
        debugPrint('Failed to fetch tennis discussion: ${response.statusCode}');
        return null;
      }
      
      final data = json.decode(response.body);
      final posts = data['data']['children'] as List;
      
      if (posts.isEmpty) {
        return {
          'discussionFound': false,
          'sentiment': 'neutral',
        };
      }
      
      // Analyze posts for sentiment
      final sentiment = _analyzeSentiment(posts);
      
      // Find most relevant discussion
      Map<String, dynamic>? mainDiscussion;
      for (final post in posts) {
        final postData = post['data'];
        final title = postData['title'].toString().toLowerCase();
        if (title.contains(player1.toLowerCase()) && 
            title.contains(player2.toLowerCase())) {
          mainDiscussion = {
            'title': postData['title'],
            'url': 'https://reddit.com${postData['permalink']}',
            'score': postData['score'],
            'comments': postData['num_comments'],
          };
          break;
        }
      }
      
      // Determine community prediction
      String? communityPrediction;
      int player1Mentions = 0;
      int player2Mentions = 0;
      
      for (final post in posts) {
        final text = post['data']['title'].toString() + 
                    (post['data']['selftext'] ?? '').toString();
        if (text.toLowerCase().contains(player1.toLowerCase())) player1Mentions++;
        if (text.toLowerCase().contains(player2.toLowerCase())) player2Mentions++;
      }
      
      if (player1Mentions > player2Mentions * 1.3) {
        communityPrediction = player1;
      } else if (player2Mentions > player1Mentions * 1.3) {
        communityPrediction = player2;
      }
      
      return {
        'discussionFound': true,
        'sentiment': sentiment,
        'mainDiscussion': mainDiscussion,
        'communityPrediction': communityPrediction,
        'player1Mentions': player1Mentions,
        'player2Mentions': player2Mentions,
        'totalPosts': posts.length,
      };
      
    } catch (e) {
      debugPrint('Error fetching tennis discussion: $e');
      return null;
    }
  }

  /// Analyze a game thread for insights
  Future<RedditGameThread> _analyzeGameThread(Map<String, dynamic> post) async {
    final thread = RedditGameThread(
      id: post['id'],
      title: post['title'],
      url: 'https://reddit.com${post['permalink']}',
      author: post['author'],
      score: post['score'] ?? 0,
      numComments: post['num_comments'] ?? 0,
      created: DateTime.fromMillisecondsSinceEpoch(
        (post['created_utc'] as num).toInt() * 1000,
      ),
    );

    // Get top comments if available
    try {
      final commentsUrl = '$_baseUrl${post['permalink']}.json?limit=20&sort=top';
      final response = await http.get(
        Uri.parse(commentsUrl),
        headers: {'User-Agent': 'BraggingRights:Edge:v1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.length > 1) {
          final comments = data[1]['data']['children'] as List;
          thread.sentiment = _analyzeCommentSentiment(comments);
          thread.topComments = _extractTopComments(comments);
        }
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }

    return thread;
  }

  /// Analyze sentiment from posts/comments
  Map<String, dynamic> _analyzeSentiment(List<dynamic> posts) {
    int positive = 0;
    int negative = 0;
    int neutral = 0;
    double totalScore = 0;
    int totalComments = 0;

    for (final post in posts) {
      final data = post['data'];
      final title = data['title'].toString().toLowerCase();
      final score = (data['score'] ?? 0) as num;
      final comments = (data['num_comments'] ?? 0) as num;
      
      totalScore += score;
      totalComments = totalComments + comments.toInt();

      // Simple sentiment based on keywords and engagement
      if (_containsPositive(title)) {
        positive++;
      } else if (_containsNegative(title)) {
        negative++;
      } else {
        neutral++;
      }
    }

    final total = posts.length;
    final avgScore = total > 0 ? totalScore / total : 0;
    final avgComments = total > 0 ? totalComments / total : 0;

    // Calculate overall sentiment
    String overall = 'neutral';
    if (positive > negative * 1.5) {
      overall = 'positive';
    } else if (negative > positive * 1.5) {
      overall = 'negative';
    }

    return {
      'overall': overall,
      'positive': positive,
      'negative': negative,
      'neutral': neutral,
      'avgScore': avgScore,
      'avgComments': avgComments,
      'engagement': avgScore + (avgComments * 10), // Engagement metric
      'confidence': (positive + negative) / total,
    };
  }

  /// Analyze comment sentiment
  String _analyzeCommentSentiment(List<dynamic> comments) {
    int positive = 0;
    int negative = 0;

    for (final comment in comments.take(20)) {
      if (comment['kind'] != 't1') continue;
      
      final body = comment['data']['body'].toString().toLowerCase();
      final score = (comment['data']['score'] ?? 0) as num;
      
      // Weight by score
      if (_containsPositive(body)) {
        positive = positive + score.abs().toInt();
      } else if (_containsNegative(body)) {
        negative = negative + score.abs().toInt();
      }
    }

    if (positive > negative * 1.5) return 'positive';
    if (negative > positive * 1.5) return 'negative';
    return 'neutral';
  }

  /// Extract top comments
  List<String> _extractTopComments(List<dynamic> comments) {
    final topComments = <String>[];
    
    for (final comment in comments.take(5)) {
      if (comment['kind'] != 't1') continue;
      
      final body = comment['data']['body'] ?? '';
      final score = comment['data']['score'] ?? 0;
      
      if (body.length > 20 && body.length < 500 && score > 5) {
        topComments.add(body);
      }
    }
    
    return topComments;
  }

  /// Check for positive sentiment
  bool _containsPositive(String text) {
    final positive = [
      'lets go', 'let\'s go', 'pumped', 'excited', 'confident',
      'dominate', 'destroy', 'win', 'victory', 'championship',
      'beast', 'goat', 'fire', '🔥', 'hype', 'comeback',
    ];
    return positive.any((word) => text.contains(word));
  }

  /// Check for negative sentiment
  bool _containsNegative(String text) {
    final negative = [
      'worried', 'concerned', 'scared', 'nervous', 'doubt',
      'lose', 'loss', 'injured', 'struggling', 'bad',
      'terrible', 'awful', 'disappointing', 'frustrated',
    ];
    return negative.any((word) => text.contains(word));
  }

  /// Calculate fan confidence from sentiments
  Map<String, dynamic> _calculateFanConfidence(Map<String, dynamic> intelligence) {
    final homeSent = intelligence['homeSentiment'] as Map<String, dynamic>? ?? {};
    final awaySent = intelligence['awaySentiment'] as Map<String, dynamic>? ?? {};
    
    final homeEngagement = homeSent['engagement'] ?? 0;
    final awayEngagement = awaySent['engagement'] ?? 0;
    
    final totalEngagement = homeEngagement + awayEngagement;
    
    return {
      'homeFanConfidence': totalEngagement > 0 
          ? homeEngagement / totalEngagement 
          : 0.5,
      'awayFanConfidence': totalEngagement > 0 
          ? awayEngagement / totalEngagement 
          : 0.5,
      'moreActiveBase': homeEngagement > awayEngagement ? 'home' : 'away',
    };
  }

  /// Extract key phrases from text
  List<String> _extractKeyPhrases(String text) {
    final phrases = <String>[];
    
    // Common NBA phrases
    final patterns = [
      RegExp(r'\b(?:injury|report|update)\b', caseSensitive: false),
      RegExp(r'\b(?:trade|rumor|news)\b', caseSensitive: false),
      RegExp(r'\b(?:mvp|dpoy|roty)\b', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) {
        phrases.add(pattern.stringMatch(text) ?? '');
      }
    }
    
    return phrases;
  }

  /// Get team subreddit name
  String _getTeamSubreddit(String teamName) {
    // Try to generate subreddit name from team name
    final parts = teamName.split(' ');
    if (parts.isNotEmpty) {
      return parts.last.toLowerCase();
    }
    return 'nba'; // Default fallback
  }

  /// Get team abbreviation
  String _getTeamAbbreviation(String teamName) {
    final abbreviations = {
      'Los Angeles Lakers': 'LAL',
      'Boston Celtics': 'BOS',
      'Golden State Warriors': 'GSW',
      'Brooklyn Nets': 'BKN',
      // Add more as needed
    };
    
    return abbreviations[teamName] ?? teamName.substring(0, 3).toUpperCase();
  }
}

// Data Models

class RedditGameThread {
  final String id;
  final String title;
  final String url;
  final String author;
  final int score;
  final int numComments;
  final DateTime created;
  String sentiment = 'neutral';
  List<String> topComments = [];

  RedditGameThread({
    required this.id,
    required this.title,
    required this.url,
    required this.author,
    required this.score,
    required this.numComments,
    required this.created,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'url': url,
    'author': author,
    'score': score,
    'numComments': numComments,
    'created': created.toIso8601String(),
    'sentiment': sentiment,
    'topComments': topComments,
  };
}