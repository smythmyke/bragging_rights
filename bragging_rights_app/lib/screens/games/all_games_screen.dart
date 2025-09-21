import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../services/espn_direct_service.dart';
import '../../services/optimized_games_service.dart';
import '../../services/games_service_v2.dart';
import '../../services/bet_tracking_service.dart';
import '../../widgets/bet_placed_ribbon.dart';
import 'package:intl/intl.dart';

class AllGamesScreen extends StatefulWidget {
  final String title;
  final String category; // 'live', 'today', 'tomorrow', 'thisweek', 'nextweek'
  final List<GameModel>? initialGames;

  const AllGamesScreen({
    Key? key,
    required this.title,
    required this.category,
    this.initialGames,
  }) : super(key: key);

  @override
  State<AllGamesScreen> createState() => _AllGamesScreenState();
}

class _AllGamesScreenState extends State<AllGamesScreen> with WidgetsBindingObserver {
  final ESPNDirectService _espnService = ESPNDirectService();
  final GamesServiceV2 _gamesService = GamesServiceV2();
  final BetTrackingService _betTrackingService = BetTrackingService();
  List<GameModel> _games = [];
  Map<String, bool> _betStatuses = {};
  bool _loading = true;
  String? _selectedSport;

  // Define all supported sports
  static const List<String> ALL_SUPPORTED_SPORTS = ['NFL', 'NBA', 'NHL', 'MLB', 'BOXING', 'MMA', 'SOCCER'];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadBetStatuses();

