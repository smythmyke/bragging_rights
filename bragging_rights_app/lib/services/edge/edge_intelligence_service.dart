import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sports/nba_service.dart';
import 'event_matcher.dart';

/// Edge Intelligence Service
/// Aggregates data from all sources and provides actionable insights
class EdgeIntelligenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventMatcher _matcher = EventMatcher();
  
  // Sport-specific services
  final NbaService _nbaService = NbaService();
  // TODO: Add NHL, MLB, NFL services as they're implemented

  /// Get comprehensive intelligence for a betting event
  Future<EdgeIntelligence> getEventIntelligence({
    required String eventId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime eventDate,
  }) async {
    debugPrint('🧠 Gathering intelligence for $homeTeam vs $awayTeam...');

    // Create event match for normalization
    final eventMatch = await _matcher.matchEvent(
      eventId: eventId,
      eventDate: eventDate,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      sport: sport,
    );

    // Initialize intelligence object
    final intelligence = EdgeIntelligence(
      eventId: eventId,
      sport: sport,
      homeTeam: eventMatch.homeTeam,
      awayTeam: eventMatch.awayTeam,
      eventDate: eventDate,
      timestamp: DateTime.now(),
    );

    // Gather data based on sport
    switch (sport.toLowerCase()) {
      case 'nba':
      case 'basketball':
        await _gatherNbaIntelligence(intelligence, eventId);
        break;
      case 'nfl':
      case 'football':
        await _gatherNflIntelligence(intelligence, eventId);
        break;
      case 'mlb':
      case 'baseball':
        await _gatherMlbIntelligence(intelligence, eventId);
        break;
      case 'nhl':
      case 'hockey':
        await _gatherNhlIntelligence(intelligence, eventId);
        break;
      default:
        debugPrint('⚠️ Sport $sport not yet supported');
    }

    // Gather cross-sport data (weather, news, social)
    await _gatherUniversalIntelligence(intelligence, eventMatch);

    // Calculate confidence scores
    intelligence.calculateConfidence();

    // Save to Firestore for caching
    await _saveIntelligence(intelligence);

    return intelligence;
  }

  /// Gather NBA-specific intelligence
  Future<void> _gatherNbaIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    try {
      // Get NBA game data
      final gameData = await _nbaService.getGameIntelligence(
        gameId: eventId,
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
      );

      // Add statistical insights
      if (gameData['analysis'] != null) {
        intelligence.addDataPoint(
          source: 'NBA Stats API',
          type: 'statistics',
          data: gameData['analysis'],
          confidence: 0.95,
        );
      }

      // Add key factors
      if (gameData['keyFactors'] != null) {
        for (final factor in gameData['keyFactors']) {
          intelligence.addInsight(
            category: factor['type'],
            insight: factor['insights'].join(', '),
            impact: 'medium',
          );
        }
      }

      // Add predictions if available
      if (gameData['predictions'] != null) {
        intelligence.predictions = gameData['predictions'];
      }
    } catch (e) {
      debugPrint('Error gathering NBA intelligence: $e');
    }
  }

  /// Gather NFL intelligence (placeholder)
  Future<void> _gatherNflIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    // TODO: Implement when NFL service is ready
    debugPrint('NFL intelligence gathering not yet implemented');
  }

  /// Gather MLB intelligence (placeholder)
  Future<void> _gatherMlbIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    // TODO: Implement when MLB service is ready
    debugPrint('MLB intelligence gathering not yet implemented');
  }

  /// Gather NHL intelligence (placeholder)
  Future<void> _gatherNhlIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    // TODO: Implement when NHL service is ready
    debugPrint('NHL intelligence gathering not yet implemented');
  }

  /// Gather universal intelligence (weather, news, social)
  Future<void> _gatherUniversalIntelligence(
    EdgeIntelligence intelligence,
    EventMatch eventMatch,
  ) async {
    // TODO: Implement weather API
    // TODO: Implement news API
    // TODO: Implement social sentiment API
    
    // For now, add placeholder data
    intelligence.addDataPoint(
      source: 'Weather',
      type: 'conditions',
      data: {'status': 'pending_implementation'},
      confidence: 0.0,
    );

    intelligence.addDataPoint(
      source: 'News',
      type: 'breaking',
      data: {'status': 'pending_implementation'},
      confidence: 0.0,
    );

    intelligence.addDataPoint(
      source: 'Social',
      type: 'sentiment',
      data: {'status': 'pending_implementation'},
      confidence: 0.0,
    );
  }

  /// Save intelligence to Firestore
  Future<void> _saveIntelligence(EdgeIntelligence intelligence) async {
    try {
      await _firestore
          .collection('edge_intelligence')
          .doc(intelligence.eventId)
          .set(intelligence.toMap());
    } catch (e) {
      debugPrint('Error saving intelligence: $e');
    }
  }

  /// Get cached intelligence if available
  Future<EdgeIntelligence?> getCachedIntelligence(String eventId) async {
    try {
      final doc = await _firestore
          .collection('edge_intelligence')
          .doc(eventId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        
        // Check if cache is fresh (less than 5 minutes old)
        if (DateTime.now().difference(timestamp).inMinutes < 5) {
          return EdgeIntelligence.fromMap(data);
        }
      }
    } catch (e) {
      debugPrint('Error getting cached intelligence: $e');
    }
    return null;
  }

  /// Get trending insights across all games
  Future<List<TrendingInsight>> getTrendingInsights() async {
    final insights = <TrendingInsight>[];
    
    try {
      // Query recent intelligence documents
      final snapshot = await _firestore
          .collection('edge_intelligence')
          .where('timestamp', 
              isGreaterThan: DateTime.now().subtract(
                const Duration(hours: 24),
              ))
          .limit(20)
          .get();

      // Aggregate insights
      final insightCounts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docInsights = data['insights'] as List? ?? [];
        
        for (final insight in docInsights) {
          final key = insight['insight'].toString();
          insightCounts[key] = (insightCounts[key] ?? 0) + 1;
        }
      }

      // Sort by frequency and create trending insights
      final sorted = insightCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sorted.take(10)) {
        insights.add(TrendingInsight(
          insight: entry.key,
          frequency: entry.value,
          trend: _calculateTrend(entry.value),
        ));
      }
    } catch (e) {
      debugPrint('Error getting trending insights: $e');
    }

    return insights;
  }

  String _calculateTrend(int frequency) {
    if (frequency > 10) return '🔥 Hot';
    if (frequency > 5) return '📈 Rising';
    return '📊 Steady';
  }
}

