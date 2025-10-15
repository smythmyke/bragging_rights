import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../cache/edge_cache_service.dart';
import '../../api_call_tracker.dart';

/// ESPN NCAAB API Service
/// Provides comprehensive NCAA Men's Basketball data including scores, stats, and rankings
class EspnNcaabService {
  final EdgeCacheService _cache = EdgeCacheService();

  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball';

  /// Get today's NCAAB games
  Future<EspnNcaabScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await _cache.getCachedData<EspnNcaabScoreboard>(
      collection: 'games',
      documentId: 'ncaab_espn_$today',
      dataType: 'scores',
      sport: 'ncaab',
      gameState: {'source': 'espn'},
      fetchFunction: () async {
        debugPrint('🏀 Fetching NCAAB games from ESPN...');
        APICallTracker.logAPICall('ESPN', 'NCAAB Scoreboard', details: 'Today\'s games');

        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NCAAB data received: ${data['events']?.length ?? 0} games');
          return EspnNcaabScoreboard.fromJson(data);
        }
        throw Exception('ESPN NCAAB API error: ${response.statusCode}');
      },
    );
  }

  /// Get NCAAB games for date range (up to 60 days)
  Future<EspnNcaabScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';

    return await _cache.getCachedData<EspnNcaabScoreboard>(
      collection: 'games',
      documentId: 'ncaab_espn_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'ncaab',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('🏀 Fetching NCAAB games from ESPN for next $daysAhead days...');
        APICallTracker.logAPICall('ESPN', 'NCAAB Scoreboard Range', details: 'Next $daysAhead days');

        // ESPN API supports date ranges with dates parameter
        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard?dates=$startStr-$endStr'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NCAAB data received: ${data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnNcaabScoreboard.fromJson(data);
        }
        throw Exception('ESPN NCAAB API error: ${response.statusCode}');
      },
    );
  }

  /// Get NCAAB teams
  Future<Map<String, dynamic>?> getTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/teams'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching NCAAB teams: $e');
    }
    return null;
  }

  /// Get NCAAB news
  Future<EspnNcaabNews?> getNews({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news?limit=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EspnNcaabNews.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching NCAAB news: $e');
    }
    return null;
  }
}

/// ESPN NCAAB Scoreboard model
class EspnNcaabScoreboard {
  final List<dynamic> events;
  final Map<String, dynamic> leagues;

  EspnNcaabScoreboard({
    required this.events,
    required this.leagues,
  });

  factory EspnNcaabScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnNcaabScoreboard(
      events: json['events'] ?? [],
      leagues: json['leagues']?[0] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'events': events,
      'leagues': leagues,
    };
  }
}

/// ESPN NCAAB News model
class EspnNcaabNews {
  final List<EspnNcaabArticle> articles;

  EspnNcaabNews({required this.articles});

  factory EspnNcaabNews.fromJson(Map<String, dynamic> json) {
    final articlesList = json['articles'] as List? ?? [];
    return EspnNcaabNews(
      articles: articlesList
          .map((a) => EspnNcaabArticle.fromJson(a))
          .toList(),
    );
  }
}

/// ESPN NCAAB Article model
class EspnNcaabArticle {
  final String headline;
  final String description;
  final String? link;
  final DateTime? published;

  EspnNcaabArticle({
    required this.headline,
    required this.description,
    this.link,
    this.published,
  });

  factory EspnNcaabArticle.fromJson(Map<String, dynamic> json) {
    return EspnNcaabArticle(
      headline: json['headline'] ?? '',
      description: json['description'] ?? '',
      link: json['links']?['web']?['href'],
      published: json['published'] != null
          ? DateTime.tryParse(json['published'])
          : null,
    );
  }
}
