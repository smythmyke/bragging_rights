import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as Math;
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';
import '../../services/bet_storage_service.dart';
import '../../services/sports_api_service.dart';
import '../../services/odds_api_service.dart';
import '../../models/game_model.dart';
import '../../models/odds_model.dart';
import '../../widgets/info_edge_carousel.dart';
import '../../models/props_models.dart';
import '../../widgets/props_tab_content.dart';

class BetSelectionScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  final String poolName;
  final String? poolId;
  final String? gameId;
  
  const BetSelectionScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
    required this.poolName,
    this.poolId,
    this.gameId,
  });

  @override
  State<BetSelectionScreen> createState() => _BetSelectionScreenState();
}

class _BetSelectionScreenState extends State<BetSelectionScreen> with TickerProviderStateMixin {
  late TabController _betTypeController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  Duration _gameStartCountdown = const Duration(hours: 1, minutes: 15);
  
  // Services
  final BetService _betService = BetService();
  final WalletService _walletService = WalletService();
  final SportsApiService _sportsApiService = SportsApiService();
  final OddsApiService _oddsApiService = OddsApiService();
  
  // Selected team/fighter
  String? _selectedTeam;
  
  // Multiple bets for parlay
  List<SelectedBet> _selectedBets = [];
  
  // Track all bets made across tabs
  final Map<String, List<SelectedBet>> _allTabBets = {};
  
  // Wager amount
  int _wagerAmount = 50;
  
  // Loading state
  bool _isLockingBets = false;
  
  // Track picks made per tab - initialized based on sport
  late Map<String, bool> _tabPicks;
  
  // Track if we should show summary
  bool _showingSummary = false;
  
  // Live betting
  bool _isLiveBetting = false;
  
  // Bet storage
  late BetStorageService _betStorage;
  List<UserBet> _existingBets = [];
  
  // Available intel (for pulsing indicators) - populated from real data
  final Map<String, String> _availableIntel = {};
  
  // Game and odds data
  GameModel? _gameData;
  OddsModel? _oddsData;
  bool _isLoadingData = true;
  String? _homeTeam;
  String? _awayTeam;
  
  // Props data
  PropsTabData? _propsData;
  bool _isLoadingProps = false;
  bool _hasAttemptedPropsLoad = false;
  String _propsSearchQuery = '';
  bool _showHomeTeamProps = true;
  final Map<String, bool> _expandedPlayers = {};
  final Map<String, bool> _expandedPositions = {};
  
  @override
  void initState() {
    super.initState();
    print('=== BET SELECTION SCREEN INIT ===');
    print('Game Title: ${widget.gameTitle}');
    print('Sport: ${widget.sport}');
    print('Pool Name: ${widget.poolName}');
    print('Pool ID: ${widget.poolId}');
    print('Game ID: ${widget.gameId}');
    print('================================');
    
    _betTypeController = _getSportSpecificTabController();
    _initializeTabPicks();
    _betTypeController.addListener(_onTabChanged);
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _startCountdownTimer();
    _loadExistingBets();
    _loadGameAndOddsData();
  }
  
  Future<void> _loadGameAndOddsData() async {
    print('[BetSelection] _loadGameAndOddsData - Sport: ${widget.sport}, GameID: ${widget.gameId}');
    
    try {
      // Try to extract team names from game title first
      if (widget.gameTitle.contains(' @ ') || widget.gameTitle.contains(' vs ')) {
        final separator = widget.gameTitle.contains(' @ ') ? ' @ ' : ' vs ';
        final teams = widget.gameTitle.split(separator);
        if (teams.length == 2) {
          _awayTeam = teams[0].trim();
          _homeTeam = teams[1].trim();
          print('[BetSelection] Teams from title: $_awayTeam vs $_homeTeam');
        }
      }
      
      if (widget.gameId != null) {
        print('[BetSelection] Fetching event odds from API...');
        
        // Use OddsApiService to get event odds
        final eventOdds = await _oddsApiService.getEventOdds(
          sport: widget.sport,
          eventId: widget.gameId!,
          includeProps: false,  // Just basic markets for now
        );
        
        print('[BetSelection] API Response: ${eventOdds != null ? "Success" : "Null"}');
        
        if (eventOdds != null) {
          // Extract teams
          if (eventOdds['home_team'] != null) {
            _homeTeam = eventOdds['home_team'];
            _awayTeam = eventOdds['away_team'];
            print('[BetSelection] Teams from API: $_awayTeam vs $_homeTeam');
          }
          
          // Parse odds from bookmakers
          if (eventOdds['bookmakers'] != null && eventOdds['bookmakers'].isNotEmpty) {
            final bookmakers = eventOdds['bookmakers'] as List;
            print('[BetSelection] Found ${bookmakers.length} bookmakers');
            
            // Parse odds data
            double? homeML, awayML, spread, total;
            double? spreadHomeOdds = -110, spreadAwayOdds = -110;
            double? overOdds = -110, underOdds = -110;
            
            for (final bookmaker in bookmakers) {
              final markets = bookmaker['markets'] as List? ?? [];
              
              for (final market in markets) {
                final key = market['key'];
                final outcomes = market['outcomes'] as List? ?? [];
                
                print('[BetSelection] Market: $key with ${outcomes.length} outcomes');
                
                if (key == 'h2h' && homeML == null) {
                  for (final outcome in outcomes) {
                    if (outcome['name'] == _homeTeam) {
                      homeML = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                    } else if (outcome['name'] == _awayTeam) {
                      awayML = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                    }
                  }
                } else if (key == 'spreads' && spread == null) {
                  for (final outcome in outcomes) {
                    if (outcome['name'] == _homeTeam) {
                      spread = (outcome['point'] as num?)?.toDouble();
                      if (outcome['price'] != null) {
                        spreadHomeOdds = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                      }
                    } else if (outcome['name'] == _awayTeam && outcome['price'] != null) {
                      spreadAwayOdds = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                    }
                  }
                } else if (key == 'totals' && total == null) {
                  for (final outcome in outcomes) {
                    if (outcome['name'] == 'Over') {
                      total = (outcome['point'] as num?)?.toDouble();
                      if (outcome['price'] != null) {
                        overOdds = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                      }
                    } else if (outcome['name'] == 'Under' && outcome['price'] != null) {
                      underOdds = _convertToAmericanOdds((outcome['price'] as num).toDouble());
                    }
                  }
                }
              }
            }
            
            print('[BetSelection] Parsed - ML: $homeML/$awayML, Spread: $spread, Total: $total');
            
            setState(() {
              _oddsData = OddsModel(
                homeMoneyline: homeML,
                awayMoneyline: awayML,
                spread: spread,
                spreadHomeOdds: spreadHomeOdds,
                spreadAwayOdds: spreadAwayOdds,
                totalPoints: total,
                overOdds: overOdds,
                underOdds: underOdds,
              );
              _isLoadingData = false;
            });
            return;
          } else {
            print('[BetSelection] No bookmakers in response');
          }
        }
      }
      
      // Fallback logic
      if (widget.sport.toUpperCase().contains('NFL') || widget.sport.toUpperCase().contains('FOOTBALL')) {
        print('[BetSelection] Using mock football data');
        _loadMockFootballData();
      } else {
        print('[BetSelection] No data available');
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      print('[BetSelection] Error: $e');
      if (widget.sport.toUpperCase().contains('NFL') || widget.sport.toUpperCase().contains('FOOTBALL')) {
        _loadMockFootballData();
      } else {
        setState(() => _isLoadingData = false);
      }
    }
  }
  
  double _convertToAmericanOdds(double decimalOdds) {
    if (decimalOdds >= 2.0) {
      return (decimalOdds - 1) * 100;
    } else {
      return -100 / (decimalOdds - 1);
    }
  }
  
  void _loadMockFootballData() {
    // Create mock odds data for demonstration
    setState(() {
      _oddsData = OddsModel(
        homeMoneyline: -150,  // Home team favored
        awayMoneyline: 130,   // Away team underdog
        spread: -3.5,         // Home team favored by 3.5
        spreadHomeOdds: -110,
        spreadAwayOdds: -110,
        totalPoints: 45.5,    // Over/Under 45.5 points
        overOdds: -110,
        underOdds: -110,
      );
      _isLoadingData = false;
    });
  }
  
  void _initializeTabPicks() {
    final tabOrder = _getTabOrder();
    _tabPicks = {};
    for (var tab in tabOrder) {
      if (tab != 'live') { // Don't track live tab
        _tabPicks[tab] = false;
      }
    }
  }
  
  List<String> _getTabOrder() {
    // Return the order of tabs based on sport (Props removed)
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
      case 'MLB':
        return ['winner', 'spread', 'totals', 'props', 'live'];
      case 'MMA':
      case 'BOXING':
        return ['winner', 'method', 'rounds'];
      case 'TENNIS':
        return ['match', 'sets', 'games'];
      default:
        return ['main', 'live'];
    }
  }
  
