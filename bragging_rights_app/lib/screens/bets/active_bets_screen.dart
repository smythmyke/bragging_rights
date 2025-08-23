import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/bet_storage_service.dart';

class ActiveBetsScreen extends StatefulWidget {
  const ActiveBetsScreen({super.key});

  @override
  State<ActiveBetsScreen> createState() => _ActiveBetsScreenState();
}

class _ActiveBetsScreenState extends State<ActiveBetsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BetStorageService _betStorage;
  List<UserBet> _activeBets = [];
  List<UserBet> _pastBets = [];
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
    _loadBets();
  }
  
  Future<void> _loadBets() async {
    setState(() => _isLoading = true);
    
    _betStorage = await BetStorageService.create();
    _activeBets = await _betStorage.getActiveBets();
    _pastBets = await _betStorage.getPastBets();
    
    // Calculate stats from past bets
    _calculateStats();
    
    setState(() => _isLoading = false);
  }
  
  void _calculateStats() {
    _totalWins = 0;
    _totalLosses = 0;
    _totalProfit = 0;
    _currentStreak = 0;
    
    for (final bet in _pastBets) {
      if (bet.won == true) {
        _totalWins++;
        _totalProfit += (bet.payout ?? 0) - bet.amount;
      } else if (bet.won == false) {
        _totalLosses++;
        _totalProfit -= bet.amount;
      }
    }
    
    // Calculate current streak
    if (_pastBets.isNotEmpty) {
      final sortedBets = List<UserBet>.from(_pastBets)
        ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
      
      bool? streakType = sortedBets.first.won;
      for (final bet in sortedBets) {
        if (bet.won == streakType) {
          _currentStreak++;
        } else {
          break;
        }
      }
      if (streakType == false) _currentStreak = -_currentStreak;
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
              icon: _activeBets.isNotEmpty 
                ? Badge(
                    label: Text(_activeBets.length.toString()),
                    child: const Icon(PhosphorIconsRegular.clock),
                  )
                : const Icon(PhosphorIconsRegular.clock),
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
              _buildStatItem('Wins', _totalWins.toString(), Colors.green),
              _buildStatItem('Losses', _totalLosses.toString(), Colors.red),
              _buildStatItem(
                'Profit', 
                '${_totalProfit >= 0 ? '+' : ''}${_totalProfit.toStringAsFixed(0)} BR',
                _totalProfit >= 0 ? Colors.green : Colors.red,
              ),
              _buildStatItem(
                'Streak',
                '${_currentStreak.abs()}${_currentStreak > 0 ? 'W' : _currentStreak < 0 ? 'L' : ''}',
                _currentStreak > 0 ? Colors.green : _currentStreak < 0 ? Colors.red : Colors.white,
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveBetsTab() {
    if (_activeBets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.empty,
              size: 64,
              color: Colors.grey[400],
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
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/pools');
              },
              icon: const Icon(PhosphorIconsRegular.plus),
              label: const Text('Browse Pools'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    // Group bets by pool
    final betsByPool = <String, List<UserBet>>{};
    for (final bet in _activeBets) {
      betsByPool.putIfAbsent(bet.poolId, () => []).add(bet);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: betsByPool.length,
      itemBuilder: (context, index) {
        final poolId = betsByPool.keys.elementAt(index);
        final poolBets = betsByPool[poolId]!;
        final poolName = poolBets.first.poolName;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              poolName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${poolBets.length} active bets'),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                PhosphorIconsRegular.trophy,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            children: poolBets.map((bet) => _buildBetTile(bet)).toList(),
          ),
        );
      },
    );
  }
  
  Widget _buildPastBetsTab() {
    if (_pastBets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.clock,
              size: 64,
              color: Colors.grey[400],
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
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pastBets.length,
      itemBuilder: (context, index) {
        final bet = _pastBets[index];
        return _buildBetTile(bet, isPast: true);
      },
    );
  }
  
  Widget _buildBetTile(UserBet bet, {bool isPast = false}) {
    final statusColor = isPast
        ? (bet.won == true ? Colors.green : bet.won == false ? Colors.red : Colors.orange)
        : Colors.orange;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.1),
        child: Icon(
          _getBetTypeIcon(bet.betType),
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        bet.selection,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${bet.gameTitle} • ${bet.sport}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (bet.description != null)
            Text(
              bet.description!,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            bet.odds,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (isPast)
            Text(
              bet.statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '${bet.amount.toStringAsFixed(0)} BR',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (bet.payout != null && bet.won == true)
            Text(
              bet.formattedPayout,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
  
  IconData _getBetTypeIcon(String betType) {
    switch (betType.toLowerCase()) {
      case 'moneyline':
        return PhosphorIconsRegular.trophy;
      case 'spread':
        return PhosphorIconsRegular.arrowsLeftRight;
      case 'total':
      case 'totals':
        return PhosphorIconsRegular.plusMinus;
      case 'prop':
        return PhosphorIconsRegular.star;
      case 'method':
        return PhosphorIconsRegular.target;
      case 'rounds':
        return PhosphorIconsRegular.timer;
      case 'live':
        return PhosphorIconsRegular.broadcast;
      default:
        return PhosphorIconsRegular.circlesFour;
    }
  }
}