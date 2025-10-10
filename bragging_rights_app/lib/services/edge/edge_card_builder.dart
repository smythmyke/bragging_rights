import 'package:flutter/foundation.dart';
import '../../widgets/edge/edge_card_types.dart';
import 'edge_intelligence_service.dart';

/// EdgeCardBuilder
/// Converts EdgeIntelligence data into EdgeCardData models for UI display
class EdgeCardBuilder {
  /// Build all available Edge cards from intelligence data
  Future<List<EdgeCardData>> buildCardsFromIntelligence({
    required EdgeIntelligence intelligence,
    required DateTime gameTime,
  }) async {
    final cards = <EdgeCardData>[];

    debugPrint('🎴 Building Edge cards from intelligence for ${intelligence.homeTeam} vs ${intelligence.awayTeam}');

    // Build Breaking News card
    final breakingNewsCard = _buildBreakingNewsCard(intelligence, gameTime);
    if (breakingNewsCard != null) {
      cards.add(breakingNewsCard);
      debugPrint('  ✅ Breaking News card created');
    }

    // Build Injury Intelligence card
    final injuryCard = _buildInjuryIntelligenceCard(intelligence, gameTime);
    if (injuryCard != null) {
      cards.add(injuryCard);
      debugPrint('  ✅ Injury Intelligence card created');
    }

    // Build Weather Impact card
    final weatherCard = _buildWeatherImpactCard(intelligence, gameTime);
    if (weatherCard != null) {
      cards.add(weatherCard);
      debugPrint('  ✅ Weather Impact card created');
    }

    // Build Matchup Analysis card
    final matchupCard = _buildMatchupAnalysisCard(intelligence, gameTime);
    if (matchupCard != null) {
      cards.add(matchupCard);
      debugPrint('  ✅ Matchup Analysis card created');
    }

    // Build Social Sentiment card
    final socialCard = _buildSocialSentimentCard(intelligence, gameTime);
    if (socialCard != null) {
      cards.add(socialCard);
      debugPrint('  ✅ Social Sentiment card created');
    }

    // Build sport-specific cards
    final sportSpecificCards = _buildSportSpecificCards(intelligence, gameTime);
    cards.addAll(sportSpecificCards);
    if (sportSpecificCards.isNotEmpty) {
      debugPrint('  ✅ ${sportSpecificCards.length} sport-specific cards created');
    }

    debugPrint('🎴 Built ${cards.length} total Edge cards');

    return cards;
  }

