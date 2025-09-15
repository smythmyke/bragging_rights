import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/bet_service.dart';
import '../../theme/app_theme.dart';

class ActiveBetsScreen extends StatefulWidget {
  const ActiveBetsScreen({super.key});

  @override
  State<ActiveBetsScreen> createState() => _ActiveBetsScreenState();
}

class _ActiveBetsScreenState extends State<ActiveBetsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BetService _betService;
  Stream<List<BetModel>>? _activeBetsStream;
  Stream<List<BetModel>>? _pastBetsStream;
  List<BetModel> _activeBets = [];
  bool _isLoading = true;
  
  // Stats
  int _totalWins = 0;
  int _totalLosses = 0;
  double _totalProfit = 0;
  int _currentStreak = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeBetService();
  }
  
  void _initializeBetService() {
    debugPrint('[ActiveBetsScreen] Initializing Firestore bet service...');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _betService = BetService();

      setState(() {
        _activeBetsStream = _betService.getActiveBets();
        _pastBetsStream = _betService.getPastBets();
        _isLoading = false;
      });

      debugPrint('[ActiveBetsScreen] Firestore streams initialized for user: ${user.uid}');
    } else {
      debugPrint('[ActiveBetsScreen] No user logged in');
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateStats(List<BetModel> pastBets) {
    _totalWins = 0;
    _totalLosses = 0;
    _totalProfit = 0;
    _currentStreak = 0;

    for (final bet in pastBets) {
      if (bet.status == 'won') {
        _totalWins++;
        _totalProfit += bet.potentialPayout - bet.wagerAmount;
      } else if (bet.status == 'lost') {
        _totalLosses++;
        _totalProfit -= bet.wagerAmount;
      }
    }

    // Calculate current streak
    if (pastBets.isNotEmpty) {
      final sortedBets = List<BetModel>.from(pastBets)
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

      final streakType = sortedBets.first.status == 'won';
      for (final bet in sortedBets) {
        if ((bet.status == 'won') == streakType) {
          _currentStreak++;
        } else {
          break;
        }
      }
      if (!streakType) _currentStreak = -_currentStreak;
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bets'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Active',
              icon: const Icon(PhosphorIconsRegular.clock),
            ),
            Tab(
              text: 'Past',
              icon: const Icon(PhosphorIconsRegular.checkCircle),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveBetsTab(),
                      _buildPastBetsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Wins', _totalWins.toString(), AppTheme.neonGreen),
              _buildStatItem('Losses', _totalLosses.toString(), AppTheme.errorPink),
              _buildStatItem(
                'Profit', 
                '${_totalProfit >= 0 ? '+' : ''}${_totalProfit.toStringAsFixed(0)} BR',
                _totalProfit >= 0 ? AppTheme.neonGreen : AppTheme.errorPink,
              ),
              _buildStatItem(
                'Streak',
                '${_currentStreak.abs()}${_currentStreak > 0 ? 'W' : _currentStreak < 0 ? 'L' : ''}',
                _currentStreak > 0 ? AppTheme.neonGreen : _currentStreak < 0 ? AppTheme.errorPink : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveBetsTab() {
    if (_activeBetsStream == null) {
      return const Center(
        child: Text('Please log in to view your bets'),
      );
    }

    return StreamBuilder<List<BetModel>>(
      stream: _activeBetsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading bets: ${snapshot.error}'),
          );
        }

        final activeBets = snapshot.data ?? [];

        if (activeBets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.empty,
                  size: 64,
                  color: AppTheme.surfaceBlue.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Active Bets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Place some bets to see them here',
                  style: TextStyle(
                    color: AppTheme.primaryCyan.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        // Display active bets
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeBets.length,
          itemBuilder: (context, index) {
            final bet = activeBets[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(
                  bet.gameTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${bet.sport} • ${bet.poolName}'),
                    const SizedBox(height: 4),
                    Text(
                      'Wager: ${bet.wagerAmount} BR • Potential: ${bet.potentialPayout} BR',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bet.bets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Selection: ${bet.bets.first.selection}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    _getSportIcon(bet.sport),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: AppTheme.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'nba':
      case 'basketball':
        return PhosphorIconsRegular.basketball;
      case 'nfl':
      case 'football':
        return PhosphorIconsRegular.football;
      case 'mlb':
      case 'baseball':
        return PhosphorIconsRegular.baseball;
      case 'nhl':
      case 'hockey':
        return Icons.sports_hockey;
      case 'mma':
      case 'boxing':
        return PhosphorIconsRegular.boxingGlove;
      case 'soccer':
        return PhosphorIconsRegular.soccerBall;
      default:
        return PhosphorIconsRegular.trophy;
    }
  }
  
  Widget _buildPastBetsTab() {
    if (_pastBetsStream == null) {
      return const Center(
        child: Text('Please log in to view your bet history'),
      );
    }

    return StreamBuilder<List<BetModel>>(
      stream: _pastBetsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading bet history: ${snapshot.error}'),
          );
        }

        final pastBets = snapshot.data ?? [];

        // Calculate stats whenever past bets are loaded
        _calculateStats(pastBets);

        if (pastBets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.clock,
                  size: 64,
                  color: AppTheme.surfaceBlue.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Past Bets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed bets will appear here',
                  style: TextStyle(
                    color: AppTheme.primaryCyan.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pastBets.length,
          itemBuilder: (context, index) {
            final bet = pastBets[index];
            final statusColor = _getStatusColor(bet.status);
            final statusText = _getStatusText(bet.status);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(
                  bet.gameTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${bet.sport} • ${bet.poolName}'),
                    const SizedBox(height: 4),
                    Text(
                      'Wager: ${bet.wagerAmount} BR • ${bet.status == 'won' ? 'Won: ${bet.potentialPayout} BR' : bet.status == 'lost' ? 'Lost' : 'Cancelled'}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bet.bets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Selection: ${bet.bets.first.selection}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(
                    _getSportIcon(bet.sport),
                    color: statusColor,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'won':
        return AppTheme.neonGreen;
      case 'lost':
        return AppTheme.errorPink;
      case 'cancelled':
        return Colors.grey;
      case 'pending':
        return AppTheme.warningAmber;
      default:
        return AppTheme.warningAmber;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'won':
        return 'WON';
      case 'lost':
        return 'LOST';
      case 'cancelled':
        return 'CANCELLED';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

}