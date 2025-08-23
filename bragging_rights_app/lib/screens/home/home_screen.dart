import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';

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
  
  // Track games with bets
  List<String> _gamesWithBets = [];

  @override
  void initState() {
    super.initState();
    _initializeCountdowns();
    _startCountdownTimer();
    _loadGamesWithBets();
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
    // Initialize with some example countdowns
    _countdowns['Lakers vs Celtics'] = const Duration(hours: 2, minutes: 15, seconds: 30);
    _countdowns['Cowboys vs Eagles'] = const Duration(minutes: 45, seconds: 23);
    _countdowns['McGregor vs Chandler'] = const Duration(hours: 1, minutes: 30, seconds: 45);
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
          _buildHomeTab(),
          _buildMyPoolsTab(),
          _buildDiscoverTab(),
          _buildLeaderboardTab(),
          _buildProfileTab(),
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
            icon: Icon(PhosphorIconsRegular.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.swimmingPool),
            label: 'My Pools',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.compass),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.trophy),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
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
                  _buildQuickActionCard(
                    'My Bets',
                    PhosphorIconsRegular.chartLine,
                    Colors.indigo,
                    () {
                      Navigator.pushNamed(context, '/active-bets');
                    },
                    showBadge: true,
                    badgeCount: 3, // This will be dynamic based on active bets
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
                    'Find Friends',
                    PhosphorIconsRegular.usersFour,
                    Colors.blue,
                    () {
                      // TODO: Find friends
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
            _buildGameCard(
              'Lakers vs Celtics',
              'NBA',
              _countdowns['Lakers vs Celtics'] ?? Duration.zero,
              Colors.orange,
              true,
            ),
            
            const SizedBox(height: 24),
            
            // Starting Soon Section
            _buildSectionHeader('⏰ Starting Soon', 'Pool closes soon!'),
            const SizedBox(height: 12),
            _buildGameCard(
              'Cowboys vs Eagles',
              'NFL',
              _countdowns['Cowboys vs Eagles'] ?? Duration.zero,
              Colors.brown,
              false,
            ),
            _buildGameCard(
              'McGregor vs Chandler',
              'MMA',
              _countdowns['McGregor vs Chandler'] ?? Duration.zero,
              Colors.red,
              false,
            ),
            
            const SizedBox(height: 24),
            
            // Your Active Pools - using Stack icon instead of target
            _buildSectionHeader('🎲 Your Active Pools', '2 active'),
            const SizedBox(height: 12),
            _buildPoolCard('NFL Sunday Pool', '25 BR', '12 players', Colors.brown),
            _buildPoolCard('Friends NBA League', '50 BR', '8 players', Colors.orange),
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

  Widget _buildMyPoolsTab() {
    return const Center(
      child: Text('My Pools - Coming Soon'),
    );
  }

  Widget _buildDiscoverTab() {
    return const Center(
      child: Text('Discover - Coming Soon'),
    );
  }

  Widget _buildLeaderboardTab() {
    return const Center(
      child: Text('Leaderboard - Coming Soon'),
    );
  }

  Widget _buildProfileTab() {
    return const Center(
      child: Text('Profile - Coming Soon'),
    );
  }
}