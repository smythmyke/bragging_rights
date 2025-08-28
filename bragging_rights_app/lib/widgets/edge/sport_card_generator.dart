import 'edge_card_types.dart';
import '../../services/edge/edge_intelligence_service.dart';

/// Generates Edge Cards from intelligence data for different sports
class SportCardGenerator {
  
  /// Generate cards from EdgeIntelligence data
  static List<EdgeCardData> generateCardsFromIntelligence(
    EdgeIntelligence intelligence,
  ) {
    final cards = <EdgeCardData>[];
    final sport = intelligence.sport.toLowerCase();
    
    // Generate sport-specific cards
    switch (sport) {
      case 'nba':
      case 'basketball':
        cards.addAll(_generateNbaCards(intelligence));
        break;
      case 'nfl':
      case 'football':
        cards.addAll(_generateNflCards(intelligence));
        break;
      case 'mlb':
      case 'baseball':
        cards.addAll(_generateMlbCards(intelligence));
        break;
      case 'nhl':
      case 'hockey':
        cards.addAll(_generateNhlCards(intelligence));
        break;
      case 'mma':
      case 'ufc':
        cards.addAll(_generateMmaCards(intelligence));
        break;
      case 'boxing':
        cards.addAll(_generateBoxingCards(intelligence));
        break;
    }
    
    // Add common cards from insights
    cards.addAll(_generateCommonCards(intelligence));
    
    return cards;
  }
  
