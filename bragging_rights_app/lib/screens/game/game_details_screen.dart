import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../theme/app_theme.dart';
import '../../services/odds_api_service.dart';
import '../../services/team_logo_service.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../services/espn_id_resolver_service.dart';

class GameDetailsScreen extends StatefulWidget {
  final String gameId;
  final String sport;
  final GameModel? gameData;

  const GameDetailsScreen({
    Key? key,
    required this.gameId,
    required this.sport,
    this.gameData,
  }) : super(key: key);

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OddsApiService _oddsService = OddsApiService();
  final TeamLogoService _logoService = TeamLogoService();

  GameModel? _game;
  Map<String, dynamic>? _eventDetails;
  Map<String, dynamic>? _boxScore;
  Map<String, dynamic>? _gameData;
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  String _selectedTeam = 'away'; // For stats tab toggle

  // NHL-specific data
  Map<String, dynamic>? _nhlBoxScore;
  List<dynamic>? _nhlScoringPlays;
  Map<String, dynamic>? _nhlStandings;
  List<dynamic>? _nhlGameLeaders;  // Changed from Map to List
  Map<String, dynamic>? _nhlOddsData;

  @override
  void initState() {
    super.initState();
    // For baseball, we have 3 tabs (Matchup, Box Score, Stats)
    // Different sports have different numbers of tabs
    final tabCount = widget.sport.toUpperCase() == 'MLB'
        ? 3
        : widget.sport.toUpperCase() == 'SOCCER'
        ? 4
        : widget.sport.toUpperCase() == 'NBA'
        ? 5
        : widget.sport.toUpperCase() == 'NFL'
        ? 3  // NFL tabs: Overview, Stats, Standings
        : widget.sport.toUpperCase() == 'NHL'
        ? 4
        : 5;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _game = widget.gameData;
    _loadEventDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetails() async {
    try {
      setState(() => _isLoading = true);

      // If game data wasn't passed, fetch it
      if (_game == null) {
        // TODO: Fetch from Firestore or API
      }

      // Fetch additional details based on sport
      if (widget.sport.toUpperCase() == 'MLB') {
        await _loadBaseballDetails();
      } else if (widget.sport.toUpperCase() == 'SOCCER') {
        await _loadSoccerDetails();
      } else if (widget.sport.toUpperCase() == 'NBA') {
        await _loadNBADetails();
      } else if (widget.sport.toUpperCase() == 'NFL') {
        await _loadNFLDetails();
      } else if (widget.sport.toUpperCase() == 'NHL') {
        await _loadNHLDetails();
      } else {
        // TODO: Implement for other sports
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading event details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBaseballDetails() async {
    try {
      print('=== LOADING BASEBALL DETAILS ===');
      print('Game ID: ${widget.gameId}');
      print('Teams: ${_game?.awayTeam} @ ${_game?.homeTeam}');

      // Use the ESPN ID resolver service
      final resolver = EspnIdResolverService();

      // Check if game already has ESPN ID
      var espnGameId = _game?.espnId;

      // If no ESPN ID, resolve it
      if (espnGameId == null && _game != null) {
        print('Resolving ESPN ID using resolver service...');
        espnGameId = await resolver.resolveEspnId(_game!);

        if (espnGameId != null) {
          print('✅ ESPN ID resolved: $espnGameId');
        } else {
          print('❌ Could not resolve ESPN ID');
          // Show user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Game details are temporarily unavailable'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else if (espnGameId == null) {
        print('❌ No game data available to resolve ESPN ID');
        return;
      }

      print('Using ESPN ID: $espnGameId');

      // Fetch game summary data from ESPN
      final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=$espnGameId';
      print('Fetching summary from: $summaryUrl');

      final summaryResponse = await http.get(Uri.parse(summaryUrl));
      print('Summary response status: ${summaryResponse.statusCode}');

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);

        // Log the structure of the data
        print('Summary data keys: ${summaryData.keys.toList()}');

        if (summaryData['boxscore'] != null) {
          print('✅ Box score data found');
          final teams = summaryData['boxscore']['teams'] as List? ?? [];
          print('  - Teams in boxscore: ${teams.length}');

          for (final team in teams) {
            final teamInfo = team['team'];
            print('  - Team: ${teamInfo?['displayName']}');

            final stats = team['statistics'] as List? ?? [];
            for (final statGroup in stats) {
              print('    - Stat group: ${statGroup['name']}');
            }
          }
        } else {
          print('❌ No box score data in response');
        }

        setState(() {
          _boxScore = summaryData['boxscore'];
          _gameData = summaryData;
          // Use header.competitions for event details which has the team/competitor data
          if (summaryData['header']?['competitions'] != null &&
              (summaryData['header']['competitions'] as List).isNotEmpty) {
            _eventDetails = {
              ...summaryData,
              'competitions': summaryData['header']['competitions'],
            };
          } else {
            _eventDetails = summaryData;
          }
        });
      } else {
        print('❌ Summary API failed with status ${summaryResponse.statusCode}');
        print('Response body: ${summaryResponse.body.substring(0, 200)}...');
      }

      // Fetch scoreboard for additional data like weather and probables
      // Parse the game date from the header if available, otherwise use game time
      DateTime? gameDate;
      if (_eventDetails?['header']?['competitions']?[0]?['date'] != null) {
        try {
          gameDate = DateTime.parse(_eventDetails!['header']['competitions'][0]['date']);
        } catch (e) {
          print('Error parsing date from header: $e');
        }
      }
      gameDate ??= _game?.gameTime ?? DateTime.now();

      final dateString = '${gameDate.year}${gameDate.month.toString().padLeft(2, '0')}${gameDate.day.toString().padLeft(2, '0')}';
      final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard?dates=$dateString';
      print('\nFetching scoreboard from: $scoreboardUrl');

      final scoreboardResponse = await http.get(Uri.parse(scoreboardUrl));
      print('Scoreboard response status: ${scoreboardResponse.statusCode}');

      if (scoreboardResponse.statusCode == 200) {
        final scoreboardData = json.decode(scoreboardResponse.body);

        // Find our specific game in the scoreboard
        final events = scoreboardData['events'] as List? ?? [];
        print('Total events in scoreboard: ${events.length}');

        bool foundGame = false;
        for (final event in events) {
          print('  Checking event ID: ${event['id']} vs $espnGameId');

          if (event['id'] == espnGameId) {
            foundGame = true;
            print('✅ Found matching game!');

            // Log competition data
            final competition = event['competitions']?[0];
            if (competition != null) {
              // Check for probables (starting pitchers)
              final probables = competition['probables'] as List? ?? [];
              print('  - Probables (pitchers): ${probables.length}');
              for (final pitcher in probables) {
                final athlete = pitcher['athlete'];
                print('    - ${pitcher['homeAway']}: ${athlete?['fullName']}');
              }

              // Check for weather
              final weather = competition['weather'];
              if (weather != null) {
                print('  - Weather: ${weather['temperature']}°F, ${weather['displayValue']}');
              } else {
                print('  - No weather data');
              }

              // Check for competitors (teams)
              final competitors = competition['competitors'] as List? ?? [];
              print('  - Competitors: ${competitors.length}');
              for (final team in competitors) {
                final teamInfo = team['team'];
                final records = team['records'] as List? ?? [];
                print('    - ${team['homeAway']}: ${teamInfo?['displayName']} (${records.length} records)');
              }
            }

            // Merge scoreboard data with existing event details
            setState(() {
              // Preserve summary data and merge with scoreboard data
              _eventDetails = {
                ..._eventDetails ?? {},
                ...event,
                'competitions': [{
                  ...competition,
                  'probables': competition['probables'] ?? [],
                  'weather': competition['weather'] ?? {},
                }],
              };
            });
            break;
          }
        }

        if (!foundGame) {
          print('❌ Game ID $espnGameId not found in scoreboard');
          print('Available game IDs: ${events.map((e) => e['id']).toList()}');
        }
      } else {
        print('❌ Scoreboard API failed with status ${scoreboardResponse.statusCode}');
      }

      print('=== BASEBALL DETAILS TEST END ===\n');
    } catch (e, stackTrace) {
      print('❌ Error loading baseball details: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadSoccerDetails() async {
    try {
      print('=== LOADING SOCCER DETAILS ===');
      print('Game ID: ${widget.gameId}');
      print('Teams: ${_game?.awayTeam} vs ${_game?.homeTeam}');

      // Use the ESPN ID resolver service - same as baseball
      final resolver = EspnIdResolverService();

      // Check if game already has ESPN ID
      var espnGameId = _game?.espnId;

      // If no ESPN ID, resolve it
      if (espnGameId == null && _game != null) {
        print('Resolving ESPN ID using resolver service...');
        espnGameId = await resolver.resolveEspnId(_game!);

        if (espnGameId != null) {
          print('✅ ESPN ID resolved: $espnGameId');
        } else {
          print('❌ Could not resolve ESPN ID');
          // Show user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Match details are temporarily unavailable'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      } else if (espnGameId == null) {
        print('❌ No game data available to resolve ESPN ID');
        setState(() => _isLoading = false);
        return;
      }

      print('Using ESPN ID: $espnGameId');

      // Determine the league for soccer
      String league = 'eng.1'; // Default to Premier League

      // You could determine league from game data if available
      if (_game?.league != null) {
        final leagueName = _game!.league!.toLowerCase();
        if (leagueName.contains('premier') || leagueName.contains('epl')) {
          league = 'eng.1';
        } else if (leagueName.contains('la liga')) {
          league = 'esp.1';
        } else if (leagueName.contains('bundesliga')) {
          league = 'ger.1';
        } else if (leagueName.contains('serie a')) {
          league = 'ita.1';
        } else if (leagueName.contains('ligue 1')) {
          league = 'fra.1';
        } else if (leagueName.contains('mls')) {
          league = 'usa.1';
        } else if (leagueName.contains('champions')) {
          league = 'uefa.champions';
        }
      }

      // Now fetch the game summary directly with the resolved ESPN ID
      final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/soccer/$league/summary?event=$espnGameId';
      print('Fetching summary from: $summaryUrl');

      final summaryResponse = await http.get(Uri.parse(summaryUrl));

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);
        print('✅ Soccer summary data loaded');

        // Store the event details for use in tabs
        setState(() {
          _eventDetails = summaryData;
          _isLoading = false;
        });

        // Log available data
        print('Available data keys: ${summaryData.keys.toList()}');
        if (summaryData['boxscore'] != null) {
          print('✅ Box score data available');
        }
        if (summaryData['standings'] != null) {
          print('✅ Standings data available');
        }
        if (summaryData['headToHeadGames'] != null) {
          print('✅ Head-to-head data available');
        }
      } else {
        print('❌ Failed to fetch soccer summary with status ${summaryResponse.statusCode}');
        print('Response: ${summaryResponse.body.substring(0, 200)}...');
        setState(() => _isLoading = false);
      }

      print('=== SOCCER DETAILS LOADING END ===\n');
    } catch (e, stackTrace) {
      print('❌ Error loading soccer details: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  String _formatEventTime(DateTime? gameTime) {
    if (gameTime == null) return '';
    final now = DateTime.now();
    final difference = gameTime.difference(now);

    if (difference.inDays > 0) {
      return DateFormat('MMM d • h:mm a').format(gameTime.toLocal());
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minutes';
    } else {
      return 'Live';
    }
  }

  bool get _isCombatSport =>
      widget.sport.toUpperCase() == 'MMA' ||
      widget.sport.toUpperCase() == 'BOXING';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surfaceBlue,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.shareNetwork),
                onPressed: _shareEvent,
              ),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.bell),
                onPressed: _setReminder,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getSportColor().withOpacity(0.8),
                      AppTheme.surfaceBlue,
                    ],
                  ),
                ),
                child: _buildHeaderContent(),
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryCyan,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryCyan,
                indicatorWeight: 3,
                tabs: widget.sport.toUpperCase() == 'MLB'
                  ? [
                      const Tab(text: 'Matchup'),
                      const Tab(text: 'Box Score'),
                      const Tab(text: 'Stats'),
                    ]
                  : widget.sport.toUpperCase() == 'SOCCER'
                  ? [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Stats'),
                      const Tab(text: 'Standings'),
                      const Tab(text: 'H2H'),
                    ]
                  : widget.sport.toUpperCase() == 'NBA'
                  ? [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Stats'),
                      const Tab(text: 'Standings'),
                      const Tab(text: 'H2H'),
                      const Tab(text: 'Injuries'),
                    ]
                  : widget.sport.toUpperCase() == 'NFL'
                  ? [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Stats'),
                      const Tab(text: 'Standings'),
                    ]
                  : widget.sport.toUpperCase() == 'NHL'
                  ? [
                      const Tab(text: 'Overview'),
                      const Tab(text: 'Box Score'),
                      const Tab(text: 'Scoring'),
                      const Tab(text: 'Standings'),
                    ]
                  : [
                      const Tab(text: 'Overview'),
                      if (_isCombatSport)
                        const Tab(text: 'Fighters')
                      else
                        const Tab(text: 'Odds'),
                      const Tab(text: 'Stats'),
                      const Tab(text: 'News'),
                      const Tab(text: 'Pools'),
                    ],
              ),
            ),
          ),

          // Content
          SliverFillRemaining(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: widget.sport.toUpperCase() == 'MLB'
                      ? [
                          _buildBaseballMatchupTab(),
                          _buildBaseballBoxScoreTab(),
                          _buildBaseballStatsTab(),
                        ]
                      : widget.sport.toUpperCase() == 'SOCCER'
                      ? [
                          _buildSoccerOverviewTab(),
                          _buildSoccerStatsTab(),
                          _buildSoccerStandingsTab(),
                          _buildSoccerH2HTab(),
                        ]
                      : widget.sport.toUpperCase() == 'NBA'
                      ? [
                          _buildNBAOverviewTab(),
                          _buildNBAStatsTab(),
                          _buildNBAStandingsTab(),
                          _buildNBAH2HTab(),
                          _buildNBAInjuriesTab(),
                        ]
                      : widget.sport.toUpperCase() == 'NFL'
                      ? [
                          _buildNFLOverviewTab(),
                          _buildNFLStatsTab(),
                          _buildNFLStandingsTab(),
                        ]
                      : widget.sport.toUpperCase() == 'NHL'
                      ? [
                          _buildNHLOverviewTab(),
                          _buildNHLBoxScoreTab(),
                          _buildNHLScoringTab(),
                          _buildNHLStandingsTab(),
                        ]
                      : [
                          _buildOverviewTab(),
                          if (_isCombatSport)
                            _buildFightersTab()
                          else
                            _buildOddsTab(),
                          _buildStatsTab(),
                          _buildNewsTab(),
                          _buildPoolsTab(),
                        ],
                  ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _navigateToPoolSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Pools',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryCyan),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(PhosphorIconsRegular.plus),
                color: AppTheme.primaryCyan,
                onPressed: _createPool,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    if (_game == null) return const SizedBox();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getSportColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getSportColor()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getSportIcon(), size: 16, color: _getSportColor()),
                  const SizedBox(width: 4),
                  Text(
                    widget.sport.toUpperCase(),
                    style: TextStyle(
                      color: _getSportColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Event Name
            Text(
              _isCombatSport
                  ? _game!.league ?? '${_game!.awayTeam} vs ${_game!.homeTeam}'
                  : '${_game!.awayTeam} @ ${_game!.homeTeam}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Time and Venue
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.clock,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatEventTime(_game!.gameTime),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                if (_game!.venue != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    PhosphorIconsRegular.mapPin,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _game!.venue!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCombatSport) ...[
            // Tale of the Tape for main event
            if (_game?.fights != null && _game!.fights!.isNotEmpty)
              _buildTaleOfTheTape(),
            if (_game?.fights != null && _game!.fights!.isNotEmpty)
              const SizedBox(height: 24),
            _buildFightCard(),
          ] else ...[
            _buildTeamMatchup(),
          ],
          const SizedBox(height: 24),
          _buildVenueInfo(),
          const SizedBox(height: 24),
          _buildBroadcastInfo(),
        ],
      ),
    );
  }

  Widget _buildRecentForm(List<String>? recentForm) {
    // Generate mock recent form if not provided
    final form = recentForm ?? _generateMockRecentForm();

    return Column(
      children: [
        Text(
          'Last 5',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: form.map((result) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: result == 'W'
                  ? Colors.green.withOpacity(0.3)
                  : result == 'L'
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              border: Border.all(
                color: result == 'W'
                    ? Colors.green
                    : result == 'L'
                    ? Colors.red
                    : Colors.grey,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                result,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: result == 'W'
                      ? Colors.green
                      : result == 'L'
                      ? Colors.red
                      : Colors.grey,
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  List<String> _generateMockRecentForm() {
    // Generate random but realistic recent form
    final random = Random();
    final forms = [
      ['W', 'W', 'W', 'L', 'W'], // Strong recent form
      ['W', 'L', 'W', 'W', 'L'], // Mixed form
      ['L', 'W', 'W', 'W', 'W'], // Comeback form
      ['W', 'W', 'L', 'W', 'W'], // Mostly winning
      ['L', 'L', 'W', 'W', 'W'], // Improving form
    ];
    return forms[random.nextInt(forms.length)];
  }

  Widget _buildTaleOfTheTape() {
    // Get main event (last fight in the list)
    final mainEvent = Map<String, dynamic>.from(_game!.fights!.last);

    // Add mock recent form if not present
    mainEvent['fighter1RecentForm'] ??= _generateMockRecentForm();
    mainEvent['fighter2RecentForm'] ??= _generateMockRecentForm();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryCyan.withOpacity(0.1),
            AppTheme.warningAmber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_mma, color: AppTheme.primaryCyan, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'MAIN EVENT - TALE OF THE TAPE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryCyan,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                // Fighter 1
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryCyan, width: 2),
                          color: AppTheme.primaryCyan.withOpacity(0.1),
                        ),
                        child: Icon(Icons.person, size: 35, color: AppTheme.primaryCyan),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mainEvent['fighter1Name'] ?? mainEvent['fighter1'] ?? 'Fighter 1',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (mainEvent['fighter1Record'] != null)
                        Text(
                          mainEvent['fighter1Record'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      const SizedBox(height: 8),
                      _buildRecentForm(mainEvent['fighter1RecentForm']),
                    ],
                  ),
                ),
                // VS Divider
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBlue,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderCyan),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (mainEvent['rounds'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${mainEvent['rounds']} ROUNDS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (mainEvent['weightClass'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        mainEvent['weightClass'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
                // Fighter 2
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.warningAmber, width: 2),
                          color: AppTheme.warningAmber.withOpacity(0.1),
                        ),
                        child: Icon(Icons.person, size: 35, color: AppTheme.warningAmber),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mainEvent['fighter2Name'] ?? mainEvent['fighter2'] ?? 'Fighter 2',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (mainEvent['fighter2Record'] != null)
                        Text(
                          mainEvent['fighter2Record'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      const SizedBox(height: 8),
                      _buildRecentForm(mainEvent['fighter2RecentForm']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFightCard() {
    if (_game?.fights == null || _game!.fights!.isEmpty) {
      return _buildSimpleFightCard();
    }

    // Organize fights into sections
    final fights = _game!.fights!;
    final mainCard = <Map<String, dynamic>>[];
    final prelims = <Map<String, dynamic>>[];

    // Typically last 5 fights are main card, rest are prelims
    for (int i = 0; i < fights.length; i++) {
      final fight = Map<String, dynamic>.from(fights[i]);
      // Add rounds information based on position
      fight['rounds'] = (i >= fights.length - 5) ? 5 : 3; // Main card fights are usually 5 rounds
      fight['cardPosition'] = i >= fights.length - 5 ? 'main' : 'prelim';

      if (i >= fights.length - 5) {
        mainCard.add(fight);
      } else {
        prelims.add(fight);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Card Section
          if (mainCard.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: AppTheme.primaryCyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'MAIN CARD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mainCard.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                // Reverse order for main card (main event first)
                final fight = mainCard[mainCard.length - 1 - index];
                final isMainEvent = index == 0;

                return Container(
                  color: isMainEvent
                      ? AppTheme.primaryCyan.withOpacity(0.05)
                      : Colors.transparent,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Round indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMainEvent
                              ? AppTheme.primaryCyan
                              : AppTheme.surfaceBlue,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderCyan),
                        ),
                        child: Text(
                          '${fight['rounds'] ?? 5}R',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isMainEvent ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fight['fighter1Name'] ?? fight['fighter1'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (fight['fighter1Record'] != null)
                                  Text(
                                    fight['fighter1Record'],
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'vs',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fight['fighter2Name'] ?? fight['fighter2'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (fight['fighter2Record'] != null)
                                  Text(
                                    fight['fighter2Record'],
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            if (fight['weightClass'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                fight['weightClass'],
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Preliminary Card Section
          if (prelims.isNotEmpty) ...[
            const Divider(height: 1, thickness: 2),
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surfaceBlue.withOpacity(0.5),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'PRELIMINARY CARD',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prelims.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                // Reverse order for prelims too
                final fight = prelims[prelims.length - 1 - index];

                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Round indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBlue,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.5)),
                        ),
                        child: Text(
                          '${fight['rounds'] ?? 3}R',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${fight['fighter1Name'] ?? fight['fighter1'] ?? ''} vs ${fight['fighter2Name'] ?? fight['fighter2'] ?? ''}',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                            if (fight['weightClass'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                fight['weightClass'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleFightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFighterInfo(_game!.awayTeam, true),
              Column(
                children: [
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_game!.league != null)
                    Text(
                      _game!.league!,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              _buildFighterInfo(_game!.homeTeam, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFighterInfo(String name, bool isAway) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            PhosphorIconsRegular.user,
            size: 40,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTeamMatchup() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo(_game!.awayTeam, _game!.awayTeamLogo, true),
          Column(
            children: [
              Text(
                '@',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_game!.league != null)
                Text(
                  _game!.league!,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          _buildTeamInfo(_game!.homeTeam, _game!.homeTeamLogo, false),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(String name, String? logo, bool isAway) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: logo != null
              ? CachedNetworkImage(
                  imageUrl: logo,
                  placeholder: (_, __) => Icon(
                    Icons.sports,
                    size: 40,
                    color: Colors.grey,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.sports,
                    size: 40,
                    color: Colors.grey,
                  ),
                )
              : Icon(
                  Icons.sports,
                  size: 40,
                  color: Colors.grey,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVenueInfo() {
    if (_game?.venue == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.mapPin,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _game!.venue!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastInfo() {
    if (_game?.broadcast == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Broadcast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.television,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 12),
              Text(
                _game!.broadcast!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOddsTab() {
    return const Center(
      child: Text('Odds comparison coming soon'),
    );
  }

  Widget _buildFightersTab() {
    if (_game?.fights == null || _game!.fights!.isEmpty) {
      return const Center(
        child: Text('No fighter information available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fighters on Card',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _game!.fights!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // Show fights in reverse order (main event first)
              final reversedIndex = _game!.fights!.length - 1 - index;
              final fight = _game!.fights![reversedIndex];
              final isMainEvent = reversedIndex == _game!.fights!.length - 1;

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMainEvent
                      ? AppTheme.primaryCyan
                      : AppTheme.borderCyan.withOpacity(0.3),
                    width: isMainEvent ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (isMainEvent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'MAIN EVENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Fighter 1
                          InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/fighter-details',
                                arguments: {
                                  'fighterId': fight['fighter1Id'] ?? (fight['fighter1Name'] ?? fight['fighter1'] ?? '').replaceAll(' ', '_').toLowerCase(),
                                  'fighterName': fight['fighter1Name'] ?? fight['fighter1'],
                                  'record': fight['fighter1Record'],
                                  'sport': widget.sport,
                                  'espnId': fight['fighter1EspnId'],
                                },
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryCyan.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppTheme.primaryCyan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fight['fighter1Name'] ?? fight['fighter1'] ?? 'TBD',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (fight['fighter1Record'] != null && fight['fighter1Record'] != '')
                                        Text(
                                          fight['fighter1Record'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[700])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey[700])),
                              ],
                            ),
                          ),

                          // Fighter 2
                          InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/fighter-details',
                                arguments: {
                                  'fighterId': fight['fighter2Id'] ?? (fight['fighter2Name'] ?? fight['fighter2'] ?? '').replaceAll(' ', '_').toLowerCase(),
                                  'fighterName': fight['fighter2Name'] ?? fight['fighter2'],
                                  'record': fight['fighter2Record'],
                                  'sport': widget.sport,
                                  'espnId': fight['fighter2EspnId'],
                                },
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningAmber.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppTheme.warningAmber,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fight['fighter2Name'] ?? fight['fighter2'] ?? 'TBD',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (fight['fighter2Record'] != null && fight['fighter2Record'] != '')
                                        Text(
                                          fight['fighter2Record'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),

                          if (fight['weightClass'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                fight['weightClass'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return const Center(
      child: Text('Statistics coming soon'),
    );
  }

  Widget _buildNewsTab() {
    return const Center(
      child: Text('News and updates coming soon'),
    );
  }

  Widget _buildPoolsTab() {
    return const Center(
      child: Text('Available pools coming soon'),
    );
  }

  // Baseball-specific tab builders
  Widget _buildBaseballMatchupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPitchingMatchupCard(),
          const SizedBox(height: 16),
          _buildWeatherCard(),
          const SizedBox(height: 16),
          _buildTeamFormCard(),
        ],
      ),
    );
  }

  Widget _buildBaseballBoxScoreTab() {
    if (_boxScore == null) {
      return const Center(
        child: Text('Box score data not available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLineScore(),
          const SizedBox(height: 16),
          _buildBattingStats(),
          const SizedBox(height: 16),
          _buildPitchingStats(),
        ],
      ),
    );
  }

  Widget _buildBaseballStatsTab() {
    return Column(
      children: [
        // Team selector toggle
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTeam = 'away'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTeam == 'away'
                          ? AppTheme.primaryCyan.withOpacity(0.2)
                          : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          bottomLeft: Radius.circular(11),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _game?.awayTeam ?? 'Away',
                          style: TextStyle(
                            color: _selectedTeam == 'away'
                              ? AppTheme.primaryCyan
                              : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: AppTheme.borderCyan.withOpacity(0.3)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTeam = 'home'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTeam == 'home'
                          ? AppTheme.primaryCyan.withOpacity(0.2)
                          : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(11),
                          bottomRight: Radius.circular(11),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _game?.homeTeam ?? 'Home',
                          style: TextStyle(
                            color: _selectedTeam == 'home'
                              ? AppTheme.primaryCyan
                              : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTeamStatsContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildPitchingMatchupCard() {
    print('Building Pitching Matchup Card...');
    print('Event details available: ${_eventDetails != null}');

    final competition = _eventDetails?['competitions']?[0];
    final probables = competition?['probables'] as List? ?? [];
    final competitors = competition?['competitors'] as List? ?? [];

    print('Probables count: ${probables.length}');

    Map<String, dynamic>? awayPitcher;
    Map<String, dynamic>? homePitcher;
    String? awayTeamName;
    String? homeTeamName;
    String? awayLogoUrl;
    String? homeLogoUrl;

    // Get team names and logos from competitors
    for (final team in competitors) {
      if (team['homeAway'] == 'away') {
        awayTeamName = team['team']?['displayName'];
        // Try to get logo URL directly from API response
        final logos = team['team']?['logos'] as List?;
        if (logos != null && logos.isNotEmpty) {
          awayLogoUrl = logos[0]['href'];
        }
      } else {
        homeTeamName = team['team']?['displayName'];
        // Try to get logo URL directly from API response
        final logos = team['team']?['logos'] as List?;
        if (logos != null && logos.isNotEmpty) {
          homeLogoUrl = logos[0]['href'];
        }
      }
    }

    // Fallback to game data if team names not found
    awayTeamName ??= _game?.awayTeam;
    homeTeamName ??= _game?.homeTeam;

    // Try to get logos from boxscore teams if not found
    if ((awayLogoUrl == null || homeLogoUrl == null) && _boxScore != null) {
      final teams = _boxScore!['teams'] as List?;
      if (teams != null) {
        for (final teamData in teams) {
          final team = teamData['team'];
          if (team != null) {
            final displayName = team['displayName'];
            if (displayName == awayTeamName && awayLogoUrl == null) {
              awayLogoUrl = team['logo'];
            } else if (displayName == homeTeamName && homeLogoUrl == null) {
              homeLogoUrl = team['logo'];
            }
          }
        }
      }
    }

    for (final probable in probables) {
      if (probable['homeAway'] == 'away') {
        awayPitcher = probable;
      } else {
        homePitcher = probable;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_baseball, color: AppTheme.primaryCyan),
                SizedBox(width: 8),
                Text(
                  'STARTING PITCHERS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryCyan,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Away Pitcher with Team Logo
                Expanded(
                  child: Column(
                    children: [
                      // Show logo if we have URL or team name
                      if (awayLogoUrl != null) ...[
                        Image.network(
                          awayLogoUrl,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stack) =>
                            const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                      ] else if (awayTeamName != null) ...[
                        FutureBuilder<TeamLogoData?>(
                          future: TeamLogoService().getTeamLogo(
                            teamName: awayTeamName,
                            sport: 'MLB',
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data?.logoUrl != null) {
                              return Image.network(
                                snapshot.data!.logoUrl!,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stack) =>
                                  const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                              );
                            }
                            return const Icon(Icons.sports_baseball, size: 60, color: Colors.grey);
                          },
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                        const SizedBox(height: 8),
                      ],
                      _buildPitcherInfo(awayPitcher, true),
                    ],
                  ),
                ),
                // VS Divider
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                // Home Pitcher with Team Logo
                Expanded(
                  child: Column(
                    children: [
                      // Show logo if we have URL or team name
                      if (homeLogoUrl != null) ...[
                        Image.network(
                          homeLogoUrl,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stack) =>
                            const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                      ] else if (homeTeamName != null) ...[
                        FutureBuilder<TeamLogoData?>(
                          future: TeamLogoService().getTeamLogo(
                            teamName: homeTeamName,
                            sport: 'MLB',
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data?.logoUrl != null) {
                              return Image.network(
                                snapshot.data!.logoUrl!,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stack) =>
                                  const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                              );
                            }
                            return const Icon(Icons.sports_baseball, size: 60, color: Colors.grey);
                          },
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        const Icon(Icons.sports_baseball, size: 60, color: Colors.grey),
                        const SizedBox(height: 8),
                      ],
                      _buildPitcherInfo(homePitcher, false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitcherInfo(Map<String, dynamic>? pitcher, bool isAway) {
    final athlete = pitcher?['athlete'];
    final stats = pitcher?['statistics'] as List? ?? [];

    String era = 'N/A';
    String record = 'N/A';

    for (final stat in stats) {
      if (stat['abbreviation'] == 'ERA') {
        era = stat['displayValue'] ?? 'N/A';
      } else if (stat['abbreviation'] == 'W-L') {
        record = stat['displayValue'] ?? 'N/A';
      }
    }

    return Column(
      children: [
        Text(
          athlete?['fullName'] ?? 'TBD',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          record,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ERA: $era',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    final weather = _eventDetails?['competitions']?[0]?['weather'];

    if (weather == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEATHER CONDITIONS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Icon(Icons.thermostat, color: AppTheme.warningAmber),
                  const SizedBox(height: 4),
                  Text(
                    '${weather['temperature'] ?? 'N/A'}°F',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.air, color: AppTheme.secondaryCyan),
                  const SizedBox(height: 4),
                  Text(
                    weather['displayValue'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFormCard() {
    final competitors = _eventDetails?['competitions']?[0]?['competitors'] as List? ?? [];

    Map<String, dynamic>? awayTeam;
    Map<String, dynamic>? homeTeam;

    for (final team in competitors) {
      if (team['homeAway'] == 'away') {
        awayTeam = team;
      } else {
        homeTeam = team;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'TEAM FORM',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTeamFormInfo(awayTeam),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: AppTheme.borderCyan.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildTeamFormInfo(homeTeam),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFormInfo(Map<String, dynamic>? team) {
    final records = team?['records'] as List? ?? [];
    String overallRecord = 'N/A';
    String last10 = 'N/A';

    for (final record in records) {
      if (record['type'] == 'total') {
        overallRecord = record['summary'] ?? 'N/A';
      } else if (record['type'] == 'last-ten-games') {
        last10 = record['summary'] ?? 'N/A';
      }
    }

    return Column(
      children: [
        Text(
          team?['team']?['abbreviation'] ?? 'N/A',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          overallRecord,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.primaryCyan,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last 10: $last10',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildLineScore() {
    final teams = _boxScore?['teams'] as List? ?? [];

    if (teams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('Line score not available'),
        ),
      );
    }

    // Extract line score data
    List<Map<String, dynamic>> lineScoreData = [];
    for (final team in teams) {
      final teamInfo = team['team'];
      final stats = team['statistics'] as List? ?? [];

      // Find innings data
      Map<String, dynamic> inningsData = {
        'team': teamInfo?['abbreviation'] ?? '',
        'innings': [],
        'runs': 0,
        'hits': 0,
        'errors': 0,
      };

      // Extract batting stats for R/H/E
      for (final statGroup in stats) {
        if (statGroup['name'] == 'batting') {
          final battingStats = statGroup['stats'] as List? ?? [];
          for (final stat in battingStats) {
            if (stat['name'] == 'runs') {
              inningsData['runs'] = stat['value']?.toInt() ?? 0;
            } else if (stat['name'] == 'hits') {
              inningsData['hits'] = stat['value']?.toInt() ?? 0;
            } else if (stat['name'] == 'errors') {
              inningsData['errors'] = stat['value']?.toInt() ?? 0;
            }
          }
        }
      }

      lineScoreData.add(inningsData);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Text(
              'LINE SCORE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(35),
                columnWidths: const {
                  0: FixedColumnWidth(50), // Team column slightly wider
                },
                children: [
                  // Header row
                  TableRow(
                    children: [
                      const Text(''),
                      ...List.generate(9, (index) => Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                      )),
                      Center(
                        child: Text(
                          'R',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'H',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'E',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                // Divider
                TableRow(
                  children: List.generate(13, (_) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        color: AppTheme.borderCyan.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                // Team rows
                ...lineScoreData.map((team) => TableRow(
                  children: [
                    Text(
                      team['team'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // Innings (placeholder for now as we don't have inning data)
                    ...List.generate(9, (index) => Center(
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    )),
                    // R/H/E
                    Center(
                      child: Text(
                        '${team['runs']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${team['hits']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${team['errors']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                )),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingStats() {
    final teams = _boxScore?['teams'] as List? ?? [];

    if (teams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('Batting statistics not available'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Text(
              'BATTING STATISTICS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Team batting stats
          ...teams.map((team) {
            final teamInfo = team['team'];
            final stats = team['statistics'] as List? ?? [];

            // Extract batting stats
            Map<String, dynamic> battingData = {
              'team': teamInfo?['displayName'] ?? '',
              'abbreviation': teamInfo?['abbreviation'] ?? '',
            };

            for (final statGroup in stats) {
              if (statGroup['name'] == 'batting') {
                final battingStats = statGroup['stats'] as List? ?? [];
                for (final stat in battingStats) {
                  battingData[stat['name']] = stat['displayValue'] ?? '0';
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team name
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        color: AppTheme.primaryCyan,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        battingData['team'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats grid - made scrollable horizontally
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatItem('AB', battingData['atBats'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('R', battingData['runs'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('H', battingData['hits'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('RBI', battingData['RBIs'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('BB', battingData['walks'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('K', battingData['strikeouts'] ?? '0'),
                        const SizedBox(width: 16),
                        _buildStatItem('AVG', battingData['avg'] ?? '.000'),
                        const SizedBox(width: 16),
                        _buildStatItem('OBP', battingData['obp'] ?? '.000'),
                        const SizedBox(width: 16),
                        _buildStatItem('SLG', battingData['slg'] ?? '.000'),
                        const SizedBox(width: 16),
                        _buildStatItem('LOB', battingData['leftOnBase'] ?? '0'),
                      ],
                    ),
                  ),
                  if (teams.indexOf(team) < teams.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Divider(
                        color: AppTheme.borderCyan.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      width: 60,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchingStats() {
    final teams = _boxScore?['teams'] as List? ?? [];

    if (teams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('Pitching statistics not available'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Text(
              'PITCHING STATISTICS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.warningAmber,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Team pitching stats
          ...teams.map((team) {
            final teamInfo = team['team'];
            final stats = team['statistics'] as List? ?? [];

            // Extract pitching stats
            Map<String, dynamic> pitchingData = {
              'team': teamInfo?['displayName'] ?? '',
              'abbreviation': teamInfo?['abbreviation'] ?? '',
            };

            for (final statGroup in stats) {
              if (statGroup['name'] == 'pitching') {
                final pitchingStats = statGroup['stats'] as List? ?? [];
                for (final stat in pitchingStats) {
                  pitchingData[stat['name']] = stat['displayValue'] ?? '0';
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team name
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        color: AppTheme.warningAmber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pitchingData['team'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats grid
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _buildStatItem('IP', pitchingData['inningsPitched'] ?? '0.0'),
                      _buildStatItem('H', pitchingData['hits'] ?? '0'),
                      _buildStatItem('R', pitchingData['runs'] ?? '0'),
                      _buildStatItem('ER', pitchingData['earnedRuns'] ?? '0'),
                      _buildStatItem('BB', pitchingData['walks'] ?? '0'),
                      _buildStatItem('K', pitchingData['strikeouts'] ?? '0'),
                      _buildStatItem('HR', pitchingData['homeRuns'] ?? '0'),
                      _buildStatItem('ERA', pitchingData['ERA'] ?? '0.00'),
                      _buildStatItem('WHIP', pitchingData['WHIP'] ?? '0.00'),
                      _buildStatItem('PC', pitchingData['pitchCount'] ?? '0'),
                    ],
                  ),
                  if (teams.indexOf(team) < teams.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Divider(
                        color: AppTheme.borderCyan.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBoxScoreStats(Map<String, dynamic> teamData) {
    final team = teamData['team'];
    final statistics = teamData['statistics'] as List? ?? [];

    // Find batting and pitching stats
    Map<String, dynamic>? battingStats;
    Map<String, dynamic>? pitchingStats;

    for (final statGroup in statistics) {
      if (statGroup['name'] == 'batting') {
        battingStats = statGroup;
      } else if (statGroup['name'] == 'pitching') {
        pitchingStats = statGroup;
      }
    }

    return Column(
      children: [
        if (battingStats != null) ...[
          _buildStatSection('Batting Statistics', battingStats),
          const SizedBox(height: 16),
        ],
        if (pitchingStats != null) ...[
          _buildStatSection('Pitching Statistics', pitchingStats),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStatSection(String title, Map<String, dynamic> statGroup) {
    final stats = statGroup['stats'] as List? ?? [];

    // Select key stats to display
    final keyStats = <String, String>{};
    for (final stat in stats) {
      final name = stat['name'] as String;
      final displayValue = stat['displayValue'] as String;
      final displayName = stat['displayName'] as String;

      // Pick important stats based on category
      if (title.contains('Batting')) {
        if (['avg', 'hits', 'runs', 'RBIs', 'homeRuns', 'strikeouts', 'walks', 'OPS'].contains(name)) {
          keyStats[displayName] = displayValue;
        }
      } else if (title.contains('Pitching')) {
        if (['ERA', 'WHIP', 'strikeouts', 'walks', 'innings', 'earnedRuns', 'hits', 'saves'].contains(name)) {
          keyStats[displayName] = displayValue;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...keyStats.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                Text(
                  entry.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTeamStatsContent() {
    // Try to get stats from box score if available
    if (_boxScore != null && _boxScore!['teams'] != null) {
      final teams = _boxScore!['teams'] as List;

      // Find the selected team's stats from box score
      for (final teamData in teams) {
        final team = teamData['team'];
        final isHome = _selectedTeam == 'home' &&
            (team['displayName'] == _game?.homeTeam || team['location'] == _game?.homeTeam);
        final isAway = _selectedTeam == 'away' &&
            (team['displayName'] == _game?.awayTeam || team['location'] == _game?.awayTeam);

        if (isHome || isAway) {
          // Use box score statistics
          return _buildBoxScoreStats(teamData);
        }
      }
    }

    // Fallback to competitors data if available
    final competitors = _eventDetails?['competitions']?[0]?['competitors'] as List? ?? [];
    Map<String, dynamic>? selectedTeamData;

    for (final team in competitors) {
      if (team['homeAway'] == _selectedTeam) {
        selectedTeamData = team;
        break;
      }
    }

    if (selectedTeamData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('Team stats not available'),
        ),
      );
    }

    final teamInfo = selectedTeamData['team'];
    final records = selectedTeamData['records'] as List? ?? [];
    final stats = selectedTeamData['statistics'] as List? ?? [];

    // Parse records
    String overallRecord = 'N/A';
    String homeRecord = 'N/A';
    String awayRecord = 'N/A';
    String divisionRecord = 'N/A';
    String last10Record = 'N/A';
    String dayRecord = 'N/A';
    String nightRecord = 'N/A';

    for (final record in records) {
      final type = record['type'] ?? '';
      final summary = record['summary'] ?? 'N/A';

      switch (type) {
        case 'total':
          overallRecord = summary;
          break;
        case 'home':
          homeRecord = summary;
          break;
        case 'road':
          awayRecord = summary;
          break;
        case 'division':
          divisionRecord = summary;
          break;
        case 'last-ten-games':
          last10Record = summary;
          break;
        case 'day':
          dayRecord = summary;
          break;
        case 'night':
          nightRecord = summary;
          break;
      }
    }

    // Parse team stats
    Map<String, String> teamStats = {};
    for (final stat in stats) {
      final name = stat['name'] ?? '';
      final displayValue = stat['displayValue'] ?? 'N/A';
      teamStats[name] = displayValue;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Team Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (teamInfo?['logo'] != null)
                      Image.network(
                        teamInfo!['logo'],
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.sports_baseball,
                          size: 40,
                          color: AppTheme.primaryCyan,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Text(
                      teamInfo?['displayName'] ?? 'Team',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  overallRecord,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Records Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECORDS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryCyan,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecordRow('Overall', overallRecord),
                _buildRecordRow('Home', homeRecord),
                _buildRecordRow('Away', awayRecord),
                // Only show these for non-MLB sports since ESPN doesn't provide them for MLB
                if (widget.sport.toUpperCase() != 'MLB') ...[
                  _buildRecordRow('Division', divisionRecord),
                  _buildRecordRow('Last 10', last10Record),
                  _buildRecordRow('Day Games', dayRecord),
                  _buildRecordRow('Night Games', nightRecord),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Team Stats Section
          if (teamStats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEAM STATISTICS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    children: teamStats.entries.map((entry) {
                      return _buildStatItem(
                        entry.key.toUpperCase(),
                        entry.value,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(String label, String record) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          Text(
            record,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSportColor() {
    switch (widget.sport.toUpperCase()) {
      case 'NFL':
        return AppTheme.primaryCyan;
      case 'NBA':
        return AppTheme.warningAmber;
      case 'MLB':
        return AppTheme.errorPink;
      case 'NHL':
        return AppTheme.secondaryCyan;
      case 'MMA':
      case 'UFC':
        return AppTheme.secondaryCyan;
      case 'BOXING':
        return AppTheme.warningAmber;
      case 'SOCCER':
        return AppTheme.neonGreen;
      default:
        return AppTheme.surfaceBlue;
    }
  }

  IconData _getSportIcon() {
    switch (widget.sport.toUpperCase()) {
      case 'NFL':
        return Icons.sports_football;
      case 'NBA':
        return Icons.sports_basketball;
      case 'MLB':
        return Icons.sports_baseball;
      case 'NHL':
        return Icons.sports_hockey;
      case 'MMA':
      case 'UFC':
      case 'BOXING':
        return Icons.sports_mma;
      case 'SOCCER':
        return Icons.sports_soccer;
      case 'TENNIS':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  void _shareEvent() {
    // TODO: Implement share functionality
  }

  void _setReminder() {
    // TODO: Implement reminder functionality
  }

  void _navigateToPoolSelection() {
    Navigator.pushNamed(
      context,
      '/pool-selection',
      arguments: {
        'gameTitle': _isCombatSport
            ? (_game!.league ?? '${_game!.awayTeam} vs ${_game!.homeTeam}')
            : '${_game!.awayTeam} @ ${_game!.homeTeam}',
        'sport': widget.sport,
        'gameId': widget.gameId,
      },
    );
  }

  void _createPool() {
    // TODO: Implement pool creation
  }

  // Soccer-specific tab builders
  Widget _buildSoccerOverviewTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading match details...'));
    }

    // Get team logos from ESPN data
    String? homeTeamLogo;
    String? awayTeamLogo;

    try {
      // Try to get logos from boxscore -> teams
      final boxscore = _eventDetails!['boxscore'];
      if (boxscore != null && boxscore['teams'] != null) {
        final teams = boxscore['teams'] as List;
        if (teams.length >= 2) {
          // Away team is usually first in ESPN data
          awayTeamLogo = teams[0]['team']?['logo'];
          homeTeamLogo = teams[1]['team']?['logo'];
        }
      }

      // Fallback to header competitors if boxscore doesn't have logos
      if ((homeTeamLogo == null || awayTeamLogo == null) && _eventDetails!['header'] != null) {
        final competitors = _eventDetails!['header']['competitions']?[0]?['competitors'];
        if (competitors != null && competitors is List && competitors.length >= 2) {
          for (var competitor in competitors) {
            if (competitor['homeAway'] == 'home') {
              homeTeamLogo = homeTeamLogo ?? competitor['team']?['logo'];
            } else {
              awayTeamLogo = awayTeamLogo ?? competitor['team']?['logo'];
            }
          }
        }
      }
    } catch (e) {
      print('Error extracting team logos: $e');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Teams and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildSoccerTeamColumn(_game!.homeTeam, homeTeamLogo ?? _game!.homeTeamLogo, true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            _game!.status == 'scheduled'
                                ? DateFormat('MMM d').format(_game!.gameTime)
                                : '${_game!.homeScore ?? 0} - ${_game!.awayScore ?? 0}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryCyan,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _game!.status == 'scheduled'
                                ? DateFormat('h:mm a').format(_game!.gameTime)
                                : _game!.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildSoccerTeamColumn(_game!.awayTeam, awayTeamLogo ?? _game!.awayTeamLogo, false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Venue
                if (_game!.venue != null) ...[
                  const Divider(color: AppTheme.borderCyan),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stadium, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _game!.venue!,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Basic Odds Display (not detailed - that's for Edge Card)
          if (_game!.odds != null && _game!.odds!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATCH ODDS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildOddsColumn('Home', _game!.odds!['home'] ?? 'N/A'),
                      _buildOddsColumn('Draw', _game!.odds!['draw'] ?? 'N/A'),
                      _buildOddsColumn('Away', _game!.odds!['away'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'For detailed odds from all bookmakers, check Edge Cards',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSoccerStatsTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading stats...'));
    }

    final boxscore = _eventDetails!['boxscore'] as Map<String, dynamic>?;
    final teams = boxscore?['teams'] as List? ?? [];
    final form = boxscore?['form'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Team Form
          if (form.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECENT FORM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...form.map((teamForm) {
                    final team = teamForm['team'] ?? {};
                    // ESPN returns 'events' not 'games' for soccer
                    final games = teamForm['events'] as List? ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team['displayName'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: games.take(5).map((game) {
                            // ESPN returns 'gameResult' not 'result' for soccer
                            final result = game['gameResult'] ?? '';
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: result == 'W'
                                    ? Colors.green
                                    : result == 'L'
                                    ? Colors.red
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  result,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Season Statistics
          if (teams.isNotEmpty) ...[
            ...teams.map((team) {
              final teamInfo = team['team'] ?? {};
              final stats = team['statistics'] as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamInfo['displayName'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...stats.map((stat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              stat['label'] ?? stat['name'] ?? '',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              stat['displayValue'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSoccerStandingsTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading standings...'));
    }

    // Standings can be either a List or a Map, handle both cases
    dynamic standingsData = _eventDetails!['standings'];
    List standings = [];

    if (standingsData is List) {
      standings = standingsData;
    } else if (standingsData is Map) {
      // If it's a map, it might contain the standings in a nested structure
      // Try to extract the actual standings list
      if (standingsData['groups'] is List) {
        standings = standingsData['groups'] as List;
      } else if (standingsData['entries'] is List) {
        standings = standingsData['entries'] as List;
      }
    }

    if (standings.isEmpty) {
      return const Center(child: Text('Standings not available'));
    }

    // Get the first group (usually the main league table)
    final group = standings.isNotEmpty ? standings[0] : null;
    List entries = [];

    // The standings can be in different formats
    if (group != null) {
      final standingsData = group['standings'];
      if (standingsData is List) {
        entries = standingsData;
      } else if (standingsData is Map) {
        // ESPN sometimes returns standings as a map with 'entries' key
        entries = standingsData['entries'] ?? [];
      }
    }

    if (entries.isEmpty) {
      return const Center(child: Text('No standings data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEAGUE STANDINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            // Table headers
            Row(
              children: [
                const SizedBox(width: 25),
                Expanded(flex: 3, child: Text('Team', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 28, child: Text('P', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('W', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('D', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 28, child: Text('L', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('GD', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 32, child: Text('Pts', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
            const Divider(color: AppTheme.borderCyan, height: 20),
            // Table rows
            ...entries.map((entry) {
              // Team can be either a string or a map
              String teamName = 'Unknown';
              if (entry['team'] is String) {
                teamName = entry['team'];
              } else if (entry['team'] is Map) {
                final teamMap = entry['team'] as Map;
                teamName = teamMap['displayName'] ?? teamMap['name'] ?? 'Unknown';
              }

              final stats = entry['stats'] as List? ?? [];

              // Extract stats including rank
              String gamesPlayed = '0';
              String wins = '0';
              String draws = '0';
              String losses = '0';
              String goalDiff = '0';
              String points = '0';
              String rank = '';

              for (final stat in stats) {
                final name = stat['name']?.toString() ?? '';
                final value = stat['displayValue']?.toString() ?? '0';

                switch (name.toLowerCase()) {
                  case 'gamesplayed':
                  case 'games played':
                  case 'gp':
                    gamesPlayed = value;
                    break;
                  case 'wins':
                  case 'w':
                    wins = value;
                    break;
                  case 'ties':
                  case 'draws':
                  case 'd':
                    draws = value;
                    break;
                  case 'losses':
                  case 'l':
                    losses = value;
                    break;
                  case 'point differential':
                  case 'goal difference':
                  case 'gd':
                  case 'pointdifferential':
                    goalDiff = value;
                    break;
                  case 'points':
                  case 'pts':
                  case 'p':
                    points = value;
                    break;
                  case 'rank':
                  case 'r':
                    rank = value;
                    break;
                }
              }

              // If rank wasn't in stats, try to get it from entry
              if (rank.isEmpty && entry['rank'] != null) {
                rank = entry['rank'].toString();
              }

              final isOurTeam = teamName == widget.gameData?.homeTeam ||
                               teamName == widget.gameData?.awayTeam;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isOurTeam ? AppTheme.primaryCyan.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 25,
                      child: Text(
                        rank,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        teamName,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        gamesPlayed,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white70,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        wins,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white70,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        draws,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white70,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        losses,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white70,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        goalDiff,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white70,
                          fontWeight: isOurTeam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        points,
                        style: TextStyle(
                          color: isOurTeam ? AppTheme.primaryCyan : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSoccerH2HTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading head-to-head...'));
    }

    // Handle both List and Map cases for head-to-head data
    dynamic h2hData = _eventDetails!['headToHeadGames'];
    List h2hGames = [];

    if (h2hData is List) {
      h2hGames = h2hData;
    } else if (h2hData is Map) {
      // If it's a map, try to extract the games list
      if (h2hData['games'] is List) {
        h2hGames = h2hData['games'] as List;
      } else if (h2hData['events'] is List) {
        h2hGames = h2hData['events'] as List;
      }
    }

    if (h2hGames.isEmpty) {
      return const Center(child: Text('No previous meetings found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HEAD TO HEAD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ...h2hGames.take(10).map((game) {
              final date = game['date'] ?? '';
              final homeTeam = game['homeTeam'] ?? {};
              final awayTeam = game['awayTeam'] ?? {};
              final homeScore = game['homeScore'] ?? 0;
              final awayScore = game['awayScore'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderCyan.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          homeTeam['displayName'] ?? '',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '$homeScore - $awayScore',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                        Text(
                          awayTeam['displayName'] ?? '',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String name, String? logo, bool isHome) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: logo != null
              ? CachedNetworkImage(
                  imageUrl: logo,
                  placeholder: (_, __) => Icon(
                    Icons.sports_soccer,
                    size: 30,
                    color: Colors.grey,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.sports_soccer,
                    size: 30,
                    color: Colors.grey,
                  ),
                )
              : Icon(
                  Icons.sports_soccer,
                  size: 30,
                  color: Colors.grey,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          isHome ? 'HOME' : 'AWAY',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSoccerTeamColumn(String name, String? logo, bool isHome) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: logo != null
                ? CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(
                      Icons.sports_soccer,
                      size: 30,
                      color: Colors.grey,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.sports_soccer,
                      size: 30,
                      color: Colors.grey,
                    ),
                  )
                : Icon(
                    Icons.sports_soccer,
                    size: 30,
                    color: Colors.grey,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          isHome ? 'HOME' : 'AWAY',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildOddsColumn(String label, String odds) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          odds,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // NBA Implementation Methods
  Future<void> _loadNBADetails() async {
    try {
      print('=== LOADING NBA DETAILS ===');
      print('Game ID: ${widget.gameId}');
      print('Game Data Available: ${_game != null}');
      print('Teams: ${_game?.awayTeam} vs ${_game?.homeTeam}');
      print('Game Date: ${_game?.gameTime}');
      print('Current ESPN ID: ${_game?.espnId}');

      // Use the ESPN ID resolver service - same pattern as soccer
      final resolver = EspnIdResolverService();

      // Check if game already has ESPN ID
      var espnGameId = _game?.espnId;

      // If no ESPN ID, resolve it
      if (espnGameId == null && _game != null) {
        print('🔍 No ESPN ID found, attempting to resolve...');
        print('Resolver input - Away: ${_game!.awayTeam}, Home: ${_game!.homeTeam}, Date: ${_game!.gameTime}');
        espnGameId = await resolver.resolveEspnId(_game!);

        if (espnGameId != null) {
          print('✅ ESPN ID resolved successfully: $espnGameId');
        } else {
          print('❌ Could not resolve ESPN ID for Lakers @ Warriors');
          print('Please check if team names match ESPN format');
          return;
        }
      } else if (espnGameId == null) {
        print('❌ No game data available to resolve ESPN ID');
        return;
      } else {
        print('✅ Using existing ESPN ID: $espnGameId');
      }

      if (espnGameId != null) {
        print('🌐 Fetching NBA game summary from ESPN...');
        final espnUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=$espnGameId';
        print('ESPN URL: $espnUrl');

        final response = await http.get(Uri.parse(espnUrl));
        print('ESPN Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ ESPN NBA data received successfully');
          print('Data keys: ${data.keys.toList()}');

          // Log header info if available
          if (data['header'] != null) {
            print('Game Status: ${data['header']['competitions']?[0]?['status']?['type']?['name']}');
          }

          setState(() {
            _eventDetails = data;

            // Extract boxscore if available
            if (data['boxscore'] != null) {
              _boxScore = data['boxscore'];
              print('✅ Box score data extracted');
            } else {
              print('⚠️ No box score data available');
            }
          });
        } else {
          print('❌ Failed to fetch ESPN NBA data');
          print('Status Code: ${response.statusCode}');
          print('Response Body: ${response.body.substring(0, min(500, response.body.length))}');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error loading NBA details: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadNFLDetails() async {
    try {
      print('=== LOADING NFL DETAILS ===');
      print('Game ID: ${widget.gameId}');
      print('Teams: ${_game?.awayTeam} vs ${_game?.homeTeam}');

      // Use the ESPN ID resolver service
      final resolver = EspnIdResolverService();

      // Check if game already has ESPN ID
      var espnGameId = _game?.espnId;

      // If no ESPN ID, resolve it
      if (espnGameId == null && _game != null) {
        print('Resolving ESPN ID using resolver service...');
        espnGameId = await resolver.resolveEspnId(_game!);

        if (espnGameId != null) {
          print('✅ ESPN ID resolved: $espnGameId');
        } else {
          print('❌ Could not resolve ESPN ID');
          // Show user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Game details are temporarily unavailable'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else if (espnGameId == null) {
        print('❌ No game data available to resolve ESPN ID');
        return;
      }

      print('Using ESPN ID: $espnGameId');

      // Fetch game summary data from ESPN
      final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=$espnGameId';
      print('Fetching summary from: $summaryUrl');

      final summaryResponse = await http.get(Uri.parse(summaryUrl));
      print('Summary response status: ${summaryResponse.statusCode}');

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);

        // Log available data sections
        print('Summary data keys: ${summaryData.keys.toList()}');

        // Debug logging for boxscore
        print('🔍 NFL boxscore data: ${summaryData['boxscore'] != null ? 'Found' : 'Not found'}');
        if (summaryData['boxscore'] != null) {
          print('  Boxscore keys: ${summaryData['boxscore'].keys.toList()}');
        }

        // Debug logging for lastFiveGames
        print('🔍 lastFiveGames in summaryData: ${summaryData['lastFiveGames'] != null ? 'EXISTS' : 'NULL'}');
        if (summaryData['lastFiveGames'] != null) {
          print('  lastFiveGames type: ${summaryData['lastFiveGames'].runtimeType}');
          if (summaryData['lastFiveGames'] is List) {
            print('  lastFiveGames is a List with ${(summaryData['lastFiveGames'] as List).length} items');
          }
        }

        // Debug logging for leaders data
        print('🔍 NFL leaders data: ${summaryData['leaders'] != null ? 'EXISTS' : 'NULL'}');
        if (summaryData['leaders'] != null) {
          print('  Leaders type: ${summaryData['leaders'].runtimeType}');
          if (summaryData['leaders'] is List) {
            final leadersList = summaryData['leaders'] as List;
            print('  Leaders is a List with ${leadersList.length} teams');
            if (leadersList.isNotEmpty) {
              print('  First team data: ${leadersList[0]}');
            }
          }
        }

        // Debug logging for STANDINGS data
        print('🏈 NFL STANDINGS CHECK:');
        print('  standings key exists: ${summaryData.containsKey('standings')}');
        print('  standings data: ${summaryData['standings'] != null ? 'EXISTS' : 'NULL'}');
        if (summaryData['standings'] != null) {
          final standings = summaryData['standings'];
          print('  Standings type: ${standings.runtimeType}');
          print('  Standings keys: ${standings is Map ? standings.keys.toList() : 'N/A'}');
          if (standings is Map && standings['groups'] != null) {
            print('  Groups found: ${standings['groups'] is List ? (standings['groups'] as List).length : 'Not a list'}');
            if (standings['groups'] is List && (standings['groups'] as List).isNotEmpty) {
              final firstGroup = standings['groups'][0];
              print('  First group keys: ${firstGroup.keys.toList()}');
              print('  First group name: ${firstGroup['name'] ?? firstGroup['header']}');
            }
          }
        }

        setState(() {
          _boxScore = summaryData['boxscore'];
          _gameData = summaryData;
          // Use header.competitions for event details
          if (summaryData['header']?['competitions'] != null &&
              (summaryData['header']['competitions'] as List).isNotEmpty) {
            _eventDetails = {
              ...summaryData,
              'competitions': summaryData['header']['competitions'],
            };
          } else {
            _eventDetails = summaryData;
          }
        });

        // Also check for weather data in scoreboard if outdoor venue
        if (summaryData['header']?['competitions']?[0]?['venue']?['indoor'] == false) {
          print('Outdoor venue detected, checking for weather data...');
          // Weather might be in the scoreboard endpoint for live/upcoming games
          await _loadNFLWeatherData(espnGameId);
        }
      } else {
        print('❌ Summary API failed with status ${summaryResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading NFL details: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadNFLWeatherData(String espnGameId) async {
    try {
      // Get current date or game date
      DateTime? gameDate;
      if (_eventDetails?['header']?['competitions']?[0]?['date'] != null) {
        try {
          gameDate = DateTime.parse(_eventDetails!['header']['competitions'][0]['date']);
        } catch (e) {
          print('Error parsing date from header: $e');
        }
      }
      gameDate ??= _game?.gameTime ?? DateTime.now();

      final dateString = '${gameDate.year}${gameDate.month.toString().padLeft(2, '0')}${gameDate.day.toString().padLeft(2, '0')}';
      final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates=$dateString';

      print('Checking scoreboard for weather: $scoreboardUrl');
      final response = await http.get(Uri.parse(scoreboardUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        for (final event in events) {
          if (event['id'] == espnGameId) {
            final weather = event['competitions']?[0]?['weather'];
            if (weather != null) {
              print('✅ Weather data found: ${weather['displayValue']}');
              setState(() {
                _eventDetails!['weather'] = weather;
              });
            }
            break;
          }
        }
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }

  Widget _buildNFLOverviewTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading game details...'));
    }

    // Check if game has started
    final status = _eventDetails!['header']?['competitions']?[0]?['status']?['type'];
    final isScheduled = status?['state'] == 'pre' || status?['description'] == 'Scheduled';

    // Debug logging for Game Leaders
    print('🏈 NFL Overview Tab - Status check:');
    print('  Status state: ${status?['state']}');
    print('  Status description: ${status?['description']}');
    print('  isScheduled: $isScheduled');
    print('  Leaders data exists: ${_eventDetails!['leaders'] != null}');
    if (_eventDetails!['leaders'] != null) {
      final leaders = _eventDetails!['leaders'] as List?;
      print('  Leaders is List: ${leaders is List}');
      print('  Leaders length: ${leaders?.length ?? 0}');
      print('  Leaders empty: ${leaders?.isEmpty ?? true}');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Card
          _buildNFLScoreCard(),
          const SizedBox(height: 16),

          // Weather Card (for outdoor venues)
          if (_eventDetails!['weather'] != null ||
              _eventDetails!['header']?['competitions']?[0]?['venue']?['indoor'] == false)
            ...[
              _buildNFLWeatherCard(),
              const SizedBox(height: 16),
            ],

          // Scheduled Game Time Card (if game hasn't started) - Moved here before Game Leaders
          if (_eventDetails!['boxscore'] == null && _game?.gameTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event, size: 20, color: AppTheme.primaryCyan),
                      const SizedBox(width: 8),
                      const Text(
                        'SCHEDULED KICKOFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryCyan,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_game!.gameTime),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(_game!.gameTime),
                    style: const TextStyle(
                      color: AppTheme.primaryCyan,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Game Leaders - Check for actual data first
          if (_eventDetails!['leaders'] != null &&
              _eventDetails!['leaders'] is List &&
              (_eventDetails!['leaders'] as List).isNotEmpty) ...[
            // We have actual leaders data, show it
            _buildNFLLeadersCard(),
            const SizedBox(height: 16),
          ] else if (isScheduled) ...[
            // No leaders data and game is scheduled
            _buildScheduledGameCard('Game Leaders'),
            const SizedBox(height: 16),
          ] else ...[
            // Game is not scheduled but no leaders data available
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  'Game Leaders data not available',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Last Five Games - Show if we have event details
          if (_eventDetails != null) ...[
            _buildNFLLastFiveGamesCard(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildNFLScoreCard() {
    final boxscore = _eventDetails!['boxscore'] as Map<String, dynamic>?;
    final header = _eventDetails!['header'] as Map<String, dynamic>?;

    // If no boxscore data, show a scheduled game display
    if (boxscore == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Away Team
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.sports_football, size: 50, color: AppTheme.primaryCyan),
                  const SizedBox(height: 8),
                  Text(
                    _game?.awayTeam ?? 'Away',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // VS
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'VS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            // Home Team
            Expanded(
              child: Column(
                children: [
                  Icon(Icons.sports_football, size: 50, color: AppTheme.primaryCyan),
                  const SizedBox(height: 8),
                  Text(
                    _game?.homeTeam ?? 'Home',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Teams and Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Away Team
              _buildNFLTeamScore(boxscore?['teams']?[0], true),
              // Score
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        boxscore?['teams']?[0]?['score'] ?? '0',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '-',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                      Text(
                        boxscore?['teams']?[1]?['score'] ?? '0',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Game Status
                  if (header?['competitions']?[0]?['status']?['type']?['detail'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: header!['competitions'][0]['status']['type']['completed'] == true
                            ? AppTheme.errorPink.withOpacity(0.2)
                            : AppTheme.successGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        header['competitions'][0]['status']['type']['detail'],
                        style: TextStyle(
                          fontSize: 12,
                          color: header['competitions'][0]['status']['type']['completed'] == true
                              ? AppTheme.errorPink
                              : AppTheme.successGreen,
                        ),
                      ),
                    ),
                ],
              ),
              // Home Team
              _buildNFLTeamScore(boxscore?['teams']?[1], false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNFLTeamScore(Map<String, dynamic>? teamData, bool isAway) {
    if (teamData == null) return const SizedBox();

    final team = teamData['team'];
    final statistics = teamData['statistics'] as List? ?? [];

    // Find key stats
    String record = '';
    for (final stat in statistics) {
      if (stat['name'] == 'record') {
        record = stat['displayValue'] ?? '';
        break;
      }
    }

    // Get team name and logo directly from API data
    final teamName = team?['displayName'] ?? (isAway ? _game?.awayTeam : _game?.homeTeam) ?? (isAway ? 'Away' : 'Home');
    final logoUrl = team?['logo'];

    return Expanded(
      child: Column(
        children: [
          if (logoUrl != null)
            CachedNetworkImage(
              imageUrl: logoUrl,
              height: 60,
              width: 60,
              errorWidget: (context, url, error) => const Icon(
                Icons.sports_football,
                size: 60,
                color: AppTheme.primaryCyan,
              ),
            )
          else
            const Icon(Icons.sports_football, size: 60, color: AppTheme.primaryCyan),
          const SizedBox(height: 8),
          Container(
            width: 100, // Fixed width to prevent breaking
            child: Text(
              teamName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (record.isNotEmpty)
            Text(
              record,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  Widget _buildNFLWeatherCard() {
    final weather = _eventDetails?['weather'] as Map<String, dynamic>?;
    final venue = _eventDetails?['header']?['competitions']?[0]?['venue'] as Map<String, dynamic>?;

    if (weather == null && venue?['indoor'] == true) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'WEATHER CONDITIONS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (weather != null) ...[
            if (weather['displayValue'] != null)
              Text(
                weather['displayValue'],
                style: const TextStyle(fontSize: 16),
              ),
            if (weather['temperature'] != null)
              Text(
                'Temperature: ${weather['temperature']}°F',
                style: TextStyle(color: Colors.grey[400]),
              ),
          ] else
            Text(
              venue?['indoor'] == false
                ? 'Weather data will be available closer to game time'
                : 'Indoor venue',
              style: TextStyle(color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  Widget _buildNFLLeadersCard() {
    final leaders = _eventDetails?['leaders'] as List? ?? [];
    print('🏈 Building NFL Leaders Card with ${leaders.length} teams');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAME LEADERS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Process each team's leaders
          ...leaders.map((teamData) {
            if (teamData is Map<String, dynamic>) {
              final teamName = teamData['team']?['displayName'] ?? '';
              final teamLeaders = teamData['leaders'] as List? ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (teamName.isNotEmpty) ...[
                    Text(
                      teamName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan.withOpacity(0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ...teamLeaders.map((leader) => _buildNFLLeaderCategory(leader)),
                  const SizedBox(height: 12),
                ],
              );
            }
            return const SizedBox();
          }),
        ],
      ),
    );
  }

  Widget _buildNFLLeaderCategory(Map<String, dynamic> category) {
    final leaders = category['leaders'] as List? ?? [];
    if (leaders.isEmpty) return const SizedBox();

    final categoryName = category['displayName'] ?? '';
    final topLeader = leaders.first;
    final athlete = topLeader['athlete'] as Map<String, dynamic>? ?? {};
    final displayValue = topLeader['displayValue'] ?? '';
    final playerName = athlete['displayName'] ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category name
          Expanded(
            flex: 2,
            child: Text(
              categoryName,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Player and stats
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNFLLastFiveGamesCard() {
    // Null safety check
    if (_eventDetails == null) {
      return const SizedBox();
    }

    print('Building Last Five Games Card...');
    print('Event Details keys: ${_eventDetails!.keys.toList()}');

    final lastFiveGamesData = _eventDetails!['lastFiveGames'];
    print('🔍 Raw lastFiveGamesData type: ${lastFiveGamesData.runtimeType}');

    // Handle both List and Map types (API returns List)
    dynamic lastFiveGames;
    if (lastFiveGamesData is List) {
      lastFiveGames = lastFiveGamesData;
      print('✅ lastFiveGames is a List with ${lastFiveGames.length} items');
    } else if (lastFiveGamesData is Map<String, dynamic>) {
      lastFiveGames = lastFiveGamesData;
      print('✅ lastFiveGames is a Map');
    } else {
      lastFiveGames = null;
      print('❌ lastFiveGames is null or unexpected type');
    }

    // Try alternative data sources
    final standings = _eventDetails?['standings'];
    print('Standings data available: ${standings != null}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'LAST 5 GAMES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (lastFiveGames != null &&
              ((lastFiveGames is List && lastFiveGames.isNotEmpty) ||
               (lastFiveGames is Map && (lastFiveGames as Map).isNotEmpty))) ...[
            // Parse and display the actual last five games data
            _buildLastFiveGamesContent(lastFiveGames),
          ] else ...[
            // Show placeholder or try to get from standings
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recent game history will appear here',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastFiveGamesContent(dynamic lastFiveData) {
    print('📊 _buildLastFiveGamesContent called with type: ${lastFiveData.runtimeType}');

    // Handle both List (actual API response) and Map formats
    List<dynamic> teams = [];

    if (lastFiveData is List) {
      teams = lastFiveData;
      print('  Processing as List with ${teams.length} teams');
    } else if (lastFiveData is Map && lastFiveData['teams'] != null) {
      teams = lastFiveData['teams'] as List? ?? [];
      print('  Processing as Map with teams field');
    }

    if (teams.isEmpty) {
      return Text(
        'No recent games data available',
        style: TextStyle(color: Colors.grey[400]),
      );
    }

    return Column(
      children: teams.map<Widget>((teamData) {
        final team = teamData['team'] as Map<String, dynamic>?;
        final events = teamData['events'] as List? ?? [];

        if (team == null) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              team['displayName'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(5).map<Widget>((event) {
                final result = event['gameResult'] ?? '';
                Color resultColor = Colors.grey;
                if (result == 'W') {
                  resultColor = AppTheme.successGreen;
                } else if (result == 'L') {
                  resultColor = AppTheme.errorPink;
                }

                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: resultColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    result,
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildScheduledGameCard(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.schedule,
                  size: 48,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 12),
                Text(
                  'Game Not Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stats will appear once the game begins',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNFLStatsTab() {
    if (_boxScore == null) {
      return const Center(child: Text('Stats not available'));
    }

    final teams = _boxScore!['teams'] as List? ?? [];
    if (teams.isEmpty) {
      return const Center(child: Text('No team stats available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Team Stats Card
          Card(
            color: AppTheme.surfaceBlue,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEAM STATS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats comparison for both teams
                  if (teams.length >= 2) ...[
                    // Team names header
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            teams[1]['team']?['displayName'] ?? 'Away',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 50),
                        Expanded(
                          flex: 2,
                          child: Text(
                            teams[0]['team']?['displayName'] ?? 'Home',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Get all statistics categories
                    ..._buildStatComparisons(teams),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatComparisons(List<dynamic> teams) {
    List<Widget> widgets = [];

    // Get statistics from both teams
    final team1Stats = teams[1]['statistics'] as List? ?? [];
    final team2Stats = teams[0]['statistics'] as List? ?? [];

    // Find common stat categories
    for (int i = 0; i < team1Stats.length && i < team2Stats.length; i++) {
      final stat1 = team1Stats[i];
      final stat2 = team2Stats[i];

      if (stat1['name'] == stat2['name']) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Stat name
                Text(
                  stat1['displayName'] ?? stat1['name'] ?? '',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                // Stat values with progress bar
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        stat1['displayValue'] ?? '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Visual comparison bar
                    Expanded(
                      flex: 3,
                      child: _buildComparisonBar(
                        _parseStatValue(stat1['displayValue']),
                        _parseStatValue(stat2['displayValue']),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Text(
                        stat2['displayValue'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  double _parseStatValue(String? value) {
    if (value == null) return 0;
    // Remove any non-numeric characters except . and -
    final cleanValue = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleanValue) ?? 0;
  }

  Widget _buildComparisonBar(double value1, double value2) {
    final total = value1 + value2;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final percentage1 = value1 / total;

    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: (percentage1 * 100).round(),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
          Expanded(
            flex: ((1 - percentage1) * 100).round(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNFLStandingsTab() {
    print('🏈 _buildNFLStandingsTab called');
    print('  _eventDetails is null: ${_eventDetails == null}');
    print('  _eventDetails keys: ${_eventDetails?.keys.toList()}');

    final standings = _eventDetails?['standings'];
    print('  standings extracted: ${standings != null ? 'EXISTS' : 'NULL'}');

    if (standings == null) {
      print('  ❌ Returning "Standings not available" message');
      return const Center(child: Text('Standings not available'));
    }

    // Debug log to understand data structure
    print('  ✅ Standings found!');
    print('  Standings type: ${standings.runtimeType}');
    print('  Standings keys: ${standings is Map ? standings.keys.toList() : 'Not a Map'}');

    // Log the actual groups data
    print('  standings["groups"] type: ${standings['groups'].runtimeType}');
    print('  standings["groups"] is null: ${standings['groups'] == null}');

    if (standings['groups'] != null) {
      print('  groups raw data: ${standings['groups']}');
      if (standings['groups'] is List) {
        print('  groups is a List with length: ${(standings['groups'] as List).length}');
        if ((standings['groups'] as List).isNotEmpty) {
          print('  First group: ${standings['groups'][0]}');
        }
      } else if (standings['groups'] is Map) {
        print('  groups is a Map with keys: ${(standings['groups'] as Map).keys.toList()}');
      }
    }

    // Parse standings data structure - handle both List and Map
    final groups = standings['groups'] is List
        ? standings['groups'] as List
        : standings['groups'] != null
            ? (standings['groups'] as Map).values.toList()
            : [];

    print('  Parsed groups length: ${groups.length}');
    if (groups.isNotEmpty) {
      print('  First parsed group type: ${groups[0].runtimeType}');
      print('  First parsed group keys: ${groups[0] is Map ? (groups[0] as Map).keys.toList() : 'Not a Map'}');
    }

    if (groups.isEmpty) {
      print('  ❌ Groups is empty after parsing');
      return const Center(child: Text('No standings data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            // Group name (AFC/NFC)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                group['header'] ?? group['name'] ?? 'Conference',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Get standings/divisions - handle both List and Map
            // The standings data is nested in group['standings']['entries']
            if (group['standings'] is Map && group['standings']['entries'] != null) ...[
              _buildSingleDivisionCard(group),
            ] else ..._buildDivisionStandings(group['standings']),

            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleDivisionCard(Map<String, dynamic> group) {
    final standings = group['standings'] as Map<String, dynamic>;
    final entries = standings['entries'] as List? ?? [];

    return Card(
      color: AppTheme.surfaceBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Division name from group header
            Text(
              group['header'] ?? group['divisionHeader'] ?? 'Division',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // Column headers
            Row(
              children: [
                const SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const Expanded(flex: 3, child: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 60, child: Text('W-L', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 50, child: Text('PCT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
            const Divider(),
            // Teams
            ...entries.map((entry) {
              final team = entry['team'] ?? {};
              final stats = entry['stats'] as List? ?? [];

              // Extract stats values
              String wins = '0';
              String losses = '0';
              String pct = '.000';
              String rank = '';

              for (var stat in stats) {
                switch (stat['type']) {
                  case 'wins':
                    wins = stat['displayValue'] ?? '0';
                    break;
                  case 'losses':
                    losses = stat['displayValue'] ?? '0';
                    break;
                  case 'winpercent':
                    pct = stat['displayValue'] ?? '.000';
                    break;
                  case 'rank':
                    rank = stat['displayValue'] ?? '';
                    break;
                }
              }

              // Use index + 1 if rank not found
              if (rank.isEmpty) {
                rank = '${entries.indexOf(entry) + 1}';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(rank, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        team is String ? team : (team['displayName'] ?? team['name'] ?? 'Unknown'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('$wins-$losses', textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(pct, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDivisionStandings(dynamic standingsData) {
    print('  📊 _buildDivisionStandings called');
    print('    standingsData is null: ${standingsData == null}');
    print('    standingsData type: ${standingsData?.runtimeType}');

    if (standingsData == null) {
      print('    ❌ Returning empty - standingsData is null');
      return [];
    }

    List<dynamic> standingsList = [];

    // Handle different data structures
    if (standingsData is List) {
      standingsList = standingsData;
      print('    ✅ standingsData is List with length: ${standingsList.length}');
    } else if (standingsData is Map) {
      // Handle numeric keys (0, 1, 2) or string keys
      standingsList = standingsData.entries.map((e) => e.value).toList();
      print('    ✅ standingsData is Map converted to List with length: ${standingsList.length}');
    } else {
      print('    ❌ standingsData is neither List nor Map');
    }

    if (standingsList.isEmpty) {
      print('    ❌ standingsList is empty');
      return [];
    }

    List<Widget> widgets = [];

    for (int i = 0; i < standingsList.length; i++) {
      final standings = standingsList[i];
      print('    Processing standings[$i]:');
      print('      Type: ${standings.runtimeType}');

      // Ensure standings is a Map
      if (standings is! Map) {
        print('      ❌ Skipping - not a Map');
        continue;
      }

      print('      Keys: ${standings.keys.toList()}');
      print('      Name: ${standings['name'] ?? standings['displayName'] ?? 'No name'}');

      widgets.add(
        Card(
          color: AppTheme.surfaceBlue,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Division name
                Text(
                  (standings['name'] ?? standings['displayName'] ?? 'Division').toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Teams table
                ..._buildTeamsTable(standings['entries'] ?? standings['teams']),
              ],
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }

  List<Widget> _buildTeamsTable(dynamic entriesData) {
    if (entriesData == null) return [];

    List<dynamic> entriesList = [];

    // Handle different data structures
    if (entriesData is List) {
      entriesList = entriesData;
    } else if (entriesData is Map) {
      // Handle numeric keys (0, 1, 2) or string keys
      entriesList = entriesData.entries.map((e) => e.value).toList();
    }

    List<Widget> widgets = [];

    for (int i = 0; i < entriesList.length; i++) {
      final entry = entriesList[i];
      if (entry is! Map) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 30,
                child: Text(
                  _getStatValue(entry['stats'], 'rank') ?? '${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // Team name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (entry['team']?['logo'] != null)
                      CachedNetworkImage(
                        imageUrl: entry['team']['logo'],
                        width: 24,
                        height: 24,
                        errorWidget: (_, __, ___) => const SizedBox(width: 24),
                      )
                    else
                      const SizedBox(width: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry['team']?['displayName'] ?? entry['team']?['name'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // W-L
              SizedBox(
                width: 60,
                child: Text(
                  '${_getStatValue(entry['stats'], 'wins') ?? '0'}-${_getStatValue(entry['stats'], 'losses') ?? '0'}',
                  textAlign: TextAlign.center,
                ),
              ),
              // PCT
              SizedBox(
                width: 50,
                child: Text(
                  _getStatDisplayValue(entry['stats'], 'winPercent') ?? '.000',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
      );

      if (i < entriesList.length - 1) {
        widgets.add(Divider(color: Colors.grey.withOpacity(0.2)));
      }
    }

    return widgets;
  }

  String? _getStatValue(dynamic stats, String statName) {
    if (stats == null) return null;

    if (stats is List) {
      try {
        final stat = stats.firstWhere((s) => s['name'] == statName);
        return stat['value']?.toString();
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  String? _getStatDisplayValue(dynamic stats, String statName) {
    if (stats == null) return null;

    if (stats is List) {
      try {
        final stat = stats.firstWhere((s) => s['name'] == statName);
        return stat['displayValue']?.toString();
      } catch (e) {
        return null;
      }
    }

    return null;
  }


  Widget _buildNFLInjuriesTab() {
    final injuries = _eventDetails?['injuries'];

    if (injuries == null) {
      return const Center(child: Text('Injury report not available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Injury reports for both teams
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INJURY REPORT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryCyan,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Injury list would go here
                Text('Player injury status and updates'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNHLDetails() async {
    try {
      print('=== LOADING NHL DETAILS ===');
      print('Game ID: ${widget.gameId}');
      print('Teams: ${_game?.awayTeam} vs ${_game?.homeTeam}');

      // Use the ESPN ID resolver service
      final resolver = EspnIdResolverService();

      // Check if game already has ESPN ID
      var espnGameId = _game?.espnId;

      // If no ESPN ID, resolve it
      if (espnGameId == null && _game != null) {
        print('Resolving ESPN ID using resolver service...');
        espnGameId = await resolver.resolveEspnId(_game!);

        if (espnGameId != null) {
          print('✅ ESPN ID resolved: $espnGameId');
        } else {
          print('❌ Could not resolve ESPN ID');
          // Show user-friendly message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Game details are temporarily unavailable'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else if (espnGameId == null) {
        print('❌ No game data available to resolve ESPN ID');
        return;
      }

      print('Using ESPN ID: $espnGameId');

      // Fetch game summary data from ESPN
      final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/summary?event=$espnGameId';
      print('Fetching summary from: $summaryUrl');

      final summaryResponse = await http.get(Uri.parse(summaryUrl));
      print('Summary response status: ${summaryResponse.statusCode}');

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);

        // Log available data sections
        print('Summary data keys: ${summaryData.keys.toList()}');

        // Store NHL-specific data
        // Log data types before assignment for debugging
        print('🔍 NHL Data Types Check:');
        print('  boxscore type: ${summaryData['boxscore']?.runtimeType}');
        print('  scoringPlays type: ${summaryData['scoringPlays']?.runtimeType}');
        print('  standings type: ${summaryData['standings']?.runtimeType}');
        print('  leaders type: ${summaryData['leaders']?.runtimeType}');

        setState(() {
          _eventDetails = summaryData;
          _nhlBoxScore = summaryData['boxscore'] as Map<String, dynamic>?;
          _nhlScoringPlays = summaryData['scoringPlays'] as List?;
          _nhlStandings = summaryData['standings'] as Map<String, dynamic>?;

          // Leaders can be either List or null
          final leadersData = summaryData['leaders'];
          if (leadersData is List) {
            _nhlGameLeaders = leadersData;
            print('✅ Leaders is a List with ${leadersData.length} items');
          } else if (leadersData != null) {
            print('⚠️ Leaders is not a List, it\'s: ${leadersData.runtimeType}');
            _nhlGameLeaders = null;
          } else {
            print('ℹ️ Leaders data is null');
            _nhlGameLeaders = null;
          }

          // Also store general game data
          if (summaryData['header']?['competitions'] != null &&
              (summaryData['header']['competitions'] as List).isNotEmpty) {
            _gameData = {
              ...summaryData,
              'competitions': summaryData['header']['competitions'],
            };
          } else {
            _gameData = summaryData;
          }
        });

        // Log what data we found with more details
        print('🏒 ======== NHL DATA ANALYSIS ========');
        print('📊 Summary Data Keys: ${summaryData.keys.toList()}');

        // Box Score Analysis
        if (_nhlBoxScore != null) {
          print('✅ Box score data found');
          print('  📋 Box score keys: ${_nhlBoxScore!.keys.toList()}');
          if (_nhlBoxScore!['teams'] != null) {
            final teams = _nhlBoxScore!['teams'] as List;
            print('  👥 Teams in box score: ${teams.length}');
            for (int i = 0; i < teams.length; i++) {
              final team = teams[i];
              print('    Team ${i + 1}: ${team['team']?['displayName']} (${team['team']?['abbreviation']})');
              print('    Team ${i + 1} logo: ${team['team']?['logo']}');
            }
          }
        } else {
          print('❌ Box score data is null');
        }

        // Scoring Plays Analysis
        if (_nhlScoringPlays != null) {
          print('✅ Scoring plays found: ${_nhlScoringPlays!.length}');
        } else {
          print('ℹ️ No scoring plays yet');
        }

        // Leaders Analysis
        print('🎯 ======== LEADERS ANALYSIS ========');
        final leadersData = summaryData['leaders'];
        print('📈 Leaders data exists: ${leadersData != null}');
        print('📈 Leaders type: ${leadersData?.runtimeType}');
        if (leadersData is List) {
          print('📈 Leaders list length: ${leadersData.length}');
          for (int i = 0; i < leadersData.length; i++) {
            final teamLeaders = leadersData[i];
            print('  Team ${i + 1} leaders data:');
            print('    Team: ${teamLeaders['team']?['displayName']}');
            print('    Leaders array: ${teamLeaders['leaders']?.runtimeType}');
            if (teamLeaders['leaders'] is List) {
              final leaders = teamLeaders['leaders'] as List;
              print('    Leaders count: ${leaders.length}');
              if (leaders.isEmpty) {
                print('    ⚠️ Leaders array is EMPTY for ${teamLeaders['team']?['displayName']}');
              } else {
                for (int j = 0; j < leaders.length; j++) {
                  final leader = leaders[j];
                  print('      Leader ${j + 1}: ${leader['displayName']} - ${leader['leaders']?[0]?['athlete']?['displayName']}');
                }
              }
            }
          }
        }

        // Logos Analysis
        print('🖼️ ======== LOGOS ANALYSIS ========');
        final header = summaryData['header'];
        if (header?['competitions'] != null) {
          final competitions = header['competitions'] as List;
          if (competitions.isNotEmpty) {
            final competition = competitions[0];
            final competitors = competition['competitors'] as List? ?? [];
            print('🏒 Competitors found: ${competitors.length}');
            for (int i = 0; i < competitors.length; i++) {
              final competitor = competitors[i];
              final team = competitor['team'];
              print('  Team ${i + 1}:');
              print('    Name: ${team?['displayName']}');
              print('    Abbreviation: ${team?['abbreviation']}');
              print('    Logo URL: ${team?['logo']}');
              print('    Color: ${team?['color']}');
              print('    Alt Color: ${team?['alternateColor']}');
            }
          }
        }

        // Standings Analysis
        if (_nhlStandings != null) {
          print('✅ Standings data found');
          print('  📊 Standings keys: ${_nhlStandings!.keys.toList()}');
          if (_nhlStandings!['groups'] != null) {
            final groups = _nhlStandings!['groups'] as List;
            print('  Number of groups: ${groups.length}');
            if (groups.isNotEmpty) {
              print('  First group keys: ${groups[0].keys.toList()}');
            }
          }
        } else {
          print('❌ Standings data is null');
        }

        if (_nhlGameLeaders != null) {
          print('✅ Game leaders found: ${_nhlGameLeaders!.length} categories');
          if (_nhlGameLeaders!.isNotEmpty) {
            final firstLeader = _nhlGameLeaders![0] as Map<String, dynamic>;
            print('  First leader category keys: ${firstLeader.keys.toList()}');
          }
        } else {
          print('ℹ️ No game leaders data');
        }
      } else {
        print('❌ Summary API failed with status ${summaryResponse.statusCode}');
      }

      // Load odds data
      await _loadNHLOdds();

      print('=== NHL DETAILS LOADING END ===\n');
    } catch (e, stackTrace) {
      print('❌ Error loading NHL details: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadNHLOdds() async {
    try {
      if (_game == null) return;

      final oddsData = await _oddsService.getMatchOdds(
        sport: 'nhl',
        homeTeam: _game!.homeTeam,
        awayTeam: _game!.awayTeam,
      );

      if (oddsData != null) {
        setState(() {
          _nhlOddsData = oddsData;
        });
        print('✅ NHL odds data loaded');
      }
    } catch (e) {
      print('Error loading NHL odds: $e');
    }
  }

  Widget _buildNHLOverviewTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading game details...'));
    }

    print('🏒 ======== BUILDING NHL OVERVIEW TAB ========');

    // Try to get data from either header (for live games) or boxscore (for scheduled/preseason)
    List competitors = [];
    Map<String, dynamic>? competition;

    // Check for header structure first (live games)
    final header = _eventDetails!['header'];
    print('🏒 DEBUG - header: $header');
    print('🏒 DEBUG - header competitions: ${header?['competitions']}');
    if (header != null && header['competitions'] != null) {
      competition = header['competitions']?[0];
      competitors = competition?['competitors'] as List? ?? [];
      print('🏒 Using header data - competitors: ${competitors.length}');
      for (int i = 0; i < competitors.length; i++) {
        print('🏒 Header competitor $i logo: ${competitors[i]?['team']?['logo']}');
      }
    }

    // If no header data, use boxscore teams (scheduled/preseason games)
    if (competitors.isEmpty && _nhlBoxScore != null) {
      final teams = _nhlBoxScore!['teams'] as List? ?? [];
      print('🏒 Using boxscore data - teams: ${teams.length}');
      // Convert boxscore team format to competitor format
      competitors = teams.map((teamData) => {
        'team': teamData['team'],
        'score': '0', // Default score for scheduled games
        'homeAway': teamData['homeAway'] ?? (teamData['displayOrder'] == 2 ? 'home' : 'away'),
      }).toList();
    }

    final gameInfo = _eventDetails!['gameInfo'];
    final venue = gameInfo?['venue'];

    print('📋 Event Details Keys: ${_eventDetails!.keys.toList()}');
    print('👥 Competitors count: ${competitors.length}');
    print('📈 NHL Game Leaders null: ${_nhlGameLeaders == null}');
    if (_nhlGameLeaders != null) {
      print('📈 NHL Game Leaders length: ${_nhlGameLeaders!.length}');
    }

    // Log competitor details for logo debugging
    for (int i = 0; i < competitors.length; i++) {
      final competitor = competitors[i];
      final team = competitor['team'];
      print('🏒 Competitor ${i + 1}:');
      print('  Display Name: ${team?['displayName']}');
      print('  Abbreviation: ${team?['abbreviation']}');
      print('  Logo URL: ${team?['logo']}');
      print('  Score: ${competitor['score']}');
      print('  Home/Away: ${competitor['homeAway']}');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score card
          Card(
            color: AppTheme.surfaceBlue,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Teams and scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final team in competitors) ...[
                        Column(
                          children: [
                            () {
                              final logoUrl = team['team']?['logo'] ?? '';
                              print('🖼️ Loading logo for ${team['team']?['displayName']}: $logoUrl');
                              return CachedNetworkImage(
                                imageUrl: logoUrl,
                                width: 60,
                                height: 60,
                                placeholder: (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryCyan,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  print('❌ Logo failed to load for ${team['team']?['displayName']}: $error');
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[600]!),
                                    ),
                                    child: const Icon(
                                      Icons.sports_hockey,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                fit: BoxFit.contain,
                              );
                            }(),
                            const SizedBox(height: 8),
                            Text(
                              team['team']?['abbreviation'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              team['score'] ?? '0',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryCyan,
                              ),
                            ),
                          ],
                        ),
                        if (competitors.indexOf(team) == 0)
                          const Column(
                            children: [
                              SizedBox(height: 40),
                              Text('VS', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                      ]
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Period and time
                  if (competition?['status'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        competition != null ? (competition['status']?['type']?['detail'] ?? '') : '',
                        style: const TextStyle(
                          color: AppTheme.primaryCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Odds section
          if (_nhlOddsData != null) ...[
            Text(
              'BETTING LINES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.surfaceBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Moneyline
                    if (_nhlOddsData!['moneyline'] != null) ...[
                      const Text('Moneyline', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final outcome in _nhlOddsData!['moneyline']['outcomes']) ...[
                            Column(
                              children: [
                                Text(outcome['name'] ?? ''),
                                Text(
                                  outcome['price'] > 0 ? '+${outcome['price']}' : '${outcome['price']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryCyan,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Puck Line
                    if (_nhlOddsData!['spreads'] != null) ...[
                      const Divider(height: 32),
                      const Text('Puck Line', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final outcome in _nhlOddsData!['spreads']['outcomes']) ...[
                            Column(
                              children: [
                                Text(outcome['name'] ?? ''),
                                Text(
                                  '${outcome['point'] > 0 ? '+' : ''}${outcome['point']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  outcome['price'] > 0 ? '+${outcome['price']}' : '${outcome['price']}',
                                  style: const TextStyle(color: AppTheme.primaryCyan),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Totals
                    if (_nhlOddsData!['totals'] != null) ...[
                      const Divider(height: 32),
                      const Text('Total Goals', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final outcome in _nhlOddsData!['totals']['outcomes']) ...[
                            Column(
                              children: [
                                Text('${outcome['name']} ${outcome['point']}'),
                                Text(
                                  outcome['price'] > 0 ? '+${outcome['price']}' : '${outcome['price']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryCyan,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Game Leaders
          if (_nhlGameLeaders != null) ...[
            () {
              print('🎯 ======== RENDERING GAME LEADERS SECTION ========');
              print('📈 Leaders data: ${_nhlGameLeaders!.length} categories');
              for (int i = 0; i < _nhlGameLeaders!.length; i++) {
                final category = _nhlGameLeaders![i];
                print('  Category ${i + 1}: ${category['displayName']}');
                print('    Leaders: ${category['leaders']?.length ?? 0}');
              }
              return const SizedBox.shrink();
            }(),
            Text(
              'GAME LEADERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.surfaceBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final category in _nhlGameLeaders!) ...[
                      if (category['leaders'] != null && (category['leaders'] as List).isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category['displayName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              category['leaders'][0]['displayValue'] ?? '',
                              style: const TextStyle(color: AppTheme.primaryCyan),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['leaders'][0]['athlete']?['displayName'] ?? '',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        const Divider(height: 16),
                      ] else ...[
                        // Show empty leader categories for debugging
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                category['displayName'] ?? 'Unknown Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'No data',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 16, color: Colors.grey),
                      ],
                    ],
                    // If all categories are empty, show a message
                    if (_nhlGameLeaders!.every((category) =>
                        category['leaders'] == null || (category['leaders'] as List).isEmpty)) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey[400],
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Game leaders will be available once the game starts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // Show Game Leaders section even when data is null (for preseason/scheduled games)
            () {
              print('📈 Game Leaders is NULL - showing placeholder');
              return const SizedBox.shrink();
            }(),
            Text(
              'GAME LEADERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.surfaceBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Game leaders will be available once the game starts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Venue info
          if (venue != null) ...[
            const SizedBox(height: 16),
            Text(
              'VENUE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.surfaceBlue,
              child: ListTile(
                leading: const Icon(Icons.location_on, color: AppTheme.primaryCyan),
                title: Text(venue['fullName'] ?? ''),
                subtitle: Text(venue['address']?['city'] ?? ''),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNHLBoxScoreTab() {
    if (_nhlBoxScore == null) {
      return const Center(child: Text('Box score not available'));
    }

    final teams = _nhlBoxScore!['teams'] as List? ?? [];
    final players = _nhlBoxScore!['players'] as List? ?? [];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Team Stats'),
              Tab(text: 'Player Stats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Team Stats
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final team in teams) ...[
                        Card(
                          color: AppTheme.surfaceBlue,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team['team']?['displayName'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (team['statistics'] != null)
                                  for (final stat in team['statistics']) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(stat['label'] ?? ''),
                                        Text(
                                          stat['displayValue'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryCyan,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                  ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // Player Stats
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final teamPlayers in players) ...[
                        Card(
                          color: AppTheme.surfaceBlue,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teamPlayers['team']?['displayName'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Forwards
                                if (teamPlayers['statistics']?[0] != null) ...[
                                  const Text(
                                    'Forwards',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildNHLPlayerTable(teamPlayers['statistics'][0]),
                                ],

                                // Defense
                                if (teamPlayers['statistics']?[1] != null) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Defense',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildNHLPlayerTable(teamPlayers['statistics'][1]),
                                ],

                                // Goalies
                                if (teamPlayers['statistics']?[2] != null) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Goalies',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildNHLGoalieTable(teamPlayers['statistics'][2]),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNHLPlayerTable(Map<String, dynamic> playerGroup) {
    final athletes = playerGroup['athletes'] as List? ?? [];
    if (athletes.isEmpty) return const Text('No player data');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Player')),
          DataColumn(label: Text('G')),
          DataColumn(label: Text('A')),
          DataColumn(label: Text('P')),
          DataColumn(label: Text('+/-')),
          DataColumn(label: Text('SOG')),
          DataColumn(label: Text('PIM')),
          DataColumn(label: Text('TOI')),
        ],
        rows: athletes.map((player) {
          final stats = player['stats'] as List? ?? [];
          return DataRow(
            cells: [
              DataCell(Text(player['athlete']?['displayName'] ?? '')),
              DataCell(Text(stats.length > 0 ? stats[0] : '0')),
              DataCell(Text(stats.length > 1 ? stats[1] : '0')),
              DataCell(Text(stats.length > 2 ? stats[2] : '0')),
              DataCell(Text(stats.length > 3 ? stats[3] : '0')),
              DataCell(Text(stats.length > 4 ? stats[4] : '0')),
              DataCell(Text(stats.length > 5 ? stats[5] : '0')),
              DataCell(Text(stats.length > 6 ? stats[6] : '0')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNHLGoalieTable(Map<String, dynamic> goalieGroup) {
    final athletes = goalieGroup['athletes'] as List? ?? [];
    if (athletes.isEmpty) return const Text('No goalie data');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Goalie')),
          DataColumn(label: Text('SA')),
          DataColumn(label: Text('SV')),
          DataColumn(label: Text('GA')),
          DataColumn(label: Text('SV%')),
          DataColumn(label: Text('TOI')),
        ],
        rows: athletes.map((player) {
          final stats = player['stats'] as List? ?? [];
          return DataRow(
            cells: [
              DataCell(Text(player['athlete']?['displayName'] ?? '')),
              DataCell(Text(stats.length > 0 ? stats[0] : '0')),
              DataCell(Text(stats.length > 1 ? stats[1] : '0')),
              DataCell(Text(stats.length > 2 ? stats[2] : '0')),
              DataCell(Text(stats.length > 3 ? stats[3] : '0')),
              DataCell(Text(stats.length > 4 ? stats[4] : '0')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNHLScoringTab() {
    if (_nhlScoringPlays == null || _nhlScoringPlays!.isEmpty) {
      return const Center(child: Text('No scoring plays yet'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GOALS (${_nhlScoringPlays!.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          for (final play in _nhlScoringPlays!) ...[
            Card(
              color: AppTheme.surfaceBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Period ${play['period']?['number'] ?? ''}',
                            style: const TextStyle(
                              color: AppTheme.primaryCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          play['clock']?['displayValue'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (play['team']?['logo'] != null)
                          CachedNetworkImage(
                            imageUrl: play['team']['logo'],
                            width: 30,
                            height: 30,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.sports_hockey,
                              size: 30,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                play['team']?['displayName'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                play['text'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (play['scoreValue'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          play['awayScore'] != null && play['homeScore'] != null
                              ? '${play['awayScore']} - ${play['homeScore']}'
                              : '',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildNHLStandingsTab() {
    if (_nhlStandings == null) {
      print('❌ NHL Standings: _nhlStandings is null');
      return const Center(child: Text('Standings not available'));
    }

    print('🏒 Building NHL Standings Tab');
    print('  Standings type: ${_nhlStandings.runtimeType}');
    print('  Standings keys: ${_nhlStandings!.keys.toList()}');

    final groups = _nhlStandings!['groups'] as List? ?? [];
    if (groups.isEmpty) {
      print('❌ NHL Standings: No groups found');
      return const Center(child: Text('No standings data available'));
    }

    print('  Found ${groups.length} groups/divisions');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final group in groups) ...[
            Card(
              color: AppTheme.surfaceBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['header'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Team')),
                          DataColumn(label: Text('GP')),
                          DataColumn(label: Text('W')),
                          DataColumn(label: Text('L')),
                          DataColumn(label: Text('OTL')),
                          DataColumn(label: Text('PTS')),
                          DataColumn(label: Text('DIFF')),
                        ],
                        rows: (() {
                          // Safely extract entries with detailed logging
                          print('  Processing group: ${group['header'] ?? 'Unknown'}');
                          print('  Group keys: ${(group as Map<String, dynamic>).keys.toList()}');

                          final standings = group['standings'];
                          if (standings == null) {
                            print('  ⚠️ No standings in group');
                            return <DataRow>[];
                          }

                          print('  Standings type: ${standings.runtimeType}');

                          final entries = standings is Map
                              ? standings['entries'] as List? ?? []
                              : standings is List
                                  ? standings
                                  : [];

                          print('  Found ${entries.length} entries');

                          return entries.map((entry) {
                            // Handle case where entry might be a Map or other type
                            final Map<String, dynamic> team = entry is Map<String, dynamic>
                                ? entry
                                : <String, dynamic>{};

                            final stats = team['stats'] as List? ?? [];

                            // Handle team info which might be a String or Map
                            Map<String, dynamic>? teamInfo;
                            if (team['team'] is Map<String, dynamic>) {
                              teamInfo = team['team'] as Map<String, dynamic>;
                            } else if (team['team'] is String) {
                              // If team is just a string (team name), create a simple map
                              teamInfo = {'displayName': team['team'], 'abbreviation': team['team']};
                            }

                            return DataRow(
                              selected: teamInfo?['displayName'] == _game?.homeTeam ||
                                  teamInfo?['displayName'] == _game?.awayTeam,
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    Text('${team['rank'] ?? ''}. '),
                                    if (teamInfo?['logos'] != null) ...[
                                      Builder(builder: (context) {
                                        final logos = teamInfo!['logos'];
                                        String? logoUrl;

                                        if (logos is List && logos.isNotEmpty) {
                                          // If logos is a List, get the first item's href
                                          final firstLogo = logos[0];
                                          if (firstLogo is Map) {
                                            logoUrl = firstLogo['href'];
                                          } else if (firstLogo is String) {
                                            logoUrl = firstLogo;
                                          }
                                        } else if (logos is String) {
                                          // If logos is already a String URL
                                          logoUrl = logos;
                                        }

                                        return logoUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: logoUrl,
                                                width: 20,
                                                height: 20,
                                                errorWidget: (_, __, ___) => const SizedBox(),
                                              )
                                            : const SizedBox();
                                      }),
                                    ],
                                    const SizedBox(width: 4),
                                    Text(teamInfo?['abbreviation'] ?? ''),
                                  ],
                                ),
                              ),
                              DataCell(Text(stats.length > 0 ? stats[0]['displayValue'] ?? '' : '')),
                              DataCell(Text(stats.length > 1 ? stats[1]['displayValue'] ?? '' : '')),
                              DataCell(Text(stats.length > 2 ? stats[2]['displayValue'] ?? '' : '')),
                              DataCell(Text(stats.length > 3 ? stats[3]['displayValue'] ?? '' : '')),
                              DataCell(Text(
                                stats.length > 4 ? stats[4]['displayValue'] ?? '' : '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryCyan,
                                ),
                              )),
                              DataCell(Text(stats.length > 8 ? stats[8]['displayValue'] ?? '' : '')),
                            ],
                          );
                        }).toList();
                      })(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildNBAOverviewTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading game details...'));
    }

    // Debug logging for NBA data structure
    print('🏀 NBA Overview - Checking data structure:');
    final boxscore = _eventDetails!['boxscore'];
    print('  - boxscore type: ${boxscore.runtimeType}');
    if (boxscore != null) {
      final teams = boxscore['teams'];
      print('  - teams type: ${teams.runtimeType}');
      if (teams != null) {
        print('  - teams is List: ${teams is List}');
        print('  - teams is Map: ${teams is Map}');
        if (teams is List) {
          print('  - teams length: ${teams.length}');
          if (teams.isNotEmpty) {
            print('  - teams[0] type: ${teams[0].runtimeType}');
            print('  - teams[0] keys: ${teams[0].keys}');
          }
        } else if (teams is Map) {
          print('  - teams keys: ${teams.keys}');
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Teams and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Away Team
                    Expanded(
                      child: Column(
                        children: [
                          if (_eventDetails!['boxscore']?['teams']?[0]?['team']?['logo'] != null)
                            CachedNetworkImage(
                              imageUrl: _eventDetails!['boxscore']['teams'][0]['team']['logo'],
                              height: 60,
                              width: 60,
                              errorWidget: (context, url, error) => Icon(
                                Icons.sports_basketball,
                                size: 60,
                                color: AppTheme.primaryCyan,
                              ),
                            )
                          else
                            Icon(Icons.sports_basketball, size: 60, color: AppTheme.primaryCyan),
                          const SizedBox(height: 8),
                          Text(
                            _game?.awayTeam ?? 'Away',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_eventDetails!['boxscore']?['teams']?[0]?['statistics'] != null)
                            Text(
                              '${_eventDetails!['boxscore']['teams'][0]['statistics'].firstWhere((s) => s['name'] == 'rebounds', orElse: () => {'displayValue': '0'})['displayValue']} REB',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    ),
                    // Score
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _eventDetails!['boxscore']?['teams']?[0]?['score'] ?? '0',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '-',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            Text(
                              _eventDetails!['boxscore']?['teams']?[1]?['score'] ?? '0',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Game Status
                        if (_eventDetails!['status']?['type']?['detail'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _eventDetails!['status']['type']['completed'] == true
                                  ? AppTheme.errorPink.withOpacity(0.2)
                                  : AppTheme.successGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _eventDetails!['status']['type']['detail'],
                              style: TextStyle(
                                fontSize: 12,
                                color: _eventDetails!['status']['type']['completed'] == true
                                    ? AppTheme.errorPink
                                    : AppTheme.successGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Home Team
                    Expanded(
                      child: Column(
                        children: [
                          if (_eventDetails!['boxscore']?['teams']?[1]?['team']?['logo'] != null)
                            CachedNetworkImage(
                              imageUrl: _eventDetails!['boxscore']['teams'][1]['team']['logo'],
                              height: 60,
                              width: 60,
                              errorWidget: (context, url, error) => Icon(
                                Icons.sports_basketball,
                                size: 60,
                                color: AppTheme.primaryCyan,
                              ),
                            )
                          else
                            Icon(Icons.sports_basketball, size: 60, color: AppTheme.primaryCyan),
                          const SizedBox(height: 8),
                          Text(
                            _game?.homeTeam ?? 'Home',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_eventDetails!['boxscore']?['teams']?[1]?['statistics'] != null)
                            Text(
                              '${_eventDetails!['boxscore']['teams'][1]['statistics'].firstWhere((s) => s['name'] == 'rebounds', orElse: () => {'displayValue': '0'})['displayValue']} REB',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Quarter Scores
                if (_eventDetails!['boxscore']?['teams']?[0]?['linescores'] != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 80, child: Text('Quarter', style: TextStyle(fontSize: 12))),
                      ...List.generate(
                        _eventDetails!['boxscore']['teams'][0]['linescores'].length,
                        (i) => Expanded(
                          child: Center(
                            child: Text(
                              'Q${i + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      if (_eventDetails!['boxscore']['teams'][0]['linescores'].length > 4)
                        const Expanded(child: Center(child: Text('OT', style: TextStyle(fontSize: 12)))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Away team quarters
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _game?.awayTeam ?? 'Away',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...(_eventDetails!['boxscore']['teams'][0]['linescores'] as List).map((score) =>
                        Expanded(
                          child: Center(
                            child: Text(
                              score['displayValue'] ?? '0',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Home team quarters
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _game?.homeTeam ?? 'Home',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...(_eventDetails!['boxscore']['teams'][1]['linescores'] as List).map((score) =>
                        Expanded(
                          child: Center(
                            child: Text(
                              score['displayValue'] ?? '0',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Game Leaders
          if (_eventDetails!['leaders'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GAME LEADERS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final leaders = _eventDetails!['leaders'] as List;

                      // Check if this is the team-based leaders structure (for future games)
                      if (leaders.isNotEmpty &&
                          leaders[0] is Map &&
                          leaders[0].containsKey('team') &&
                          (leaders[0]['leaders'] == null || (leaders[0]['leaders'] as List).isEmpty)) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Game leaders will be available once the game starts',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      }

                      // Filter out categories without valid data
                      final validCategories = leaders.where((category) {
                        return category is Map &&
                               category['displayName'] != null &&
                               category['leaders'] != null &&
                               (category['leaders'] as List).isNotEmpty;
                      }).toList();

                      if (validCategories.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No leader statistics available yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: validCategories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    category['displayName'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: (category['leaders'] as List).map((leader) {
                                      final athleteName = leader['athlete']?['displayName'] ?? 'Unknown';
                                      final displayValue = leader['displayValue'] ?? '-';

                                      return Column(
                                        children: [
                                          Text(
                                            athleteName.split(' ').last,
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            displayValue,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNBAStatsTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading stats...'));
    }

    final teams = _eventDetails!['boxscore']?['teams'];
    if (teams == null) {
      return const Center(child: Text('Stats not available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Team Stats Comparison
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEAM STATS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats rows
                ..._buildNBAStatsRows(teams),
              ],
            ),
          ),

          // Player Stats if available
          if (_eventDetails!['boxscore']?['players'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLAYER STATS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Player stats available during live games',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildNBAStatsRows(List teams) {
    final stats = [
      {'key': 'fieldGoalsPercentage', 'label': 'FG%'},
      {'key': 'threePointFieldGoalsPercentage', 'label': '3PT%'},
      {'key': 'freeThrowsPercentage', 'label': 'FT%'},
      {'key': 'rebounds', 'label': 'Rebounds'},
      {'key': 'assists', 'label': 'Assists'},
      {'key': 'steals', 'label': 'Steals'},
      {'key': 'blocks', 'label': 'Blocks'},
      {'key': 'turnovers', 'label': 'Turnovers'},
      {'key': 'points', 'label': 'Points'},
    ];

    return stats.map((stat) {
      final awayStats = teams[0]['statistics'] ?? [];
      final homeStats = teams[1]['statistics'] ?? [];

      final awayStat = awayStats.firstWhere(
        (s) => s['name'] == stat['key'],
        orElse: () => {'displayValue': '-'},
      );
      final homeStat = homeStats.firstWhere(
        (s) => s['name'] == stat['key'],
        orElse: () => {'displayValue': '-'},
      );

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                awayStat['displayValue'] ?? '-',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                stat['label']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ),
            Expanded(
              child: Text(
                homeStat['displayValue'] ?? '-',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildNBAStandingsTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading standings...'));
    }

    final standings = _eventDetails!['standings'];
    if (standings == null || (standings is Map && standings.isEmpty)) {
      return const Center(child: Text('Standings not available'));
    }

    // Handle the standings structure from ESPN API
    List standingsGroups = [];
    if (standings is Map) {
      // ESPN API returns standings as a Map with 'groups' key
      standingsGroups = standings['groups'] ?? [];
    } else if (standings is List) {
      // In case the standings are already a list
      standingsGroups = standings;
    }

    if (standingsGroups.isEmpty) {
      return const Center(child: Text('No standings data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: standingsGroups.map((group) {
          final groupName = group['name'] ?? 'Conference';
          final entries = group['standings']?['entries'] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                // Table header
                Row(
                  children: [
                    const SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 10))),
                    const Expanded(flex: 3, child: Text('Team', style: TextStyle(fontSize: 10))),
                    const SizedBox(width: 35, child: Text('W', style: TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    const SizedBox(width: 35, child: Text('L', style: TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    const SizedBox(width: 45, child: Text('PCT', style: TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    const SizedBox(width: 35, child: Text('GB', style: TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                    const SizedBox(width: 50, child: Text('L10', style: TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                  ],
                ),
                const Divider(),
                // Table rows
                ...(entries as List).take(15).map((entry) {
                  print('🏀 NBA Standings - Processing entry:');
                  print('  - entry type: ${entry.runtimeType}');
                  print('  - entry keys: ${entry is Map ? entry.keys : 'Not a map'}');

                  final team = entry['team'];
                  print('  - team type: ${team.runtimeType}');
                  print('  - team value: $team');

                  final stats = entry['stats'] ?? [];
                  print('  - stats type: ${stats.runtimeType}');

                  String getStatValue(String name) {
                    final stat = stats.firstWhere(
                      (s) => s['name'] == name,
                      orElse: () => {'displayValue': '-'},
                    );
                    return stat['displayValue'] ?? '-';
                  }

                  // Safely access team displayName
                  String? teamDisplayName;
                  if (team is Map) {
                    teamDisplayName = team['displayName']?.toString();
                  } else if (team is String) {
                    teamDisplayName = team;
                  }

                  final isCurrentTeam = teamDisplayName == _game?.homeTeam ||
                                      teamDisplayName == _game?.awayTeam;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentTeam ? AppTheme.primaryCyan.withOpacity(0.1) : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${entries.indexOf(entry) + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            team is Map ? (team['abbreviation'] ?? team['displayName'] ?? 'Team') : teamDisplayName ?? 'Team',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 35,
                          child: Text(
                            getStatValue('wins'),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 35,
                          child: Text(
                            getStatValue('losses'),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            getStatValue('winPercent'),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 35,
                          child: Text(
                            getStatValue('gamesBehind'),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            getStatValue('l10'),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNBAH2HTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading head to head...'));
    }

    final lastFiveGames = _eventDetails!['lastFiveGames'];
    final seasonSeries = _eventDetails!['seasonSeries'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Season Series
          if (seasonSeries != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SEASON SERIES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (seasonSeries['events'] != null)
                    ...(seasonSeries['events'] as List).map((game) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                game['date'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${game['competitors']?[1]?['team']?['abbreviation'] ?? ''} ${game['competitors']?[1]?['score'] ?? ''} - ${game['competitors']?[0]?['score'] ?? ''} ${game['competitors']?[0]?['team']?['abbreviation'] ?? ''}',
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                game['status']?['type']?['shortDetail'] ?? '',
                                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Last Five Games for each team
          if (lastFiveGames != null) ...[
            ...(lastFiveGames as List).map((teamGames) {
              final teamName = teamGames['team']?['displayName'] ?? 'Team';
              final games = teamGames['events'] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$teamName - LAST 5 GAMES',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(games as List).map((game) {
                      final isWin = game['winner'] == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isWin
                                  ? AppTheme.successGreen.withOpacity(0.2)
                                  : AppTheme.errorPink.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  isWin ? 'W' : 'L',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isWin ? AppTheme.successGreen : AppTheme.errorPink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${game['atVs'] ?? ''} ${game['opponent']?['abbreviation'] ?? ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${game['score'] ?? ''} - ${game['opponentScore'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildNBAInjuriesTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading injuries...'));
    }

    final injuries = _eventDetails!['injuries'];
    if (injuries == null || injuries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: AppTheme.successGreen),
            SizedBox(height: 16),
            Text(
              'No injuries reported',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: (injuries as List).map((teamInjuries) {
          final teamName = teamInjuries['team']?['displayName'] ?? 'Team';
          final injuryList = teamInjuries['injuries'] ?? [];

          if (injuryList.isEmpty) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                ...(injuryList as List).map((injury) {
                  final status = injury['status'] ?? 'Unknown';
                  Color statusColor = Colors.grey;

                  if (status.toLowerCase().contains('out')) {
                    statusColor = AppTheme.errorPink;
                  } else if (status.toLowerCase().contains('questionable')) {
                    statusColor = AppTheme.warningAmber;
                  } else if (status.toLowerCase().contains('probable')) {
                    statusColor = AppTheme.successGreen;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                injury['athlete']?['displayName'] ?? 'Unknown Player',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (injury['athlete']?['position']?['abbreviation'] != null)
                                Text(
                                  injury['athlete']['position']['abbreviation'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            injury['details']?['detail'] ?? injury['details']?['type'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Custom delegate for pinned tab bar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surfaceBlue,
      child: Column(
        children: [
          tabBar,
          Container(
            height: 1,
            color: AppTheme.borderCyan.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}