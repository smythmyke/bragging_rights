import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../services/espn_direct_service.dart';
import '../../services/optimized_games_service.dart';
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

class _AllGamesScreenState extends State<AllGamesScreen> {
  final ESPNDirectService _espnService = ESPNDirectService();
  List<GameModel> _games = [];
  bool _loading = true;
  String? _selectedSport;

  // Define all supported sports
  static const List<String> ALL_SUPPORTED_SPORTS = ['NFL', 'NBA', 'NHL', 'MLB', 'BOXING', 'MMA', 'SOCCER'];
  
  @override
  void initState() {
    super.initState();
    if (widget.initialGames != null) {
      _games = widget.initialGames!;
      _loading = false;
    } else {
      _loadGames();
    }
  }
  
  Future<void> _loadGames() async {
    setState(() => _loading = true);

    try {
      List<GameModel> games = [];

      // If a specific sport is selected, only load that sport
      if (_selectedSport != null) {
        debugPrint('Loading games for selected sport: $_selectedSport');
        // Import the optimized service for consistent data fetching
        final optimizedService = OptimizedGamesService();
        games = await optimizedService.loadAllGamesForSport(_selectedSport!);
        debugPrint('Loaded ${games.length} $_selectedSport games');
      } else {
        // Load games based on category
        switch (widget.category) {
        case 'live':
          games = await _espnService.getLiveGames();
          break;
        case 'today':
          games = await _espnService.getTodaysGames();
          break;
        case 'tomorrow':
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final dayAfter = tomorrow.add(const Duration(days: 1));
          final allGames = await _espnService.fetchAllGames();
          games = allGames.where((game) => 
            game.gameTime.isAfter(DateTime(tomorrow.year, tomorrow.month, tomorrow.day)) &&
            game.gameTime.isBefore(DateTime(dayAfter.year, dayAfter.month, dayAfter.day))
          ).toList();
          break;
        case 'thisweek':
          games = await _espnService.getUpcomingGames(days: 7);
          break;
        case 'nextweek':
          final nextWeek = DateTime.now().add(const Duration(days: 7));
          final twoWeeks = DateTime.now().add(const Duration(days: 14));
          final allGames = await _espnService.fetchAllGames();
          games = allGames.where((game) => 
            game.gameTime.isAfter(nextWeek) &&
            game.gameTime.isBefore(twoWeeks)
          ).toList();
          break;
        default:
          games = await _espnService.fetchAllGames();
        }
      }

      setState(() {
        _games = games;
        _loading = false;
      });
    } catch (e) {
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
    
    return Card(
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
                          Text(
                            '• ${game.venue}',
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
                        onPressed: () {
                          debugPrint('🎯 View Pools button tapped in AllGamesScreen');
                          debugPrint('  - Navigating to /pool-selection');
                          Navigator.pushNamed(
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
                ...availableSports.map((sport) => Padding(
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
                        Text(sport),
                      ],
                    ),
                    selected: _selectedSport == sport,
                    backgroundColor: _getSportColor(sport).withOpacity(0.2),
                    selectedColor: _getSportColor(sport).withOpacity(0.4),
                    onSelected: (selected) {
                      setState(() => _selectedSport = selected ? sport : null);
                    },
                  ),
                )),
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