import 'package:flutter/material.dart';
// import 'edge_detail_screen.dart'; // Removed - using EdgeScreenV2 now
import '../../services/edge/sports/espn_nba_service.dart';
import '../../services/edge/sports/espn_nhl_service.dart';
import '../../services/edge/sports/nhl_api_service.dart';
import '../../services/edge/news/news_api_service.dart';
import '../../services/edge/social/reddit_service.dart';

class EdgeScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  
  const EdgeScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
  });

  @override
  State<EdgeScreen> createState() => _EdgeScreenState();
}

class _EdgeScreenState extends State<EdgeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Selected edge cards
  final Set<String> _revealedCards = {};
  int _userBRBalance = 500; // User's BR balance
  
  // Services
  final EspnNbaService _espnNbaService = EspnNbaService();
  final EspnNhlService _espnNhlService = EspnNhlService();
  final NhlApiService _nhlApiService = NhlApiService();
  final NewsApiService _newsService = NewsApiService();
  final RedditService _redditService = RedditService();
  
  // Real-time data
  Map<String, dynamic>? _liveGameData;
  Map<String, dynamic>? _newsData;
  Map<String, dynamic>? _redditData;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Load real data
    _loadRealTimeData();
  }
  
  Future<void> _loadRealTimeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Fetch live game data based on sport
      if (widget.sport.toUpperCase() == 'NBA') {
        // Get today's games from ESPN
        final scoreboard = await _espnNbaService.getTodaysGames();
        if (scoreboard != null && scoreboard.events.isNotEmpty) {
          final firstGame = scoreboard.events.first;
          final competitions = firstGame['competitions'] as List? ?? [];
          if (competitions.isNotEmpty) {
            final competition = competitions.first as Map<String, dynamic>;
            final competitors = competition['competitors'] as List? ?? [];
            
            String homeTeam = 'Team 1';
            String awayTeam = 'Team 2';
            String homeScore = '0';
            String awayScore = '0';
            
            for (final competitor in competitors) {
              final team = competitor['team'] as Map<String, dynamic>? ?? {};
              final isHome = competitor['homeAway'] == 'home';
              if (isHome) {
                homeTeam = team['displayName'] ?? 'Home Team';
                homeScore = competitor['score'] ?? '0';
              } else {
                awayTeam = team['displayName'] ?? 'Away Team';
                awayScore = competitor['score'] ?? '0';
              }
            }
            
            final status = firstGame['status'] as Map<String, dynamic>? ?? {};
            final statusType = status['type'] as Map<String, dynamic>? ?? {};
            
            _liveGameData = {
              'gameId': firstGame['id'] ?? '',
              'status': statusType['description'] ?? 'Scheduled',
              'homeTeam': homeTeam,
              'awayTeam': awayTeam,
              'homeScore': homeScore,
              'awayScore': awayScore,
              'period': status['period'] ?? 0,
              'clock': status['displayClock'] ?? '',
            };
          }
        }
        
        // Get NBA news
        final teams = widget.gameTitle.split(' vs ');
        String newsQuery = 'NBA';
        if (teams.length >= 2) {
          newsQuery = '${teams[0]} OR ${teams[1]} NBA';
        }
        final newsResponse = await _newsService.getTeamNews(
          query: newsQuery,
          pageSize: 10,
        );
        if (newsResponse != null) {
          _newsData = {
            'articles': newsResponse.articles.map((a) => {
              'title': a.title,
              'description': a.description,
              'url': a.url,
              'publishedAt': a.publishedAt,
            }).toList(),
          };
        }
        
        // Get Reddit game thread or team sentiment
        if (teams.length >= 2) {
          final gameThread = await _redditService.getGameThread(
            homeTeam: teams[0].trim(),
            awayTeam: teams[1].trim(),
            sport: 'nba',
            gameDate: DateTime.now(),
          );
          if (gameThread != null) {
            _redditData = {
              'posts': [
                {'title': gameThread.title},
              ],
              'sentiment': gameThread.sentiment,
            };
          }
        } else {
          // Fallback to team sentiment
          final sentiment = await _redditService.getTeamSentiment(
            teamName: teams.first.trim(),
            limit: 10,
          );
          _redditData = sentiment;
        }
      } else if (widget.sport.toUpperCase() == 'NHL') {
        // Get NHL games from both sources
        // Try official NHL API first
        final nhlScoreboard = await _nhlApiService.getScoreboard();
        if (nhlScoreboard != null && nhlScoreboard.gamesByDate.isNotEmpty) {
          for (final gameDate in nhlScoreboard.gamesByDate) {
            if (gameDate.games.isNotEmpty) {
              final firstGame = gameDate.games.first;
              _liveGameData = {
                'gameId': firstGame.id.toString(),
                'status': firstGame.gameState,
                'homeTeam': firstGame.homeTeam['name']?['default'] ?? 'Home',
                'awayTeam': firstGame.awayTeam['name']?['default'] ?? 'Away',
                'homeScore': firstGame.homeTeam['score']?.toString() ?? '0',
                'awayScore': firstGame.awayTeam['score']?.toString() ?? '0',
                'period': firstGame.period ?? 0,
                'clock': firstGame.clock ?? '',
                'venue': firstGame.venue['default'] ?? '',
              };
              break;
            }
          }
        }
        
        // Fallback to ESPN if needed
        if (_liveGameData == null) {
          final espnScoreboard = await _espnNhlService.getTodaysGames();
          if (espnScoreboard != null && espnScoreboard.events.isNotEmpty) {
            final firstGame = espnScoreboard.events.first;
            final competitions = firstGame['competitions'] as List? ?? [];
            if (competitions.isNotEmpty) {
              final competition = competitions.first as Map<String, dynamic>;
              final competitors = competition['competitors'] as List? ?? [];
              
              String homeTeam = 'Team 1';
              String awayTeam = 'Team 2';
              String homeScore = '0';
              String awayScore = '0';
              
              for (final competitor in competitors) {
                final team = competitor['team'] as Map<String, dynamic>? ?? {};
                final isHome = competitor['homeAway'] == 'home';
                if (isHome) {
                  homeTeam = team['displayName'] ?? 'Home Team';
                  homeScore = competitor['score'] ?? '0';
                } else {
                  awayTeam = team['displayName'] ?? 'Away Team';
                  awayScore = competitor['score'] ?? '0';
                }
              }
              
              final status = firstGame['status'] as Map<String, dynamic>? ?? {};
              final statusType = status['type'] as Map<String, dynamic>? ?? {};
              
              _liveGameData = {
                'gameId': firstGame['id'] ?? '',
                'status': statusType['description'] ?? 'Scheduled',
                'homeTeam': homeTeam,
                'awayTeam': awayTeam,
                'homeScore': homeScore,
                'awayScore': awayScore,
                'period': status['period'] ?? 0,
                'clock': status['displayClock'] ?? '',
              };
            }
          }
        }
        
        // Get NHL news
        final teams = widget.gameTitle.split(' vs ');
        String newsQuery = 'NHL';
        if (teams.length >= 2) {
          newsQuery = '${teams[0]} OR ${teams[1]} NHL hockey';
        }
        final newsResponse = await _newsService.getTeamNews(
          query: newsQuery,
          pageSize: 10,
        );
        if (newsResponse != null) {
          _newsData = {
            'articles': newsResponse.articles.map((a) => {
              'title': a.title,
              'description': a.description,
              'url': a.url,
              'publishedAt': a.publishedAt,
            }).toList(),
          };
        }
        
        // Get Reddit game thread or team sentiment
        if (teams.length >= 2) {
          final gameThread = await _redditService.getGameThread(
            homeTeam: teams[0].trim(),
            awayTeam: teams[1].trim(),
            sport: 'nhl',
            gameDate: DateTime.now(),
          );
          if (gameThread != null) {
            _redditData = {
              'posts': [
                {'title': gameThread.title},
              ],
              'sentiment': gameThread.sentiment,
            };
          }
        } else {
          // Fallback to team sentiment
          final sentiment = await _redditService.getTeamSentiment(
            teamName: teams.first.trim(),
            limit: 10,
          );
          _redditData = sentiment;
        }
      }
    } catch (e) {
      debugPrint('Error loading real-time data: $e');
      _error = 'Failed to load live data. Using sample data.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('The Edge', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_userBRBalance BR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.purple.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.gameTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose Your Intelligence Cards',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reveal costs vary by intel value',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Edge Cards Grid with Loading/Error States
            Expanded(
              child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.purple,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading Live Intelligence...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, color: Colors.amber, size: 48),
                          SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadRealTimeData,
                            icon: Icon(Icons.refresh),
                            label: Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRealTimeData,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _getEdgeCards().length,
                        itemBuilder: (context, index) {
                          final card = _getEdgeCards()[index];
                          return _buildEdgeCard(card);
                        },
                      ),
                    ),
            ),
            
            // Bottom Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (_userBRBalance < 10)
                    ElevatedButton.icon(
                      onPressed: _purchaseBR,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Buy More BR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Intel expires when game starts',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<EdgeCard> _getEdgeCards() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
        // Build dynamic cards based on real data
        final cards = <EdgeCard>[];
        
        // Live Score Card (if game data available)
        if (_liveGameData != null) {
          cards.add(EdgeCard(
            id: 'live_score',
            title: 'Live Score',
            icon: Icons.sports_basketball,
            color: Colors.orange,
            data: '${_liveGameData!['homeTeam']}: ${_liveGameData!['homeScore']}\n'
                  '${_liveGameData!['awayTeam']}: ${_liveGameData!['awayScore']}\n'
                  'Period: ${_liveGameData!['period']} | ${_liveGameData!['clock']}\n'
                  'Status: ${_liveGameData!['status']}',
            source: 'ESPN Live Data',
            cost: 5,
            hasAlert: _liveGameData!['status'] == 'InProgress',
            alertIcon: Icons.live_tv,
          ));
        }
        
        // Injury Report Card (with real or simulated data)
        cards.add(EdgeCard(
          id: 'injury',
          title: 'Injury Report',
          icon: Icons.healing,
          color: Colors.red,
          data: _newsData != null && _newsData!['injuries'] != null
              ? _newsData!['injuries'].toString()
              : 'Checking latest injury reports...\nRefresh for updates',
          source: 'Team Medical Staff',
          cost: 20,
          hasAlert: true,
          alertIcon: Icons.healing,
        ));
        
        // Social Sentiment Card
        cards.add(EdgeCard(
          id: 'sentiment',
          title: 'Reddit Buzz',
          icon: Icons.trending_up,
          color: Colors.blue,
          data: _redditData != null && _redditData!['posts'] != null
              ? 'Top Reddit Discussion:\n${(_redditData!['posts'] as List).take(3).map((p) => '• ${p['title']}').join('\n')}'
              : 'Loading Reddit sentiment...',
          source: 'r/nba Community',
          cost: 10,
        ));
        
        // Breaking News Card
        cards.add(EdgeCard(
          id: 'insider',
          title: 'Breaking News',
          icon: Icons.newspaper,
          color: Colors.green,
          data: _newsData != null && _newsData!['articles'] != null
              ? 'Latest News:\n${(_newsData!['articles'] as List).take(2).map((a) => '• ${a['title']}').join('\n')}'
              : 'Fetching latest news...',
          source: 'NewsAPI',
          cost: 15,
          hasAlert: _newsData != null && _newsData!['breaking'] == true,
          alertIcon: Icons.warning,
        ));
        
        // Analytics Card
        cards.add(EdgeCard(
          id: 'analytics',
          title: 'Game Analytics',
          icon: Icons.analytics,
          color: Colors.purple,
          data: _liveGameData != null
              ? 'Game Flow Analysis:\n• Momentum: ${_getMomentum()}\n• Pace: Fast\n• Key Matchup: Paint Battle'
              : 'Analytics loading...',
          source: 'AI Analysis',
          cost: 25,
        ));
        
        return cards;
      case 'NHL':
        // Build dynamic NHL cards
        final cards = <EdgeCard>[];
        
        // Live Score Card
        if (_liveGameData != null) {
          cards.add(EdgeCard(
            id: 'live_score',
            title: 'Live Score',
            icon: Icons.sports_hockey,
            color: Colors.blue,
            data: '${_liveGameData!['homeTeam']}: ${_liveGameData!['homeScore']}\n'
                  '${_liveGameData!['awayTeam']}: ${_liveGameData!['awayScore']}\n'
                  'Period: ${_getPeriodText(_liveGameData!['period'])} | ${_liveGameData!['clock']}\n'
                  'Status: ${_liveGameData!['status']}',
            source: 'NHL Live Data',
            cost: 5,
            hasAlert: _liveGameData!['status'] == 'LIVE' || _liveGameData!['status'] == 'InProgress',
            alertIcon: Icons.live_tv,
          ));
        }
        
        // Penalty Box Card
        cards.add(EdgeCard(
          id: 'penalties',
          title: 'Penalty Box',
          icon: Icons.warning,
          color: Colors.yellow.shade700,
          data: _liveGameData != null
              ? 'Current Penalties:\n• No penalties tracked\nPower Play Status: Even strength'
              : 'Loading penalty data...',
          source: 'NHL Stats',
          cost: 10,
          hasAlert: false,
        ));
        
        // Injury Report
        cards.add(EdgeCard(
          id: 'injuries',
          title: 'Injury Report',
          icon: Icons.medical_services,
          color: Colors.red,
          data: _newsData != null && _newsData!['injuries'] != null
              ? _newsData!['injuries'].toString()
              : 'Checking injury reports...\nKey players status pending',
          source: 'Team Medical',
          cost: 20,
          hasAlert: true,
          alertIcon: Icons.medical_services,
        ));
        
        // NHL News
        cards.add(EdgeCard(
          id: 'news',
          title: 'Breaking News',
          icon: Icons.newspaper,
          color: Colors.green,
          data: _newsData != null && _newsData!['articles'] != null
              ? 'Latest:\n${(_newsData!['articles'] as List).take(2).map((a) => '• ${a['title']}').join('\n')}'
              : 'Fetching NHL news...',
          source: 'NHL Media',
          cost: 15,
        ));
        
        // Reddit Buzz
        cards.add(EdgeCard(
          id: 'reddit',
          title: 'Fan Sentiment',
          icon: Icons.forum,
          color: Colors.orange,
          data: _redditData != null && _redditData!['sentiment'] != null
              ? 'r/hockey Sentiment: ${_redditData!['sentiment']}\n'
                'Hot Topics:\n• Game thread active\n• Playoff implications discussed'
              : 'Loading fan reactions...',
          source: 'r/hockey',
          cost: 10,
        ));
        
        // Analytics Card
        cards.add(EdgeCard(
          id: 'analytics',
          title: 'Game Analytics',
          icon: Icons.analytics,
          color: Colors.purple,
          data: _liveGameData != null
              ? 'Period Analysis:\n${_getHockeyAnalytics()}\n• Shot attempts tracking\n• Face-off win %'
              : 'Analytics loading...',
          source: 'AI Analysis',
          cost: 25,
        ));
        
        return cards;
      case 'MMA':
        return [
          EdgeCard(
            id: 'compubox',
            title: 'CompuBox Stats',
            icon: Icons.sports_mma,
            color: Colors.red,
            data: 'Fighter statistics coming soon',
            source: 'CompuBox',
            cost: 25,
          ),
          EdgeCard(
            id: 'camp',
            title: 'Training Camp',
            icon: Icons.fitness_center,
            color: Colors.orange,
            data: 'Training camp reports coming soon',
            source: 'Camp Sources',
            cost: 20,
            hasAlert: false,
            alertIcon: Icons.warning_amber,
          ),
          EdgeCard(
            id: 'weigh',
            title: 'Weigh-in Intel',
            icon: Icons.monitor_weight,
            color: Colors.purple,
            data: 'Weigh-in analysis coming soon',
            source: 'Backstage Report',
            cost: 15,
            hasAlert: false,
            alertIcon: Icons.scale,
          ),
          EdgeCard(
            id: 'judge',
            title: 'Judge Tendencies',
            icon: Icons.gavel,
            color: Colors.blue,
            data: 'Judge analysis coming soon',
            source: 'Historical Data',
            cost: 30,
          ),
        ];
      default:
        return [
          EdgeCard(
            id: 'generic1',
            title: 'Team News',
            icon: Icons.group,
            color: Colors.blue,
            data: 'Latest team updates and roster changes',
            source: 'Team Sources',
            cost: 15,
          ),
          EdgeCard(
            id: 'generic2',
            title: 'Analytics',
            icon: Icons.analytics,
            color: Colors.green,
            data: 'Advanced statistics and trends',
            source: 'Data Provider',
            cost: 20,
          ),
        ];
    }
  }
  
  Widget _buildEdgeCard(EdgeCard card) {
    final isRevealed = _revealedCards.contains(card.id);
    final canAfford = _userBRBalance >= card.cost;
    
    return AnimatedBuilder(
      animation: card.hasAlert ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: card.hasAlert && !isRevealed ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () {
              if (!isRevealed && canAfford) {
                _revealCard(card);
              } else if (!isRevealed && !canAfford) {
                _showNeedBRDialog(card.cost);
              } else if (isRevealed) {
                _showDetailedView(card);
              }
            },
            onLongPress: isRevealed ? () => _showDetailedView(card) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: isRevealed
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          card.color.withOpacity(0.8),
                          card.color.withOpacity(0.4),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade900,
                          Colors.grey.shade800,
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRevealed 
                      ? card.color 
                      : card.hasAlert 
                          ? card.color.withOpacity(0.5) 
                          : Colors.grey.shade700,
                  width: card.hasAlert && !isRevealed ? 3 : 2,
                ),
                boxShadow: [
                  if (isRevealed || card.hasAlert)
                    BoxShadow(
                      color: card.color.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: isRevealed
                  ? _buildRevealedCard(card)
                  : _buildHiddenCard(card, canAfford),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHiddenCard(EdgeCard card, bool canAfford) {
    return Stack(
      children: [
        // Background pattern
        Positioned.fill(
          child: CustomPaint(
            painter: CardBackPainter(),
          ),
        ),
        // Alert indicator
        if (card.hasAlert)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: card.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: card.color.withOpacity(0.7),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                card.alertIcon ?? Icons.priority_high,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canAfford ? Icons.lock_open : Icons.lock,
                color: canAfford ? Colors.grey.shade500 : Colors.grey.shade700,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                card.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford 
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canAfford ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on, 
                      color: canAfford ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${card.cost} BR',
                      style: TextStyle(
                        color: canAfford ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canAfford ? 'TAP TO REVEAL' : 'INSUFFICIENT BR',
                style: TextStyle(
                  color: canAfford ? Colors.white54 : Colors.red.shade300,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildRevealedCard(EdgeCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(card.icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        card.data,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green.shade300, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Source: ${card.source}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMomentum() {
    if (_liveGameData == null) return 'Unknown';
    final homeScore = int.tryParse(_liveGameData!['homeScore'] ?? '0') ?? 0;
    final awayScore = int.tryParse(_liveGameData!['awayScore'] ?? '0') ?? 0;
    final diff = (homeScore - awayScore).abs();
    
    if (diff <= 5) return 'Tight Game 🔥';
    if (diff <= 10) return 'Competitive';
    if (diff <= 20) return 'One-sided';
    return 'Blowout';
  }
  
  String _getPeriodText(dynamic period) {
    final p = period ?? 0;
    if (p == 0) return 'Not Started';
    if (p == 1) return '1st Period';
    if (p == 2) return '2nd Period';
    if (p == 3) return '3rd Period';
    if (p == 4) return 'Overtime';
    if (p == 5) return 'Shootout';
    return 'Period $p';
  }
  
  String _getHockeyAnalytics() {
    if (_liveGameData == null) return 'No game data';
    final homeScore = int.tryParse(_liveGameData!['homeScore'] ?? '0') ?? 0;
    final awayScore = int.tryParse(_liveGameData!['awayScore'] ?? '0') ?? 0;
    final period = _liveGameData!['period'] ?? 0;
    final diff = (homeScore - awayScore).abs();
    
    if (period == 3 && diff <= 1) {
      return '• CLUTCH TIME! One-goal game in 3rd\n• High pressure situation';
    } else if (period >= 4) {
      return '• OVERTIME! Sudden death\n• Next goal wins';
    } else if (diff >= 4) {
      return '• Game likely decided\n• Low comeback probability';
    } else if (diff <= 1) {
      return '• Tight defensive battle\n• Every shot matters';
    }
    return '• Competitive matchup\n• Momentum shifts possible';
  }
  
  void _revealCard(EdgeCard card) {
    setState(() {
      _revealedCards.add(card.id);
      _userBRBalance -= card.cost;
    });
    
    // Animate the reveal
    _animationController.forward().then((_) {
      _animationController.reset();
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Revealed ${card.title} for ${card.cost} BR'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showNeedBRDialog(int requiredBR) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Insufficient BR',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 16),
            Text(
              'You need $requiredBR BR to reveal this intel',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your balance: $_userBRBalance BR',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseBR();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy BR'),
          ),
        ],
      ),
    );
  }
  
  void _purchaseBR() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Purchase BR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildBRPackage('Starter Pack', 50, 4.99, false),
            _buildBRPackage('Pro Pack', 500, 39.99, true),
            _buildBRPackage('Elite Pack', 1000, 74.99, false),
          ],
        ),
      ),
    );
  }
  
  void _showDetailedView(EdgeCard card) {
    // EdgeDetailScreen is not implemented yet
    // TODO: Implement EdgeDetailScreen or use a dialog instead
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(card.icon, color: card.color),
            const SizedBox(width: 8),
            Expanded(child: Text(card.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.data,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.source, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Source: ${card.source}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              if (card.hasAlert) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(card.alertIcon ?? Icons.warning, 
                         size: 20, 
                         color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'High Impact Alert',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBRPackage(String name, int brAmount, double price, bool isBestValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isBestValue
            ? const LinearGradient(colors: [Colors.green, Colors.teal])
            : null,
        color: isBestValue ? null : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestValue ? Colors.green : Colors.grey.shade700,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.monetization_on,
              color: isBestValue ? Colors.white : Colors.green,
              size: 32,
            ),
            if (isBestValue)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isBestValue ? Colors.white : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$brAmount BR',
          style: TextStyle(
            color: isBestValue ? Colors.white70 : Colors.white70,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            setState(() {
              _userBRBalance += brAmount;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchased $brAmount BR for \$$price!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isBestValue ? Colors.white : Colors.green,
            foregroundColor: isBestValue ? Colors.green : Colors.white,
          ),
          child: Text('\$$price'),
        ),
      ),
    );
  }
}

class EdgeCard {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String data;
  final String source;
  final int cost;
  final bool hasAlert;
  final IconData? alertIcon;
  
  EdgeCard({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
    required this.source,
    required this.cost,
    this.hasAlert = false,
    this.alertIcon,
  });
}

class CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw diagonal lines pattern
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}