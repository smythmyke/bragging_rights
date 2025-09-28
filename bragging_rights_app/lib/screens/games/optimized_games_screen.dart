import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../services/optimized_games_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/wallet_service.dart';
import '../../models/victory_coin_model.dart';
import '../../services/card_service.dart';
import 'package:intl/intl.dart';
import '../pools/pool_selection_screen.dart';
import '../cards/card_inventory_screen.dart';
import '../../data/card_definitions.dart';
import '../../widgets/bragging_rights_logo.dart';

/// Optimized games screen with lazy loading and smart fetching
class OptimizedGamesScreen extends StatefulWidget {
  const OptimizedGamesScreen({Key? key}) : super(key: key);

  @override
  State<OptimizedGamesScreen> createState() => _OptimizedGamesScreenState();
}

class _OptimizedGamesScreenState extends State<OptimizedGamesScreen>
    with TickerProviderStateMixin {
  final OptimizedGamesService _gamesService = OptimizedGamesService();
  final UserPreferencesService _prefsService = UserPreferencesService();
  final WalletService _walletService = WalletService();
  final CardService _cardService = CardService();
  final ScrollController _scrollController = ScrollController();
  
  List<GameModel> _featuredGames = [];
  Map<String, List<GameModel>> _gamesBySport = {};
  Map<String, List<GameModel>> _allGamesBySport = {}; // Full 14-day game lists cache
  bool _loading = true;
  bool _loadingMore = false;
  String? _selectedSport;
  TabController? _tabController;
  List<String> _availableSports = [];
  
  @override
  void initState() {
    super.initState();
    debugPrint('OptimizedGamesScreen: initState called');

    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    debugPrint('OptimizedGamesScreen: dispose called - cleaning up resources');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController?.dispose();
    // Cancel any pending async operations
    _gamesService.dispose();
    super.dispose();
    debugPrint('OptimizedGamesScreen: dispose completed');
  }
  
  Future<void> _loadInitialData() async {
    debugPrint('OptimizedGamesScreen: Starting initial data load');
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    try {
      // Load featured games first
      debugPrint('OptimizedGamesScreen: Loading featured games');
      final result = await _gamesService.loadFeaturedGames();
      if (!mounted) return;
      
      final games = result['games'] as List<GameModel>;  // Featured games for display
      final allGamesMap = result['allGamesMap'] as Map<String, List<GameModel>>?;  // Full game lists by sport
      final allSports = result['allSports'] as List<String>;

      // Organize featured games by sport (for featured "All Sports" view)
      _gamesBySport.clear();
      for (final game in games) {
        final sport = game.sport.toLowerCase();
        debugPrint('Adding game to sport category: "${game.sport}" -> "$sport"');
        if (game.sport.toUpperCase() == 'MMA' || game.sport.toUpperCase() == 'BOXING') {
          debugPrint('  Combat sport event: ${game.league ?? "Unknown"} - ${game.awayTeam} vs ${game.homeTeam}');
        }
        _gamesBySport[sport] ??= [];
        _gamesBySport[sport]!.add(game);
      }

      // Store ALL games by sport for caching (from full 14-day window)
      _allGamesBySport.clear();
      if (allGamesMap != null) {
        allGamesMap.forEach((sport, gamesList) {
          _allGamesBySport[sport.toLowerCase()] = gamesList;
          debugPrint('Total ${sport} games in 14-day window: ${gamesList.length}');
        });
      }

      // Always show ALL supported sports, regardless of whether they have games
      // This ensures Boxing and other sports are always visible
      _availableSports = ['nfl', 'nba', 'nhl', 'mlb', 'boxing', 'mma', 'soccer'];
      debugPrint('OptimizedGamesScreen: Available sports: $_availableSports (showing all supported sports)');
      
      // Initialize tab controller with actual sports found
      if (_availableSports.isNotEmpty && mounted) {
        _tabController = TabController(
          length: _availableSports.length + 1, // +1 for "All" tab
          vsync: this,
        );
      }
      
      if (mounted) {
        setState(() {
          _featuredGames = games;
          _loading = false;
        });
      }
      
      debugPrint('✅ OptimizedGamesScreen: Loaded ${games.length} featured games');
    } catch (e) {
      debugPrint('❌ OptimizedGamesScreen: Error loading initial data: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading games. Pull to refresh.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadInitialData,
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _onRefresh() async {
    // If a sport is selected, refresh that sport's games
    if (_selectedSport != null && _selectedSport != 'all') {
      setState(() => _loadingMore = true);
      await _loadAllGamesForSport(_selectedSport!);
      setState(() => _loadingMore = false);
    } else {
      // Otherwise refresh all featured games
      await _gamesService.loadFeaturedGames(forceRefresh: true);
      await _loadInitialData();
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGames();
    }
  }
  
  Future<void> _loadMoreGames() async {
    if (_loadingMore || _selectedSport == null) return;
    
    setState(() => _loadingMore = true);
    
    try {
      final currentGames = _gamesBySport[_selectedSport] ?? [];
      final moreGames = await _gamesService.loadMoreGames(
        sport: _selectedSport!,
        offset: currentGames.length,
        limit: 10,
      );
      
      if (moreGames.isNotEmpty) {
        setState(() {
          _gamesBySport[_selectedSport]!.addAll(moreGames);
          _featuredGames.addAll(moreGames);
        });
      }
    } catch (e) {
      debugPrint('Error loading more games: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }
  
  Future<void> _loadAllGamesForSport(String sport) async {
    try {
      debugPrint('Loading ALL games for $sport...');

      // First check if we have the full list in _allGamesBySport
      if (_allGamesBySport[sport] != null && _allGamesBySport[sport]!.isNotEmpty) {
        // Use the cached full list from initial load
        debugPrint('Using cached full list for $sport: ${_allGamesBySport[sport]!.length} games');
        if (mounted) {
          setState(() {
            _gamesBySport[sport] = _allGamesBySport[sport]!;
            _loadingMore = false;
          });
        }
        return;
      }

      // Otherwise load ALL games for this sport (still within 14-day window from the service)
      final allGames = await _gamesService.loadAllGamesForSport(sport);

      if (mounted) {
        setState(() {
          _gamesBySport[sport] = allGames;
          _allGamesBySport[sport] = allGames;  // Also update the full list
          _loadingMore = false;
        });

        debugPrint('Loaded ${allGames.length} $sport games');

        // Check if Canelo vs Crawford is in the list
        if (sport.toLowerCase() == 'boxing') {
          for (final game in allGames) {
            if (game.homeTeam.toLowerCase().contains('canelo') ||
                game.awayTeam.toLowerCase().contains('crawford')) {
              debugPrint('✅ FOUND CANELO VS CRAWFORD IN UI: ${game.awayTeam} vs ${game.homeTeam}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading all games for $sport: $e');
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading $sport games')),
        );
      }
    }
  }
  
  List<GameModel> _getFilteredGames() {
    if (_selectedSport == null) {
      return [];  // No sport selected yet
    }
    if (_selectedSport == 'all') {
      return _featuredGames;  // All sports selected
    }
    return _gamesBySport[_selectedSport] ?? [];
  }
  
  Future<void> _onGameTap(GameModel game) async {
    debugPrint('🎮 Game card tapped:');
    debugPrint('  - Sport: ${game.sport}');
    debugPrint('  - Game: ${game.awayTeam} vs ${game.homeTeam}');
    debugPrint('  - Game ID: ${game.id}');

    // Additional logging for MMA events
    if (game.sport == 'MMA') {
      debugPrint('  📍 MMA Event Details:');
      debugPrint('    - Event Name: ${game.eventName}');
      debugPrint('    - Main Event Fighters: ${game.mainEventFighters}');
      debugPrint('    - League/Promotion: ${game.league}');
      debugPrint('    - Total Fights: ${game.totalFights ?? 0}');
      debugPrint('    - Has Fights List: ${game.fights != null ? game.fights!.length : 0} fights');
    }

    debugPrint('  - Navigating to /game-details');

    // Navigate to game details page
    Navigator.pushNamed(
      context,
      '/game-details',
      arguments: {
        'gameId': game.id,
        'sport': game.sport,
        'gameData': game,
      },
    );
  }

  Future<void> _onViewPoolsTap(GameModel game) async {
    debugPrint('🎯 View Pools button tapped:');
    debugPrint('  - Sport: ${game.sport}');
    debugPrint('  - Game: ${game.awayTeam} vs ${game.homeTeam}');
    debugPrint('  - Navigating to /pool-selection');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Enrich this specific game with odds on-demand
      await _gamesService.enrichGameOnDemand(game.id);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to pool selection
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PoolSelectionScreen(
              gameId: game.id,
              gameTitle: '${game.awayTeam} @ ${game.homeTeam}',
              sport: game.sport,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading game details: $e')),
        );
      }
    }
  }
  
  IconData _getSportIcon(String sport) {
    debugPrint('Getting icon for sport: "$sport"');
    switch (sport.toUpperCase()) {
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
        debugPrint('  -> MMA/UFC detected, using sports_mma icon');
        return Icons.sports_mma;
      case 'BOXING':
        debugPrint('  -> Boxing detected, using sports_mma icon');
        return Icons.sports_mma;
      case 'TENNIS':
        return Icons.sports_tennis;
      case 'SOCCER':
        return Icons.sports_soccer;
      default:
        debugPrint('  -> Unknown sport, using sports icon');
        return Icons.sports;
    }
  }
  
  Color _getSportColor(String sport) {
    switch (sport.toUpperCase()) {
      case 'NFL':
        return Colors.blue;
      case 'NBA':
        return Colors.orange;
      case 'NHL':
        return Colors.cyan;
      case 'MLB':
        return Colors.red;
      case 'MMA':
      case 'UFC':
        return Colors.redAccent;  // Bright red-orange for excellent visibility
      case 'BOXING':
        return Colors.amber;
      case 'TENNIS':
        return Colors.green;
      case 'SOCCER':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getPromotionColor(String promotion) {
    switch (promotion.toUpperCase()) {
      case 'UFC':
        return Colors.red;
      case 'PFL':
        return Colors.blue;
      case 'BELLATOR':
        return Colors.orange;
      case 'ONE':
        return Colors.purple;
      case 'BOXING':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildSportCard(String sport, {bool isAllSports = false}) {
    final sportUpper = sport.toUpperCase();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          if (isAllSports) {
            setState(() {
              _selectedSport = 'all';  // Set to 'all' instead of null for All Sports
            });
          } else {
            setState(() {
              _selectedSport = sport.toLowerCase();
              _loadingMore = true;
            });
            await _loadAllGamesForSport(sport.toLowerCase());
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAllSports
                  ? [Colors.purple.shade400, Colors.purple.shade700]
                  : [
                      _getSportColor(sportUpper).withOpacity(0.8),
                      _getSportColor(sportUpper),
                    ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Icon(
                    isAllSports ? Icons.sports : _getSportIcon(sportUpper),
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    isAllSports ? 'ALL SPORTS' : sportUpper,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSportSelectionGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Sport',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review events by all sports',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,  // Increased from 1.2 to give more height
              children: [
                _buildSportCard('all', isAllSports: true),
                ..._availableSports.map((sport) => _buildSportCard(sport)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameModel game) {
    final bool isLive = game.isLive;
    final bool hasStarted = game.isFinal || isLive;
    final timeFormat = DateFormat('h:mm a');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isLive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLive 
            ? BorderSide(color: Colors.red.shade400, width: 2)
            : BorderSide.none,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('===== INKWELL TAP DETECTED =====');
            debugPrint('Game: ${game.awayTeam} vs ${game.homeTeam}');
            _onGameTap(game);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header with sport and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSportColor(game.sport).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSportIcon(game.sport),
                          size: 16,
                          color: _getSportColor(game.sport),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          game.sport.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getSportColor(game.sport),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!hasStarted)
                    Text(
                      timeFormat.format(game.gameTime),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Teams and scores
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show event title for combat sports, regular matchup for others
                        if (game.isCombatSport && game.league != null) ...[
                          // Promotion and Event Name
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getPromotionColor(game.league!).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  game.league!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getPromotionColor(game.league!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateForDisplay(game.gameTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Event Name if available
                          if (game.eventName != null) ...[
                            Text(
                              game.eventName!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          // Main Event Fighters
                          Text(
                            game.mainEventFighters ?? '${game.awayTeam} vs ${game.homeTeam}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (game.totalFights != null && game.totalFights! > 1) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.sports_mma,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${game.totalFights} fights on card',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          Text(
                            game.awayTeam,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            game.homeTeam,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasStarted)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${game.awayScore ?? 0}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: (game.awayScore ?? 0) > (game.homeScore ?? 0)
                                ? Colors.green
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${game.homeScore ?? 0}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: (game.homeScore ?? 0) > (game.awayScore ?? 0)
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (game.venue != null) ...[
                const SizedBox(height: 8),
                Text(
                  game.venue!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Add Enter Pool button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Stop propagation by handling the tap here
                    _onViewPoolsTap(game);
                  },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Enter Pool',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Align(
            alignment: Alignment.centerLeft,
            child: BraggingRightsLogo(
              height: 40,
              showUnderline: false,
            ),
          ),
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              debugPrint('OptimizedGamesScreen: Back arrow pressed - going back');
              Navigator.of(context).pop();
            },
          ),
          actions: [
            // Victory Coins Display
            InkWell(
              onTap: () {
                Navigator.of(context).pushNamed('/more');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsDuotone.trophy,
                      color: Colors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    StreamBuilder<VictoryCoinModel?>(
                      stream: _walletService.getVCStream(),
                      builder: (context, snapshot) {
                        // Debug logging
                        print('VC StreamBuilder: hasData=${snapshot.hasData}, data=${snapshot.data}, error=${snapshot.error}');

                        if (snapshot.hasError) {
                          print('VC Stream Error: ${snapshot.error}');
                          return const Text(
                            '-- VC',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            '... VC',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        final vcBalance = snapshot.data?.balance ?? 0;
                        print('VC Balance displayed: $vcBalance');

                        return Text(
                          '$vcBalance VC',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // BR Balance Display
            InkWell(
              onTap: () {
                Navigator.of(context).pushNamed('/more');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.coins,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    StreamBuilder<int>(
                      stream: _walletService.getBalanceStream(),
                      builder: (context, snapshot) {
                        final balance = snapshot.data ?? 0;
                        return Text(
                          '$balance',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.bell),
              onPressed: () {
                // TODO: Show notifications
              },
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.gear),
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/preferences');
                if (result == true) {
                  // Refresh games if preferences were changed
                  _loadInitialData();
                }
              },
            ),
          ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selectedSport == null
              ? _buildSportSelectionGrid()
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: Column(
                    children: [
                      // Sport header with back button
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() {
                                  _selectedSport = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _selectedSport == 'all'
                                  ? Icons.sports
                                  : _getSportIcon(_selectedSport!.toUpperCase()),
                              color: _selectedSport == 'all'
                                  ? Colors.purple
                                  : _getSportColor(_selectedSport!.toUpperCase()),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedSport == 'all'
                                  ? 'ALL SPORTS'
                                  : _selectedSport!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (_selectedSport == 'all'
                                    ? Colors.purple
                                    : _getSportColor(_selectedSport!.toUpperCase()))
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_getFilteredGames().length} games',
                                style: TextStyle(
                                  color: _selectedSport == 'all'
                                      ? Colors.purple
                                      : _getSportColor(_selectedSport!.toUpperCase()),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Games list
                      Expanded(
                        child: _getFilteredGames().isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedSport == 'all'
                                          ? Icons.sports
                                          : _getSportIcon(_selectedSport!.toUpperCase()),
                                      size: 64,
                                      color: (_selectedSport == 'all'
                                          ? Colors.purple
                                          : _getSportColor(_selectedSport!.toUpperCase()))
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedSport == 'all'
                                          ? 'No games available'
                                          : 'No ${_selectedSport!.toUpperCase()} games available',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _onRefresh,
                                      child: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _getFilteredGames().length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _getFilteredGames().length) {
                                    if (_loadingMore) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }

                                  final game = _getFilteredGames()[index];
                                  return _buildGameCard(game);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      );
  }

  Widget _buildCardIndicatorWithIcon({
    required IconData icon,
    required int count,
    required CardType type,
    required BuildContext context,
  }) {
    Color iconColor;
    switch (type) {
      case CardType.offensive:
        iconColor = Colors.orange;
        break;
      case CardType.defensive:
        iconColor = Colors.blue;
        break;
      case CardType.special:
        iconColor = Colors.purple;
        break;
    }
    
    return GestureDetector(
      onTap: () {
        // Navigate to card inventory page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardInventoryScreen(cardType: type),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateForDisplay(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();

    // Check if it's today
    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return 'Today ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    }

    // Check if it's tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    if (localDate.year == tomorrow.year &&
        localDate.month == tomorrow.month &&
        localDate.day == tomorrow.day) {
      return 'Tomorrow ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    }

    // Otherwise show month/day
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[localDate.month - 1]} ${localDate.day}';
  }
}