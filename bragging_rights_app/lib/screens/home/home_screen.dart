import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';
import '../../services/sports_api_service.dart';
import '../../services/wager_service.dart';
import '../../models/game_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _countdownTimer;
  final Map<String, Duration> _countdowns = {};
  
  // Services
  final BetService _betService = BetService();
  final WalletService _walletService = WalletService();
  final SportsApiService _sportsApiService = SportsApiService();
  final WagerService _wagerService = WagerService();
  
  // Track games with bets
  List<String> _gamesWithBets = [];
  
  // Games data
  List<GameModel> _liveGames = [];
  List<GameModel> _upcomingGames = [];
  bool _isLoadingGames = true;

  @override
  void initState() {
    super.initState();
    _initializeCountdowns();
    _startCountdownTimer();
    _loadGamesWithBets();
    _loadGamesData();
  }
  
  void _loadGamesWithBets() {
    _betService.getGamesWithBets().listen((games) {
      if (mounted) {
        setState(() {
          _gamesWithBets = games;
        });
      }
    });
  }

  void _initializeCountdowns() {
    // Countdowns will be populated from real game data
  }
  
  Future<void> _loadGamesData() async {
    setState(() {
      _isLoadingGames = true;
    });
    
    try {
      // Load live games and convert to GameModel
      final liveGamesData = await _sportsApiService.getLiveGames();
      final liveGames = liveGamesData.map((game) => game.toGameModel()).toList();
      
      // Load upcoming games from user's favorite sports
      final upcomingGames = <GameModel>[];
      final sports = ['NFL', 'NBA', 'NHL', 'MLB']; // TODO: Get from user preferences
      
      for (final sport in sports) {
        final games = await _sportsApiService.getUpcomingGames(sport, limit: 5);
        // Convert Game objects to GameModel objects
        upcomingGames.addAll(games.map((game) => game.toGameModel()));
      }
      
      // Sort upcoming games by time
      upcomingGames.sort((a, b) => a.gameTime.compareTo(b.gameTime));
      
      setState(() {
        _liveGames = liveGames;
        _upcomingGames = upcomingGames.take(10).toList(); // Limit to 10 games
        _isLoadingGames = false;
        
        // Initialize countdowns for upcoming games
        for (final game in _upcomingGames) {
          _countdowns[game.id] = game.timeUntilGame;
        }
      });
    } catch (e) {
      print('Error loading games: $e');
      setState(() {
        _isLoadingGames = false;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdowns.forEach((key, value) {
          if (value.inSeconds > 0) {
            _countdowns[key] = Duration(seconds: value.inSeconds - 1);
          }
        });
      });
    });
  }

  @override
  void dispose() {
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
        title: const Text('Bragging Rights'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // BR Balance Display
          Container(
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
                      '$balance BR',
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
          IconButton(
            icon: const Icon(PhosphorIconsRegular.bell),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildGamesTab(),
          _buildBetsTab(),
          _buildPoolsTab(),
          _buildEdgeTab(),
          _buildMoreTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.gameController),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.currencyDollar),
            label: 'Bets',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.trophy),
            label: 'Pools',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.lightning),
            label: 'Edge',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.dotsThreeOutline),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildGamesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Refresh data
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // Quick Actions
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildQuickActionCard(
                    'Quick Play',
                    PhosphorIconsRegular.lightning,
                    Colors.orange,
                    () {
                      // TODO: Quick play
                    },
                  ),
                  StreamBuilder<int>(
                    stream: _getActiveWagerCount(),
                    builder: (context, snapshot) {
                      return _buildQuickActionCard(
                        'My Wagers',
                        PhosphorIconsRegular.chartLine,
                        Colors.indigo,
                        () {
                          Navigator.pushNamed(context, '/active-wagers');
                        },
                        showBadge: snapshot.data != null && snapshot.data! > 0,
                        badgeCount: snapshot.data ?? 0,
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    'My Pools',
                    PhosphorIconsRegular.trophy,
                    Colors.green,
                    () {
                      Navigator.pushNamed(context, '/my-pools');
                    },
                  ),
                  _buildQuickActionCard(
                    'History',
                    PhosphorIconsRegular.receipt,
                    Colors.blue,
                    () {
                      Navigator.pushNamed(context, '/transactions');
                    },
                  ),
                  _buildQuickActionCard(
                    'Get BR',
                    PhosphorIconsRegular.wallet,
                    Colors.purple,
                    () {
                      // TODO: In-app purchase
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Live Now Section
            _buildSectionHeader('🔴 Live Now', 'Games in progress'),
            const SizedBox(height: 12),
            _isLoadingGames
                ? const Center(child: CircularProgressIndicator())
                : _liveGames.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: const Center(
                          child: Text(
                            'No live games at the moment',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _liveGames.length,
                          itemBuilder: (context, index) {
                            final game = _liveGames[index];
                            return _buildLiveGameCard(game);
                          },
                        ),
                      ),
            
            const SizedBox(height: 24),
            
            // Starting Soon Section
            _buildSectionHeader('⏰ Starting Soon', 'Upcoming games'),
            const SizedBox(height: 12),
            _isLoadingGames
                ? const Center(child: CircularProgressIndicator())
                : _upcomingGames.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: const Center(
                          child: Text(
                            'No upcoming games scheduled',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: _upcomingGames.take(3).map((game) {
                          return _buildUpcomingGameCard(game);
                        }).toList(),
                      ),
            
            const SizedBox(height: 24),
            
            // Your Active Pools
            _buildSectionHeader('🎲 Your Active Pools', 'Join pools to see them here'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: const Center(
                child: Text(
                  'Your active pools will appear here\nJoin a pool from the Pools tab',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title, 
    IconData icon, 
    Color color, 
    VoidCallback onTap, 
    {bool showBadge = false, int badgeCount = 0}
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (showBadge && badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // TODO: View all
          },
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildGameCard(String title, String sport, Duration countdown, Color sportColor, bool isLive) {
    final countdownStr = _formatDuration(countdown);
    final isUrgent = countdown.inMinutes < 10;
    
    // Generate game ID to check for bets (matching the format in bet_selection_screen)
    final gameId = '${sport}_${title}_';
    final hasBet = _gamesWithBets.any((id) => id.startsWith(gameId.substring(0, gameId.length - 1)));
    
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: hasBet 
                ? BorderSide(color: Colors.green.withOpacity(0.5), width: 2)
                : BorderSide.none,
          ),
          child: Container(
            decoration: hasBet
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.green.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  )
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: sportColor.withOpacity(0.2),
                radius: 28,
                child: Text(
                  sport,
                  style: TextStyle(
                    color: sportColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (hasBet)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'BET PLACED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isLive ? PhosphorIconsRegular.broadcast : PhosphorIconsRegular.timer,
                        size: 16,
                        color: isUrgent ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLive ? 'LIVE NOW' : 'Closes in: $countdownStr',
                        style: TextStyle(
                          color: isUrgent ? Colors.red : Colors.grey[600],
                          fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(PhosphorIconsRegular.users, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('234 in pool', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 12),
                      Icon(PhosphorIconsRegular.coins, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('Min: 25 BR', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              trailing: hasBet 
                  ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('View Bet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        foregroundColor: Colors.green,
                        disabledBackgroundColor: Colors.green.withOpacity(0.2),
                        disabledForegroundColor: Colors.green,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/pool-selection',
                          arguments: {
                            'gameTitle': title,
                            'sport': sport,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLive ? Colors.green : Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isLive ? 'View' : 'Join',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoolCard(String name, String buyIn, String players, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(PhosphorIconsRegular.stack, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Buy-in: $buyIn • $players'),
        trailing: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowRight),
          onPressed: () {
            // TODO: Navigate to pool details
          },
        ),
      ),
    );
  }
  
  Widget _buildLiveGameCard(GameModel game) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.8),
            Colors.orange.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        game.sport,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.circle, color: Colors.red, size: 8),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  game.gameTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.formattedScore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (game.period != null) ...[  
                  const SizedBox(height: 4),
                  Text(
                    game.period!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUpcomingGameCard(GameModel game) {
    final countdown = _countdowns[game.id] ?? Duration.zero;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(game.sport),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.gameTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${game.sport} • ${game.venue ?? "Venue TBD"}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(countdown),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
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
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 20),
                    ),
                    child: const Text('View Pools'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
      case 'BOXING':
        return Icons.sports_mma;
      case 'SOCCER':
        return Icons.sports_soccer;
      case 'TENNIS':
        return Icons.sports_tennis;
      case 'GOLF':
        return Icons.golf_course;
      default:
        return Icons.sports;
    }
  }

  Widget _buildBetsTab() {
    return const Center(
      child: Text('My Pools - Coming Soon'),
    );
  }

  Widget _buildPoolsTab() {
    return const Center(
      child: Text('Discover - Coming Soon'),
    );
  }

  Widget _buildEdgeTab() {
    return const Center(
      child: Text('Leaderboard - Coming Soon'),
    );
  }

  Widget _buildMoreTab() {
    return const Center(
      child: Text('Profile - Coming Soon'),
    );
  }

  Stream<int> _getActiveWagerCount() {
    return _wagerService.getActiveWagersStream().map((wagers) => wagers.length);
  }
}