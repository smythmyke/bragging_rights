import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sports/nba_service.dart';
import 'sports/nhl_api_service.dart';
import 'sports/espn_nhl_service.dart';
import 'sports/espn_nfl_service.dart';
import 'sports/espn_mlb_service.dart';
import 'sports/espn_mma_service.dart';
import 'sports/espn_boxing_service.dart';
import 'news/news_api_service.dart';
import 'social/reddit_service.dart';
import 'event_matcher.dart';

/// Edge Intelligence Service
/// Aggregates data from all sources and provides actionable insights
class EdgeIntelligenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventMatcher _matcher = EventMatcher();
  
  // Sport-specific services
  final NbaService _nbaService = NbaService();
  final NhlApiService _nhlApiService = NhlApiService();
  final EspnNhlService _espnNhlService = EspnNhlService();
  final EspnNflService _espnNflService = EspnNflService();
  final EspnMlbService _espnMlbService = EspnMlbService();
  final EspnMmaService _espnMmaService = EspnMmaService();
  final EspnBoxingService _espnBoxingService = EspnBoxingService();
  final NewsApiService _newsService = NewsApiService();
  final RedditService _redditService = RedditService();

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
      case 'mma':
      case 'ufc':
      case 'bellator':
      case 'pfl':
      case 'one':
      case 'bkfc':
        await _gatherMmaIntelligence(intelligence, eventId, sport);
        break;
      case 'boxing':
        await _gatherBoxingIntelligence(intelligence, eventId);
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

  /// Gather NFL intelligence
  Future<void> _gatherNflIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    debugPrint('🏈 Gathering NFL intelligence for ${intelligence.homeTeam} vs ${intelligence.awayTeam}');
    
    try {
      // Get ESPN NFL data (primary source for NFL)
      final espnData = await _espnNflService.getGameIntelligence(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
      );
      
      if (espnData.isNotEmpty) {
        // Add betting odds
        if (espnData['odds'] != null && espnData['odds'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN NFL',
            type: 'betting_odds',
            data: espnData['odds'],
            confidence: 0.95,
          );
          
          // Add spread insight
          final spread = espnData['odds']['spread'];
          if (spread != null) {
            intelligence.addInsight(
              category: 'betting_line',
              insight: 'Spread: $spread',
              impact: 'medium',
            );
          }
        }
        
        // CRITICAL FOR NFL: Weather data
        if (espnData['weather'] != null && espnData['weather'].isNotEmpty) {
          final weather = espnData['weather'];
          intelligence.addDataPoint(
            source: 'ESPN Weather',
            type: 'weather_conditions',
            data: weather,
            confidence: 0.90,
          );
          
          // Add weather impact insight
          final impact = weather['impact'] ?? '';
          if (impact.contains('HIGH')) {
            intelligence.addInsight(
              category: 'weather',
              insight: impact,
              impact: 'high',
            );
            
            // Weather-based betting suggestion
            if (impact.contains('wind') || impact.contains('rain')) {
              intelligence.predictions['weatherAlert'] = {
                'condition': weather['conditions'],
                'suggestion': 'Consider UNDER total points',
                'reasoning': 'Adverse weather typically reduces scoring',
              };
            }
          } else if (impact.contains('MEDIUM')) {
            intelligence.addInsight(
              category: 'weather',
              insight: impact,
              impact: 'medium',
            );
          }
        }
        
        // Add injuries (crucial for NFL)
        if (espnData['injuries'] != null && espnData['injuries'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN NFL',
            type: 'injury_report',
            data: espnData['injuries'],
            confidence: 0.85,
          );
          
          // Count significant injuries
          final injuries = espnData['injuries'] as List;
          if (injuries.length > 2) {
            intelligence.addInsight(
              category: 'injuries',
              insight: '${injuries.length} players on injury report',
              impact: 'high',
            );
          }
          
          // Check for QB injuries (highest impact)
          for (final injury in injuries) {
            final note = injury['note'] ?? injury['headline'] ?? '';
            if (note.toLowerCase().contains('quarterback') || 
                note.toLowerCase().contains(' qb ')) {
              intelligence.addInsight(
                category: 'injuries',
                insight: 'QB injury concern: $note',
                impact: 'high',
              );
            }
          }
        }
        
        // Add team stats and recent form
        if (espnData['teamStats'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN NFL',
            type: 'team_statistics',
            data: espnData['teamStats'],
            confidence: 0.85,
          );
          
          // Analyze offensive efficiency
          final homeStats = espnData['teamStats']['home'] ?? {};
          final awayStats = espnData['teamStats']['away'] ?? {};
          
          if (homeStats['pointsPerGame'] != null) {
            final ppg = homeStats['pointsPerGame'];
            if (ppg > 28) {
              intelligence.addInsight(
                category: 'offense',
                insight: '${intelligence.homeTeam} high-powered offense (${ppg} PPG)',
                impact: 'high',
              );
            }
          }
          
          // Red zone efficiency
          if (homeStats['redZonePct'] != null) {
            final rzPct = homeStats['redZonePct'];
            if (rzPct > 65) {
              intelligence.addInsight(
                category: 'red_zone',
                insight: '${intelligence.homeTeam} elite in red zone ($rzPct%)',
                impact: 'medium',
              );
            }
          }
        }
        
        // Add recent form
        if (espnData['recentForm'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN NFL',
            type: 'recent_form',
            data: espnData['recentForm'],
            confidence: 0.80,
          );
          
          // Home field advantage
          final homeForm = espnData['recentForm']['home'] ?? {};
          if (homeForm['homeRecord'] != null) {
            intelligence.addInsight(
              category: 'home_advantage',
              insight: 'Home record: ${homeForm['homeRecord']}',
              impact: 'medium',
            );
          }
          
          // Check streaks
          if (homeForm['streak'] != null && homeForm['streak'] > 3) {
            intelligence.addInsight(
              category: 'momentum',
              insight: '${intelligence.homeTeam} on ${homeForm['streak']}-game win streak',
              impact: 'high',
            );
          }
        }
        
        // Add key matchups
        if (espnData['keyMatchups'] != null && espnData['keyMatchups'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN NFL',
            type: 'key_matchups',
            data: espnData['keyMatchups'],
            confidence: 0.75,
          );
          
          for (final matchup in espnData['keyMatchups']) {
            if (matchup['impact'] == 'high') {
              intelligence.addInsight(
                category: 'matchup',
                insight: matchup['description'],
                impact: matchup['impact'],
              );
            }
          }
        }
      }
      
      // Get NFL news
      final newsData = await _newsService.getGameNews(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'NFL',
      );
      
      if (newsData != null && newsData['articles'] != null && (newsData['articles'] as List).isNotEmpty) {
        final articles = newsData['articles'] as List;
        intelligence.addDataPoint(
          source: 'NewsAPI',
          type: 'recent_news',
          data: {
            'articleCount': articles.length,
            'headlines': articles.take(3).map((a) => a['title']).toList(),
          },
          confidence: 0.75,
        );
      }
      
      // Get Reddit sentiment from r/nfl
      final redditData = await _redditService.getGameIntelligence(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'nfl',
        gameDate: intelligence.eventDate,
      );
      
      if (redditData.isNotEmpty) {
        intelligence.addDataPoint(
          source: 'Reddit r/nfl',
          type: 'fan_sentiment',
          data: redditData,
          confidence: 0.70,
        );
      }
      
      // NFL-specific predictions
      intelligence.predictions = intelligence.predictions.isEmpty 
        ? {'suggestedBets': [], 'confidence': 0.0}
        : intelligence.predictions;
        
      // Add suggested bets based on insights
      final suggestions = intelligence.predictions['suggestedBets'] as List? ?? [];
      
      // Weather-based suggestions
      if (intelligence.insights.any((i) => i.category == 'weather' && i.impact == 'high')) {
        suggestions.add({
          'type': 'Under Total Points',
          'reasoning': 'Weather conditions favor lower scoring',
          'confidence': 0.85,
        });
        suggestions.add({
          'type': 'Running Game Props',
          'reasoning': 'Teams likely to run more in bad weather',
          'confidence': 0.80,
        });
      }
      
      // Home advantage suggestion
      if (intelligence.insights.any((i) => i.category == 'home_advantage')) {
        suggestions.add({
          'type': 'Home Team Spread',
          'reasoning': 'Strong home field advantage',
          'confidence': 0.75,
        });
      }
      
      // Injury-based suggestions
      if (intelligence.insights.any((i) => i.category == 'injuries' && i.insight.contains('QB'))) {
        suggestions.add({
          'type': 'Fade Injured Team',
          'reasoning': 'Starting QB injury significantly impacts performance',
          'confidence': 0.90,
        });
      }
      
      intelligence.predictions['suggestedBets'] = suggestions;
      intelligence.predictions['confidence'] = intelligence.overallConfidence;
      
    } catch (e) {
      debugPrint('Error gathering NFL intelligence: $e');
      intelligence.addDataPoint(
        source: 'System',
        type: 'error',
        data: {'error': e.toString()},
        confidence: 0.0,
      );
    }
  }

  /// Gather MLB intelligence
  Future<void> _gatherMlbIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    debugPrint('⚾ Gathering MLB intelligence for ${intelligence.homeTeam} vs ${intelligence.awayTeam}');
    
    try {
      // Get ESPN MLB data
      final espnData = await _espnMlbService.getGameIntelligence(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
      );
      
      if (espnData.isNotEmpty) {
        // CRITICAL FOR MLB: Starting pitchers
        if (espnData['startingPitchers'] != null && espnData['startingPitchers'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'starting_pitchers',
            data: espnData['startingPitchers'],
            confidence: 0.95,
          );
          
          // Add pitcher insights
          final homePitcher = espnData['startingPitchers']['home'];
          final awayPitcher = espnData['startingPitchers']['away'];
          
          if (homePitcher != null && homePitcher['stats'] != null) {
            final era = homePitcher['stats']['era'];
            if (era != null && era != 'N/A') {
              final eraValue = double.tryParse(era.toString()) ?? 99.0;
              if (eraValue < 3.0) {
                intelligence.addInsight(
                  category: 'pitching_matchup',
                  insight: '${homePitcher['name']} dealing (${era} ERA)',
                  impact: 'high',
                );
              } else if (eraValue > 5.0) {
                intelligence.addInsight(
                  category: 'pitching_matchup',
                  insight: '${homePitcher['name']} struggling (${era} ERA)',
                  impact: 'high',
                );
              }
            }
          }
          
          if (awayPitcher != null && awayPitcher['stats'] != null) {
            final era = awayPitcher['stats']['era'];
            if (era != null && era != 'N/A') {
              final eraValue = double.tryParse(era.toString()) ?? 99.0;
              if (eraValue < 3.0) {
                intelligence.addInsight(
                  category: 'pitching_matchup',
                  insight: '${awayPitcher['name']} dealing (${era} ERA)',
                  impact: 'high',
                );
              }
            }
          }
        }
        
        // Add betting odds
        if (espnData['odds'] != null && espnData['odds'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'betting_odds',
            data: espnData['odds'],
            confidence: 0.95,
          );
        }
        
        // Weather impact (crucial for MLB)
        if (espnData['weather'] != null && espnData['weather'].isNotEmpty) {
          final weather = espnData['weather'];
          intelligence.addDataPoint(
            source: 'ESPN Weather',
            type: 'weather_conditions',
            data: weather,
            confidence: 0.90,
          );
          
          // Wind is critical in baseball
          if (weather['wind'] != null) {
            final wind = weather['wind'] as Map<String, dynamic>;
            final windDirection = wind['direction'] ?? '';
            final windSpeed = wind['speed'] ?? 0;
            
            if (windDirection == 'Out' && windSpeed > 10) {
              intelligence.addInsight(
                category: 'weather',
                insight: 'Wind blowing out ${windSpeed} mph - ball will carry',
                impact: 'high',
              );
              
              // Betting suggestion
              intelligence.predictions['weatherSuggestion'] = {
                'condition': 'Wind out',
                'suggestion': 'Consider OVER total runs',
                'confidence': 0.80,
              };
            } else if (windDirection == 'In' && windSpeed > 10) {
              intelligence.addInsight(
                category: 'weather',
                insight: 'Wind blowing in ${windSpeed} mph - fly balls held up',
                impact: 'high',
              );
              
              intelligence.predictions['weatherSuggestion'] = {
                'condition': 'Wind in',
                'suggestion': 'Consider UNDER total runs',
                'confidence': 0.80,
              };
            }
          }
          
          // Temperature impact
          final temp = int.tryParse(weather['temperature']?.toString() ?? '72') ?? 72;
          if (temp > 90) {
            intelligence.addInsight(
              category: 'weather',
              insight: 'Hot weather (${temp}°F) - ball carries further',
              impact: 'medium',
            );
          } else if (temp < 50) {
            intelligence.addInsight(
              category: 'weather',
              insight: 'Cold weather (${temp}°F) - ball doesn\'t carry',
              impact: 'medium',
            );
          }
        }
        
        // Ballpark factors
        if (espnData['ballparkFactors'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'ballpark_factors',
            data: espnData['ballparkFactors'],
            confidence: 0.85,
          );
          
          final parkType = espnData['ballparkFactors']['type'];
          if (parkType == 'Hitters Park') {
            intelligence.addInsight(
              category: 'ballpark',
              insight: '${espnData['ballparkFactors']['name']} favors hitters',
              impact: 'medium',
            );
          } else if (parkType == 'Pitchers Park') {
            intelligence.addInsight(
              category: 'ballpark',
              insight: '${espnData['ballparkFactors']['name']} favors pitchers',
              impact: 'medium',
            );
          }
        }
        
        // Team stats and recent form
        if (espnData['keyStats'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'team_statistics',
            data: espnData['keyStats'],
            confidence: 0.85,
          );
          
          // Check batting averages
          final homeStats = espnData['keyStats']['home'] ?? {};
          final awayStats = espnData['keyStats']['away'] ?? {};
          
          if (homeStats['battingAverage'] != null) {
            final avg = double.tryParse(homeStats['battingAverage'].toString()) ?? 0;
            if (avg > .270) {
              intelligence.addInsight(
                category: 'offense',
                insight: '${intelligence.homeTeam} hitting well (.${(avg * 1000).toStringAsFixed(0)})',
                impact: 'medium',
              );
            }
          }
        }
        
        // Recent form
        if (espnData['recentForm'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'recent_form',
            data: espnData['recentForm'],
            confidence: 0.80,
          );
          
          // Check last 10 games
          final homeForm = espnData['recentForm']['home'] ?? {};
          if (homeForm['last10'] != null) {
            final parts = homeForm['last10'].split('-');
            if (parts.length == 2) {
              final wins = int.tryParse(parts[0]) ?? 0;
              if (wins >= 7) {
                intelligence.addInsight(
                  category: 'momentum',
                  insight: '${intelligence.homeTeam} hot (${homeForm['last10']} last 10)',
                  impact: 'medium',
                );
              } else if (wins <= 3) {
                intelligence.addInsight(
                  category: 'momentum',
                  insight: '${intelligence.homeTeam} cold (${homeForm['last10']} last 10)',
                  impact: 'medium',
                );
              }
            }
          }
        }
        
        // Injuries
        if (espnData['injuries'] != null && espnData['injuries'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'injury_report',
            data: espnData['injuries'],
            confidence: 0.85,
          );
        }
        
        // Game situation (if live)
        if (espnData['gameSituation'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MLB',
            type: 'game_situation',
            data: espnData['gameSituation'],
            confidence: 0.95,
          );
        }
      }
      
      // Get MLB news
      final newsData = await _newsService.getGameNews(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'MLB',
      );
      
      if (newsData != null && newsData['articles'] != null && (newsData['articles'] as List).isNotEmpty) {
        final articles = newsData['articles'] as List;
        intelligence.addDataPoint(
          source: 'NewsAPI',
          type: 'recent_news',
          data: {
            'articleCount': articles.length,
            'headlines': articles.take(3).map((a) => a['title']).toList(),
          },
          confidence: 0.75,
        );
      }
      
      // Get Reddit sentiment from r/baseball
      final redditData = await _redditService.getGameIntelligence(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'mlb',
        gameDate: intelligence.eventDate,
      );
      
      if (redditData.isNotEmpty) {
        intelligence.addDataPoint(
          source: 'Reddit r/baseball',
          type: 'fan_sentiment',
          data: redditData,
          confidence: 0.70,
        );
      }
      
      // MLB-specific predictions
      intelligence.predictions = intelligence.predictions.isEmpty 
        ? {'suggestedBets': [], 'confidence': 0.0}
        : intelligence.predictions;
        
      final suggestions = intelligence.predictions['suggestedBets'] as List? ?? [];
      
      // Pitcher-based suggestions
      if (intelligence.insights.any((i) => 
          i.category == 'pitching_matchup' && 
          i.insight.contains('dealing'))) {
        suggestions.add({
          'type': 'Under Total Runs',
          'reasoning': 'Elite pitching matchup',
          'confidence': 0.85,
        });
      }
      
      // Wind-based suggestions (already added above)
      
      // Ballpark-based suggestions
      if (intelligence.insights.any((i) => 
          i.category == 'ballpark' && 
          i.insight.contains('hitters'))) {
        suggestions.add({
          'type': 'Over Total Runs',
          'reasoning': 'Hitters park advantage',
          'confidence': 0.70,
        });
      }
      
      // Day game suggestion
      final hour = DateTime.now().hour;
      if (hour < 16) {
        suggestions.add({
          'type': 'Check Day/Night Splits',
          'reasoning': 'Day games often play differently',
          'confidence': 0.60,
        });
      }
      
      intelligence.predictions['suggestedBets'] = suggestions;
      intelligence.predictions['confidence'] = intelligence.overallConfidence;
      
    } catch (e) {
      debugPrint('Error gathering MLB intelligence: $e');
      intelligence.addDataPoint(
        source: 'System',
        type: 'error',
        data: {'error': e.toString()},
        confidence: 0.0,
      );
    }
  }

  /// Gather NHL intelligence
  Future<void> _gatherNhlIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    debugPrint('🏒 Gathering NHL intelligence for ${intelligence.homeTeam} vs ${intelligence.awayTeam}');
    
    try {
      // Get NHL Official API data
      final nhlData = await _nhlApiService.getGameIntelligence(
        gameId: eventId,
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
      );
      
      if (nhlData.isNotEmpty) {
        // Add game stats
        if (nhlData['gameData'] != null) {
          intelligence.addDataPoint(
            source: 'NHL Official API',
            type: 'game_data',
            data: nhlData['gameData'],
            confidence: 0.95,
          );
        }
        
        // Add team stats
        if (nhlData['teamStats'] != null) {
          intelligence.addDataPoint(
            source: 'NHL Official API',
            type: 'team_stats',
            data: nhlData['teamStats'],
            confidence: 0.90,
          );
          
          // Extract key insights
          final homeStats = nhlData['teamStats']['home'] ?? {};
          final awayStats = nhlData['teamStats']['away'] ?? {};
          
          // Power play efficiency
          if (homeStats['powerPlayPercentage'] != null) {
            final ppPct = homeStats['powerPlayPercentage'];
            if (ppPct > 25) {
              intelligence.addInsight(
                category: 'special_teams',
                insight: '${intelligence.homeTeam} has elite power play (${ppPct.toStringAsFixed(1)}%)',
                impact: 'high',
              );
            }
          }
          
          // Penalty kill
          if (awayStats['penaltyKillPercentage'] != null) {
            final pkPct = awayStats['penaltyKillPercentage'];
            if (pkPct < 75) {
              intelligence.addInsight(
                category: 'special_teams',
                insight: '${intelligence.awayTeam} struggling on penalty kill (${pkPct.toStringAsFixed(1)}%)',
                impact: 'medium',
              );
            }
          }
        }
        
        // Add player stats (injuries, hot/cold streaks)
        if (nhlData['playerStats'] != null) {
          intelligence.addDataPoint(
            source: 'NHL Official API',
            type: 'player_stats',
            data: nhlData['playerStats'],
            confidence: 0.85,
          );
        }
        
        // Goalie matchup is crucial in NHL
        if (nhlData['goalieMatchup'] != null) {
          intelligence.addDataPoint(
            source: 'NHL Official API',
            type: 'goalie_matchup',
            data: nhlData['goalieMatchup'],
            confidence: 0.90,
          );
          
          final homeGoalie = nhlData['goalieMatchup']['home'];
          final awayGoalie = nhlData['goalieMatchup']['away'];
          
          if (homeGoalie != null && homeGoalie['savePercentage'] != null) {
            final svPct = homeGoalie['savePercentage'];
            if (svPct > 0.920) {
              intelligence.addInsight(
                category: 'goaltending',
                insight: '${homeGoalie['name']} is hot (.${(svPct * 1000).toStringAsFixed(0)} SV%)',
                impact: 'high',
              );
            }
          }
        }
      }
      
      // Get ESPN NHL data for odds and additional info
      final espnData = await _espnNhlService.getGameIntelligence(
        gameId: eventId,
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
      );
      
      if (espnData.isNotEmpty) {
        // Add betting lines
        if (espnData['odds'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN NHL',
            type: 'betting_odds',
            data: espnData['odds'],
            confidence: 0.95,
          );
        }
        
        // Add injuries
        if (espnData['injuries'] != null && espnData['injuries'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN NHL',
            type: 'injuries',
            data: espnData['injuries'],
            confidence: 0.90,
          );
          
          // Check for key player injuries
          final injuries = espnData['injuries'] as List;
          for (final injury in injuries) {
            if (injury['impact'] == 'high') {
              intelligence.addInsight(
                category: 'injuries',
                insight: '${injury['player']} ${injury['status']} - ${injury['description']}',
                impact: 'high',
              );
            }
          }
        }
        
        // Recent form
        if (espnData['recentForm'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN NHL',
            type: 'recent_form',
            data: espnData['recentForm'],
            confidence: 0.85,
          );
          
          // Check for hot/cold streaks
          final homeForm = espnData['recentForm']['home'];
          final awayForm = espnData['recentForm']['away'];
          
          if (homeForm != null && homeForm['last10'] != null) {
            final wins = homeForm['last10']['wins'] ?? 0;
            if (wins >= 7) {
              intelligence.addInsight(
                category: 'momentum',
                insight: '${intelligence.homeTeam} on fire (${wins}-${10-wins} last 10)',
                impact: 'high',
              );
            }
          }
        }
      }
      
      // Get news for both teams
      final newsData = await _newsService.getGameNews(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'NHL',
      );
      
      if (newsData != null && newsData['articles'] != null && (newsData['articles'] as List).isNotEmpty) {
        final articles = newsData['articles'] as List;
        intelligence.addDataPoint(
          source: 'NewsAPI',
          type: 'recent_news',
          data: {
            'articleCount': articles.length,
            'headlines': articles.take(3).map((a) => a['title']).toList(),
          },
          confidence: 0.75,
        );
      }
      
      // Get Reddit sentiment
      final redditData = await _redditService.getGameIntelligence(
        homeTeam: intelligence.homeTeam,
        awayTeam: intelligence.awayTeam,
        sport: 'nhl',
        gameDate: intelligence.eventDate,
      );
      
      if (redditData.isNotEmpty) {
        intelligence.addDataPoint(
          source: 'Reddit r/hockey',
          type: 'fan_sentiment',
          data: redditData,
          confidence: 0.70,
        );
        
        // Add fan confidence insight
        if (redditData['fanConfidence'] != null) {
          final confidence = redditData['fanConfidence'];
          if (confidence['homeFanConfidence'] != null && 
              confidence['homeFanConfidence'] > 0.75) {
            intelligence.addInsight(
              category: 'social_sentiment',
              insight: '${intelligence.homeTeam} fans very confident',
              impact: 'low',
            );
          }
        }
      }
      
      // NHL-specific predictions
      intelligence.predictions = {
        'suggestedBets': [],
        'confidence': intelligence.overallConfidence,
      };
      
      // Add suggested bets based on insights
      if (intelligence.insights.any((i) => i.category == 'goaltending' && i.impact == 'high')) {
        intelligence.predictions['suggestedBets'].add({
          'type': 'Under Total Goals',
          'reasoning': 'Elite goaltending performance expected',
        });
      }
      
      if (intelligence.insights.any((i) => i.category == 'special_teams')) {
        intelligence.predictions['suggestedBets'].add({
          'type': 'Team Total Goals',
          'reasoning': 'Power play advantage identified',
        });
      }
      
    } catch (e) {
      debugPrint('Error gathering NHL intelligence: $e');
      intelligence.addDataPoint(
        source: 'System',
        type: 'error',
        data: {'error': e.toString()},
        confidence: 0.0,
      );
    }
  }

  /// Gather MMA/Combat Sports intelligence
  Future<void> _gatherMmaIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
    String promotion,
  ) async {
    debugPrint('🥊 Gathering MMA intelligence for ${intelligence.homeTeam}');
    
    // For MMA, we use event name instead of team vs team
    // The homeTeam field contains the event name (e.g., "UFC 295")
    final eventName = intelligence.homeTeam;
    
    // Determine promotion from sport parameter
    final mmaPromotion = promotion.toLowerCase() == 'mma' ? 'ufc' : promotion.toLowerCase();
    
    try {
      // Get MMA event data
      final mmaData = await _espnMmaService.getEventIntelligence(
        eventName: eventName,
        promotion: mmaPromotion,
      );
      
      if (mmaData.isNotEmpty) {
        // Add main event intelligence
        if (mmaData['mainEvent'] != null && mmaData['mainEvent'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'main_event',
            data: mmaData['mainEvent'],
            confidence: 0.95,
          );
          
          // Extract main event fighters
          final fighter1 = mmaData['mainEvent']['fighter1'];
          final fighter2 = mmaData['mainEvent']['fighter2'];
          
          if (fighter1 != null && fighter2 != null) {
            intelligence.addInsight(
              category: 'main_event',
              insight: '${fighter1['name']} (${fighter1['record']}) vs ${fighter2['name']} (${fighter2['record']})',
              impact: 'high',
            );
            
            // Add odds insight if available
            if (mmaData['mainEvent']['odds'] != null) {
              final odds = mmaData['mainEvent']['odds'];
              intelligence.addInsight(
                category: 'betting_line',
                insight: 'Odds: ${fighter1['name']} ${odds['fighter1']} | ${fighter2['name']} ${odds['fighter2']}',
                impact: 'medium',
              );
            }
          }
          
          // Championship fight insight
          if (mmaData['mainEvent']['rounds'] == 5) {
            intelligence.addInsight(
              category: 'championship',
              insight: '5-round championship fight - cardio crucial',
              impact: 'high',
            );
          }
        }
        
        // Add co-main event
        if (mmaData['coMainEvent'] != null && mmaData['coMainEvent'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'co_main_event',
            data: mmaData['coMainEvent'],
            confidence: 0.90,
          );
        }
        
        // Add main card fights
        if (mmaData['mainCard'] != null && mmaData['mainCard'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'main_card',
            data: mmaData['mainCard'],
            confidence: 0.85,
          );
          
          intelligence.addInsight(
            category: 'card_depth',
            insight: '${mmaData['mainCard'].length} fights on main card',
            impact: 'low',
          );
        }
        
        // Add fighter profiles if available
        if (mmaData['fighterProfiles'] != null && mmaData['fighterProfiles'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'fighter_profiles',
            data: mmaData['fighterProfiles'],
            confidence: 0.85,
          );
          
          // Analyze fighter stats for insights
          for (final profile in mmaData['fighterProfiles'].values) {
            if (profile['stats'] != null) {
              // Check for high finish rate fighters
              final finishRate = profile['stats']['finishRate'];
              if (finishRate != null && finishRate > 70) {
                intelligence.addInsight(
                  category: 'finisher',
                  insight: '${profile['name']} has ${finishRate}% finish rate',
                  impact: 'medium',
                );
              }
            }
          }
        }
        
        // Add camp intelligence
        if (mmaData['campIntelligence'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'camp_analysis',
            data: mmaData['campIntelligence'],
            confidence: 0.75,
          );
          
          // Add top camp insights
          if (mmaData['campIntelligence']['topCamps'] != null) {
            intelligence.addInsight(
              category: 'camps',
              insight: 'Elite camps represented on this card',
              impact: 'low',
            );
          }
        }
        
        // Add betting lines
        if (mmaData['bettingLines'] != null && mmaData['bettingLines'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'betting_odds',
            data: mmaData['bettingLines'],
            confidence: 0.95,
          );
        }
        
        // Add weigh-in report
        if (mmaData['weighInReport'] != null) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'weigh_in',
            data: mmaData['weighInReport'],
            confidence: 0.90,
          );
          
          // Check for weight cutting issues
          final concerns = mmaData['weighInReport']['concerns'] ?? [];
          if (concerns.isNotEmpty) {
            intelligence.addInsight(
              category: 'weight_cut',
              insight: 'Weight cutting concerns reported',
              impact: 'high',
            );
          }
        }
        
        // Add injury report
        if (mmaData['injuryReport'] != null && mmaData['injuryReport'].isNotEmpty) {
          intelligence.addDataPoint(
            source: 'ESPN MMA',
            type: 'injuries',
            data: mmaData['injuryReport'],
            confidence: 0.85,
          );
          
          intelligence.addInsight(
            category: 'injuries',
            insight: '${mmaData['injuryReport'].length} injury concerns on card',
            impact: 'medium',
          );
        }
        
        // Add MMA-specific insights from the service
        if (mmaData['insights'] != null) {
          for (final insight in mmaData['insights']) {
            intelligence.addInsight(
              category: insight['category'] ?? 'general',
              insight: insight['insight'] ?? '',
              impact: insight['confidence'] > 0.8 ? 'high' : 'medium',
            );
          }
        }
      }
      
      // Get MMA news
      final newsData = await _newsService.getGameNews(
        homeTeam: eventName, // Use event name for news search
        awayTeam: '',
        sport: mmaPromotion.toUpperCase(),
      );
      
      if (newsData != null && newsData['articles'] != null && (newsData['articles'] as List).isNotEmpty) {
        final articles = newsData['articles'] as List;
        intelligence.addDataPoint(
          source: 'NewsAPI',
          type: 'recent_news',
          data: {
            'articleCount': articles.length,
            'headlines': articles.take(3).map((a) => a['title']).toList(),
          },
          confidence: 0.75,
        );
      }
      
      // Get Reddit sentiment from r/MMA
      final redditData = await _redditService.getGameIntelligence(
        homeTeam: eventName,
        awayTeam: '', // No away team for MMA
        sport: 'mma',
        gameDate: intelligence.eventDate,
      );
      
      if (redditData.isNotEmpty) {
        intelligence.addDataPoint(
          source: 'Reddit r/MMA',
          type: 'fan_sentiment',
          data: redditData,
          confidence: 0.70,
        );
        
        // Add fan sentiment insights
        if (redditData['homeSentiment'] != null) {
          final sentiment = redditData['homeSentiment']['overall'];
          if (sentiment == 'positive') {
            intelligence.addInsight(
              category: 'social',
              insight: 'Fans excited about this card',
              impact: 'low',
            );
          }
        }
      }
      
      // MMA-specific predictions
      intelligence.predictions = {
        'suggestedBets': [],
        'confidence': intelligence.overallConfidence,
      };
      
      final suggestions = intelligence.predictions['suggestedBets'] as List;
      
      // Add betting suggestions based on insights
      if (intelligence.insights.any((i) => i.category == 'finisher')) {
        suggestions.add({
          'type': 'Fight Doesn\'t Go Distance',
          'reasoning': 'High finish rate fighters on card',
          'confidence': 0.75,
        });
      }
      
      if (intelligence.insights.any((i) => i.category == 'championship')) {
        suggestions.add({
          'type': 'Over 2.5 Rounds',
          'reasoning': 'Championship fights often go longer',
          'confidence': 0.70,
        });
      }
      
      // Style matchup suggestions
      suggestions.add({
        'type': 'Method of Victory Props',
        'reasoning': 'Check fighter finishing tendencies',
        'confidence': 0.65,
      });
      
      intelligence.predictions['suggestedBets'] = suggestions;
      
    } catch (e) {
      debugPrint('Error gathering MMA intelligence: $e');
      intelligence.addDataPoint(
        source: 'System',
        type: 'error',
        data: {'error': e.toString()},
        confidence: 0.0,
      );
    }
  }

  /// Gather boxing-specific intelligence
  Future<void> _gatherBoxingIntelligence(
    EdgeIntelligence intelligence,
    String eventId,
  ) async {
    debugPrint('🥊 Gathering boxing intelligence for ${intelligence.homeTeam} vs ${intelligence.awayTeam}');
    
    try {
      final boxingData = <String, dynamic>{
        'mainEvent': {},
        'undercard': [],
        'fighterProfiles': {},
        'odds': {},
        'judgeAnalysis': {},
        'venueAdvantage': {},
        'beltImplications': [],
        'styleMatchup': {},
        'predictions': [],
      };

      // Get boxing event data from ESPN
      final espnData = await _espnBoxingService.getBoxingIntelligence(
        fighter1: intelligence.homeTeam,
        fighter2: intelligence.awayTeam,
        eventContext: {'eventId': eventId},
      );

      if (espnData.isNotEmpty) {
        // Merge ESPN data
        boxingData.addAll(espnData);
        
        // Extract key boxing metrics
        final mainEvent = espnData['mainEvent'] ?? {};
        final profiles = espnData['fighterProfiles'] ?? {};
        
        // Add boxing-specific insights
        if (mainEvent.isNotEmpty) {
          // Round information
          final rounds = mainEvent['rounds'] ?? 10;
          intelligence.insights.add(
            EdgeInsight(
              message: '$rounds-round ${mainEvent['titleFight'] == true ? 'championship' : 'bout'}',
              type: 'fight_format',
              confidence: 1.0,
              data: {'rounds': rounds, 'title': mainEvent['titleFight'] ?? false},
            ),
          );
          
          // Belt implications
          if (mainEvent['belts'] != null && (mainEvent['belts'] as List).isNotEmpty) {
            final belts = mainEvent['belts'] as List;
            intelligence.insights.add(
              EdgeInsight(
                message: '${belts.join('/')} ${belts.length > 1 ? 'unification' : 'title'} on the line',
                type: 'championship',
                confidence: 1.0,
                data: {'belts': belts},
              ),
            );
          }
        }
        
        // Fighter profiles analysis
        profiles.forEach((fighterName, profile) {
          final koRate = profile['koPercentage'] ?? 0.0;
          final record = profile['record'] ?? 'N/A';
          final stance = profile['stance'] ?? 'Unknown';
          
          // KO threat analysis
          if (koRate > 65) {
            intelligence.insights.add(
              EdgeInsight(
                message: '$fighterName: ${koRate.toStringAsFixed(1)}% KO rate - dangerous puncher',
                type: 'ko_threat',
                confidence: 0.85,
                data: profile,
              ),
            );
          }
          
          // Stance matchup
          if (stance != 'Unknown') {
            boxingData['styleMatchup']['$fighterName-stance'] = stance;
          }
        });
        
        // Style matchup analysis
        final fighter1Stance = profiles[intelligence.homeTeam]?['stance'];
        final fighter2Stance = profiles[intelligence.awayTeam]?['stance'];
        
        if (fighter1Stance != null && fighter2Stance != null) {
          if (fighter1Stance != fighter2Stance) {
            intelligence.insights.add(
              EdgeInsight(
                message: '$fighter1Stance vs $fighter2Stance - expect awkward exchanges',
                type: 'style_matchup',
                confidence: 0.75,
                data: {'fighter1': fighter1Stance, 'fighter2': fighter2Stance},
              ),
            );
          }
        }
        
        // Age and experience factors
        profiles.forEach((fighterName, profile) {
          final age = profile['age'] ?? 0;
          final record = profile['record']?.toString() ?? '0-0';
          final parts = record.split('-');
          final totalFights = parts.length >= 2 
              ? (int.tryParse(parts[0]) ?? 0) + (int.tryParse(parts[1]) ?? 0)
              : 0;
          
          // Age concern
          if (age > 36) {
            intelligence.insights.add(
              EdgeInsight(
                message: '$fighterName is $age - age could impact stamina in later rounds',
                type: 'age_factor',
                confidence: 0.70,
                data: {'age': age, 'fighter': fighterName},
              ),
            );
          }
          
          // Experience advantage
          if (totalFights > 30) {
            intelligence.insights.add(
              EdgeInsight(
                message: '$fighterName: $totalFights pro fights - veteran experience',
                type: 'experience',
                confidence: 0.75,
                data: {'fights': totalFights, 'record': record},
              ),
            );
          }
        });
      }

      // Get boxing odds from ESPN (includes method of victory, rounds)
      if (espnData['odds'] != null && espnData['odds'].isNotEmpty) {
        boxingData['odds'] = espnData['odds'];
        
        // Analyze betting lines
        final moneyline = espnData['odds']['moneyline'] ?? {};
        if (moneyline.isNotEmpty) {
          // Find favorite
          String favorite = '';
          double bestOdds = 999;
          moneyline.forEach((fighter, odds) {
            final oddsValue = double.tryParse(odds.toString()) ?? 999;
            if (oddsValue < bestOdds) {
              bestOdds = oddsValue;
              favorite = fighter;
            }
          });
          
          if (favorite.isNotEmpty && bestOdds < -200) {
            intelligence.insights.add(
              EdgeInsight(
                message: '$favorite heavy favorite at ${bestOdds.toStringAsFixed(0)}',
                type: 'betting_favorite',
                confidence: 0.80,
                data: moneyline,
              ),
            );
          }
        }
        
        // Method of victory odds
        final methodOdds = espnData['odds']['methodOfVictory'] ?? {};
        if (methodOdds.isNotEmpty) {
          // Find most likely outcome
          String likelyMethod = '';
          double bestMethodOdds = 999;
          methodOdds.forEach((method, odds) {
            final oddsValue = double.tryParse(odds.toString()) ?? 999;
            if (oddsValue < bestMethodOdds) {
              bestMethodOdds = oddsValue;
              likelyMethod = method;
            }
          });
          
          if (likelyMethod.isNotEmpty) {
            intelligence.insights.add(
              EdgeInsight(
                message: 'Most likely outcome: $likelyMethod',
                type: 'method_prediction',
                confidence: 0.65,
                data: methodOdds,
              ),
            );
          }
        }
      }

      // Get boxing news
      final newsQuery = '${intelligence.homeTeam} ${intelligence.awayTeam} boxing';
      final newsData = await _newsService.getTeamNews(query: newsQuery);
      
      if (newsData != null && newsData.articles.isNotEmpty) {
        final articles = newsData.articles;
        boxingData['news'] = {
          'articleCount': articles.length,
          'headlines': articles.take(3).map((a) => a.title).toList(),
        };
        
        // Look for injury or training camp news
        for (final article in articles) {
          final headline = article.title?.toLowerCase() ?? '';
          final description = article.description?.toLowerCase() ?? '';
          final content = '$headline $description';
          
          if (content.contains('injur') || content.contains('pull out') || content.contains('withdraw')) {
            intelligence.insights.add(
              EdgeInsight(
                message: 'Injury concern reported in news',
                type: 'injury_alert',
                confidence: 0.60,
                data: {'headline': article.title},
              ),
            );
          }
          
          if (content.contains('sparring') || content.contains('camp') || content.contains('train')) {
            boxingData['trainingCamp'] = {
              'recentNews': article.title,
              'source': article.source ?? 'Unknown',
            };
          }
        }
      }

      // Get Reddit sentiment for boxing
      final redditData = await _redditService.getFightCardIntelligence(
        eventName: '${intelligence.homeTeam} vs ${intelligence.awayTeam}',
        mainEvent: '${intelligence.homeTeam} vs ${intelligence.awayTeam}',
        promotion: 'boxing',
      );

      if (redditData.isNotEmpty) {
        boxingData['reddit'] = redditData;
        
        // Analyze fighter sentiment
        final fighterSentiment = redditData['fighterSentiment'] ?? {};
        if (fighterSentiment.isNotEmpty) {
          String fanFavorite = '';
          int maxPositive = 0;
          
          fighterSentiment.forEach((fighter, data) {
            final positive = data['positive'] ?? 0;
            if (positive > maxPositive) {
              maxPositive = positive;
              fanFavorite = fighter;
            }
          });
          
          if (fanFavorite.isNotEmpty && maxPositive > 5) {
            intelligence.insights.add(
              EdgeInsight(
                message: 'Reddit favoring $fanFavorite ($maxPositive positive mentions)',
                type: 'social_sentiment',
                confidence: 0.60,
                data: fighterSentiment,
              ),
            );
          }
        }
        
        // Fan excitement level
        final excitement = redditData['fanExcitement'] ?? 0.0;
        if (excitement > 0.7) {
          intelligence.insights.add(
            EdgeInsight(
              message: 'High fan excitement - ${(excitement * 100).toStringAsFixed(0)}% engagement',
              type: 'fan_interest',
              confidence: 0.65,
              data: {'excitement': excitement},
            ),
          );
        }
      }

      // Judge analysis for title fights
      if (espnData['mainEvent']?['titleFight'] == true) {
        boxingData['judgeAnalysis'] = {
          'type': 'championship_scoring',
          'note': 'Title fights often favor champions in close rounds',
          'recommendation': 'Consider champion bias in decision betting',
        };
        
        intelligence.insights.add(
          EdgeInsight(
            message: 'Championship bout - incumbent champion may get benefit in close rounds',
            type: 'judge_bias',
            confidence: 0.65,
            data: boxingData['judgeAnalysis'],
          ),
        );
      }

      // Generate boxing-specific predictions
      final predictions = _generateBoxingPredictions(boxingData, intelligence);
      boxingData['predictions'] = predictions;
      
      // Add predictions as insights
      for (final prediction in predictions.take(3)) {
        intelligence.insights.add(
          EdgeInsight(
            message: prediction['insight'],
            type: prediction['type'],
            confidence: prediction['confidence'],
            data: prediction,
          ),
        );
      }

      // Store all boxing data
      intelligence.data['boxing'] = boxingData;

      debugPrint('✅ Boxing intelligence gathered: ${intelligence.insights.length} insights');

    } catch (e) {
      debugPrint('❌ Error gathering boxing intelligence: $e');
      intelligence.insights.add(
        EdgeInsight(
          message: 'Limited boxing data available',
          type: 'error',
          confidence: 0.0,
          data: {'error': e.toString()},
        ),
      );
    }
  }

  /// Generate boxing-specific predictions
  List<Map<String, dynamic>> _generateBoxingPredictions(
    Map<String, dynamic> boxingData,
    EdgeIntelligence intelligence,
  ) {
    final predictions = <Map<String, dynamic>>[];
    
    // Analyze for upset potential
    final odds = boxingData['odds']?['moneyline'] ?? {};
    if (odds.isNotEmpty) {
      // Check for close odds (potential upset)
      final values = odds.values.map((v) => double.tryParse(v.toString()) ?? 0).toList();
      if (values.length >= 2) {
        final diff = (values[0] - values[1]).abs();
        if (diff < 100) {
          predictions.add({
            'type': 'close_fight',
            'insight': 'Odds suggest competitive fight - consider underdog value',
            'confidence': 0.70,
          });
        } else if (values.any((v) => v > 300)) {
          predictions.add({
            'type': 'upset_potential',
            'insight': 'Large underdog could provide value if stylistic matchup favors',
            'confidence': 0.55,
          });
        }
      }
    }
    
    // Rounds prediction based on KO rates
    final profiles = boxingData['fighterProfiles'] ?? {};
    double avgKoRate = 0;
    int fighterCount = 0;
    
    profiles.forEach((name, profile) {
      final koRate = profile['koPercentage'] ?? 0;
      avgKoRate += koRate;
      fighterCount++;
    });
    
    if (fighterCount > 0) {
      avgKoRate /= fighterCount;
      
      if (avgKoRate > 60) {
        predictions.add({
          'type': 'distance_prediction',
          'insight': 'High combined KO rate (${avgKoRate.toStringAsFixed(0)}%) - unlikely to go distance',
          'confidence': 0.75,
        });
      } else if (avgKoRate < 30) {
        predictions.add({
          'type': 'distance_prediction',
          'insight': 'Low KO rate - likely to go to decision',
          'confidence': 0.70,
        });
      }
    }
    
    // Championship rounds factor
    final rounds = boxingData['mainEvent']?['rounds'] ?? 10;
    if (rounds == 12) {
      predictions.add({
        'type': 'championship_rounds',
        'insight': '12-round fight - conditioning crucial in rounds 10-12',
        'confidence': 0.80,
      });
    }
    
    // Style matchup predictions
    if (boxingData['styleMatchup'] != null && boxingData['styleMatchup'].isNotEmpty) {
      final stances = boxingData['styleMatchup'];
      if (stances.values.contains('Southpaw') && stances.values.contains('Orthodox')) {
        predictions.add({
          'type': 'tactical_fight',
          'insight': 'Orthodox vs Southpaw - expect tactical, technical fight',
          'confidence': 0.70,
        });
      }
    }
    
    return predictions;
  }

  /// Gather universal intelligence (weather, news, social)
  Future<void> _gatherUniversalIntelligence(
    EdgeIntelligence intelligence,
    EventMatch eventMatch,
  ) async {
    // News and social are now handled in sport-specific methods
    // Weather only relevant for outdoor sports (MLB, some NHL/NFL games)
    
    // Check if outdoor venue (Winter Classic, Stadium Series for NHL)
    final outdoorVenues = ['Fenway Park', 'Wrigley Field', 'MetLife Stadium'];
    
    // TODO: Implement weather API for outdoor games
    if (outdoorVenues.any((v) => intelligence.homeTeam.contains(v))) {
      intelligence.addDataPoint(
        source: 'Weather',
        type: 'conditions',
        data: {'status': 'outdoor_venue_check_needed'},
        confidence: 0.0,
      );
    }
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
  final Map<String, dynamic> data = {};  // Storage for sport-specific data
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
      message: insight,
      type: category,
      confidence: impact == 'high' ? 0.9 : impact == 'medium' ? 0.7 : 0.5,
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
  final String message;
  final String type;
  final double confidence;
  final Map<String, dynamic>? data;
  
  // Legacy properties for compatibility
  String get category => type;
  String get insight => message;
  String get impact => confidence > 0.8 ? 'high' : confidence > 0.6 ? 'medium' : 'low';

  EdgeInsight({
    required this.message,
    required this.type,
    required this.confidence,
    this.data,
  });

  Map<String, dynamic> toMap() => {
    'message': message,
    'type': type,
    'confidence': confidence,
    'data': data,
    // Legacy compatibility
    'category': category,
    'insight': insight,
    'impact': impact,
  };

  factory EdgeInsight.fromMap(Map<String, dynamic> map) {
    return EdgeInsight(
      message: map['message'] ?? map['insight'] ?? '',
      type: map['type'] ?? map['category'] ?? '',
      confidence: map['confidence'] ?? 0.5,
      data: map['data'],
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