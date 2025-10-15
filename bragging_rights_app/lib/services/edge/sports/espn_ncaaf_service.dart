import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../cache/edge_cache_service.dart';
import '../../api_call_tracker.dart';

/// ESPN NCAAF API Service
/// Provides comprehensive NCAA Football data including scores, stats, and rankings
class EspnNcaafService {
  final EdgeCacheService _cache = EdgeCacheService();

  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/college-football';

  /// Get today's NCAAF games
  Future<EspnNcaafScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await _cache.getCachedData<EspnNcaafScoreboard>(
      collection: 'games',
      documentId: 'ncaaf_espn_$today',
      dataType: 'scores',
      sport: 'ncaaf',
      gameState: {'source': 'espn'},
      fetchFunction: () async {
        debugPrint('🏈 Fetching NCAAF games from ESPN...');
        APICallTracker.logAPICall('ESPN', 'NCAAF Scoreboard', details: 'Today\'s games');

        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NCAAF data received: ${data['events']?.length ?? 0} games');
          return EspnNcaafScoreboard.fromJson(data);
        }
        throw Exception('ESPN NCAAF API error: ${response.statusCode}');
      },
    );
  }

  /// Get NCAAF games for date range (up to 60 days)
  Future<EspnNcaafScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';

    return await _cache.getCachedData<EspnNcaafScoreboard>(
      collection: 'games',
      documentId: 'ncaaf_espn_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'ncaaf',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('🏈 Fetching NCAAF games from ESPN for next $daysAhead days...');
        APICallTracker.logAPICall('ESPN', 'NCAAF Scoreboard Range', details: 'Next $daysAhead days');

        // ESPN API supports date ranges with dates parameter
        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard?dates=$startStr-$endStr'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NCAAF data received: ${data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnNcaafScoreboard.fromJson(data);
        }
        throw Exception('ESPN NCAAF API error: ${response.statusCode}');
      },
    );
  }

  /// Get NCAAF teams
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
      debugPrint('Error fetching NCAAF teams: $e');
    }
    return null;
  }

  /// Get NCAAF news
  Future<EspnNcaafNews?> getNews({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news?limit=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EspnNcaafNews.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching NCAAF news: $e');
    }
    return null;
  }
}

/// ESPN NCAAF Scoreboard model
class EspnNcaafScoreboard {
  final List<dynamic> events;
  final Map<String, dynamic> leagues;

  EspnNcaafScoreboard({
    required this.events,
    required this.leagues,
  });

  factory EspnNcaafScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnNcaafScoreboard(
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

/// ESPN NCAAF News model
class EspnNcaafNews {
  final List<EspnNcaafArticle> articles;

  EspnNcaafNews({required this.articles});

  factory EspnNcaafNews.fromJson(Map<String, dynamic> json) {
    final articlesList = json['articles'] as List? ?? [];
    return EspnNcaafNews(
      articles: articlesList
          .map((a) => EspnNcaafArticle.fromJson(a))
          .toList(),
    );
  }
}

/// ESPN NCAAF Article model
class EspnNcaafArticle {
  final String headline;
  final String description;
  final String? link;
  final DateTime? published;

  EspnNcaafArticle({
    required this.headline,
    required this.description,
    this.link,
    this.published,
  });

  factory EspnNcaafArticle.fromJson(Map<String, dynamic> json) {
    return EspnNcaafArticle(
      headline: json['headline'] ?? '',
      description: json['description'] ?? '',
      link: json['links']?['web']?['href'],
      published: json['published'] != null
          ? DateTime.tryParse(json['published'])
          : null,
    );
  }
}
