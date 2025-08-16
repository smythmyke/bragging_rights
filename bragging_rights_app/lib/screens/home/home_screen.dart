import 'package:flutter/material.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _countdownTimer;
  final Map<String, Duration> _countdowns = {};

  @override
  void initState() {
    super.initState();
    _initializeCountdowns();
    _startCountdownTimer();
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
                  Icons.monetization_on,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '500 BR',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pool),
            label: 'My Pools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
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
                    Icons.flash_on,
                    Colors.orange,
                    () {
                      // TODO: Quick play
                    },
                  ),
                  _buildQuickActionCard(
                    'Create Pool',
                    Icons.add_circle,
                    Colors.green,
                    () {
                      // TODO: Create pool
                    },
                  ),
                  _buildQuickActionCard(
                    'Find Friends',
                    Icons.people,
                    Colors.blue,
                    () {
                      // TODO: Find friends
                    },
                  ),
                  _buildQuickActionCard(
                    'Get BR',
                    Icons.shopping_cart,
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
            
            // Your Active Pools
            _buildSectionHeader('🎯 Your Active Pools', '2 active'),
            const SizedBox(height: 12),
            _buildPoolCard('NFL Sunday Pool', '25 BR', '12 players', Colors.brown),
            _buildPoolCard('Friends NBA League', '50 BR', '8 players', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isLive ? Icons.live_tv : Icons.timer,
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
                Icon(Icons.people, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('234 in pool', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(width: 12),
                Icon(Icons.monetization_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('Min: 25 BR', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
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
          child: Icon(Icons.pool, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Buy-in: $buyIn • $players'),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
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