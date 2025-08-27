import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import 'package:intl/intl.dart';

/// NewsAPI Service for Edge Intelligence
/// Provides breaking news and media coverage analysis
class NewsApiService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  
  static const String _apiName = 'news_api';
  
  // NewsAPI endpoints
  static const String _everythingEndpoint = '/everything';
  static const String _topHeadlinesEndpoint = '/top-headlines';
  static const String _sourcesEndpoint = '/sources';

  // Sports news sources
  static const List<String> _sportsSources = [
    'espn',
    'bleacher-report', 
    'fox-sports',
    'the-athletic',
    'nfl-news',
    'nhl-news',
  ];

  /// Get sports news for specific teams/players
  Future<NewsResponse?> getTeamNews({
    required String query,
    int pageSize = 20,
    String? language = 'en',
    String sortBy = 'relevancy', // relevancy, popularity, publishedAt
  }) async {
    try {
      debugPrint('📰 Fetching news for: $query');
      
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _everythingEndpoint,
        queryParams: {
          'q': query,
          'language': language,
          'sortBy': sortBy,
          'pageSize': pageSize.toString(),
          'domains': 'espn.com,bleacherreport.com,cbssports.com,foxsports.com',
        },
      );

      if (response.data != null) {
        return NewsResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
    return null;
  }

  /// Get breaking sports headlines
  Future<NewsResponse?> getSportsHeadlines({
    String category = 'sports',
    String country = 'us',
    int pageSize = 10,
  }) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _topHeadlinesEndpoint,
        queryParams: {
          'category': category,
          'country': country,
          'pageSize': pageSize.toString(),
        },
      );

      if (response.data != null) {
        return NewsResponse.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching headlines: $e');
    }
    return null;
  }

  /// Get news for a specific game/event
  Future<Map<String, dynamic>> getGameNews({
    required String homeTeam,
    required String awayTeam,
    required String sport,
    DateTime? gameDate,
  }) async {
    debugPrint('📰 Gathering news intelligence for $homeTeam vs $awayTeam');
    
    final newsData = <String, dynamic>{
      'articles': [],
      'sentiment': {},
      'keyTopics': [],
      'injuryNews': [],
    };

    // Normalize team names
    final homeNorm = _matcher.normalizeTeamName(homeTeam);
    final awayNorm = _matcher.normalizeTeamName(awayTeam);

    // Search queries
    final queries = [
      '"$homeNorm" "$awayNorm"',  // Both teams
      homeNorm,  // Home team news
      awayNorm,  // Away team news
    ];

    // Fetch news for each query
    for (final query in queries) {
      final news = await getTeamNews(
        query: query,
        pageSize: 5,
        sortBy: 'publishedAt',
      );

      if (news != null) {
        for (final article in news.articles) {
          // Analyze article for relevance and sentiment
          final analysis = _analyzeArticle(article, homeNorm, awayNorm);
          
          if (analysis['relevance'] > 0.5) {
            newsData['articles'].add({
              'title': article.title,
              'description': article.description,
              'url': article.url,
              'source': article.source['name'],
              'publishedAt': article.publishedAt,
              'analysis': analysis,
            });

            // Check for injury news
            if (_isInjuryNews(article)) {
              newsData['injuryNews'].add({
                'title': article.title,
                'impact': _assessInjuryImpact(article),
              });
            }
          }
        }
      }
    }

    // Calculate overall sentiment
    newsData['sentiment'] = _calculateSentiment(newsData['articles']);
    
    // Extract key topics
    newsData['keyTopics'] = _extractKeyTopics(newsData['articles']);

    return newsData;
  }

  /// Analyze article for relevance and sentiment
  Map<String, dynamic> _analyzeArticle(
    NewsArticle article,
    String homeTeam,
    String awayTeam,
  ) {
    double relevance = 0.0;
    String sentiment = 'neutral';
    List<String> mentions = [];

    final text = '${article.title} ${article.description}'.toLowerCase();
    final homeNorm = homeTeam.toLowerCase();
    final awayNorm = awayTeam.toLowerCase();

    // Check team mentions
    if (text.contains(homeNorm)) {
      relevance += 0.5;
      mentions.add(homeTeam);
    }
    if (text.contains(awayNorm)) {
      relevance += 0.5;
      mentions.add(awayTeam);
    }

    // Check for relevant keywords
    final keywords = ['injury', 'doubtful', 'questionable', 'probable', 
                      'starting', 'lineup', 'suspension', 'return'];
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        relevance += 0.2;
      }
    }

    // Simple sentiment analysis
    final positiveWords = ['win', 'victory', 'dominant', 'streak', 'healthy', 'return'];
    final negativeWords = ['loss', 'injury', 'doubtful', 'struggle', 'suspension'];
    
    int positiveCount = 0;
    int negativeCount = 0;
    
    for (final word in positiveWords) {
      if (text.contains(word)) positiveCount++;
    }
    for (final word in negativeWords) {
      if (text.contains(word)) negativeCount++;
    }

    if (positiveCount > negativeCount) {
      sentiment = 'positive';
    } else if (negativeCount > positiveCount) {
      sentiment = 'negative';
    }

    return {
      'relevance': relevance.clamp(0.0, 1.0),
      'sentiment': sentiment,
      'mentions': mentions,
    };
  }

  /// Check if article contains injury news
  bool _isInjuryNews(NewsArticle article) {
    final text = '${article.title} ${article.description}'.toLowerCase();
    final injuryKeywords = [
      'injury', 'injured', 'hurt', 'doubtful', 'questionable',
      'probable', 'game-time decision', 'sidelined', 'out',
    ];
    
    return injuryKeywords.any((keyword) => text.contains(keyword));
  }

  /// Assess injury impact on game
  String _assessInjuryImpact(NewsArticle article) {
    final text = '${article.title} ${article.description}'.toLowerCase();
    
    if (text.contains('out') || text.contains('ruled out')) {
      return 'high';
    } else if (text.contains('doubtful')) {
      return 'high';
    } else if (text.contains('questionable')) {
      return 'medium';
    } else if (text.contains('probable') || text.contains('game-time')) {
      return 'low';
    }
    
    return 'unknown';
  }

  /// Calculate overall sentiment from articles
  Map<String, dynamic> _calculateSentiment(List<dynamic> articles) {
    int positive = 0;
    int negative = 0;
    int neutral = 0;

    for (final article in articles) {
      final sentiment = article['analysis']['sentiment'];
      switch (sentiment) {
        case 'positive':
          positive++;
          break;
        case 'negative':
          negative++;
          break;
        default:
          neutral++;
      }
    }

    final total = articles.length;
    return {
      'positive': positive,
      'negative': negative,
      'neutral': neutral,
      'overall': positive > negative ? 'positive' : 
                 negative > positive ? 'negative' : 'neutral',
      'confidence': total > 0 ? (positive + negative) / total : 0.0,
    };
  }

  /// Extract key topics from articles
  List<String> _extractKeyTopics(List<dynamic> articles) {
    final topics = <String, int>{};
    
    // Common topics to track
    final topicKeywords = {
      'injuries': ['injury', 'injured', 'hurt', 'sidelined'],
      'lineup_changes': ['lineup', 'starting', 'benched'],
      'momentum': ['streak', 'hot', 'cold', 'momentum'],
      'rivalry': ['rivalry', 'rival', 'history'],
      'playoffs': ['playoff', 'seed', 'standings'],
    };

    for (final article in articles) {
      final text = '${article['title']} ${article['description']}'.toLowerCase();
      
      topicKeywords.forEach((topic, keywords) {
        if (keywords.any((k) => text.contains(k))) {
          topics[topic] = (topics[topic] ?? 0) + 1;
        }
      });
    }

    // Sort by frequency and return top topics
    final sorted = topics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => e.key).toList();
  }
}

// Data Models

class NewsResponse {
  final String status;
  final int totalResults;
  final List<NewsArticle> articles;

  NewsResponse({
    required this.status,
    required this.totalResults,
    required this.articles,
  });

  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    return NewsResponse(
      status: json['status'] ?? 'error',
      totalResults: json['totalResults'] ?? 0,
      articles: (json['articles'] as List? ?? [])
          .map((a) => NewsArticle.fromJson(a))
          .toList(),
    );
  }
}

class NewsArticle {
  final Map<String, dynamic> source;
  final String? author;
  final String title;
  final String? description;
  final String url;
  final String? urlToImage;
  final DateTime publishedAt;
  final String? content;

  NewsArticle({
    required this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    this.content,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      source: json['source'] ?? {},
      author: json['author'],
      title: json['title'] ?? '',
      description: json['description'],
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'],
      publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toIso8601String()),
      content: json['content'],
    );
  }
}