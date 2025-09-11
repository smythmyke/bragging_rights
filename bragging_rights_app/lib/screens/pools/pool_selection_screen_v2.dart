import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/pool_model.dart';
import '../../services/pool_service.dart';
import '../../services/wallet_service.dart';
import '../../services/bet_storage_service.dart';

class PoolSelectionScreenV2 extends StatefulWidget {
  final String gameId;
  final String gameTitle;
  final String sport;
  
  const PoolSelectionScreenV2({
    super.key,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
  });

  @override
  State<PoolSelectionScreenV2> createState() => _PoolSelectionScreenV2State();
}

class _PoolSelectionScreenV2State extends State<PoolSelectionScreenV2> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PoolService _poolService = PoolService();
  final WalletService _walletService = WalletService();
  late BetStorageService _betStorage;
  Map<String, int> _poolBetCounts = {}; // Track bet counts per pool
  
  int _userBalance = 0;
  final Set<String> _userPoolIds = {}; // Track pools user has joined
  bool _isLoadingBalance = true;
  Timer? _countdownTimer;
  final Map<String, Duration> _poolCountdowns = {};
  
  // Real data only - no mock data
  bool _useMockData = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Pool> _mockQuickPools = [];
  List<Pool> _mockRegionalPools = [];
  List<Pool> _mockPrivatePools = [];
  List<Pool> _mockTournamentPools = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserBalance();
    // Mock pools removed - using real data from Firestore
    _startCountdownTimer(); // Currently disabled to prevent flickering
    _loadBetStorage();
  }

  void _loadUserBalance() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        // Use getCurrentBalance instead of getBalance
        final balance = await _walletService.getCurrentBalance();
        
        // Also load user's pools
        final userPools = await _firestore
            .collection('user_pools')
            .where('userId', isEqualTo: userId)
            .where('gameId', isEqualTo: widget.gameId)
            .get();
        
        final poolIds = userPools.docs.map((doc) => 
            doc.data()['poolId'] as String).toSet();
        
        if (mounted) {
          setState(() {
            _userBalance = balance;
            _userPoolIds.clear();
            _userPoolIds.addAll(poolIds);
            _isLoadingBalance = false;
          });
        }
      } catch (e) {
        print('Error loading balance: $e');
        if (mounted) {
          setState(() {
            _isLoadingBalance = false;
          });
        }
      }
    }
  }

  void _initializeMockPools() {
    if (!_useMockData) return;
    
    final now = DateTime.now();
    
    // Create mock Quick Play pools
    _mockQuickPools = [
      QuickPlayPoolTemplate.beginner(
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
      ).copyWith(
        id: 'mock_beginner',
        currentPlayers: 234,
        playerIds: List.generate(234, (i) => 'player_$i'),
      ),
      QuickPlayPoolTemplate.standard(
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
      ).copyWith(
        id: 'mock_standard',
        currentPlayers: 156,
        playerIds: List.generate(156, (i) => 'player_$i'),
      ),
      QuickPlayPoolTemplate.highStakes(
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
      ).copyWith(
        id: 'mock_high',
        currentPlayers: 45,
        playerIds: List.generate(45, (i) => 'player_$i'),
      ),
      QuickPlayPoolTemplate.vip(
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
      ).copyWith(
        id: 'mock_vip',
        currentPlayers: 12,
        playerIds: List.generate(12, (i) => 'player_$i'),
      ),
    ];

    // Create mock Regional pools
    _mockRegionalPools = [
      Pool(
        id: 'mock_local',
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        type: PoolType.regional,
        status: PoolStatus.open,
        name: 'Local Champions',
        buyIn: 25,
        minPlayers: 5,
        maxPlayers: 20,
        currentPlayers: 8,
        playerIds: List.generate(8, (i) => 'player_$i'),
        startTime: now.add(const Duration(hours: 1)),
        closeTime: now.add(const Duration(minutes: 30)),
        prizePool: 200,
        prizeStructure: {'1': 100, '2': 60, '3': 40},
        regionalLevel: RegionalLevel.neighborhood,
        region: 'Zip: 10001',
        createdAt: now,
      ),
      Pool(
        id: 'mock_city',
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        type: PoolType.regional,
        status: PoolStatus.open,
        name: 'NYC Elite',
        buyIn: 100,
        minPlayers: 20,
        maxPlayers: 100,
        currentPlayers: 45,
        playerIds: List.generate(45, (i) => 'player_$i'),
        startTime: now.add(const Duration(hours: 2)),
        closeTime: now.add(const Duration(minutes: 45)),
        prizePool: 4500,
        prizeStructure: {'1': 2000, '2': 1500, '3': 1000},
        regionalLevel: RegionalLevel.city,
        region: 'New York',
        createdAt: now,
      ),
    ];

    // Create mock Tournament pools
    _mockTournamentPools = [
      Pool(
        id: 'mock_weekly',
        gameId: widget.gameId,
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        type: PoolType.tournament,
        status: PoolStatus.open,
        name: 'Weekly Championship',
        buyIn: 50,
        minPlayers: 64,
        maxPlayers: 256,
        currentPlayers: 128,
        playerIds: List.generate(128, (i) => 'player_$i'),
        startTime: now.add(const Duration(days: 1)),
        closeTime: now.add(const Duration(hours: 12)),
        prizePool: 6400,
        prizeStructure: {'1': 5000, '2': 1000, '3': 400},
        createdAt: now,
      ),
    ];
  }

  void _startCountdownTimer() {
    // Commenting out the timer to prevent flickering
    // This timer was causing unnecessary rebuilds every second
    // If countdown functionality is needed, implement it with proper state management
    // _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    //   setState(() {
    //     // Update countdowns for all pools
    //   });
    // });
  }
  
  Future<void> _loadBetStorage() async {
    _betStorage = await BetStorageService.create();
    await _loadPoolBetCounts();
  }
  
  Future<void> _loadPoolBetCounts() async {
    final allBets = await _betStorage.getActiveBets();
    final counts = <String, int>{};
    
    for (final bet in allBets) {
      counts[bet.poolId] = (counts[bet.poolId] ?? 0) + 1;
    }
    
    if (mounted) {
      setState(() {
        _poolBetCounts = counts;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // _countdownTimer?.cancel(); // Commented out since timer is disabled
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return 'Closed';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${twoDigits(duration.inMinutes.remainder(60))}m';
    }
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getPoolColor(PoolTier? tier) {
    switch (tier) {
      case PoolTier.beginner:
        return Colors.blue;
      case PoolTier.standard:
        return Colors.green;
      case PoolTier.high:
        return Colors.orange;
      case PoolTier.vip:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gameTitle, style: const TextStyle(fontSize: 16)),
            Text(
              widget.sport,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_userBalance BR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Quick Play'),
            Tab(text: 'Regional'),
            Tab(text: 'Private'),
            Tab(text: 'Tournament'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickPlayTab(),
          _buildRegionalTab(),
          _buildPrivateTab(),
          _buildTournamentTab(),
        ],
      ),
    );
  }

  Widget _buildQuickPlayTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.flash_on, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Play - Instant Match',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Auto-matched with players at your BR level',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _useMockData
              ? _buildMockQuickPlayList()
              : StreamBuilder<List<Pool>>(
                  stream: _poolService.getPoolsByType(widget.gameId, PoolType.quick),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final pools = snapshot.data ?? [];
                    if (pools.isEmpty && !_useMockData) {
                      return _buildEmptyState('No quick play pools available');
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pools.length,
                      itemBuilder: (context, index) {
                        return _buildPoolCard(pools[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMockQuickPlayList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mockQuickPools.length,
      itemBuilder: (context, index) {
        return _buildPoolCard(_mockQuickPools[index]);
      },
    );
  }

  Widget _buildPoolCard(Pool pool) {
    final color = _getPoolColor(pool.tier);
    final canAfford = _userBalance >= pool.buyIn;
    final fillPercentage = pool.fillPercentage;
    final spotsRemaining = pool.maxPlayers - pool.currentPlayers;
    final hasBets = _poolBetCounts[pool.id] != null && _poolBetCounts[pool.id]! > 0;
    final betCount = _poolBetCounts[pool.id] ?? 0;
    final isUserInPool = _userPoolIds.contains(pool.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${pool.buyIn}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'BR',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(pool.name)),
                if (hasBets) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$betCount BETS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (pool.tier == PoolTier.vip) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pool.playerCountDisplay} • $spotsRemaining spots left'),
                if (pool.isClosingSoon) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.red, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Closes in ${_formatDuration(pool.timeUntilClose)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isUserInPool 
                      ? () => _continueInPool(pool)
                      : canAfford && !pool.isFull 
                          ? () => _joinPool(pool) 
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUserInPool 
                        ? Colors.green 
                        : canAfford 
                            ? color 
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    isUserInPool 
                        ? 'Continue'
                        : pool.isFull 
                            ? 'Full' 
                            : canAfford 
                                ? 'Join' 
                                : 'Need BR',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '🏆 ${pool.getPrizeForPosition(1)} BR',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: fillPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(fillPercentage * 100).toStringAsFixed(0)}% full',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Prize pool: ${pool.prizePool} BR',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionalTab() {
    if (_useMockData) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRegionalSection('Neighborhood (Zip: 10001)', 
            _mockRegionalPools.where((p) => p.regionalLevel == RegionalLevel.neighborhood).toList()),
          _buildRegionalSection('City (New York)', 
            _mockRegionalPools.where((p) => p.regionalLevel == RegionalLevel.city).toList()),
        ],
      );
    }

    return StreamBuilder<List<Pool>>(
      stream: _poolService.getPoolsByType(widget.gameId, PoolType.regional),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final pools = snapshot.data ?? [];
        if (pools.isEmpty) {
          return _buildEmptyStateWithCreate('No regional pools available', PoolType.regional);
        }
        
        // Group pools by regional level
        final grouped = <RegionalLevel, List<Pool>>{};
        for (final pool in pools) {
          if (pool.regionalLevel != null) {
            grouped.putIfAbsent(pool.regionalLevel!, () => []).add(pool);
          }
        }
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.map((entry) {
            return _buildRegionalSection(
              entry.key.toString().split('.').last,
              entry.value,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRegionalSection(String title, List<Pool> pools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...pools.map((pool) => _buildPoolCard(pool)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPrivateTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _createPrivatePool,
            icon: const Icon(Icons.add),
            label: const Text('Create Private Pool'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Text(
                'Join with Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                onSubmitted: (code) => _joinWithCode(code),
                decoration: InputDecoration(
                  hintText: 'Enter pool code',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {},
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Friend Pools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Pool>>(
                stream: _poolService.getFriendPools(widget.gameId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final pools = snapshot.data ?? [];
                  if (pools.isEmpty) {
                    return _buildEmptyState('No friend pools available');
                  }
                  
                  return Column(
                    children: pools.map((pool) => _buildFriendPoolCard(pool)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendPoolCard(Pool pool) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.people, color: Colors.white),
        ),
        title: Text(pool.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buy-in: ${pool.buyIn} BR • ${pool.playerCountDisplay}'),
            const SizedBox(height: 2),
            if (pool.code != null)
              Text(
                'Code: ${pool.code}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _joinPool(pool),
          child: const Text('Join'),
        ),
      ),
    );
  }

  Widget _buildTournamentTab() {
    if (_useMockData) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: _mockTournamentPools.map((pool) => _buildTournamentCard(pool)).toList(),
      );
    }

    return StreamBuilder<List<Pool>>(
      stream: _poolService.getTournamentPools(widget.gameId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final pools = snapshot.data ?? [];
        if (pools.isEmpty) {
          return _buildEmptyStateWithCreate('No tournaments available', PoolType.tournament);
        }
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: pools.map((pool) => _buildTournamentCard(pool)).toList(),
        );
      },
    );
  }

  Widget _buildTournamentCard(Pool pool) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.amber,
          child: Icon(Icons.emoji_events, color: Colors.white),
        ),
        title: Text(pool.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entry: ${pool.buyIn} BR • ${pool.playerCountDisplay}'),
            const SizedBox(height: 2),
            Text(
              '🏆 1st: ${pool.getPrizeForPosition(1)} BR',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => _joinPool(pool),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pool, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyStateWithCreate(String message, PoolType type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == PoolType.regional ? Icons.map : Icons.emoji_events,
            size: 64, 
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createAutoPool(type),
            icon: const Icon(Icons.add),
            label: Text('Create ${type == PoolType.regional ? 'Regional' : 'Tournament'} Pool'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createAutoPool(PoolType type) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a pool'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is already in a pool for this game
    try {
      // Get all pools for this game that the user has joined
      final userPoolsSnapshot = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: widget.gameId)
          .where('participants', arrayContains: userId)
          .get();
      
      if (userPoolsSnapshot.docs.isNotEmpty) {
        // User is already in a pool for this game
        final existingPool = userPoolsSnapshot.docs.first;
        final poolData = existingPool.data();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already in the pool: ${poolData['name'] ?? 'Unnamed Pool'}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Go to Pool',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to the existing pool
                final pool = Pool.fromMap(poolData, existingPool.id);
                _continueInPool(pool);
              },
            ),
          ),
        );
        return;
      }
      
      // If user is not in any pool, proceed with creation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creating ${type.toString().split('.').last} pool...'),
          backgroundColor: Colors.blue,
        ),
      );
      
      // TODO: Implement actual pool creation logic here
      // For now, just show that we checked membership first
      
    } catch (e) {
      print('Error checking/creating pool: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error creating pool. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _continueInPool(Pool pool) {
    // Navigate directly to bet selection for existing pool members
    Navigator.pushNamed(
      context,
      '/bet-selection',
      arguments: {
        'gameId': widget.gameId,
        'gameTitle': widget.gameTitle,
        'sport': widget.sport,
        'poolName': pool.name,
        'poolId': pool.id,
        'poolId': pool.id,
      },
    );
  }

  void _joinPool(Pool pool) {
    // Check if already in pool
    if (_userPoolIds.contains(pool.id)) {
      _continueInPool(pool);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Join ${pool.name}?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Entry: ${pool.buyIn} BR',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Your new balance: ${_userBalance} BR → ${_userBalance - pool.buyIn} BR',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Prize Structure',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...pool.prizeStructure.entries.take(3).map((entry) {
                    final position = int.parse(entry.key);
                    final prize = entry.value as int;
                    return Text(
                      '${position == 1 ? '🥇' : position == 2 ? '🥈' : '🥉'} #$position: $prize BR',
                      style: const TextStyle(fontSize: 12),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      
                      // For mock data, just navigate
                      if (_useMockData) {
                        Navigator.pushNamed(
                          context,
                          '/bet-selection',
                          arguments: {
                            'gameId': widget.gameId,
                            'gameTitle': widget.gameTitle,
                            'sport': widget.sport,
                            'poolName': pool.name,
                            'poolId': pool.id,
                            'poolId': pool.id,
                          },
                        );
                        return;
                      }
                      
                      // Real pool joining
                      final success = await _poolService.joinPool(pool.id, pool.buyIn);
                      if (success) {
                        Navigator.pushNamed(
                          context,
                          '/bet-selection',
                          arguments: {
                            'gameId': widget.gameId,
                            'gameTitle': widget.gameTitle,
                            'sport': widget.sport,
                            'poolName': pool.name,
                            'poolId': pool.id,
                            'poolId': pool.id,
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to join pool'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createPrivatePool() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a pool'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is already in a pool for this game
    try {
      final userPoolsSnapshot = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: widget.gameId)
          .where('participants', arrayContains: userId)
          .get();
      
      if (userPoolsSnapshot.docs.isNotEmpty) {
        // User is already in a pool for this game
        final existingPool = userPoolsSnapshot.docs.first;
        final poolData = existingPool.data();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already in: ${poolData['name'] ?? 'a pool for this game'}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Go to Pool',
              textColor: Colors.white,
              onPressed: () {
                final pool = Pool.fromMap(poolData, existingPool.id);
                _continueInPool(pool);
              },
            ),
          ),
        );
        return;
      }
      
      // TODO: Navigate to create private pool screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create Private Pool - Coming Soon')),
      );
    } catch (e) {
      print('Error checking pools: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error checking pool membership'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _joinWithCode(String code) async {
    if (code.isEmpty) return;
    
    final success = await _poolService.joinPoolWithCode(code);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined pool!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid pool code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}