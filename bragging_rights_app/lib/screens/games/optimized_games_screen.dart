import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../services/optimized_games_service.dart';
import '../../services/user_preferences_service.dart';
import 'package:intl/intl.dart';
import '../pools/pool_selection_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  
  List<GameModel> _featuredGames = [];
  Map<String, List<GameModel>> _gamesBySport = {};
  bool _loading = true;
  bool _loadingMore = false;
  String? _selectedSport;
  TabController? _tabController;
  List<String> _userSports = [];
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    
    try {
      // Load user preferences
      final prefs = await _prefsService.getUserPreferences();
      _userSports = prefs.sportsToLoad;
      
      // Initialize tab controller
      _tabController = TabController(
        length: _userSports.length + 1, // +1 for "All" tab
        vsync: this,
      );
      
      // Load featured games
      final games = await _gamesService.loadFeaturedGames();
      
      // Organize games by sport
      _gamesBySport.clear();
      for (final game in games) {
        final sport = game.sport.toLowerCase();
        _gamesBySport[sport] ??= [];
        _gamesBySport[sport]!.add(game);
      }
      
      setState(() {
        _featuredGames = games;
        _loading = false;
      });
      
      debugPrint('✅ Loaded ${games.length} featured games');
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() => _loading = false);
      if (mounted) {
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
    await _gamesService.loadFeaturedGames(forceRefresh: true);
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
      case 'BOXING':
        return PhosphorIconsRegular.boxingGlove;
      case 'TENNIS':
        return Icons.sports_tennis;
      default:
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
        return Colors.purple;
      case 'BOXING':
        return Colors.amber;
      case 'TENNIS':
        return Colors.green;
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
        title: const Text('Games'),
        bottom: _tabController != null && _userSports.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  const Tab(text: 'All'),
                  ..._userSports.map((sport) => Tab(
                    text: sport.toUpperCase(),
                  )),
                ],
                onTap: (index) {
                  setState(() {
                    _selectedSport = index == 0 
                        ? null 
                        : _userSports[index - 1];
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to preferences screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preferences screen coming soon'),
                ),
              );
            },
          ),
        ],
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
}