/// Edge Intelligence Model
class EdgeIntelligence {
  final String eventId;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final DateTime eventDate;
  final DateTime timestamp;
  
  final List<DataPoint> dataPoints = [];
  final List<EdgeInsight> insights = [];
  Map<String, dynamic> predictions = {};
  double overallConfidence = 0.0;

  EdgeIntelligence({
    required this.eventId,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.eventDate,
    required this.timestamp,
  });

  /// Add a data point from an API source
  void addDataPoint({
    required String source,
    required String type,
    required Map<String, dynamic> data,
    required double confidence,
  }) {
    dataPoints.add(DataPoint(
      source: source,
      type: type,
      data: data,
      confidence: confidence,
      timestamp: DateTime.now(),
    ));
  }

  /// Add an actionable insight
  void addInsight({
    required String category,
    required String insight,
    required String impact,
  }) {
    insights.add(EdgeInsight(
      category: category,
      insight: insight,
      impact: impact,
    ));
  }

  /// Calculate overall confidence based on data points
  void calculateConfidence() {
    if (dataPoints.isEmpty) {
      overallConfidence = 0.0;
      return;
    }

    double totalConfidence = 0.0;
    int validSources = 0;

    for (final point in dataPoints) {
      if (point.confidence > 0) {
        totalConfidence += point.confidence;
        validSources++;
      }
    }

    overallConfidence = validSources > 0 
        ? totalConfidence / validSources 
        : 0.0;
  }

  /// Get high-confidence insights
  List<EdgeInsight> getHighConfidenceInsights() {
    return insights.where((i) => i.impact == 'high').toList();
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'eventDate': eventDate.toIso8601String(),
      'timestamp': timestamp,
      'dataPoints': dataPoints.map((d) => d.toMap()).toList(),
      'insights': insights.map((i) => i.toMap()).toList(),
      'predictions': predictions,
      'overallConfidence': overallConfidence,
    };
  }

  /// Create from Firestore map
  factory EdgeIntelligence.fromMap(Map<String, dynamic> map) {
    final intelligence = EdgeIntelligence(
      eventId: map['eventId'],
      sport: map['sport'],
      homeTeam: map['homeTeam'],
      awayTeam: map['awayTeam'],
      eventDate: DateTime.parse(map['eventDate']),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );

    // Add data points
    final dataPointsList = map['dataPoints'] as List? ?? [];
    for (final dp in dataPointsList) {
      intelligence.dataPoints.add(DataPoint.fromMap(dp));
    }

    // Add insights
    final insightsList = map['insights'] as List? ?? [];
    for (final ins in insightsList) {
      intelligence.insights.add(EdgeInsight.fromMap(ins));
    }

    intelligence.predictions = map['predictions'] ?? {};
    intelligence.overallConfidence = map['overallConfidence'] ?? 0.0;

    return intelligence;
  }
}

/// Data point from an API source
class DataPoint {
  final String source;
  final String type;
  final Map<String, dynamic> data;
  final double confidence;
  final DateTime timestamp;

  DataPoint({
    required this.source,
    required this.type,
    required this.data,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'source': source,
    'type': type,
    'data': data,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DataPoint.fromMap(Map<String, dynamic> map) {
    return DataPoint(
      source: map['source'],
      type: map['type'],
      data: map['data'],
      confidence: map['confidence'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

/// Actionable insight
class EdgeInsight {
  final String category;
  final String insight;
  final String impact; // high, medium, low

  EdgeInsight({
    required this.category,
    required this.insight,
    required this.impact,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'insight': insight,
    'impact': impact,
  };

  factory EdgeInsight.fromMap(Map<String, dynamic> map) {
    return EdgeInsight(
      category: map['category'],
      insight: map['insight'],
      impact: map['impact'],
    );
  }
}

/// Trending insight across multiple games
class TrendingInsight {
  final String insight;
  final int frequency;
  final String trend;

  TrendingInsight({
    required this.insight,
    required this.frequency,
    required this.trend,
  });
}