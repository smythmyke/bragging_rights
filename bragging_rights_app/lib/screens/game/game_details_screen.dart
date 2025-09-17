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
          _eventDetails = summaryData; // Ensure event details is populated
        });
      } else {
        print('❌ Summary API failed with status ${summaryResponse.statusCode}');
        print('Response body: ${summaryResponse.body.substring(0, 200)}...');
      }

      // Fetch scoreboard for additional data like weather and probables
      // Use date-specific scoreboard to ensure we get the right game
      final gameDate = _game?.gameTime ?? DateTime.now();
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

    // Get team names for logo lookup
    for (final team in competitors) {
      if (team['homeAway'] == 'away') {
        awayTeamName = team['team']?['displayName'];
      } else {
        homeTeamName = team['team']?['displayName'];
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
                      if (awayTeamName != null) ...[
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
                      if (homeTeamName != null) ...[
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

  Widget _buildTeamStatsContent() {
    // Get the selected team's data
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
                    _buildTeamColumn(_game!.homeTeam, _game!.homeTeamLogo, true),
                    Column(
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
                    _buildTeamColumn(_game!.awayTeam, _game!.awayTeamLogo, false),
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
                    final games = teamForm['games'] as List? ?? [];
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
                            final result = game['result'] ?? '';
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
      print('Teams: ${_game?.awayTeam} vs ${_game?.homeTeam}');

      // Use the ESPN ID resolver service - same pattern as soccer
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
          return;
        }
      }

      if (espnGameId != null) {
        print('Fetching NBA game summary from ESPN...');
        final espnUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=$espnGameId';

        final response = await http.get(Uri.parse(espnUrl));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ ESPN NBA data received');

          setState(() {
            _eventDetails = data;

            // Extract boxscore if available
            if (data['boxscore'] != null) {
              _boxScore = data['boxscore'];
            }
          });
        } else {
          print('❌ Failed to fetch ESPN NBA data: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error loading NBA details: $e');
    }
  }

  Widget _buildNBAOverviewTab() {
    if (_eventDetails == null) {
      return const Center(child: Text('Loading game details...'));
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
                  final team = entry['team'];
                  final stats = entry['stats'] ?? [];

                  String getStatValue(String name) {
                    final stat = stats.firstWhere(
                      (s) => s['name'] == name,
                      orElse: () => {'displayValue': '-'},
                    );
                    return stat['displayValue'] ?? '-';
                  }

                  final isCurrentTeam = team['displayName'] == _game?.homeTeam ||
                                      team['displayName'] == _game?.awayTeam;

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
                            team['abbreviation'] ?? team['displayName'],
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