  void _onTabChanged() {
    // Track which tab user is currently on
    setState(() {});
  }
  
  TabController _getSportSpecificTabController() {
    // Clean up the sport string and check for keywords
    final sportUpper = widget.sport.toUpperCase().trim();
    
    print('Getting tab controller for sport: "$sportUpper"');
    
    // Check for NBA, NFL, NHL, MLB - Now 5 tabs WITH Props
    if (sportUpper.contains('NBA') || sportUpper.contains('BASKETBALL') ||
        sportUpper.contains('NFL') || sportUpper.contains('FOOTBALL') ||
        sportUpper.contains('NHL') || sportUpper.contains('HOCKEY') ||
        sportUpper.contains('MLB') || sportUpper.contains('BASEBALL')) {
      print('Creating 5-tab controller for team sports with props');
      return TabController(length: 5, vsync: this); // Winner, Spread, Totals, Props, Live
    }
    
    // Check for MMA/Boxing - Keep as is since no props tab
    if (sportUpper.contains('MMA') || sportUpper.contains('UFC') || 
        sportUpper.contains('BOXING') || sportUpper.contains('FIGHT')) {
      print('Creating 3-tab controller for combat sports');
      return TabController(length: 3, vsync: this); // Winner, Method, Rounds (no live for now)
    }
    
    // Check for Tennis
    if (sportUpper.contains('TENNIS')) {
      print('Creating 3-tab controller for tennis');
      return TabController(length: 3, vsync: this); // Match, Sets, Games (no live for now)
    }
    
    // Default fallback
    print('Creating default 2-tab controller');
    return TabController(length: 2, vsync: this); // Main, Live
  }
  
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_gameStartCountdown.inSeconds > 0) {
            _gameStartCountdown = Duration(seconds: _gameStartCountdown.inSeconds - 1);
          } else {
            _isLiveBetting = true;
          }
        });
      }
    });
  }
  
  Future<void> _loadExistingBets() async {
    _betStorage = await BetStorageService.create();
    
    if (widget.poolId != null && widget.gameId != null) {
      final allBets = await _betStorage.getGameBets(widget.poolId!, widget.gameId!);
      
      debugPrint('Loading existing bets for pool ${widget.poolId}, game ${widget.gameId}');
      debugPrint('Found ${allBets.length} total bets');
      
      // Separate temporary and confirmed bets
      final tempBets = allBets.where((b) => b.metadata?['isTemporary'] == true).toList();
      final confirmedBets = allBets.where((b) => b.metadata?['isTemporary'] != true).toList();
      
      debugPrint('Temporary bets: ${tempBets.length}, Confirmed bets: ${confirmedBets.length}');
      
      // Store confirmed bets
      _existingBets = confirmedBets;
      
      // Load the appropriate selections
      final betsToLoad = confirmedBets.isNotEmpty ? confirmedBets : tempBets;
      
      for (final bet in betsToLoad) {
        final existingSelection = SelectedBet(
          id: bet.selection,
          title: bet.description ?? bet.selection,
          odds: bet.odds,
          type: _getBetTypeFromString(bet.betType),
        );
        
        // Check if not already in _selectedBets
        if (!_selectedBets.any((s) => s.id == existingSelection.id)) {
          _selectedBets.add(existingSelection);
          debugPrint('Loaded selection: ${existingSelection.title}');
        }
        
        // Mark the tab as picked based on bet type
        final tabKey = _getTabKeyFromBetType(bet.betType);
        if (tabKey != null) {
          _tabPicks[tabKey] = true;
        }
      }
      
      debugPrint('Total selections loaded: ${_selectedBets.length}');
      setState(() {});
    }
  }
  
  Future<void> _saveSelectionsToStorage() async {
    if (widget.poolId == null || widget.gameId == null) return;
    
    try {
      // Save current selections as temporary bets
      final tempBets = <UserBet>[];
      
      debugPrint('=== SAVING SELECTIONS ===');
      debugPrint('Pool ID: ${widget.poolId}');
      debugPrint('Game ID: ${widget.gameId}');
      debugPrint('Number of selections: ${_selectedBets.length}');
      
      for (final selection in _selectedBets) {
        debugPrint('Saving selection: ID="${selection.id}", Title="${selection.title}", Odds="${selection.odds}"');
        
        final bet = UserBet(
          id: 'temp_${selection.id}_${DateTime.now().millisecondsSinceEpoch}',
          poolId: widget.poolId!,
          poolName: widget.poolName,
          gameId: widget.gameId!,
          gameTitle: widget.gameTitle,
          sport: widget.sport,
          betType: selection.type.toString().split('.').last,
          selection: selection.id,  // This is the key field for matching
          odds: selection.odds,
          amount: _wagerAmount.toDouble(),
          placedAt: DateTime.now(),
          description: selection.title,
          metadata: {
            'isTemporary': true,
            'savedAt': DateTime.now().toIso8601String(),
          },
        );
        tempBets.add(bet);
      }
      
      // Clear old temporary selections for this game
      final allBets = await _betStorage.getActiveBets();
      final nonTempBets = allBets.where((b) => 
        !(b.poolId == widget.poolId && 
          b.gameId == widget.gameId && 
          b.metadata?['isTemporary'] == true)
      ).toList();
      
      // Add new temporary selections
      nonTempBets.addAll(tempBets);
      
      // Save to storage
      await _betStorage.saveBets(nonTempBets);
      
      debugPrint('Successfully saved ${tempBets.length} temporary selections for pool ${widget.poolId}');
      debugPrint('======================');
    } catch (e) {
      debugPrint('Error saving selections: $e');
    }
  }
  
  BetType _getBetTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'moneyline':
      case 'winner':
        return BetType.moneyline;
      case 'spread':
        return BetType.spread;
      case 'total':
      case 'totals':
        return BetType.total;
      case 'prop':
      case 'props':
        return BetType.prop;
      case 'method':
        return BetType.method;
      case 'rounds':
        return BetType.rounds;
      case 'live':
        return BetType.live;
      default:
        return BetType.moneyline; // Default to moneyline instead of removed prop
    }
  }
  
  String? _getTabKeyFromBetType(String betType) {
    switch (betType.toLowerCase()) {
      case 'moneyline':
      case 'winner':
        return 'winner';
      case 'spread':
        return 'spread';
      case 'total':
      case 'totals':
        return 'totals';
      case 'prop':
      case 'props':
        return 'props';
      case 'method':
        return 'method';
      case 'rounds':
        return 'rounds';
      case 'live':
        return 'live';
      default:
        return null;
    }
  }
  
  @override
  void dispose() {
    _betTypeController.removeListener(_onTabChanged);
    _betTypeController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gameTitle, style: const TextStyle(fontSize: 14)),
            Text(
              '${widget.sport} • ${widget.poolName}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Progress indicator
          _buildQuickProgress(),
          const SizedBox(width: 8),
          // Timer or Live indicator
          if (_isLiveBetting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.live_tv, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _gameStartCountdown.inMinutes < 30 ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDuration(_gameStartCountdown),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildBetTypeTabs(),
        ),
      ),
      body: Column(
        children: [
          // Team/Fighter Selection
          _buildTeamSelection(),
          
          // Bet Options
          Expanded(
            child: TabBarView(
              controller: _betTypeController,
              children: _buildSportSpecificTabs(),
            ),
          ),
          
          // Bet Slip
          _buildBetSlip(),
          
          // Lock In Bets Button
          _buildLockInBetsButton(),
        ],
      ),
    );
  }
  
  Widget _buildBetTypeTabs() {
    final sportUpper = widget.sport.toUpperCase().trim();
    
    if (sportUpper.contains('NBA') || sportUpper.contains('BASKETBALL') ||
        sportUpper.contains('NFL') || sportUpper.contains('FOOTBALL') ||
        sportUpper.contains('NHL') || sportUpper.contains('HOCKEY') ||
        sportUpper.contains('MLB') || sportUpper.contains('BASEBALL')) {
      return TabBar(
        controller: _betTypeController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Winner'),
          Tab(text: 'Spread'),
          Tab(text: 'Totals'),
          Tab(text: 'Props'),
          Tab(text: 'Live'),
        ],
      );
    }
    
    if (sportUpper.contains('MMA') || sportUpper.contains('UFC') || 
        sportUpper.contains('BOXING') || sportUpper.contains('FIGHT')) {
      return TabBar(
        controller: _betTypeController,
        tabs: const [
          Tab(text: 'Winner'),
          Tab(text: 'Method'),
          Tab(text: 'Rounds'),
        ],
      );
    }
    
    if (sportUpper.contains('TENNIS')) {
      return TabBar(
        controller: _betTypeController,
        tabs: const [
          Tab(text: 'Match'),
          Tab(text: 'Sets'),
          Tab(text: 'Games'),
        ],
      );
    }
    
    // Default
    return TabBar(
      controller: _betTypeController,
      tabs: const [
        Tab(text: 'Main'),
        Tab(text: 'Live'),
      ],
    );
  }
  
  List<Widget> _buildSportSpecificTabs() {
    final sportUpper = widget.sport.toUpperCase().trim();
    
    if (sportUpper.contains('NBA') || sportUpper.contains('BASKETBALL') ||
        sportUpper.contains('NFL') || sportUpper.contains('FOOTBALL') ||
        sportUpper.contains('NHL') || sportUpper.contains('HOCKEY') ||
        sportUpper.contains('MLB') || sportUpper.contains('BASEBALL')) {
      return [
        _buildMoneylineTab(),
        _buildSpreadTab(),
        _buildTotalsTab(),
        _buildPropsTab(),
        _buildLiveBettingTab(),
      ];
    }
    
    if (sportUpper.contains('MMA') || sportUpper.contains('UFC') || 
        sportUpper.contains('BOXING') || sportUpper.contains('FIGHT')) {
      return [
        _buildMoneylineTab(),
        _buildMethodOfVictoryTab(),
        _buildRoundBettingTab(),
      ];
    }
    
    if (sportUpper.contains('TENNIS')) {
      return [
        _buildMoneylineTab(),
        _buildSetsTab(),
        _buildGamesTab(),
      ];
    }
    
    // Default
    return [
      _buildMoneylineTab(),
      _buildLiveBettingTab(),
    ];
  }
  
  Widget _buildTeamSelection() {
    if (_isLoadingData) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.gameTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_gameData != null) ...[  
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTeamInfo(
                  _awayTeam ?? 'Away',
                  _getTeamAbbr(_awayTeam ?? 'AWAY'),
                  Theme.of(context).colorScheme.secondary,
                  _oddsData?.formatMoneyline(_oddsData?.awayMoneyline) ?? '--',
                ),
                Column(
                  children: [
                    const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_oddsData?.totalPoints != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'O/U ${_oddsData!.formatTotal(_oddsData!.totalPoints)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                _buildTeamInfo(
                  _homeTeam ?? 'Home',
                  _getTeamAbbr(_homeTeam ?? 'HOME'),
                  Theme.of(context).colorScheme.primary,
                  _oddsData?.formatMoneyline(_oddsData?.homeMoneyline) ?? '--',
                ),
              ],
            ),
          ] else ...[  
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                'Game data not available',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _getTeamAbbr(String teamName) {
    // NFL team abbreviations
    final Map<String, String> nflAbbreviations = {
      'Arizona Cardinals': 'ARI',
      'Atlanta Falcons': 'ATL',
      'Baltimore Ravens': 'BAL',
      'Buffalo Bills': 'BUF',
      'Carolina Panthers': 'CAR',
      'Chicago Bears': 'CHI',
      'Cincinnati Bengals': 'CIN',
      'Cleveland Browns': 'CLE',
      'Dallas Cowboys': 'DAL',
      'Denver Broncos': 'DEN',
      'Detroit Lions': 'DET',
      'Green Bay Packers': 'GB',
      'Houston Texans': 'HOU',
      'Indianapolis Colts': 'IND',
      'Jacksonville Jaguars': 'JAX',
      'Kansas City Chiefs': 'KC',
      'Las Vegas Raiders': 'LV',
      'Los Angeles Chargers': 'LAC',
      'Los Angeles Rams': 'LAR',
      'Miami Dolphins': 'MIA',
      'Minnesota Vikings': 'MIN',
      'New England Patriots': 'NE',
      'New Orleans Saints': 'NO',
      'New York Giants': 'NYG',
      'New York Jets': 'NYJ',
      'Philadelphia Eagles': 'PHI',
      'Pittsburgh Steelers': 'PIT',
      'San Francisco 49ers': 'SF',
      'Seattle Seahawks': 'SEA',
      'Tampa Bay Buccaneers': 'TB',
      'Tennessee Titans': 'TEN',
      'Washington Commanders': 'WAS',
      // Also check for partial matches
      'Cardinals': 'ARI',
      'Falcons': 'ATL',
      'Ravens': 'BAL',
      'Bills': 'BUF',
      'Panthers': 'CAR',
      'Bears': 'CHI',
      'Bengals': 'CIN',
      'Browns': 'CLE',
      'Cowboys': 'DAL',
      'Broncos': 'DEN',
      'Lions': 'DET',
      'Packers': 'GB',
      'Texans': 'HOU',
      'Colts': 'IND',
      'Jaguars': 'JAX',
      'Chiefs': 'KC',
      'Raiders': 'LV',
      'Chargers': 'LAC',
      'Rams': 'LAR',
      'Dolphins': 'MIA',
      'Vikings': 'MIN',
      'Patriots': 'NE',
      'Saints': 'NO',
      'Giants': 'NYG',
      'Jets': 'NYJ',
      'Eagles': 'PHI',
      'Steelers': 'PIT',
      '49ers': 'SF',
      'Seahawks': 'SEA',
      'Buccaneers': 'TB',
      'Titans': 'TEN',
      'Commanders': 'WAS',
    };
    
    // Check for exact match
    if (nflAbbreviations.containsKey(teamName)) {
      return nflAbbreviations[teamName]!;
    }
    
    // Check for partial match
    for (final entry in nflAbbreviations.entries) {
      if (teamName.contains(entry.key) || entry.key.contains(teamName)) {
        return entry.value;
      }
    }
    
    // Default abbreviation
    if (teamName.length <= 3) return teamName.toUpperCase();
    return teamName.substring(0, 3).toUpperCase();
  }
  
  Widget _buildFighterSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.sports_mma, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              widget.gameTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Fighter data loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeamInfo(String team, String abbreviation, Color color, String odds) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Text(
              abbreviation,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(team, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              odds,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFighterCard(String name, String nickname, Color color, String odds) {
    final isSelected = _selectedTeam == name;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTeam = name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.person, size: 32),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(nickname, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                odds,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMoneylineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Winner (Moneyline)',
          description: 'Pick who will win. Negative odds mean favorite, positive odds mean underdog.',
          icon: Icons.emoji_events,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        if (_oddsData != null && _oddsData!.homeMoneyline != null && _oddsData!.awayMoneyline != null) ...[
          _buildBetCard(
            '${_awayTeam ?? "Away"} to Win',
            _oddsData!.formatMoneyline(_oddsData!.awayMoneyline),
            _oddsData!.awayMoneyline! > 0 
                ? 'Bet 100 to win ${_oddsData!.awayMoneyline!.toStringAsFixed(0)}'
                : 'Bet ${_oddsData!.awayMoneyline!.abs().toStringAsFixed(0)} to win 100',
            Theme.of(context).colorScheme.secondary,
            BetType.moneyline,
            '${_awayTeam ?? "Away"} ML',
          ),
          _buildBetCard(
            '${_homeTeam ?? "Home"} to Win',
            _oddsData!.formatMoneyline(_oddsData!.homeMoneyline),
            _oddsData!.homeMoneyline! > 0
                ? 'Bet 100 to win ${_oddsData!.homeMoneyline!.toStringAsFixed(0)}'
                : 'Bet ${_oddsData!.homeMoneyline!.abs().toStringAsFixed(0)} to win 100',
            Theme.of(context).colorScheme.primary,
            BetType.moneyline,
            '${_homeTeam ?? "Home"} ML',
          ),
        ] else
          _buildEmptyBettingState(
            'No moneyline bets available',
            'Odds data will appear when available',
          ),
      ],
    );
  }
  
  Widget _buildSpreadTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Point Spread',
          description: 'Bet on the margin of victory. Favorites must win by more than the spread.',
          icon: Icons.trending_up,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        if (_oddsData != null && _oddsData!.spread != null) ...[
          _buildBetCard(
            '${_awayTeam ?? "Away"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: false)}',
            _oddsData!.formatMoneyline(_oddsData!.spreadAwayOdds ?? -110),
            'Cover the spread',
            Theme.of(context).colorScheme.secondary,
            BetType.spread,
            '${_awayTeam ?? "Away"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: false)}',
          ),
          _buildBetCard(
            '${_homeTeam ?? "Home"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: true)}',
            _oddsData!.formatMoneyline(_oddsData!.spreadHomeOdds ?? -110),
            'Cover the spread',
            Theme.of(context).colorScheme.primary,
            BetType.spread,
            '${_homeTeam ?? "Home"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: true)}',
          ),
        ] else
          _buildEmptyBettingState(
            'No spread bets available',
            'Spread betting options will appear when data is available',
          ),
      ],
    );
  }
  
  Widget _buildTotalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Over/Under (Totals)',
          description: 'Bet on the total combined score.',
          icon: Icons.add_circle_outline,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        if (_oddsData != null && _oddsData!.totalPoints != null) ...[
          const Text('Game Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildBetCard(
            'Over ${_oddsData!.formatTotal(_oddsData!.totalPoints)}',
            _oddsData!.formatMoneyline(_oddsData!.overOdds ?? -110),
            'Combined score over ${_oddsData!.totalPoints}',
            Colors.orange,
            BetType.total,
            'Over ${_oddsData!.totalPoints}',
          ),
          _buildBetCard(
            'Under ${_oddsData!.formatTotal(_oddsData!.totalPoints)}',
            _oddsData!.formatMoneyline(_oddsData!.underOdds ?? -110),
            'Combined score under ${_oddsData!.totalPoints}',
            Colors.blue,
            BetType.total,
            'Under ${_oddsData!.totalPoints}',
          ),
        ] else
          _buildEmptyBettingState(
            'No totals bets available',
            'Over/Under options will appear when data is available',
          ),
      ],
    );
  }
  
  // Props tab with real data from event-specific endpoint
  Widget _buildPropsTab() {
    // Load props on first access - but add a flag to prevent repeated calls
    if (_propsData == null && !_isLoadingProps && !_hasAttemptedPropsLoad && widget.gameId != null) {
      _hasAttemptedPropsLoad = true;
      _loadPropsData();
    }
    
    if (_isLoadingProps) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading player props...'),
          ],
        ),
      );
    }
    
    if (_propsData == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoEdgeCarousel(
            title: 'Player Props',
            description: 'Bet on individual player performances',
            icon: Icons.person,
            onEdgePressed: _navigateToEdge,
            autoScrollDelay: const Duration(seconds: 3),
          ),
          const SizedBox(height: 16),
          _buildEmptyBettingState(
            'Props not available',
            'Player props will appear when game data is available',
          ),
        ],
      );
    }
    
    return _buildPropsContent();
  }
  
  Future<void> _loadPropsData() async {
    if (_isLoadingProps || widget.gameId == null) return;
    
    print('[BetSelection] Loading props for ${widget.sport} - Event: ${widget.gameId}');
    if (mounted) {
      setState(() => _isLoadingProps = true);
    }
    
    try {
      // First, try to find the correct Odds API event ID using team names
      String? oddsApiEventId = widget.gameId;
      
      if (_homeTeam != null && _awayTeam != null) {
        print('[BetSelection] Finding Odds API event ID for: $_homeTeam vs $_awayTeam');
        final foundEventId = await _oddsApiService.findOddsApiEventId(
          sport: widget.sport,
          homeTeam: _homeTeam!,
          awayTeam: _awayTeam!,
        );
        
        if (foundEventId != null) {
          oddsApiEventId = foundEventId;
          print('[BetSelection] Using Odds API event ID: $oddsApiEventId');
        } else {
          print('[BetSelection] Could not find matching Odds API event');
        }
      }
      
      // Get event odds with props using the correct event ID
      final eventOdds = await _oddsApiService.getEventOdds(
        sport: widget.sport,
        eventId: oddsApiEventId!,
        includeProps: true,
        includeAlternates: true,
      );
      
      print('[BetSelection] Props response: ${eventOdds != null ? "Success" : "Null"}');
      
      if (eventOdds != null && eventOdds['bookmakers'] != null) {
        final bookmakers = eventOdds['bookmakers'] as List;
        print('[BetSelection] Props: ${bookmakers.length} bookmakers');
        
        // Check available markets
        if (bookmakers.isNotEmpty) {
          final markets = bookmakers[0]['markets'] as List? ?? [];
          final marketKeys = markets.map((m) => m['key']).toList();
          print('[BetSelection] Available prop markets: $marketKeys');
        }
        
        // Parse props data from bookmakers
        final propsData = _parsePropsFromBookmakers(
          bookmakers,
          _homeTeam ?? 'Home',
          _awayTeam ?? 'Away',
        );
        
        print('[BetSelection] Parsed ${propsData?.playersByName.length ?? 0} players');
        
        if (mounted) {
          setState(() {
            _propsData = propsData;
            _isLoadingProps = false;
          });
        }
      } else {
        print('[BetSelection] No props data');
        if (mounted) {
          setState(() => _isLoadingProps = false);
        }
      }
    } catch (e) {
      print('[BetSelection] Props error: $e');
      if (mounted) {
        setState(() => _isLoadingProps = false);
      }
    }
  }
  
  
  PropsTabData? _parsePropsFromBookmakers(
    List<dynamic> bookmakers,
    String homeTeam,
    String awayTeam,
  ) {
    if (bookmakers.isEmpty) return null;
    
    final playersByName = <String, PlayerProps>{};
    final playersByTeam = <String, List<String>>{
      homeTeam: [],
      awayTeam: [],
    };
    final playersByPosition = <String, List<String>>{};
    
    // Process each bookmaker
    for (final bookmaker in bookmakers) {
      final markets = bookmaker['markets'] as List? ?? [];
      
      for (final market in markets) {
        final marketKey = market['key'] as String;
        
        // Skip non-prop markets
        if (!marketKey.startsWith('player_') && 
            !marketKey.startsWith('batter_') && 
            !marketKey.startsWith('pitcher_')) {
          continue;
        }
        
        final outcomes = market['outcomes'] as List? ?? [];
        
        for (final outcome in outcomes) {
          final playerName = PropsParser.extractPlayerName(outcome['name'] as String);
          
          if (!playersByName.containsKey(playerName)) {
            playersByName[playerName] = PlayerProps(
              name: playerName,
              team: homeTeam, // Default to home, will need roster data to improve
              position: '',
              isStar: false,
              props: [],
            );
          }
          
          // Create prop option
          final prop = PropOption(
            marketKey: marketKey,
            type: PropsParser.getMarketDisplayName(marketKey),
            displayName: PropsParser.getMarketDisplayName(marketKey),
            line: outcome['point']?.toDouble(),
            overOdds: outcome['name'].toString().contains('Over') 
                ? outcome['price']?.toDouble() : null,
            underOdds: outcome['name'].toString().contains('Under') 
                ? outcome['price']?.toDouble() : null,
            straightOdds: (!outcome['name'].toString().contains('Over') && 
                          !outcome['name'].toString().contains('Under')) 
                ? outcome['price']?.toDouble() : null,
            bookmaker: bookmaker['title'] ?? 'Unknown',
            description: outcome['name'] as String,
          );
          
          playersByName[playerName]!.props.add(prop);
        }
      }
    }
    
    // Identify star players and organize by position
    final starPlayers = <String>[];
    
    playersByName.forEach((name, player) {
      // Infer position from prop types
      final propTypes = player.props.map((p) => p.marketKey).toList();
      final position = PropsParser.inferPosition(propTypes);
      
      // Check if star player
      final isStar = PropsParser.isStarPlayer(player.props);
      
      // Update player
      final updatedPlayer = PlayerProps(
        name: player.name,
        team: player.team,
        position: position,
        isStar: isStar,
        props: player.props,
      );
      
      playersByName[name] = updatedPlayer;
      
      // Track by team
      if (!playersByTeam[player.team]!.contains(name)) {
        playersByTeam[player.team]!.add(name);
      }
      
      // Track by position
      if (!playersByPosition.containsKey(position)) {
        playersByPosition[position] = [];
      }
      if (!playersByPosition[position]!.contains(name)) {
        playersByPosition[position]!.add(name);
      }
      
      // Track stars
      if (isStar) {
        starPlayers.add(name);
      }
    });
    
    // Sort stars by prop count
    starPlayers.sort((a, b) => 
      playersByName[b]!.propCount.compareTo(playersByName[a]!.propCount));
    
    return PropsTabData(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      playersByName: playersByName,
      starPlayers: starPlayers.take(5).toList(),
      playersByPosition: playersByPosition,
      playersByTeam: playersByTeam,
      cacheTime: DateTime.now(),
      eventId: widget.gameId ?? '',
    );
  }
  
  Widget _buildPropsContent() {
    if (_propsData == null) {
      return const SizedBox.shrink();
    }
    
    return PropsTabContent(
      propsData: _propsData!,
      onBetSelected: (id, title, odds, type) {
        setState(() {
          final betId = 'prop_$id';
          if (_selectedBets.any((bet) => bet.id == betId)) {
            _selectedBets.removeWhere((bet) => bet.id == betId);
          } else {
            _selectedBets.add(SelectedBet(
              id: betId,
              title: title,
              odds: odds,
              type: type,
            ));
          }
        });
        // Save selection
        _saveSelectionsToStorage();
      },
      selectedBetIds: _selectedBets
          .where((bet) => bet.type == BetType.prop)
          .map((bet) => bet.id.replaceFirst('prop_', ''))
          .toSet(),
      onRefresh: () {
        setState(() {
          _propsData = null;
          _isLoadingProps = false;
        });
        _loadPropsData();
      },
    );
  }
  
  Widget _buildMethodOfVictoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Method of Victory',
          description: 'Bet on how the fight will end.',
          icon: Icons.sports_mma,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        _buildEmptyBettingState(
          'No method of victory bets available',
          'Betting options will appear when fight data is connected',
        ),
      ],
    );
  }
  
  Widget _buildRoundBettingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Round Betting',
          description: 'Bet on when the fight will end.',
          icon: Icons.timer,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        _buildEmptyBettingState(
          'No round betting available',
          'Round betting options will appear when fight data is connected',
        ),
      ],
    );
  }
  
  Widget _buildLiveBettingTab() {
    if (!_isLiveBetting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              widget.sport.toUpperCase() == 'MMA' || widget.sport.toUpperCase() == 'BOXING'
                  ? 'Live Betting Available When Fight Starts'
                  : 'Live Betting Available When Game Starts',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back in ${_formatDuration(_gameStartCountdown)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    // Live betting when available - show same markets with updated odds
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Live Betting',
          description: 'Updated odds during the game. Same markets, live prices.',
          icon: Icons.live_tv,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        // Live odds notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.live_tv, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE - Odds update every 30 seconds',
                  style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Show live versions of the same markets
        if (_oddsData != null) ...[
          const Text('Live Moneyline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_oddsData!.homeMoneyline != null && _oddsData!.awayMoneyline != null) ...[
            _buildBetCard(
              '${_awayTeam ?? "Away"} to Win (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.awayMoneyline),
              'Live moneyline odds',
              Colors.red,
              BetType.live,
              'live_${_awayTeam ?? "Away"}_ML',
            ),
            _buildBetCard(
              '${_homeTeam ?? "Home"} to Win (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.homeMoneyline),
              'Live moneyline odds',
              Colors.red,
              BetType.live,
              'live_${_homeTeam ?? "Home"}_ML',
            ),
          ],
          const SizedBox(height: 16),
          const Text('Live Spread', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_oddsData!.spread != null) ...[
            _buildBetCard(
              '${_awayTeam ?? "Away"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: false)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.spreadAwayOdds ?? -110),
              'Live spread betting',
              Colors.orange,
              BetType.live,
              'live_${_awayTeam ?? "Away"}_spread',
            ),
            _buildBetCard(
              '${_homeTeam ?? "Home"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: true)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.spreadHomeOdds ?? -110),
              'Live spread betting',
              Colors.orange,
              BetType.live,
              'live_${_homeTeam ?? "Home"}_spread',
            ),
          ],
          const SizedBox(height: 16),
          const Text('Live Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_oddsData!.totalPoints != null) ...[
            _buildBetCard(
              'Over ${_oddsData!.formatTotal(_oddsData!.totalPoints)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.overOdds ?? -110),
              'Live total points',
              Colors.green,
              BetType.live,
              'live_Over_${_oddsData!.totalPoints}',
            ),
            _buildBetCard(
              'Under ${_oddsData!.formatTotal(_oddsData!.totalPoints)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.underOdds ?? -110),
              'Live total points',
              Colors.blue,
              BetType.live,
              'live_Under_${_oddsData!.totalPoints}',
            ),
          ],
        ] else
          _buildEmptyBettingState(
            'Live odds updating...',
            'Live betting markets will appear once the game starts',
          ),
      ],
    );
  }
  
  // Tennis Sets betting
  Widget _buildSetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Set Betting',
          description: 'Bet on the number of sets in the match.',
          icon: Icons.sports_tennis,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        _buildEmptyBettingState(
          'Set betting coming soon',
          'Set betting options will appear when tennis data is available',
        ),
      ],
    );
  }
  
  // Tennis Games betting
  Widget _buildGamesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Game Betting',
          description: 'Bet on total games in the match.',
          icon: Icons.sports_tennis,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        _buildEmptyBettingState(
          'Game betting coming soon',
          'Game betting options will appear when tennis data is available',
        ),
      ],
    );
  }
  
  void _navigateToEdge() {
    Navigator.pushNamed(
      context,
      '/edge',
      arguments: {
        'gameTitle': widget.gameTitle,
        'sport': widget.sport,
      },
    );
  }
  
  Widget _buildEdgeButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: _navigateToEdge,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get The Edge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Unlock insider intelligence',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Intel indicators
                  if (_availableIntel.containsKey('injury'))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.healing,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (_availableIntel.containsKey('news'))
                    Positioned(
                      top: 8,
                      right: _availableIntel.containsKey('injury') ? 40 : 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.newspaper,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyBettingState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBetCard(
    String title,
    String odds,
    String description,
    Color color,
    BetType type,
    String betId, {
    bool isPremium = false,
  }) {
    final isSelected = _selectedBets.any((bet) => bet.id == betId);
    final wasAlreadyPlaced = _existingBets.any((bet) => bet.selection == betId);
    
    // Debug logging for persistence
    if (_selectedBets.isNotEmpty || _existingBets.isNotEmpty) {
      debugPrint('=== BET CARD CHECK ===');
      debugPrint('Bet ID: $betId');
      debugPrint('Is Selected: $isSelected');
      debugPrint('Was Already Placed: $wasAlreadyPlaced');
      debugPrint('Selected Bets IDs: ${_selectedBets.map((b) => b.id).toList()}');
      debugPrint('Existing Bets Selections: ${_existingBets.map((b) => b.selection).toList()}');
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: wasAlreadyPlaced 
            ? Colors.green 
            : isSelected 
              ? color.withOpacity(0.8)
              : Colors.grey.withOpacity(0.2),
          width: wasAlreadyPlaced || isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected || wasAlreadyPlaced ? [
          BoxShadow(
            color: (wasAlreadyPlaced ? Colors.green : color).withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ] : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isSelected || wasAlreadyPlaced ? 3 : 1,
        color: isSelected 
          ? color.withOpacity(0.05)
          : wasAlreadyPlaced 
            ? Colors.green.withOpacity(0.05)
            : null,
        child: ListTile(
        onTap: wasAlreadyPlaced ? null : () async {
          debugPrint('\n=== BET CARD TAPPED ===');
          debugPrint('Bet ID: $betId');
          debugPrint('Title: $title');
          debugPrint('Odds: $odds');
          debugPrint('Type: $type');
          debugPrint('Was Selected: $isSelected');
          debugPrint('Before: ${_selectedBets.length} bets selected');
          
          setState(() {
            if (isSelected) {
              _selectedBets.removeWhere((bet) => bet.id == betId);
              debugPrint('REMOVED bet from selections');
            } else {
              _selectedBets.add(SelectedBet(
                id: betId,
                title: title,
                odds: odds,
                type: type,
              ));
              debugPrint('ADDED bet to selections');
            }
          });
          
          debugPrint('After: ${_selectedBets.length} bets selected');
          debugPrint('Selected IDs: ${_selectedBets.map((b) => b.id).toList()}');
          
          // Save selection immediately to persist
          await _saveSelectionsToStorage();
        },
        leading: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected || wasAlreadyPlaced 
                  ? (wasAlreadyPlaced ? Colors.green : color)
                  : color.withOpacity(0.15),
                border: Border.all(
                  color: isSelected || wasAlreadyPlaced 
                    ? (wasAlreadyPlaced ? Colors.green : color)
                    : color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _getBetTypeIcon(type),
                color: isSelected || wasAlreadyPlaced 
                  ? Colors.white 
                  : color,
                size: 22,
              ),
            ),
            if (wasAlreadyPlaced || isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: wasAlreadyPlaced ? Colors.green : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    wasAlreadyPlaced ? Icons.lock : Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: wasAlreadyPlaced ? Colors.green : null,
          ),
        ),
        subtitle: Text(
          description, 
          style: TextStyle(
            fontSize: 12,
            color: wasAlreadyPlaced 
              ? Colors.green.withOpacity(0.7)
              : null,
          ),
        ),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: wasAlreadyPlaced 
              ? Colors.green 
              : isSelected 
                ? color 
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected || wasAlreadyPlaced ? [
              BoxShadow(
                color: (wasAlreadyPlaced ? Colors.green : color).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
          child: Text(
            odds,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected || wasAlreadyPlaced ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
      ),
    );
  }
  
  IconData _getBetTypeIcon(BetType type) {
    switch (type) {
      case BetType.moneyline:
        return Icons.attach_money;
      case BetType.spread:
        return Icons.trending_up;
      case BetType.total:
        return Icons.add_circle;
      case BetType.prop:
        return Icons.person;
      case BetType.method:
        return Icons.sports_mma;
      case BetType.rounds:
        return Icons.timer;
      case BetType.live:
        return Icons.live_tv;
    }
  }
  
  Widget _buildBetSlip() {
    if (_selectedBets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: const Center(
          child: Text(
            'Select bets to add to your slip',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    final isParlay = _selectedBets.length > 1;
    final totalOdds = _calculateParlayOdds();
    final potentialPayout = _calculatePayout(totalOdds);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isParlay ? 'Parlay (${_selectedBets.length} legs)' : 'Single Bet',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (isParlay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${totalOdds.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._selectedBets.map((bet) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bet.title,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  bet.odds,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBets.remove(bet);
                    });
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ],
            ),
          )),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wager Amount', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '50',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _wagerAmount = int.tryParse(value) ?? 50;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Potential Payout', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$potentialPayout BR',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _placeBet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Place Bet ($_wagerAmount BR)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateParlayOdds() {
    if (_selectedBets.length <= 1) {
      return _parseOdds(_selectedBets.first.odds);
    }
    
    // Simplified parlay calculation
    double multiplier = 1;
    for (var bet in _selectedBets) {
      multiplier *= (_parseOdds(bet.odds) / 100 + 1);
    }
    return (multiplier - 1) * 100;
  }
  
  double _parseOdds(String odds) {
    // Convert American odds to decimal for calculation
    final value = double.tryParse(odds.replaceAll('+', '').replaceAll('-', '')) ?? 100;
    if (odds.startsWith('+')) {
      return value;
    } else {
      return 100 / value * 100;
    }
  }
  
  int _calculatePayout(double odds) {
    return (_wagerAmount * (odds / 100 + 1)).toInt();
  }
  
  void _placeBet() {
    // Mark current tab as having a bet placed
    _markCurrentTabAsHavingBet();
    
    final betType = _selectedBets.length > 1 ? 'Parlay' : 'Single';
    
    // Check if all tabs have picks
    final allPicked = _tabPicks.values.every((picked) => picked);
    
    if (allPicked && !_showingSummary) {
      // Show summary screen
      _showBetSummary();
    } else {
      // Show confirmation and navigate to next unpicked tab
      _showBetConfirmationAndNavigate(betType);
    }
  }
  
  void _markCurrentTabAsHavingBet() {
    // Mark the current tab index as having a bet placed
    final currentIndex = _betTypeController.index;
    final tabOrder = _getTabOrder();
    
    if (currentIndex < tabOrder.length) {
      final currentTab = tabOrder[currentIndex];
      setState(() {
        _tabPicks[currentTab] = true;
        // Store the current bets for this tab
        if (_selectedBets.isNotEmpty) {
          _allTabBets[currentTab] = List.from(_selectedBets);
        }
      });
    }
  }
  
  // Check if any bets have been made across all tabs
  bool _hasAnyBets() {
    return _allTabBets.values.any((bets) => bets.isNotEmpty);
  }
  
  // Get all bets from all tabs
  List<SelectedBet> _getAllBets() {
    // Return the current _selectedBets which contains all selections
    return List.from(_selectedBets);
  }
  
  // Lock in all bets and save to Firestore
  Future<void> _lockInBets() async {
    debugPrint('Lock in bets clicked');
    setState(() => _isLockingBets = true);
    
    try {
      final allBets = _getAllBets();
      debugPrint('Found ${allBets.length} bets to lock in');
      
      if (allBets.isEmpty) {
        throw Exception('No bets selected');
      }
      
      // Calculate total wager and potential payout
      final totalWager = _wagerAmount * allBets.length;
      final totalOdds = _calculateTotalOdds(allBets);
      final potentialPayout = (totalWager * totalOdds).round();
      
      // Create bet details
      final betDetails = allBets.map((bet) => BetDetail(
        title: bet.title,
        selection: bet.title, // You might want to parse this better
        odds: bet.odds,
        type: bet.type.toString(),
      )).toList();
      
      // Generate a unique game ID (you might want to get this from actual game data)
      final gameId = '${widget.sport}_${widget.gameTitle}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Place the bet
      await _betService.placeBet(
        gameId: gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        poolName: widget.poolName,
        bets: betDetails,
        wagerAmount: totalWager,
        totalOdds: totalOdds,
        potentialPayout: potentialPayout,
      );
      
      // Save bets to local storage
      if (widget.poolId != null && widget.gameId != null) {
        final userBets = allBets.map((bet) => UserBet(
          id: DateTime.now().millisecondsSinceEpoch.toString() + bet.id,
          poolId: widget.poolId!,
          poolName: widget.poolName,
          gameId: widget.gameId!,
          gameTitle: widget.gameTitle,
          sport: widget.sport,
          betType: bet.type.toString().split('.').last,
          selection: bet.title,
          odds: bet.odds,
          amount: _wagerAmount.toDouble(),
          placedAt: DateTime.now(),
          description: bet.title, // Using title as description since subtitle doesn't exist
        )).toList();
        
        await _betStorage.saveBets(userBets);
        debugPrint('Saved ${userBets.length} bets to storage');
      }
      
      debugPrint('Bets locked in successfully! Potential payout: $potentialPayout BR');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bets locked in! Potential payout: $potentialPayout BR'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error locking in bets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLockingBets = false);
      }
    }
  }
  
  double _calculateTotalOdds(List<SelectedBet> bets) {
    // Simple calculation - you might want to improve this
    double totalOdds = 1.0;
    for (var bet in bets) {
      // Parse odds (assuming format like "+150" or "-110")
      final oddsStr = bet.odds.replaceAll('+', '').replaceAll('-', '');
      final odds = double.tryParse(oddsStr) ?? 100;
      totalOdds *= (odds / 100);
    }
    return totalOdds;
  }
  
  void _showBetConfirmationAndNavigate(String betType) {
    // Find next unpicked tab
    int nextTabIndex = _getNextUnpickedTab();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Bet Placed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$betType bet placed successfully'),
            Text('Wager: $_wagerAmount BR'),
            if (_selectedBets.length > 1)
              Text('${_selectedBets.length} legs'),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            if (nextTabIndex != -1)
              const Text(
                '💡 Try the Spread next for more betting options!',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear current bets for next selection
              setState(() {
                _selectedBets.clear();
              });
              // Navigate to next tab if available
              if (nextTabIndex != -1) {
                _betTypeController.animateTo(nextTabIndex);
              }
            },
            child: Text(nextTabIndex != -1 ? 'Next Tab' : 'Continue'),
          ),
        ],
      ),
    );
  }
  
  int _getNextUnpickedTab() {
    // Map tab indices to pick status
    final tabOrder = _getTabOrder();
    
    // Only check non-live tabs (exclude 'live' tab if it exists)
    for (int i = 0; i < tabOrder.length && i < _betTypeController.length; i++) {
      final tabKey = tabOrder[i];
      if (tabKey != 'live' && !(_tabPicks[tabKey] ?? false)) {
        return i;
      }
    }
    return -1; // All tabs have picks
  }
  
  Widget _buildProgressIndicator() {
    final pickedCount = _tabPicks.values.where((v) => v).length;
    final totalTabs = _tabPicks.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress: $pickedCount of $totalTabs picks made',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: totalTabs > 0 ? pickedCount / totalTabs : 0,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            pickedCount == totalTabs ? Colors.green : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _buildTabStatusWidgets(),
        ),
      ],
    );
  }
  
  List<Widget> _buildTabStatusWidgets() {
    final widgets = <Widget>[];
    final tabOrder = _getTabOrder();
    final displayNames = _getTabDisplayNames();
    
    for (int i = 0; i < tabOrder.length; i++) {
      final tabKey = tabOrder[i];
      if (tabKey != 'live' && displayNames.containsKey(tabKey)) {
        widgets.add(_buildTabStatus(
          displayNames[tabKey] ?? tabKey,
          _tabPicks[tabKey] ?? false,
        ));
      }
    }
    return widgets;
  }
  
  Map<String, String> _getTabDisplayNames() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
      case 'MLB':
        return {
          'winner': 'Winner',
          'spread': 'Spread',
          'totals': 'O/U',
          'props': 'Props',
        };
      case 'MMA':
      case 'BOXING':
        return {
          'winner': 'Winner',
          'method': 'Method',
          'rounds': 'Rounds',
        };
      case 'TENNIS':
        return {
          'match': 'Match',
          'sets': 'Sets',
          'games': 'Games',
        };
      default:
        return {
          'main': 'Main',
        };
    }
  }
  
  Widget _buildTabStatus(String label, bool isPicked) {
    return Column(
      children: [
        Icon(
          isPicked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isPicked ? Colors.green : Colors.grey,
          size: 20,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isPicked ? Colors.green : Colors.grey,
            fontWeight: isPicked ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  void _showBetSummary() {
    setState(() {
      _showingSummary = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('All Picks Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.amber,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 You\'ve made picks for all categories!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Good luck with your bets!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to pool selection
            },
            child: const Text('View Other Games'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedBets.clear();
                _showingSummary = false;
              });
            },
            child: const Text('Review My Picks'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBetTypeInfo(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _showInfoDialog(title, description, icon);
                      },
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showInfoDialog(String title, String description, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            const Text(
              'Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (title.contains('Winner'))
              const Text('• Best for beginners\n• Simple win/lose outcome\n• Check team form and head-to-head records'),
            if (title.contains('Spread'))
              const Text('• More balanced odds\n• Consider home advantage\n• Look at recent scoring margins'),
            if (title.contains('Over/Under'))
              const Text('• Study team scoring averages\n• Check pace of play\n• Weather can affect totals'),
            if (title.contains('Prop'))
              const Text('• Research player stats\n• Check injury reports\n• Consider matchup advantages'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickProgress() {
    final pickedCount = _tabPicks.values.where((v) => v).length;
    final totalTabs = _tabPicks.length;
    
    if (pickedCount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pickedCount == totalTabs ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pickedCount/$totalTabs',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.check,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLockInBetsButton() {
    final hasAnyBets = _hasAnyBets();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: hasAnyBets ? 100 : 0,  // Increased height from 80 to 100
      child: hasAnyBets
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),  // Added extra bottom padding
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLockingBets ? null : _lockInBets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isLockingBets
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Lock In All Bets (${_selectedBets.length} selections)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

enum BetType {
  moneyline,
  spread,
  total,
  prop,
  method,
  rounds,
  live,
}

class SelectedBet {
  final String id;
  final String title;
  final String odds;
  final BetType type;
  
  SelectedBet({
    required this.id,
    required this.title,
    required this.odds,
    required this.type,
  });
}