  /// Build Breaking News card from news data
  EdgeCardData? _buildBreakingNewsCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find news data points
    final newsDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'recent_news',
    ).toList();

    if (newsDataPoints.isEmpty) {
      debugPrint('  ⚠️ No news data available for Breaking News card');
      return null;
    }

    // Get the most recent news data
    final newsData = newsDataPoints.last;
    final articles = newsData.data['headlines'] as List? ?? [];

    if (articles.isEmpty) {
      debugPrint('  ⚠️ No articles in news data');
      return null;
    }

    // Build teaser text (first headline)
    final teaserText = articles.first.toString();

    // Build full content with all headlines
    final fullContent = _buildBreakingNewsContent(articles, newsData.data);

    // Calculate confidence based on article count and recency
    final articleCount = newsData.data['articleCount'] ?? 0;
    final confidence = (articleCount / 10).clamp(0.5, 0.95);

    // Determine rarity based on content
    EdgeCardRarity rarity = EdgeCardRarity.epic;
    final badges = <EdgeCardBadge>[EdgeCardBadge.breaking];

    // Check if this is fresh breaking news (less than 1 hour old)
    if (newsData.timestamp.difference(DateTime.now()).inMinutes.abs() < 60) {
      badges.add(EdgeCardBadge.hot);
      rarity = EdgeCardRarity.legendary;
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_breaking_news',
      category: EdgeCardCategory.breaking,
      title: 'Breaking: ${intelligence.homeTeam} vs ${intelligence.awayTeam}',
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: {
        'articleCount': articleCount,
        'source': newsData.source,
        'sport': intelligence.sport,
      },
      timestamp: newsData.timestamp,
      rarity: rarity,
      badges: badges,
      currentCost: EdgeCardConfigs.getConfig(EdgeCardCategory.breaking).baseCost,
      confidence: confidence,
      impactText: _getNewsImpactText(intelligence),
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build full content for Breaking News card
  String _buildBreakingNewsContent(List<dynamic> headlines, Map<String, dynamic> newsData) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 BREAKING NEWS\n');
    buffer.writeln('Latest Updates:\n');

    for (int i = 0; i < headlines.length && i < 5; i++) {
      buffer.writeln('${i + 1}. ${headlines[i]}');
      if (i < headlines.length - 1) buffer.writeln();
    }

    buffer.writeln('\n📊 Coverage:');
    buffer.writeln('${newsData['articleCount'] ?? 0} articles found');

    return buffer.toString();
  }

  /// Get news impact text
  String? _getNewsImpactText(EdgeIntelligence intelligence) {
    // Check for high-impact news (injuries, suspensions, etc.)
    final highImpactInsights = intelligence.insights.where(
      (i) => i.impact == 'high' && (i.category == 'injuries' || i.category == 'news'),
    );

    if (highImpactInsights.isNotEmpty) {
      return 'HIGH IMPACT: Breaking developments that could affect betting lines';
    }

    return 'Monitor for lineup changes and betting adjustments';
  }

  /// Build Injury Intelligence card
  EdgeCardData? _buildInjuryIntelligenceCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find injury data points
    final injuryDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'injury_report' || dp.type == 'injuries',
    ).toList();

    if (injuryDataPoints.isEmpty) {
      debugPrint('  ⚠️ No injury data available');
      return null;
    }

    // Get injury data
    final injuryData = injuryDataPoints.last;
    final injuries = injuryData.data['injuries'] as List? ??
                     (injuryData.data is List ? injuryData.data as List : []);

    if (injuries.isEmpty) {
      debugPrint('  ⚠️ No injuries in injury data');
      return null;
    }

    // Build teaser (count of significant injuries)
    final highImpactCount = intelligence.insights.where(
      (i) => i.category == 'injuries' && i.impact == 'high',
    ).length;

    final teaserText = highImpactCount > 0
        ? '$highImpactCount critical injury concern${highImpactCount > 1 ? 's' : ''} detected'
        : '${injuries.length} player${injuries.length > 1 ? 's' : ''} on injury report';

    // Build full content
    final fullContent = _buildInjuryReportContent(injuries, intelligence);

    // Calculate confidence
    final confidence = injuryData.confidence;

    // Determine rarity based on injury severity
    EdgeCardRarity rarity = EdgeCardRarity.rare;
    final badges = <EdgeCardBadge>[];

    if (highImpactCount > 0) {
      badges.add(EdgeCardBadge.hot);
      rarity = EdgeCardRarity.epic;
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_injury_intelligence',
      category: EdgeCardCategory.injury,
      title: 'Injury Report: ${intelligence.homeTeam} vs ${intelligence.awayTeam}',
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: {
        'injuryCount': injuries.length,
        'highImpactCount': highImpactCount,
        'source': injuryData.source,
        'sport': intelligence.sport,
      },
      timestamp: injuryData.timestamp,
      rarity: rarity,
      badges: badges,
      currentCost: EdgeCardConfigs.getConfig(EdgeCardCategory.injury).baseCost,
      confidence: confidence,
      impactText: _getInjuryImpactText(highImpactCount, injuries.length),
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build injury report content
  String _buildInjuryReportContent(List<dynamic> injuries, EdgeIntelligence intelligence) {
    final buffer = StringBuffer();
    buffer.writeln('⚕️ INJURY INTELLIGENCE\n');

    // Separate by impact level
    final highImpact = <String>[];
    final mediumImpact = <String>[];
    final lowImpact = <String>[];

    for (final insight in intelligence.insights) {
      if (insight.category == 'injuries') {
        if (insight.impact == 'high') {
          highImpact.add(insight.message);
        } else if (insight.impact == 'medium') {
          mediumImpact.add(insight.message);
        } else {
          lowImpact.add(insight.message);
        }
      }
    }

    if (highImpact.isNotEmpty) {
      buffer.writeln('🔴 HIGH IMPACT:');
      for (final injury in highImpact) {
        buffer.writeln('  • $injury');
      }
      buffer.writeln();
    }

    if (mediumImpact.isNotEmpty) {
      buffer.writeln('🟡 MEDIUM IMPACT:');
      for (final injury in mediumImpact) {
        buffer.writeln('  • $injury');
      }
      buffer.writeln();
    }

    if (lowImpact.isNotEmpty) {
      buffer.writeln('🟢 LOW IMPACT:');
      for (final injury in lowImpact) {
        buffer.writeln('  • $injury');
      }
    }

    if (highImpact.isEmpty && mediumImpact.isEmpty && lowImpact.isEmpty) {
      buffer.writeln('📋 INJURY REPORT:');
      for (int i = 0; i < injuries.length && i < 10; i++) {
        final injury = injuries[i];
        final note = injury['note'] ?? injury['headline'] ?? 'Status unknown';
        buffer.writeln('  • $note');
      }
    }

    return buffer.toString();
  }

  /// Get injury impact text
  String? _getInjuryImpactText(int highImpactCount, int totalInjuries) {
    if (highImpactCount > 0) {
      return 'CRITICAL: Key player injury concerns - line movement likely';
    } else if (totalInjuries > 3) {
      return 'MODERATE: Multiple injuries may impact performance';
    }
    return 'Monitor for game-time decisions';
  }

  /// Build Weather Impact card
  EdgeCardData? _buildWeatherImpactCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Only relevant for outdoor sports (NFL, MLB)
    if (!['NFL', 'MLB', 'NCAAF'].contains(intelligence.sport.toUpperCase())) {
      return null;
    }

    // Find weather data points
    final weatherDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'weather_conditions',
    ).toList();

    if (weatherDataPoints.isEmpty) {
      debugPrint('  ⚠️ No weather data available');
      return null;
    }

    // Get weather data
    final weatherData = weatherDataPoints.last;
    final weather = weatherData.data;

    // Build teaser
    final teaserText = _buildWeatherTeaser(weather, intelligence);

    // Build full content
    final fullContent = _buildWeatherContent(weather, intelligence);

    // Calculate confidence
    final confidence = weatherData.confidence;

    // Determine rarity based on weather severity
    EdgeCardRarity rarity = EdgeCardRarity.uncommon;
    final badges = <EdgeCardBadge>[];

    final impact = weather['impact'] ?? '';
    if (impact.toString().contains('HIGH')) {
      badges.add(EdgeCardBadge.hot);
      rarity = EdgeCardRarity.rare;
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_weather_impact',
      category: EdgeCardCategory.weather,
      title: 'Weather Alert: ${intelligence.homeTeam} vs ${intelligence.awayTeam}',
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: {
        'temperature': weather['temperature'],
        'conditions': weather['conditions'],
        'windSpeed': weather['wind']?['speed'] ?? weather['windSpeed'],
        'windDirection': weather['wind']?['direction'] ?? weather['windDirection'],
        'source': weatherData.source,
        'sport': intelligence.sport,
      },
      timestamp: weatherData.timestamp,
      rarity: rarity,
      badges: badges,
      currentCost: EdgeCardConfigs.getConfig(EdgeCardCategory.weather).baseCost,
      confidence: confidence,
      impactText: _getWeatherImpactText(weather, intelligence),
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build weather teaser text
  String _buildWeatherTeaser(Map<String, dynamic> weather, EdgeIntelligence intelligence) {
    final wind = weather['wind'];
    if (wind != null && wind is Map) {
      final speed = wind['speed'] ?? 0;
      final direction = wind['direction'] ?? '';
      if (speed > 10) {
        return '$speed mph wind $direction - Significant impact expected';
      }
    }

    final windSpeed = weather['windSpeed'];
    if (windSpeed != null && windSpeed > 10) {
      return '$windSpeed mph wind - Game conditions affected';
    }

    final conditions = weather['conditions'] ?? weather['displayValue'] ?? 'Unknown';
    return 'Weather: $conditions';
  }

  /// Build weather content
  String _buildWeatherContent(Map<String, dynamic> weather, EdgeIntelligence intelligence) {
    final buffer = StringBuffer();
    buffer.writeln('🌦️ WEATHER IMPACT\n');

    // Temperature
    final temp = weather['temperature'];
    if (temp != null) {
      buffer.writeln('🌡️ Temperature: ${temp}°F');
    }

    // Wind
    final wind = weather['wind'];
    if (wind != null && wind is Map) {
      final speed = wind['speed'] ?? 0;
      final direction = wind['direction'] ?? '';
      buffer.writeln('🌬️ Wind: $speed mph $direction');
    } else {
      final windSpeed = weather['windSpeed'];
      final windDirection = weather['windDirection'];
      if (windSpeed != null) {
        buffer.writeln('🌬️ Wind: $windSpeed mph ${windDirection ?? ''}');
      }
    }

    // Conditions
    final conditions = weather['conditions'] ?? weather['displayValue'];
    if (conditions != null) {
      buffer.writeln('☁️ Conditions: $conditions');
    }

    buffer.writeln();

    // Impact analysis
    final weatherInsights = intelligence.insights.where(
      (i) => i.category == 'weather',
    );

    if (weatherInsights.isNotEmpty) {
      buffer.writeln('📊 IMPACT ANALYSIS:');
      for (final insight in weatherInsights) {
        buffer.writeln('  • ${insight.message}');
      }
      buffer.writeln();
    }

    // Betting suggestion
    final weatherSuggestion = intelligence.predictions['weatherSuggestion'] ??
                             intelligence.predictions['weatherAlert'];
    if (weatherSuggestion != null) {
      buffer.writeln('💡 BETTING SUGGESTION:');
      buffer.writeln('  ${weatherSuggestion['suggestion'] ?? 'Consider weather impact'}');
      if (weatherSuggestion['reasoning'] != null) {
        buffer.writeln('  Reasoning: ${weatherSuggestion['reasoning']}');
      }
    }

    return buffer.toString();
  }

  /// Get weather impact text
  String? _getWeatherImpactText(Map<String, dynamic> weather, EdgeIntelligence intelligence) {
    final impact = weather['impact']?.toString() ?? '';

    if (impact.contains('HIGH')) {
      return 'SEVERE: Weather conditions significantly affect gameplay';
    } else if (impact.contains('MEDIUM')) {
      return 'MODERATE: Weather may influence scoring and outcomes';
    }

    // Check for specific conditions
    final wind = weather['wind'];
    if (wind != null && wind is Map) {
      final speed = wind['speed'] ?? 0;
      if (speed > 15) {
        return 'HIGH: Strong winds will impact passing/throwing';
      } else if (speed > 10) {
        return 'MODERATE: Wind conditions may affect play';
      }
    }

    return 'Monitor weather conditions approaching game time';
  }

  /// Build Matchup Analysis card
  EdgeCardData? _buildMatchupAnalysisCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find matchup-related data points
    final statsDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'team_statistics' || dp.type == 'team_stats',
    ).toList();

    final formDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'recent_form',
    ).toList();

    if (statsDataPoints.isEmpty && formDataPoints.isEmpty) {
      debugPrint('  ⚠️ No matchup data available');
      return null;
    }

    // Build teaser
    final teaserText = _buildMatchupTeaser(intelligence);

    // Build full content
    final fullContent = _buildMatchupContent(intelligence, statsDataPoints, formDataPoints);

    // Calculate confidence (average of available data points)
    final allPoints = [...statsDataPoints, ...formDataPoints];
    final avgConfidence = allPoints.isEmpty
        ? 0.7
        : allPoints.map((dp) => dp.confidence).reduce((a, b) => a + b) / allPoints.length;

    return EdgeCardData(
      id: '${intelligence.eventId}_matchup_analysis',
      category: EdgeCardCategory.matchup,
      title: 'Matchup Intel: ${intelligence.homeTeam} vs ${intelligence.awayTeam}',
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: {
        'hasStats': statsDataPoints.isNotEmpty,
        'hasForm': formDataPoints.isNotEmpty,
        'sport': intelligence.sport,
      },
      timestamp: DateTime.now(),
      rarity: EdgeCardRarity.uncommon,
      badges: [],
      currentCost: EdgeCardConfigs.getConfig(EdgeCardCategory.matchup).baseCost,
      confidence: avgConfidence,
      impactText: 'Historical patterns and statistical edge analysis',
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build matchup teaser
  String _buildMatchupTeaser(EdgeIntelligence intelligence) {
    // Look for high-impact matchup insights
    final matchupInsights = intelligence.insights.where(
      (i) => ['offense', 'defense', 'momentum', 'matchup'].contains(i.category),
    );

    if (matchupInsights.isNotEmpty) {
      return matchupInsights.first.message;
    }

    return 'Statistical analysis and recent form comparison';
  }

  /// Build matchup content
  String _buildMatchupContent(
    EdgeIntelligence intelligence,
    List<DataPoint> statsDataPoints,
    List<DataPoint> formDataPoints,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('📊 MATCHUP INTELLIGENCE\n');

    // Team statistics
    if (statsDataPoints.isNotEmpty) {
      buffer.writeln('📈 TEAM STATISTICS:');

      final offenseInsights = intelligence.insights.where(
        (i) => i.category == 'offense',
      );
      final defenseInsights = intelligence.insights.where(
        (i) => i.category == 'defense',
      );

      if (offenseInsights.isNotEmpty) {
        buffer.writeln('\n  OFFENSIVE ANALYSIS:');
        for (final insight in offenseInsights) {
          buffer.writeln('    • ${insight.message}');
        }
      }

      if (defenseInsights.isNotEmpty) {
        buffer.writeln('\n  DEFENSIVE ANALYSIS:');
        for (final insight in defenseInsights) {
          buffer.writeln('    • ${insight.message}');
        }
      }

      buffer.writeln();
    }

    // Recent form
    if (formDataPoints.isNotEmpty) {
      buffer.writeln('🔥 RECENT FORM:');

      final momentumInsights = intelligence.insights.where(
        (i) => i.category == 'momentum',
      );

      if (momentumInsights.isNotEmpty) {
        for (final insight in momentumInsights) {
          buffer.writeln('  • ${insight.message}');
        }
      } else {
        buffer.writeln('  Recent performance data available');
      }

      buffer.writeln();
    }

    // Key matchups
    final matchupInsights = intelligence.insights.where(
      (i) => i.category == 'matchup',
    );

    if (matchupInsights.isNotEmpty) {
      buffer.writeln('⚔️ KEY MATCHUPS:');
      for (final insight in matchupInsights) {
        buffer.writeln('  • ${insight.message}');
      }
    }

    return buffer.toString();
  }

  /// Build Social Sentiment card
  EdgeCardData? _buildSocialSentimentCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find social sentiment data points
    final socialDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'fan_sentiment' || dp.type == 'social_sentiment',
    ).toList();

    if (socialDataPoints.isEmpty) {
      debugPrint('  ⚠️ No social sentiment data available');
      return null;
    }

    // Get social data
    final socialData = socialDataPoints.last;

    // Build teaser
    final teaserText = _buildSocialTeaser(socialData.data, intelligence);

    // Build full content
    final fullContent = _buildSocialContent(socialData.data, intelligence);

    // Calculate confidence
    final confidence = socialData.confidence;

    return EdgeCardData(
      id: '${intelligence.eventId}_social_sentiment',
      category: EdgeCardCategory.social,
      title: 'Fan Buzz: ${intelligence.homeTeam} vs ${intelligence.awayTeam}',
      teaserText: teaserText,
      fullContent: fullContent,
      metadata: {
        'source': socialData.source,
        'sport': intelligence.sport,
      },
      timestamp: socialData.timestamp,
      rarity: EdgeCardRarity.common,
      badges: [EdgeCardBadge.trending],
      currentCost: EdgeCardConfigs.getConfig(EdgeCardCategory.social).baseCost,
      confidence: confidence,
      impactText: 'Community sentiment and contrarian betting opportunities',
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build social sentiment teaser
  String _buildSocialTeaser(Map<String, dynamic> socialData, EdgeIntelligence intelligence) {
    final fanConfidence = socialData['fanConfidence'];
    if (fanConfidence != null) {
      final homeConfidence = fanConfidence['homeFanConfidence'];
      if (homeConfidence != null) {
        final pct = (homeConfidence * 100).toStringAsFixed(0);
        return '${intelligence.homeTeam} fans $pct% confident';
      }
    }

    return 'Community sentiment analysis available';
  }

  /// Build social sentiment content
  String _buildSocialContent(Map<String, dynamic> socialData, EdgeIntelligence intelligence) {
    final buffer = StringBuffer();
    buffer.writeln('🗳️ FAN SENTIMENT\n');

    // Fan confidence
    final fanConfidence = socialData['fanConfidence'];
    if (fanConfidence != null) {
      final homeConfidence = fanConfidence['homeFanConfidence'];
      final awayConfidence = fanConfidence['awayFanConfidence'];

      if (homeConfidence != null) {
        final pct = (homeConfidence * 100).toStringAsFixed(0);
        buffer.writeln('${intelligence.homeTeam}: $pct% confident');
      }

      if (awayConfidence != null) {
        final pct = (awayConfidence * 100).toStringAsFixed(0);
        buffer.writeln('${intelligence.awayTeam}: $pct% confident');
      }

      buffer.writeln();
    }

    // Social insights
    final socialInsights = intelligence.insights.where(
      (i) => ['social', 'social_sentiment'].contains(i.category),
    );

    if (socialInsights.isNotEmpty) {
      buffer.writeln('💬 COMMUNITY INSIGHTS:');
      for (final insight in socialInsights) {
        buffer.writeln('  • ${insight.message}');
      }
      buffer.writeln();
    }

    // Contrarian alert
    if (fanConfidence != null) {
      final homeConf = fanConfidence['homeFanConfidence'] ?? 0.5;
      final awayConf = fanConfidence['awayFanConfidence'] ?? 0.5;

      if ((homeConf - awayConf).abs() > 0.25) {
        buffer.writeln('⚠️ CONTRARIAN OPPORTUNITY:');
        final favorite = homeConf > awayConf ? intelligence.homeTeam : intelligence.awayTeam;
        buffer.writeln('  Public heavily favoring $favorite');
        buffer.writeln('  Consider fading public sentiment');
      }
    }

    return buffer.toString();
  }

  /// Build sport-specific cards
  List<EdgeCardData> _buildSportSpecificCards(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    final cards = <EdgeCardData>[];

    switch (intelligence.sport.toUpperCase()) {
      case 'MLB':
        final pitcherCard = _buildPitcherMatchupCard(intelligence, gameTime);
        if (pitcherCard != null) cards.add(pitcherCard);
        break;

      case 'NHL':
        final goalieCard = _buildGoalieMatchupCard(intelligence, gameTime);
        if (goalieCard != null) cards.add(goalieCard);
        break;

      case 'MMA':
      case 'UFC':
      case 'BELLATOR':
      case 'PFL':
      case 'BOXING':
        final fighterCard = _buildFighterAnalysisCard(intelligence, gameTime);
        if (fighterCard != null) cards.add(fighterCard);
        break;
    }

    return cards;
  }

  /// Build MLB Pitcher Matchup card
  EdgeCardData? _buildPitcherMatchupCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find pitcher data
    final pitcherDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'starting_pitchers',
    ).toList();

    if (pitcherDataPoints.isEmpty) {
      return null;
    }

    final pitcherData = pitcherDataPoints.last;
    final pitchers = pitcherData.data;

    // Build teaser
    final homePitcher = pitchers['home'];
    final awayPitcher = pitchers['away'];
    final teaserText = '${awayPitcher?['name'] ?? 'TBD'} vs ${homePitcher?['name'] ?? 'TBD'}';

    // Build content
    final buffer = StringBuffer();
    buffer.writeln('⚾ PITCHER MATCHUP\n');

    if (homePitcher != null) {
      buffer.writeln('${intelligence.homeTeam}:');
      buffer.writeln('  ${homePitcher['name']}');
      if (homePitcher['stats'] != null) {
        final stats = homePitcher['stats'];
        buffer.writeln('  ERA: ${stats['era']}');
        buffer.writeln('  WHIP: ${stats['whip'] ?? 'N/A'}');
      }
      buffer.writeln();
    }

    if (awayPitcher != null) {
      buffer.writeln('${intelligence.awayTeam}:');
      buffer.writeln('  ${awayPitcher['name']}');
      if (awayPitcher['stats'] != null) {
        final stats = awayPitcher['stats'];
        buffer.writeln('  ERA: ${stats['era']}');
        buffer.writeln('  WHIP: ${stats['whip'] ?? 'N/A'}');
      }
    }

    // Add pitching insights
    final pitchingInsights = intelligence.insights.where(
      (i) => i.category == 'pitching_matchup',
    );

    if (pitchingInsights.isNotEmpty) {
      buffer.writeln('\n📊 ANALYSIS:');
      for (final insight in pitchingInsights) {
        buffer.writeln('  • ${insight.message}');
      }
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_pitcher_matchup',
      category: EdgeCardCategory.matchup,
      title: 'Pitcher Matchup',
      teaserText: teaserText,
      fullContent: buffer.toString(),
      metadata: {
        'sport': 'MLB',
        'homePitcher': homePitcher?['name'],
        'awayPitcher': awayPitcher?['name'],
      },
      timestamp: pitcherData.timestamp,
      rarity: EdgeCardRarity.rare,
      badges: [],
      currentCost: 15,
      confidence: pitcherData.confidence,
      impactText: 'Starting pitcher matchup analysis - critical for totals',
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build NHL Goalie Matchup card
  EdgeCardData? _buildGoalieMatchupCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find goalie data
    final goalieDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'goalie_matchup',
    ).toList();

    if (goalieDataPoints.isEmpty) {
      return null;
    }

    final goalieData = goalieDataPoints.last;
    final goalies = goalieData.data;

    // Build teaser
    final homeGoalie = goalies['home'];
    final awayGoalie = goalies['away'];
    final teaserText = '${awayGoalie?['name'] ?? 'TBD'} vs ${homeGoalie?['name'] ?? 'TBD'}';

    // Build content
    final buffer = StringBuffer();
    buffer.writeln('🏒 GOALIE MATCHUP\n');

    if (homeGoalie != null) {
      buffer.writeln('${intelligence.homeTeam}:');
      buffer.writeln('  ${homeGoalie['name']}');
      final svPct = homeGoalie['savePercentage'];
      if (svPct != null) {
        buffer.writeln('  Save %: .${(svPct * 1000).toStringAsFixed(0)}');
      }
      final gaa = homeGoalie['goalsAgainstAverage'];
      if (gaa != null) {
        buffer.writeln('  GAA: ${gaa.toStringAsFixed(2)}');
      }
      buffer.writeln();
    }

    if (awayGoalie != null) {
      buffer.writeln('${intelligence.awayTeam}:');
      buffer.writeln('  ${awayGoalie['name']}');
      final svPct = awayGoalie['savePercentage'];
      if (svPct != null) {
        buffer.writeln('  Save %: .${(svPct * 1000).toStringAsFixed(0)}');
      }
      final gaa = awayGoalie['goalsAgainstAverage'];
      if (gaa != null) {
        buffer.writeln('  GAA: ${gaa.toStringAsFixed(2)}');
      }
    }

    // Add goaltending insights
    final goalieInsights = intelligence.insights.where(
      (i) => i.category == 'goaltending',
    );

    if (goalieInsights.isNotEmpty) {
      buffer.writeln('\n📊 ANALYSIS:');
      for (final insight in goalieInsights) {
        buffer.writeln('  • ${insight.message}');
      }
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_goalie_matchup',
      category: EdgeCardCategory.matchup,
      title: 'Goalie Matchup',
      teaserText: teaserText,
      fullContent: buffer.toString(),
      metadata: {
        'sport': 'NHL',
        'homeGoalie': homeGoalie?['name'],
        'awayGoalie': awayGoalie?['name'],
      },
      timestamp: goalieData.timestamp,
      rarity: EdgeCardRarity.rare,
      badges: [],
      currentCost: 15,
      confidence: goalieData.confidence,
      impactText: 'Goaltending matchup - critical factor for NHL totals',
      isLocked: true,
      expiresAt: gameTime,
    );
  }

  /// Build Fighter Analysis card (MMA/Boxing)
  EdgeCardData? _buildFighterAnalysisCard(
    EdgeIntelligence intelligence,
    DateTime gameTime,
  ) {
    // Find fighter profile data
    final fighterDataPoints = intelligence.dataPoints.where(
      (dp) => dp.type == 'fighter_profiles' || dp.type == 'main_event',
    ).toList();

    if (fighterDataPoints.isEmpty) {
      return null;
    }

    final fighterData = fighterDataPoints.last;

    // Build teaser
    final teaserText = 'Fighter profiles and finishing tendencies';

    // Build content
    final buffer = StringBuffer();
    buffer.writeln('🥊 FIGHTER ANALYSIS\n');

    // Main event details
    if (fighterData.type == 'main_event') {
      final mainEvent = fighterData.data;
      final fighter1 = mainEvent['fighter1'];
      final fighter2 = mainEvent['fighter2'];

      if (fighter1 != null) {
        buffer.writeln('${fighter1['name'] ?? intelligence.awayTeam}:');
        buffer.writeln('  Record: ${fighter1['record'] ?? 'N/A'}');
        buffer.writeln();
      }

      if (fighter2 != null) {
        buffer.writeln('${fighter2['name'] ?? intelligence.homeTeam}:');
        buffer.writeln('  Record: ${fighter2['record'] ?? 'N/A'}');
        buffer.writeln();
      }
    }

    // Fighter insights
    final fighterInsights = intelligence.insights.where(
      (i) => ['finisher', 'ko_threat', 'fighter_stats'].contains(i.category),
    );

    if (fighterInsights.isNotEmpty) {
      buffer.writeln('📊 KEY INSIGHTS:');
      for (final insight in fighterInsights) {
        buffer.writeln('  • ${insight.message}');
      }
    }

    return EdgeCardData(
      id: '${intelligence.eventId}_fighter_analysis',
      category: EdgeCardCategory.matchup,
      title: 'Fighter Analysis',
      teaserText: teaserText,
      fullContent: buffer.toString(),
      metadata: {
        'sport': intelligence.sport,
      },
      timestamp: fighterData.timestamp,
      rarity: EdgeCardRarity.rare,
      badges: [],
      currentCost: 15,
      confidence: fighterData.confidence,
      impactText: 'Fighter records and finishing rates - key for method props',
      isLocked: true,
      expiresAt: gameTime,
    );
  }
}
