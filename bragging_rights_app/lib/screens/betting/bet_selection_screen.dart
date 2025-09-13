import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as Math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';
import '../../services/bet_storage_service.dart';
import '../../services/sports_api_service.dart';
import '../../services/odds_api_service.dart';
import '../../services/team_logo_service.dart';
import '../../models/game_model.dart';
import '../../models/odds_model.dart';
import '../../widgets/info_edge_carousel.dart';
import '../../models/props_models.dart';
import '../../widgets/props_player_selection.dart';
import '../../widgets/props_tab_content.dart';
import '../../widgets/baseball_props_widget.dart';
import '../../services/props_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/team_bet_card.dart' as team_card;

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
  final TeamLogoService _logoService = TeamLogoService();
  
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
  
  // Track which tabs have available data
  Map<String, bool> _tabAvailability = {};
  
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

  // Team logos
  TeamLogoData? _homeTeamLogo;
  TeamLogoData? _awayTeamLogo;
  
  // Props data
  PropsTabData? _propsData;
  bool _isLoadingProps = false;
  bool _hasAttemptedPropsLoad = false;
  String _propsSearchQuery = '';
  bool _showHomeTeamProps = true;
  bool _isBetSlipMinimized = false;
  String _currentTabName = 'Winner';
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
      print('[BetSelection] Game Title: "${widget.gameTitle}"');
      if (widget.gameTitle.contains(' @ ') || widget.gameTitle.contains(' vs ')) {
        final separator = widget.gameTitle.contains(' @ ') ? ' @ ' : ' vs ';
        print('[BetSelection] Using separator: "$separator"');
        final teams = widget.gameTitle.split(separator);
        print('[BetSelection] Split into ${teams.length} parts: $teams');
        if (teams.length == 2) {
          _awayTeam = teams[0].trim();
          _homeTeam = teams[1].trim();
          print('[BetSelection] Extracted teams:');
          print('[BetSelection]   Away: "$_awayTeam"');
          print('[BetSelection]   Home: "$_homeTeam"');
        } else {
          print('[BetSelection] Could not parse teams from title');
        }
      } else {
        print('[BetSelection] Title does not contain expected separators');
      }
      
      if (widget.gameId != null) {
        print('[BetSelection] Fetching event odds from API...');
        print('[BetSelection] Game ID type: ${widget.gameId} (looks like ${widget.gameId!.contains('-') ? "Odds API" : "ESPN"} format)');
        
        // If we have team names and ESPN ID, try to find Odds API event ID
        String eventIdToUse = widget.gameId!;
        if (!widget.gameId!.contains('-') && _homeTeam != null && _awayTeam != null) {
          print('[BetSelection] ESPN ID detected, finding Odds API event ID for $_awayTeam @ $_homeTeam');
          final oddsApiEventId = await _oddsApiService.findOddsApiEventId(
            sport: widget.sport,
            homeTeam: _homeTeam!,
            awayTeam: _awayTeam!,
          );
          if (oddsApiEventId != null) {
            eventIdToUse = oddsApiEventId;
            print('[BetSelection] Found Odds API event ID: $eventIdToUse');
          } else {
            print('[BetSelection] WARNING: Could not find matching Odds API event ID, will try with ESPN ID');
          }
        }
        
        // Use OddsApiService to get event odds
        final eventOdds = await _oddsApiService.getEventOdds(
          sport: widget.sport,
          eventId: eventIdToUse,
          includeProps: true,  // Include props for complete data
          includeAlternates: true,
        );
        
        print('[BetSelection] API Response: ${eventOdds != null ? "Success" : "Null"}');
        print('[BetSelection] Response status code: ${eventOdds?['status_code'] ?? 'N/A'}');
        
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
                    // DEBUG: Log raw price values from API
                    print('[BetSelection] H2H Outcome: ${outcome['name']}, Raw Price: ${outcome['price']}, Type: ${outcome['price'].runtimeType}');
                    
                    if (outcome['name'] == _homeTeam) {
                      final rawPrice = (outcome['price'] as num).toDouble();
                      print('[BetSelection] Home team raw price: $rawPrice');
                      homeML = _convertToAmericanOdds(rawPrice);
                      print('[BetSelection] Home team converted odds: $homeML');
                    } else if (outcome['name'] == _awayTeam) {
                      final rawPrice = (outcome['price'] as num).toDouble();
                      print('[BetSelection] Away team raw price: $rawPrice');
                      awayML = _convertToAmericanOdds(rawPrice);
                      print('[BetSelection] Away team converted odds: $awayML');
                    }
                  }
                } else if (key == 'spreads' && spread == null) {
                  for (final outcome in outcomes) {
                    if (outcome['name'] == _homeTeam) {
                      final point = outcome['point'];
                      spread = point is num ? point.toDouble() : null;
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
                      final point = outcome['point'];
                      total = point is num ? point.toDouble() : null;
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
            
            // Parse props data from the same bookmakers response
            print('[BetSelection] Parsing props from initial load...');
            
            // Check what markets we have
            final availableMarkets = <String>{};
            final availableProps = <String>{};
            for (final bookmaker in bookmakers) {
              final markets = bookmaker['markets'] as List? ?? [];
              for (final market in markets) {
                final key = market['key'] as String;
                availableMarkets.add(key);
                if (key.startsWith('player_') || key.startsWith('batter_') || key.startsWith('pitcher_')) {
                  availableProps.add(key);
                }
              }
            }
            
            print('[BetSelection] Initial load markets: ${availableMarkets.toList()}');
            print('[BetSelection] Initial load prop markets: ${availableProps.toList()}');
            
            final propsData = _parsePropsFromBookmakers(
              bookmakers,
              _homeTeam ?? 'Home',
              _awayTeam ?? 'Away',
            );
            
            print('[BetSelection] Initial load parsed ${propsData?.playersByName.length ?? 0} players with props');
            
            setState(() {
              // Create GameModel from the event data
              _gameData = GameModel(
                id: eventIdToUse,
                sport: widget.sport.toUpperCase(),
                homeTeam: _homeTeam ?? 'Home',
                awayTeam: _awayTeam ?? 'Away',
                gameTime: eventOdds['commence_time'] != null 
                    ? DateTime.parse(eventOdds['commence_time'])
                    : DateTime.now(),
                status: 'scheduled',
                league: widget.sport.toUpperCase(),
              );
              
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
              _propsData = propsData;
              _isLoadingData = false;

              // Load team logos for soccer
              _loadTeamLogos();

              // Update tab availability based on data
              _updateTabAvailability();
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
        print('[BetSelection] No odds data available, creating basic game data');
        setState(() {
          // Create basic GameModel even without odds
          if (_homeTeam != null && _awayTeam != null) {
            _gameData = GameModel(
              id: widget.gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
              sport: widget.sport.toUpperCase(),
              homeTeam: _homeTeam!,
              awayTeam: _awayTeam!,
              gameTime: DateTime.now(),
              status: 'scheduled',
              league: widget.sport.toUpperCase(),
            );
          }
          _isLoadingData = false;
        });
      }
    } catch (e, stackTrace) {
      print('[BetSelection] Error: $e');
      print('[BetSelection] Stack trace: $stackTrace');
      if (widget.sport.toUpperCase().contains('NFL') || widget.sport.toUpperCase().contains('FOOTBALL')) {
        _loadMockFootballData();
      } else {
        setState(() {
          // Create basic GameModel even in error case
          if (_homeTeam != null && _awayTeam != null) {
            _gameData = GameModel(
              id: widget.gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
              sport: widget.sport.toUpperCase(),
              homeTeam: _homeTeam!,
              awayTeam: _awayTeam!,
              gameTime: DateTime.now(),
              status: 'scheduled',
              league: widget.sport.toUpperCase(),
            );
          }
          _isLoadingData = false;
        });
      }
    }
  }
  
  double _convertToAmericanOdds(double odds) {
    // Check if odds are already in American format
    // American odds are typically > 100 or < -100, or very close to -100 to +100
    // Decimal odds are typically between 1.0 and 10.0
    
    print('[BetSelection] _convertToAmericanOdds input: $odds');
    
    // If odds are already American (large positive or negative values)
    if (odds >= 100 || odds <= -100) {
      print('[BetSelection] Odds appear to be already in American format, returning as-is');
      return odds;
    }
    
    // If odds are between -100 and 100 but not close to 0, likely American
    if (odds > -100 && odds < 100 && odds != 0) {
      // Check if it looks like a decimal odd (1.x to 9.x range)
      if (odds >= 1.0 && odds <= 10.0) {
        print('[BetSelection] Odds appear to be decimal format, converting...');
        // This is likely decimal odds, convert it
        if (odds >= 2.0) {
          return (odds - 1) * 100;
        } else {
          return -100 / (odds - 1);
        }
      } else {
        // Odds between -100 and 100 but not in decimal range, likely American
        print('[BetSelection] Small American odds, returning as-is');
        return odds;
      }
    }
    
    // Default: treat as decimal and convert
    print('[BetSelection] Treating as decimal odds, converting...');
    if (odds >= 2.0) {
      return (odds - 1) * 100;
    } else {
      return -100 / (odds - 1);
    }
  }
  
  Future<void> _loadTeamLogos() async {
    // Only load logos for soccer
    if (!widget.sport.toLowerCase().contains('soccer')) {
      return;
    }

    try {
      // Fetch home team logo
      if (_homeTeam != null) {
        final homeLogo = await _logoService.getTeamLogo(
          teamName: _homeTeam!,
          sport: widget.sport,
          league: 'EPL', // Default to EPL for now
        );
        if (mounted && homeLogo != null) {
          setState(() {
            _homeTeamLogo = homeLogo;
          });
        }
      }

      // Fetch away team logo
      if (_awayTeam != null) {
        final awayLogo = await _logoService.getTeamLogo(
          teamName: _awayTeam!,
          sport: widget.sport,
          league: 'EPL', // Default to EPL for now
        );
        if (mounted && awayLogo != null) {
          setState(() {
            _awayTeamLogo = awayLogo;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading team logos: $e');
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
    _tabAvailability = {};
    for (var tab in tabOrder) {
      if (tab != 'live') { // Don't track live tab
        _tabPicks[tab] = false;
      }
      // Initialize all tabs as unavailable initially (will be updated when data loads)
      _tabAvailability[tab] = false;
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
  
  String _getTabDisplayName(String tabKey) {
    switch (tabKey) {
      case 'winner':
        return 'Winner';
      case 'spread':
        return 'Spread';
      case 'totals':
        return 'Totals';
      case 'props':
        return 'Props';
      case 'live':
        return 'Live';
      case 'method':
        return 'Method';
      case 'rounds':
        return 'Rounds';
      case 'match':
        return 'Match';
      case 'sets':
        return 'Sets';
      case 'games':
        return 'Games';
      case 'main':
        return 'Main';
      default:
        return tabKey;
    }
  }
  
  void _onTabChanged() {
    // Track which tab user is currently on
    // Skip to next available tab if current tab is unavailable
    final tabOrder = _getTabOrder();
    if (_betTypeController.index >= tabOrder.length) return;
    
    final currentTab = tabOrder[_betTypeController.index];
    
    // Update current tab name for bet slip display
    setState(() {
      _currentTabName = _getTabDisplayName(currentTab);
    });
    
    if (_tabAvailability[currentTab] == false) {
      // Find next available tab
      for (int i = _betTypeController.index + 1; i < tabOrder.length; i++) {
        if (_tabAvailability[tabOrder[i]] == true) {
          _betTypeController.animateTo(i);
          return;
        }
      }
      // If no available tabs forward, check backwards
      for (int i = _betTypeController.index - 1; i >= 0; i--) {
        if (_tabAvailability[tabOrder[i]] == true) {
          _betTypeController.animateTo(i);
          return;
        }
      }
    }
    
    setState(() {});
  }
  
  void _updateTabAvailability() {
    // Update availability based on what data we have
    _tabAvailability['winner'] = _oddsData?.homeMoneyline != null && _oddsData?.awayMoneyline != null;
    _tabAvailability['spread'] = _oddsData?.spread != null;
    _tabAvailability['totals'] = _oddsData?.totalPoints != null;
    _tabAvailability['props'] = _propsData != null && _propsData!.playersByName.isNotEmpty;
    _tabAvailability['live'] = _isLiveBetting;
    
    // For combat sports
    _tabAvailability['method'] = false; // Not available from API yet
    _tabAvailability['rounds'] = false; // Not available from API yet
    
    // Log availability
    print('[BetSelection] Tab availability: $_tabAvailability');
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
              style: TextStyle(fontSize: 11, color: AppTheme.surfaceBlue.withOpacity(0.6)),
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
                color: AppTheme.errorPink,
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
                color: _gameStartCountdown.inMinutes < 30 ? AppTheme.warningAmber : AppTheme.neonGreen,
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
        tabs: [
          Tab(
            child: Text(
              'Winner',
              style: TextStyle(
                color: _tabAvailability['winner'] == false ? AppTheme.surfaceBlue : null,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Spread',
              style: TextStyle(
                color: _tabAvailability['spread'] == false ? AppTheme.surfaceBlue : null,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Totals',
              style: TextStyle(
                color: _tabAvailability['totals'] == false ? AppTheme.surfaceBlue : null,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Props',
              style: TextStyle(
                color: _tabAvailability['props'] == false ? AppTheme.surfaceBlue : null,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Live',
              style: TextStyle(
                color: _tabAvailability['live'] == false ? AppTheme.surfaceBlue : null,
              ),
            ),
          ),
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
                  _awayTeamLogo,
                ),
                Column(
                  children: [
                    const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_oddsData?.totalPoints != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBlue,
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
                  _homeTeamLogo,
                ),
              ],
            ),
          ] else ...[  
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
              ),
              child: const Text(
                'Game data not available',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.warningAmber,
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
          colors: [AppTheme.errorPink.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.sports_mma, size: 32, color: AppTheme.errorPink),
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
                color: AppTheme.warningAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Fighter data loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningAmber,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeamInfo(String team, String abbreviation, Color color, String odds, TeamLogoData? logoData) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.surfaceBlue,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Show logo if available, otherwise show abbreviation
          logoData != null && logoData.logoUrl.isNotEmpty
              ? Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: logoData.logoUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => CircleAvatar(
                        radius: 25,
                        backgroundColor: color,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
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
                    ),
                  ),
                )
              : CircleAvatar(
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
              color: AppTheme.surfaceBlue,
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
            color: isSelected ? color : AppTheme.surfaceBlue,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.person, size: 32),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(nickname, style: TextStyle(fontSize: 10, color: AppTheme.surfaceBlue.withOpacity(0.6))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                odds,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMoneylineTab() {
    print('[BetSelection] Building Moneyline Tab');
    print('[BetSelection]   _oddsData: ${_oddsData != null ? "EXISTS" : "NULL"}');
    if (_oddsData != null) {
      print('[BetSelection]   homeMoneyline: ${_oddsData!.homeMoneyline}');
      print('[BetSelection]   awayMoneyline: ${_oddsData!.awayMoneyline}');
    }
    
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
            AppTheme.warningAmber,
            BetType.total,
            'Over ${_oddsData!.totalPoints}',
          ),
          _buildBetCard(
            'Under ${_oddsData!.formatTotal(_oddsData!.totalPoints)}',
            _oddsData!.formatMoneyline(_oddsData!.underOdds ?? -110),
            'Combined score under ${_oddsData!.totalPoints}',
            AppTheme.primaryCyan,
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
    // Load props on first access only if not already loaded from main data load
    if (_propsData == null && !_isLoadingProps && !_hasAttemptedPropsLoad && widget.gameId != null && !_isLoadingData) {
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
      // Check Firestore cache first
      final cacheService = PropsCacheService();
      final cachedProps = await cacheService.getCachedProps(widget.gameId!);
      
      if (cachedProps != null) {
        print('[BetSelection] Using cached props data');
        if (mounted) {
          setState(() {
            _propsData = cachedProps;
            _isLoadingProps = false;
          });
        }
        return;
      }
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
        
        // Check available markets across all bookmakers
        final allMarkets = <String>{};
        final propMarkets = <String>{};
        
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] as List? ?? [];
          for (final market in markets) {
            final key = market['key'] as String;
            allMarkets.add(key);
            if (key.startsWith('player_') || key.startsWith('batter_') || key.startsWith('pitcher_')) {
              propMarkets.add(key);
            }
          }
        }
        
        print('[BetSelection] Total markets found: ${allMarkets.toList()}');
        print('[BetSelection] Prop markets found: ${propMarkets.toList()}');
        
        // Parse props data from bookmakers
        final propsData = _parsePropsFromBookmakers(
          bookmakers,
          _homeTeam ?? 'Home',
          _awayTeam ?? 'Away',
        );
        
        print('[BetSelection] Parsed ${propsData?.playersByName.length ?? 0} players with props');
        
        if (mounted) {
          setState(() {
            _propsData = propsData;
            _isLoadingProps = false;
          });
          
          // Cache the props data
          if (propsData != null && eventOdds != null) {
            final commenceTime = eventOdds['commence_time'];
            final isLive = commenceTime != null 
              ? DateTime.now().isAfter(DateTime.parse(commenceTime))
              : false;
            await cacheService.cacheProps(widget.gameId!, propsData, isLive);
          }
        }
      } else {
        print('[BetSelection] No props data - eventOdds: ${eventOdds != null}, bookmakers: ${eventOdds?['bookmakers'] != null}');
        if (mounted) {
          setState(() => _isLoadingProps = false);
        }
      }
    } catch (e, stackTrace) {
      print('[BetSelection] Props error: $e');
      print('[BetSelection] Stack trace: $stackTrace');
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
            line: outcome['point'] is num ? (outcome['point'] as num).toDouble() : null,
            overOdds: outcome['name'].toString().contains('Over') 
                ? (outcome['price'] is num ? (outcome['price'] as num).toInt() : null) : null,
            underOdds: outcome['name'].toString().contains('Under') 
                ? (outcome['price'] is num ? (outcome['price'] as num).toInt() : null) : null,
            straightOdds: (!outcome['name'].toString().contains('Over') && 
                          !outcome['name'].toString().contains('Under')) 
                ? (outcome['price'] is num ? (outcome['price'] as num).toInt() : null) : null,
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
    if (_propsData == null || _propsData!.playersByName.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_football, size: 64, color: AppTheme.surfaceBlue),
              const SizedBox(height: 16),
              const Text(
                'Player Props Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Props typically become available closer to game time',
                style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Check if this is baseball/MLB and use specialized widget
    final sportUpper = widget.sport.toUpperCase();
    if (sportUpper.contains('MLB') || sportUpper.contains('BASEBALL')) {
      return _buildBaseballPropsContent();
    }
    
    // Use PropsTabContent for other sports to show Over/Under together
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
  
  Widget _buildBaseballPropsContent() {
    // Parse props data into categories for baseball
    final propsByCategory = _parseBaseballProps();
    
    if (propsByCategory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_baseball, size: 64, color: AppTheme.surfaceBlue),
              const SizedBox(height: 16),
              const Text(
                'Baseball Props Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Props data is being loaded',
                style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoEdgeCarousel(
          title: 'Baseball Props',
          description: 'Select category, then line, then Over/Under',
          icon: Icons.sports_baseball,
          onEdgePressed: _navigateToEdge,
          autoScrollDelay: const Duration(seconds: 3),
        ),
        const SizedBox(height: 16),
        BaseballPropsWidget(
          propsByCategory: propsByCategory,
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
                  type: BetType.prop,
                ));
              }
            });
            _saveSelectionsToStorage();
          },
          selectedBetIds: _selectedBets
              .where((bet) => bet.type == BetType.prop)
              .map((bet) => bet.id.replaceFirst('prop_', ''))
              .toSet(),
        ),
      ],
    );
  }
  
  Map<String, List<PropOption>> _parseBaseballProps() {
    if (_propsData == null) return {};
    
    final propsByCategory = <String, List<PropOption>>{};
    
    // Group all props by their market key (category)
    for (final player in _propsData!.playersByName.values) {
      for (final prop in player.props) {
        if (!propsByCategory.containsKey(prop.marketKey)) {
          propsByCategory[prop.marketKey] = [];
        }
        propsByCategory[prop.marketKey]!.add(prop);
      }
    }
    
    return propsByCategory;
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
            Icon(Icons.timer, size: 64, color: AppTheme.surfaceBlue),
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
              style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
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
            color: AppTheme.errorPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.errorPink.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.live_tv, color: AppTheme.errorPink, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE - Odds update every 30 seconds',
                  style: TextStyle(fontSize: 12, color: AppTheme.errorPink, fontWeight: FontWeight.bold),
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
              AppTheme.errorPink,
              BetType.live,
              'live_${_awayTeam ?? "Away"}_ML',
            ),
            _buildBetCard(
              '${_homeTeam ?? "Home"} to Win (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.homeMoneyline),
              'Live moneyline odds',
              AppTheme.errorPink,
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
              AppTheme.warningAmber,
              BetType.live,
              'live_${_awayTeam ?? "Away"}_spread',
            ),
            _buildBetCard(
              '${_homeTeam ?? "Home"} ${_oddsData!.formatSpread(_oddsData!.spread, isHome: true)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.spreadHomeOdds ?? -110),
              'Live spread betting',
              AppTheme.warningAmber,
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
              AppTheme.neonGreen,
              BetType.live,
              'live_Over_${_oddsData!.totalPoints}',
            ),
            _buildBetCard(
              'Under ${_oddsData!.formatTotal(_oddsData!.totalPoints)} (LIVE)',
              _oddsData!.formatMoneyline(_oddsData!.underOdds ?? -110),
              'Live total points',
              AppTheme.primaryCyan,
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
                  colors: [AppTheme.warningAmber, AppTheme.warningAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningAmber.withOpacity(0.5),
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
                          color: AppTheme.errorPink,
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
                          color: AppTheme.primaryCyan,
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
              color: AppTheme.surfaceBlue,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.surfaceBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.surfaceBlue.withOpacity(0.6),
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
    
    // Extract team name from title for logo display
    String teamName = title;
    if (title.contains(' to Win')) {
      teamName = title.replaceAll(' to Win', '');
    } else if (title.contains(' ML')) {
      teamName = title.replaceAll(' ML', '');
    } else if (title.contains('+') || title.contains('-')) {
      // For spread bets, extract team name before the spread
      final parts = title.split(RegExp(r'[+-]'));
      if (parts.isNotEmpty) {
        teamName = parts[0].trim();
      }
    }
    
    // Use TeamBetCard for team-based bets
    if (type == BetType.moneyline || type == BetType.spread) {
      return team_card.TeamBetCard(
        teamName: teamName,
        sport: widget.sport,
        title: title,
        odds: odds,
        description: description,
        color: color,
        type: team_card.BetType.values[type.index],
        betId: betId,
        isSelected: isSelected,
        wasAlreadyPlaced: wasAlreadyPlaced,
        isPremium: isPremium,
        onTap: wasAlreadyPlaced ? () {} : () async {
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
      );
    }
    
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
            ? AppTheme.neonGreen 
            : isSelected 
              ? color.withOpacity(0.8)
              : AppTheme.surfaceBlue.withOpacity(0.2),
          width: wasAlreadyPlaced || isSelected ? 2.5 : 1,
        ),
        boxShadow: isSelected || wasAlreadyPlaced ? [
          BoxShadow(
            color: (wasAlreadyPlaced ? AppTheme.neonGreen : color).withOpacity(0.2),
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
            ? AppTheme.neonGreen.withOpacity(0.05)
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
                  ? (wasAlreadyPlaced ? AppTheme.neonGreen : color)
                  : color.withOpacity(0.15),
                border: Border.all(
                  color: isSelected || wasAlreadyPlaced 
                    ? (wasAlreadyPlaced ? AppTheme.neonGreen : color)
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
                    color: wasAlreadyPlaced ? AppTheme.neonGreen : color,
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
            color: wasAlreadyPlaced ? AppTheme.neonGreen : null,
          ),
        ),
        subtitle: Text(
          description, 
          style: TextStyle(
            fontSize: 12,
            color: wasAlreadyPlaced 
              ? AppTheme.neonGreen.withOpacity(0.7)
              : null,
          ),
        ),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: wasAlreadyPlaced 
                ? [AppTheme.neonGreen, AppTheme.neonGreen.withOpacity(0.8)]
                : isSelected 
                  ? [color, color.withOpacity(0.8)]
                  : Theme.of(context).brightness == Brightness.dark
                    ? [Colors.white, Colors.white.withOpacity(0.9)]
                    : [AppTheme.primaryCyan, AppTheme.primaryCyan.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: wasAlreadyPlaced 
                  ? AppTheme.neonGreen.withOpacity(0.4)
                  : isSelected 
                    ? color.withOpacity(0.4)
                    : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.3)
                      : AppTheme.primaryCyan.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            odds,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isSelected || wasAlreadyPlaced || Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : AppTheme.deepBlue,
              letterSpacing: 0.5,
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
          color: AppTheme.surfaceBlue,
          border: Border(top: BorderSide(color: AppTheme.surfaceBlue!)),
        ),
        child: const Center(
          child: Text(
            'Select bets to add to your slip',
            style: TextStyle(color: AppTheme.surfaceBlue),
          ),
        ),
      );
    }
    
    // Show minimized view if minimized
    if (_isBetSlipMinimized) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isBetSlipMinimized = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: AppTheme.surfaceBlue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedBets.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bet Slip • $_currentTabName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white,
              ),
            ],
          ),
        ),
      );
    }
    
    final isParlay = _selectedBets.length > 1;
    final totalOdds = _calculateParlayOdds();
    final potentialPayout = _calculatePayout(totalOdds);
    
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // Allow swipe down to minimize
        if (details.delta.dy > 5) {
          setState(() {
            _isBetSlipMinimized = true;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppTheme.surfaceBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isParlay ? 'Parlay (${_selectedBets.length} legs)' : 'Single Bet',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Current Tab: $_currentTabName',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.surfaceBlue.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isParlay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen,
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () {
                        setState(() {
                          _isBetSlipMinimized = true;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
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
                    child: const Icon(Icons.close, size: 16, color: AppTheme.errorPink),
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
                          border: Border.all(color: AppTheme.surfaceBlue!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '50',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$potentialPayout BR',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonGreen,
                          ),
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
      ),
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
    // Check the current _selectedBets list instead of _allTabBets
    return _selectedBets.isNotEmpty;
  }
  
  // Get all bets from all tabs
  List<SelectedBet> _getAllBets() {
    // Return the current _selectedBets which contains all selections
    return List.from(_selectedBets);
  }
  
  // Show bet confirmation bottom sheet
  void _showBetConfirmationSheet() {
    final allBets = _getAllBets();
    if (allBets.isEmpty) return;
    
    final totalWager = _wagerAmount * allBets.length;
    final totalOdds = _calculateTotalOdds(allBets);
    final potentialPayout = (totalWager * totalOdds).round();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepBlue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confirm Your Bets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Bet details
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...allBets.map((bet) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(bet.title),
                      subtitle: Text('Odds: ${bet.odds}'),
                      trailing: Text(
                        '$_wagerAmount BR',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                  // Summary card
                  Card(
                    color: AppTheme.neonGreen.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Selections:'),
                              Text(
                                '${allBets.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Wager:'),
                              Text(
                                '$totalWager BR',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Potential Payout:'),
                              Text(
                                '$potentialPayout BR',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.neonGreen,
                                  fontSize: 18,
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
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLockingBets ? null : () {
                    Navigator.pop(context);
                    _lockInBets();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm & Place Bets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      
      // Save bets to local storage - always save regardless of poolId/gameId
      // Use the generated gameId if widget.gameId is not available
      final actualGameId = widget.gameId ?? gameId;
      final actualPoolId = widget.poolId ?? 'default_pool_${widget.poolName.replaceAll(' ', '_').toLowerCase()}';
      
      final userBets = allBets.map((bet) => UserBet(
        id: DateTime.now().millisecondsSinceEpoch.toString() + bet.id,
        poolId: actualPoolId,
        poolName: widget.poolName,
        gameId: actualGameId,
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
      debugPrint('Saved ${userBets.length} bets to storage with poolId: $actualPoolId and gameId: $actualGameId');
      
      debugPrint('Bets locked in successfully! Potential payout: $potentialPayout BR');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bets locked in! Potential payout: $potentialPayout BR'),
            backgroundColor: AppTheme.neonGreen,
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
            backgroundColor: AppTheme.errorPink,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 24),
                const SizedBox(width: 8),
                const Text('Bet Placed!'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(context),
            ),
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
              Text(
                '💡 Try ${_getTabDisplayName(_getTabOrder()[nextTabIndex])} next for more betting options!',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
            child: Text(nextTabIndex != -1 ? 'Next: ${_getTabDisplayName(_getTabOrder()[nextTabIndex])}' : 'Continue'),
          ),
        ],
      ),
    );
  }
  
  int _getNextUnpickedTab() {
    // Map tab indices to pick status
    final tabOrder = _getTabOrder();
    
    // Only check non-live tabs that are available (exclude 'live' tab and unavailable tabs)
    for (int i = 0; i < tabOrder.length && i < _betTypeController.length; i++) {
      final tabKey = tabOrder[i];
      // Skip live tab, unavailable tabs, and tabs that already have picks
      if (tabKey != 'live' && 
          (_tabAvailability[tabKey] ?? false) && 
          !(_tabPicks[tabKey] ?? false)) {
        return i;
      }
    }
    return -1; // All available tabs have picks
  }
  
  Widget _buildProgressIndicator() {
    // Count only available tabs (exclude live and unavailable tabs)
    final tabOrder = _getTabOrder();
    int availableTabCount = 0;
    int pickedAvailableCount = 0;
    
    for (final tabKey in tabOrder) {
      if (tabKey != 'live' && (_tabAvailability[tabKey] ?? false)) {
        availableTabCount++;
        if (_tabPicks[tabKey] ?? false) {
          pickedAvailableCount++;
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress: $pickedAvailableCount of $availableTabCount picks made',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: availableTabCount > 0 ? pickedAvailableCount / availableTabCount : 0,
          backgroundColor: AppTheme.surfaceBlue,
          valueColor: AlwaysStoppedAnimation<Color>(
            pickedAvailableCount == availableTabCount ? AppTheme.neonGreen : Theme.of(context).colorScheme.primary,
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
          color: isPicked ? AppTheme.neonGreen : AppTheme.surfaceBlue,
          size: 20,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isPicked ? AppTheme.neonGreen : AppTheme.surfaceBlue,
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
            Icon(Icons.emoji_events, color: AppTheme.warningAmber, size: 28),
            SizedBox(width: 8),
            Text('All Picks Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              color: AppTheme.warningAmber,
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
        color: AppTheme.primaryCyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryCyan, size: 28),
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
                        color: AppTheme.primaryCyan,
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
                    color: AppTheme.surfaceBlue,
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
        color: pickedCount == totalTabs ? AppTheme.neonGreen : AppTheme.warningAmber,
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
                    color: AppTheme.deepBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLockingBets ? null : _showBetConfirmationSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
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