    // Use initialGames if provided, otherwise load fresh data
    if (widget.initialGames != null && widget.initialGames!.isNotEmpty) {
      setState(() {
        _games = widget.initialGames!;
        _loading = false;
      });
      // Still check for fresh data in background
      _loadGamesInBackground();
    } else {
      // Load fresh games based on the category
      _loadGames();
    }
  }

  Future<void> _initializeServices() async {
    await _gamesService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload bet statuses when app comes back to foreground
      _loadBetStatuses();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload bet statuses when returning to this screen
    _loadBetStatuses();
  }

  // Called when the app returns to foreground after navigation
  @override
  Future<void> didPopNext() async {
    // Reload bet statuses when returning from another screen
    await _loadBetStatuses();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBetStatuses() async {
    try {
      debugPrint('[AllGamesScreen] Loading bet statuses...');
      // Load all bet statuses
      await _betTrackingService.loadAllBetStatuses();
      final allStatuses = await _betTrackingService.getAllBetStatuses();

      // Update the bet statuses map
      if (mounted) {
        setState(() {
          _betStatuses = {};
          allStatuses.forEach((gameId, status) {
            if (status.isActive) {
              _betStatuses[gameId] = true;
              debugPrint('[AllGamesScreen] Found active bet for game: $gameId');
            }
          });
          debugPrint('[AllGamesScreen] Total active bets: ${_betStatuses.length}');
        });
      }
    } catch (e) {
      debugPrint('[AllGamesScreen] Error loading bet statuses: $e');
    }
  }
  
  Future<void> _loadGamesInBackground() async {
    // Load fresh games in background without showing loading indicator
    try {
      List<GameModel> games = [];

      // Load games based on category
      debugPrint('📱 Background loading games for category: ${widget.category}');

      switch (widget.category) {
        case 'live':
          games = await _gamesService.getLiveGames();
          break;
        case 'today':
          final todayGames = await _gamesService.getTodayGamesAllSports();
          games = [];
          todayGames.forEach((sport, sportGames) {
            games.addAll(sportGames);
          });
          break;
        case 'tomorrow':
          final futures = <Future<List<GameModel>>>[];
          for (final sport in ALL_SUPPORTED_SPORTS) {
            futures.add(_gamesService.getGamesForPeriod(
              period: 'tomorrow',
              sport: sport,
            ));
          }
          final results = await Future.wait(futures);
          games = results.expand((list) => list).toList();
          break;
        case 'thisweek':
          final futures = <Future<List<GameModel>>>[];
          for (final sport in ALL_SUPPORTED_SPORTS) {
            futures.add(_gamesService.getGamesForPeriod(
              period: 'this week',
              sport: sport,
            ));
          }
          final results = await Future.wait(futures);
          games = results.expand((list) => list).toList();
          break;
        case 'nextweek':
          final futures = <Future<List<GameModel>>>[];
          for (final sport in ALL_SUPPORTED_SPORTS) {
            futures.add(_gamesService.getGamesForPeriod(
              period: 'next week',
              sport: sport,
            ));
          }
          final results = await Future.wait(futures);
          games = results.expand((list) => list).toList();
          break;
        default:
          final featured = await _gamesService.getFeaturedGames();
          games = featured['games'] ?? [];
      }

      // Sort games by time
      games.sort((a, b) => a.gameTime.compareTo(b.gameTime));

      // Update UI only if we have different data
      if (mounted && games.length != _games.length) {
        setState(() {
          _games = games;
        });
      }

      debugPrint('✅ Background loaded ${games.length} games for ${widget.category}');
    } catch (e) {
      debugPrint('❌ Background load error: $e');
    }
  }

  Future<void> _loadGames() async {
    setState(() => _loading = true);

    try {
      List<GameModel> games = [];

      // If a specific sport is selected, only load that sport
      if (_selectedSport != null) {
        debugPrint('🎯 Loading games for selected sport: $_selectedSport');

        // Use the new service for all sports
        games = await _gamesService.getAllGamesForSport(_selectedSport!);
        debugPrint('✅ Loaded ${games.length} $_selectedSport games');
      } else {
        // Load games based on category using the new caching service
        // This ensures we get fresh data based on game timestamps
        debugPrint('📱 Loading games for category: ${widget.category}');

        // Map category to period for the new service
        String period;
        switch (widget.category) {
          case 'live':
            // Get live games across all sports
            games = await _gamesService.getLiveGames();
            break;
          case 'today':
            period = 'today';
            // Get today's games for all sports
            final todayGames = await _gamesService.getTodayGamesAllSports();
            games = [];
            todayGames.forEach((sport, sportGames) {
              games.addAll(sportGames);
            });
            break;
          case 'tomorrow':
            period = 'tomorrow';
            // Get tomorrow's games for all sports
            final futures = <Future<List<GameModel>>>[];
            for (final sport in ALL_SUPPORTED_SPORTS) {
              futures.add(_gamesService.getGamesForPeriod(
                period: period,
                sport: sport,
              ));
            }
            final results = await Future.wait(futures);
            games = results.expand((list) => list).toList();
            break;
          case 'thisweek':
            period = 'this week';
            // Get this week's games for all sports
            final futures = <Future<List<GameModel>>>[];
            for (final sport in ALL_SUPPORTED_SPORTS) {
              futures.add(_gamesService.getGamesForPeriod(
                period: period,
                sport: sport,
              ));
            }
            final results = await Future.wait(futures);
            games = results.expand((list) => list).toList();
            break;
          case 'nextweek':
            period = 'next week';
            // Get next week's games for all sports
            final futures = <Future<List<GameModel>>>[];
            for (final sport in ALL_SUPPORTED_SPORTS) {
              futures.add(_gamesService.getGamesForPeriod(
                period: period,
                sport: sport,
              ));
            }
            final results = await Future.wait(futures);
            games = results.expand((list) => list).toList();
            break;
          default:
            // Get all upcoming games
            final featured = await _gamesService.getFeaturedGames();
            games = featured['games'] ?? [];
        }

        debugPrint('✅ Loaded ${games.length} games for ${widget.category}');
      }

      // Sort games by time
      games.sort((a, b) => a.gameTime.compareTo(b.gameTime));

      setState(() {
        _games = games;
        _loading = false;
      });

      // Reload bet statuses after loading games
      _loadBetStatuses();
    } catch (e) {
      debugPrint('❌ Error loading games: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games: $e')),
        );
      }
    }
  }
  
  List<String> _getAvailableSports() {
    // Always return all supported sports for consistent UI
    return ALL_SUPPORTED_SPORTS;
  }

  List<GameModel> _getFilteredGames() {
    if (_selectedSport == null) return _games;
    return _games.where((game) => game.sport == _selectedSport).toList();
  }

  int _getGamesCountForSport(String sport) {
    return _games.where((game) => game.sport == sport).length;
  }

  Future<void> _loadGamesForSport(String sport) async {
    debugPrint('🔄 Loading games for $sport...');
    setState(() => _loading = true);

    try {
      final games = await _gamesService.getAllGamesForSport(sport);

      if (mounted) {
        setState(() {
          // Add new games to existing games, avoiding duplicates
          final existingIds = _games.map((g) => g.id).toSet();
          final newGames = games.where((g) => !existingIds.contains(g.id)).toList();
          _games.addAll(newGames);

          // Sort all games by time
          _games.sort((a, b) => a.gameTime.compareTo(b.gameTime));
          _loading = false;
        });

        debugPrint('✅ Loaded ${games.length} $sport games');
      }
    } catch (e) {
      debugPrint('❌ Error loading $sport games: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  IconData _getSportIcon(String sport) {
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
        return Icons.sports_mma;
      case 'BOXING':
        return Icons.sports_mma;
      case 'SOCCER':
        return Icons.sports_soccer;
      default:
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
        return Colors.orange[600]!;  // Bright orange for better visibility on dark theme
      case 'BOXING':
        return Colors.amber;
      case 'SOCCER':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildGameCard(GameModel game) {
    final bool isLive = game.isLive;
    final bool hasStarted = game.isFinal || isLive;
    final bool hasBet = _betStatuses[game.id] ?? false;
    if (hasBet) {
      debugPrint('[AllGamesScreen] Showing bet ribbon for game: ${game.id} - ${game.gameTitle}');
    }

    return Stack(
      children: [
        Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          debugPrint('🎮 Game card tapped in AllGamesScreen:');
          debugPrint('  - Sport: ${game.sport}');
          debugPrint('  - Game: ${game.awayTeam} vs ${game.homeTeam}');
          debugPrint('  - Game ID: ${game.id}');
          debugPrint('  - Navigating to /game-details');

          Navigator.pushNamed(
            context,
            '/game-details',
            arguments: {
              'gameId': game.id,
              'sport': game.sport,
              'gameData': game,
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sport Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getSportColor(game.sport).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(game.sport),
                  color: _getSportColor(game.sport),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Game Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show event title for combat sports, regular title for others
                    if (game.isCombatSport && game.league != null) ...[
                      Text(
                        game.league!, // Event name (UFC 311, Boxing Card, etc.)
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.mainEventFighters ?? game.gameTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (game.totalFights != null && game.totalFights! > 1)
                        Text(
                          '${game.totalFights} fights',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ] else
                      Text(
                        game.gameTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          game.sport,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getSportColor(game.sport),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (game.venue != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '• ${game.venue}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasStarted) 
                      Row(
                        children: [
                          if (isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            game.formattedScore,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isLive ? Colors.red : null,
                            ),
                          ),
                          if (game.period != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              game.period!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Text(
                        DateFormat('MMM d • h:mm a').format(game.gameTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Action Button
              Column(
                children: [
                  if (!hasStarted)
                    GestureDetector(
                      onTap: () {}, // This blocks the tap from propagating to parent InkWell
                      child: ElevatedButton(
                        onPressed: () async {
                          debugPrint('🎯 View Pools button tapped in AllGamesScreen');
                          debugPrint('  - Navigating to /pool-selection');
                          debugPrint('  - Game ID: ${game.id}');
                          await Navigator.pushNamed(
                          context,
                          '/pool-selection',
                          arguments: {
                            'gameId': game.id,
                            'gameTitle': game.gameTitle,
                            'sport': game.sport,
                            'homeTeam': game.homeTeam,
                            'awayTeam': game.awayTeam,
                          },
                        );
                        // Reload bet statuses when returning
                        debugPrint('  - Returned from pool selection, reloading bet statuses...');
                        await _loadBetStatuses();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Pools'),
                      ),
                    )
                  else if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'In Progress',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Final',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
        ),
        // Add the bet placed ribbon
        BetPlacedRibbon(
          isVisible: hasBet,
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredGames = _getFilteredGames();
    final availableSports = _getAvailableSports();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGames,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sport Filter - Always show for consistency
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All Sports'),
                  selected: _selectedSport == null,
                  onSelected: (selected) {
                    setState(() => _selectedSport = null);
                  },
                ),
                const SizedBox(width: 8),
                ...availableSports.map((sport) {
                  final count = _getGamesCountForSport(sport);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSportIcon(sport),
                            size: 16,
                            color: _selectedSport == sport ? Colors.white : _getSportColor(sport),
                          ),
                          const SizedBox(width: 4),
                          Text('$sport${count > 0 ? ' ($count)' : ''}'),
                        ],
                      ),
                      selected: _selectedSport == sport,
                      backgroundColor: _getSportColor(sport).withOpacity(0.2),
                      selectedColor: _getSportColor(sport).withOpacity(0.4),
                      onSelected: (selected) {
                        setState(() => _selectedSport = selected ? sport : null);
                        if (selected && count == 0) {
                          // Load games for this sport if we don't have any
                          _loadGamesForSport(sport);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Games List
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filteredGames.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedSport != null ? _getSportIcon(_selectedSport!) : PhosphorIconsRegular.empty,
                          size: 64,
                          color: _selectedSport != null ? _getSportColor(_selectedSport!).withOpacity(0.5) : Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSport != null
                            ? 'No $_selectedSport games ${widget.title.toLowerCase()}'
                            : 'No games available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedSport != null
                            ? 'Check back later for $_selectedSport games'
                            : 'Select a sport or check back later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadGames,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadGames,
                    child: ListView.builder(
                      itemCount: filteredGames.length,
                      itemBuilder: (context, index) {
                        return _buildGameCard(filteredGames[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}