  /// Generate NBA-specific cards
  static List<EdgeCardData> _generateNbaCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Check for injuries
    if (data['injuries'] != null && (data['injuries'] as List).isNotEmpty) {
      final injuries = data['injuries'] as List;
      for (final injury in injuries.take(2)) {
        cards.add(EdgeCardData(
          id: 'nba_injury_${DateTime.now().millisecondsSinceEpoch}',
          category: EdgeCardCategory.injury,
          title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.injury, intelligence.homeTeam.split(' ').last),
          teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.injury),
          fullContent: '${injury['player']} - ${injury['status']}\n'
              'Impact: ${injury['impact'] ?? 'Unknown'}\n'
              'Last update: ${injury['lastUpdate'] ?? 'Recently'}',
          metadata: injury as Map<String, dynamic>,
          timestamp: DateTime.now(),
          rarity: EdgeCardRarity.rare,
          badges: [EdgeCardBadge.verified],
          currentCost: 15,
          confidence: 0.85,
          impactText: injury['impact'],
        ));
      }
    }
    
    // Check for rest advantage
    if (data['restAdvantage'] != null) {
      final rest = data['restAdvantage'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'nba_rest_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, intelligence.homeTeam.split(' ').last),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: '${rest['team']} has ${rest['daysRest']} days rest\n'
            'Opponent: ${rest['opponentDaysRest']} days rest\n'
            'Historical win rate with rest advantage: ${rest['winRate'] ?? 'N/A'}%',
        metadata: rest,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.uncommon,
        badges: [],
        currentCost: 10,
        confidence: 0.75,
        impactText: '+${rest['advantage'] ?? 3} pts',
      ));
    }
    
    // Check for clutch performance
    if (data['clutchStats'] != null) {
      final clutch = data['clutchStats'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'nba_clutch_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.clutch,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.clutch, intelligence.homeTeam.split(' ').last),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.clutch),
        fullContent: 'Clutch Net Rating: ${clutch['netRating']}\n'
            'FG% in clutch: ${clutch['fgPercentage']}%\n'
            'Key player: ${clutch['keyPlayer'] ?? 'Team'}\n'
            'Clutch wins: ${clutch['clutchWins'] ?? 0}',
        metadata: clutch,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.uncommon,
        badges: [EdgeCardBadge.trending],
        currentCost: 10,
        confidence: 0.70,
        impactText: clutch['rating'] ?? 'Moderate',
      ));
    }
    
    return cards;
  }
  
  /// Generate NFL-specific cards
  static List<EdgeCardData> _generateNflCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Weather card for NFL
    if (data['weather'] != null) {
      final weather = data['weather'] as Map<String, dynamic>;
      final impact = weather['impact']?.toString() ?? '';
      
      if (impact.contains('HIGH')) {
        cards.add(EdgeCardData(
          id: 'nfl_weather_${DateTime.now().millisecondsSinceEpoch}',
          category: EdgeCardCategory.weather,
          title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.weather, 'Game'),
          teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.weather),
          fullContent: 'Conditions: ${weather['conditions']}\n'
              'Temperature: ${weather['temperature']}°F\n'
              'Wind: ${weather['wind']}\n'
              'Precipitation: ${weather['precipitation']}%\n'
              'Impact: ${weather['impact']}',
          metadata: weather,
          timestamp: DateTime.now(),
          rarity: EdgeCardRarity.rare,
          badges: [EdgeCardBadge.verified, EdgeCardBadge.hot],
          currentCost: 15,
          confidence: 0.90,
          impactText: 'Favor under & running game',
        ));
      }
    }
    
    // QB matchup
    if (data['qbMatchup'] != null) {
      final qb = data['qbMatchup'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'nfl_qb_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, intelligence.homeTeam.split(' ').last),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: 'QB: ${qb['quarterback']}\n'
            'Passer Rating: ${qb['passerRating']}\n'
            'vs Defense Rank: ${qb['defenseRank']}\n'
            'Pressure Rate: ${qb['pressureRate']}%\n'
            'Previous matchups: ${qb['history'] ?? 'N/A'}',
        metadata: qb,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.uncommon,
        badges: [],
        currentCost: 10,
        confidence: 0.75,
        impactText: qb['advantage'] ?? 'Neutral',
      ));
    }
    
    return cards;
  }
  
  /// Generate MLB-specific cards
  static List<EdgeCardData> _generateMlbCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Starting pitcher matchup
    if (data['pitchers'] != null) {
      final pitchers = data['pitchers'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'mlb_pitcher_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, intelligence.homeTeam.split(' ').last),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: 'Home: ${pitchers['home']} (${pitchers['homeERA']} ERA)\n'
            'Away: ${pitchers['away']} (${pitchers['awayERA']} ERA)\n'
            'H2H History: ${pitchers['h2h'] ?? 'No previous matchups'}\n'
            'Recent Form: ${pitchers['recentForm'] ?? 'N/A'}',
        metadata: pitchers,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.rare,
        badges: [EdgeCardBadge.verified],
        currentCost: 15,
        confidence: 0.80,
        impactText: pitchers['advantage'] ?? 'Even matchup',
      ));
    }
    
    // Ballpark factors
    if (data['ballpark'] != null) {
      final park = data['ballpark'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'mlb_park_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, 'Ballpark'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: 'Park: ${park['name']}\n'
            'Type: ${park['type']} park\n'
            'Wind: ${park['wind'] ?? 'N/A'}\n'
            'Impact on runs: ${park['runFactor'] ?? '1.0'}x\n'
            'Best for: ${park['favors'] ?? 'Neutral'}',
        metadata: park,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.common,
        badges: [],
        currentCost: 5,
        confidence: 0.70,
        impactText: park['recommendation'] ?? 'Standard',
      ));
    }
    
    return cards;
  }
  
  /// Generate NHL-specific cards
  static List<EdgeCardData> _generateNhlCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Goalie matchup
    if (data['goalies'] != null) {
      final goalies = data['goalies'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'nhl_goalie_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, intelligence.homeTeam.split(' ').last),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: 'Home: ${goalies['home']} (${goalies['homeSV']} SV%)\n'
            'Away: ${goalies['away']} (${goalies['awaySV']} SV%)\n'
            'Recent form: ${goalies['form'] ?? 'N/A'}\n'
            'H2H record: ${goalies['h2h'] ?? 'First meeting'}',
        metadata: goalies,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.rare,
        badges: [EdgeCardBadge.verified],
        currentCost: 15,
        confidence: 0.85,
        impactText: goalies['edge'] ?? 'Even',
      ));
    }
    
    // Special teams
    if (data['specialTeams'] != null) {
      final special = data['specialTeams'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'nhl_special_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, 'Teams'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: 'Home PP: ${special['homePP']}%\n'
            'Away PK: ${special['awayPK']}%\n'
            'Home PK: ${special['homePK']}%\n'
            'Away PP: ${special['awayPP']}%\n'
            'Expected PP opportunities: ${special['expectedPP'] ?? '4-5'}',
        metadata: special,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.uncommon,
        badges: [],
        currentCost: 10,
        confidence: 0.75,
        impactText: special['advantage'] ?? 'Balanced',
      ));
    }
    
    return cards;
  }
  
  /// Generate MMA-specific cards
  static List<EdgeCardData> _generateMmaCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Fighter profiles
    if (data['fighterProfiles'] != null) {
      final profiles = data['fighterProfiles'] as Map<String, dynamic>;
      profiles.forEach((fighter, profile) {
        if (profile['camp'] != null) {
          cards.add(EdgeCardData(
            id: 'mma_camp_${DateTime.now().millisecondsSinceEpoch}',
            category: EdgeCardCategory.insider,
            title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.insider, fighter),
            teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.insider),
            fullContent: 'Fighter: $fighter\n'
                'Camp: ${profile['camp']}\n'
                'Coach: ${profile['coach'] ?? 'Unknown'}\n'
                'Record: ${profile['record']}\n'
                'Recent form: ${profile['form'] ?? 'N/A'}\n'
                'Preparation: ${profile['preparation'] ?? 'Standard'}',
            metadata: profile as Map<String, dynamic>,
            timestamp: DateTime.now(),
            rarity: EdgeCardRarity.rare,
            badges: [EdgeCardBadge.exclusive],
            currentCost: 15,
            confidence: 0.75,
            impactText: profile['campQuality'] ?? 'Good',
          ));
        }
      });
    }
    
    // Weight cut info
    if (data['weightCut'] != null) {
      final weight = data['weightCut'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'mma_weight_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.insider,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.insider, 'Fight'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.insider),
        fullContent: 'Fighter: ${weight['fighter']}\n'
            'Weight: ${weight['weight']} lbs\n'
            'Cut difficulty: ${weight['difficulty'] ?? 'Normal'}\n'
            'Hydration: ${weight['hydration'] ?? 'Unknown'}\n'
            'Previous cuts: ${weight['history'] ?? 'N/A'}',
        metadata: weight,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.epic,
        badges: [EdgeCardBadge.breaking, EdgeCardBadge.verified],
        currentCost: 20,
        confidence: 0.80,
        impactText: weight['impact'] ?? 'Minimal',
      ));
    }
    
    return cards;
  }
  
  /// Generate Boxing-specific cards
  static List<EdgeCardData> _generateBoxingCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    final data = intelligence.data;
    
    // Belt implications
    if (data['beltImplications'] != null && 
        (data['beltImplications'] as List).isNotEmpty) {
      final belts = data['beltImplications'] as List;
      cards.add(EdgeCardData(
        id: 'boxing_belts_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.breaking,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.breaking, 'Title'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.breaking),
        fullContent: belts.map((b) => '• ${b['belts'].join(', ')}').join('\n'),
        metadata: {'belts': belts},
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.legendary,
        badges: [EdgeCardBadge.exclusive, EdgeCardBadge.verified],
        currentCost: 20,
        confidence: 1.0,
        impactText: 'Title fight',
      ));
    }
    
    // Judge analysis
    if (data['judgeAnalysis'] != null) {
      final judges = data['judgeAnalysis'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'boxing_judges_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.insider,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.insider, 'Officials'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.insider),
        fullContent: 'Analysis: ${judges['note']}\n'
            'Recommendation: ${judges['recommendation']}\n'
            'Historical bias: ${judges['bias'] ?? 'None detected'}',
        metadata: judges,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.rare,
        badges: [EdgeCardBadge.exclusive],
        currentCost: 15,
        confidence: 0.65,
        impactText: 'Decision betting factor',
      ));
    }
    
    // Style matchup
    if (data['styleMatchup'] != null) {
      final styles = data['styleMatchup'] as Map<String, dynamic>;
      cards.add(EdgeCardData(
        id: 'boxing_style_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.matchup, 'Fighters'),
        teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.matchup),
        fullContent: styles.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n'),
        metadata: styles,
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.uncommon,
        badges: [],
        currentCost: 10,
        confidence: 0.70,
        impactText: 'Tactical advantage',
      ));
    }
    
    return cards;
  }
  
  /// Generate common cards from insights
  static List<EdgeCardData> _generateCommonCards(EdgeIntelligence intelligence) {
    final cards = <EdgeCardData>[];
    
    // Convert insights to cards
    for (final insight in intelligence.insights) {
      EdgeCardCategory category;
      EdgeCardRarity rarity;
      List<EdgeCardBadge> badges = [];
      
      // Map insight type to card category
      switch (insight.type) {
        case 'injury':
        case 'injury_report':
          category = EdgeCardCategory.injury;
          rarity = EdgeCardRarity.rare;
          badges = [EdgeCardBadge.verified];
          break;
        case 'weather':
        case 'weather_impact':
          category = EdgeCardCategory.weather;
          rarity = EdgeCardRarity.uncommon;
          badges = [EdgeCardBadge.verified];
          break;
        case 'breaking':
        case 'news':
          category = EdgeCardCategory.breaking;
          rarity = EdgeCardRarity.epic;
          badges = [EdgeCardBadge.breaking, EdgeCardBadge.newItem];
          break;
        case 'betting':
        case 'line_movement':
          category = EdgeCardCategory.betting;
          rarity = EdgeCardRarity.rare;
          badges = [EdgeCardBadge.trending];
          break;
        case 'social':
        case 'reddit':
          category = EdgeCardCategory.social;
          rarity = EdgeCardRarity.common;
          badges = [EdgeCardBadge.hot];
          break;
        default:
          category = EdgeCardCategory.matchup;
          rarity = EdgeCardRarity.uncommon;
          badges = [];
      }
      
      // Skip if confidence too low
      if (insight.confidence < 0.5) continue;
      
      // Get team name for title (use home team as default)
      final teamName = intelligence.homeTeam.split(' ').last; // Get last word (e.g., "Lakers" from "Los Angeles Lakers")
      
      cards.add(EdgeCardData(
        id: 'insight_${insight.type}_${DateTime.now().millisecondsSinceEpoch}',
        category: category,
        title: EdgeCardConfigs.getObfuscatedTitle(category, teamName),
        teaserText: EdgeCardConfigs.getGenericTeaser(category),
        fullContent: insight.message,
        metadata: insight.data ?? {},
        timestamp: DateTime.now(),
        rarity: rarity,
        badges: badges,
        currentCost: EdgeCardConfigs.getConfig(category).baseCost,
        confidence: insight.confidence,
        impactText: insight.data?['impact']?.toString(),
      ));
    }
    
    // Add social sentiment if available
    if (intelligence.data['reddit'] != null) {
      final reddit = intelligence.data['reddit'] as Map<String, dynamic>;
      if (reddit['fanExcitement'] != null) {
        final excitement = reddit['fanExcitement'] as double;
        cards.add(EdgeCardData(
          id: 'social_reddit_${DateTime.now().millisecondsSinceEpoch}',
          category: EdgeCardCategory.social,
          title: EdgeCardConfigs.getObfuscatedTitle(EdgeCardCategory.social, intelligence.homeTeam.split(' ').last),
          teaserText: EdgeCardConfigs.getGenericTeaser(EdgeCardCategory.social),
          fullContent: 'Reddit community engagement:\n'
              'Excitement level: ${(excitement * 100).toInt()}%\n'
              'Trending topics: ${reddit['trendingTopics']?.join(', ') ?? 'N/A'}\n'
              'Sentiment: ${reddit['sentiment'] ?? 'Mixed'}',
          metadata: reddit,
          timestamp: DateTime.now(),
          rarity: excitement > 0.8 
              ? EdgeCardRarity.rare 
              : EdgeCardRarity.common,
          badges: excitement > 0.7 
              ? [EdgeCardBadge.hot, EdgeCardBadge.trending]
              : [EdgeCardBadge.trending],
          currentCost: 5,
          confidence: 0.60,
          impactText: excitement > 0.7 ? 'High interest' : 'Normal',
        ));
      }
    }
    
    return cards;
  }
}