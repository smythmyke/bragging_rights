import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../services/optimized_games_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/wallet_service.dart';
import '../../services/card_service.dart';
import 'package:intl/intl.dart';
import '../pools/pool_selection_screen.dart';
import '../cards/card_inventory_screen.dart';
import '../../widgets/bragging_rights_logo.dart';
import '../../data/card_definitions.dart';

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
      
      final games = result['games'] as List<GameModel>;
      final allSports = result['allSports'] as List<String>;
      
      // Organize games by sport
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
      
      // Use all sports that have games available (not just featured)
      _availableSports = allSports.map((s) => s.toLowerCase()).toList()..sort();
      debugPrint('OptimizedGamesScreen: Available sports: $_availableSports');
      
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
    final result = await _gamesService.loadFeaturedGames(forceRefresh: true);
    await _loadInitialData();
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
      
      // Load ALL games for this sport without date limit
      final allGames = await _gamesService.loadAllGamesForSport(sport);
      
      if (mounted) {
        setState(() {
          _gamesBySport[sport] = allGames;
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
    if (_selectedSport == null || _selectedSport == 'all') {
      return _featuredGames;
    }
    return _gamesBySport[_selectedSport] ?? [];
  }
  
  Future<void> _onGameTap(GameModel game) async {
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
        return PhosphorIconsRegular.football;
      case 'NBA':
        return PhosphorIconsRegular.basketball;
      case 'MLB':
        return PhosphorIconsRegular.baseball;
      case 'NHL':
        return PhosphorIconsRegular.hockey;
      case 'MMA':
      case 'UFC':
        debugPrint('  -> MMA/UFC detected, using hand fist icon');
        return PhosphorIconsRegular.handFist; // Different icon for MMA
      case 'BOXING':
        debugPrint('  -> Boxing detected, using boxing glove icon');
        return PhosphorIconsRegular.boxingGlove;
      case 'TENNIS':
        return Icons.sports_tennis;
      case 'SOCCER':
        return PhosphorIconsRegular.soccerBall;
      default:
        debugPrint('  -> Unknown sport, using trophy icon');
        return PhosphorIconsRegular.trophy;
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
      child: InkWell(
        onTap: () => _onGameTap(game),
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
                          Text(
                            game.league!, // Event name (UFC 311, Boxing Card, etc.)
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.mainEventFighters ?? '${game.awayTeam} vs ${game.homeTeam}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (game.totalFights != null && game.totalFights! > 1) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${game.totalFights} fights on card',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
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
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Align(
            alignment: Alignment.centerLeft,
            child: const BraggingRightsLogo(
              height: 100,
              showUnderline: true,
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
            // Power Cards Indicators
            StreamBuilder<UserCardInventory>(
              stream: _cardService.getUserCardInventory(),
              builder: (context, snapshot) {
                final inventory = snapshot.data ?? UserCardInventory.empty();
                
                return Row(
                  children: [
                    // Offensive Cards
                    _buildCardIndicatorWithIcon(
                      icon: PhosphorIconsDuotone.lightning,
                      count: inventory.offensiveCount,
                      type: CardType.offensive,
                      context: context,
                    ),
                    const SizedBox(width: 4),
                    // Defensive Cards
                    _buildCardIndicatorWithIcon(
                      icon: PhosphorIconsDuotone.castleTurret,
                      count: inventory.defensiveCount,
                      type: CardType.defensive,
                      context: context,
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
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
          bottom: _tabController != null && _availableSports.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  const Tab(text: 'All'),
                  ..._availableSports.map((sport) => Tab(
                    text: sport.toUpperCase(),
                  )),
                ],
                onTap: (index) async {
                  if (index == 0) {
                    // "All" tab - use featured games
                    setState(() {
                      _selectedSport = null;
                    });
                  } else {
                    // Specific sport tab - load ALL games for that sport
                    final sport = _availableSports[index - 1];
                    debugPrint('Tab selected: $sport (index $index)');
                    setState(() {
                      _selectedSport = sport;
                      _loadingMore = true;
                    });

                    // Load ALL games for this sport (not just 14 days)
                    await _loadAllGamesForSport(sport);
                  }
                },
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _featuredGames.isEmpty
                  ? Center(
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
                            'No games available',
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
}