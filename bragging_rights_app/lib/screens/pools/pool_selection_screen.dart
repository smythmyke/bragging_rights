import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/pool_service.dart';
import '../../services/wallet_service.dart';
import '../../models/pool_model.dart';

class PoolSelectionScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  
  const PoolSelectionScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
  });

  @override
  State<PoolSelectionScreen> createState() => _PoolSelectionScreenState();
}

class _PoolSelectionScreenState extends State<PoolSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PoolService _poolService = PoolService();
  final WalletService _walletService = WalletService();
  String _selectedPoolType = 'quick';
  Timer? _countdownTimer;
  Duration _poolCloseCountdown = const Duration(minutes: 15, seconds: 30);
  String? gameId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startCountdownTimer();
    // Generate game ID from title and sport
    gameId = '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_poolCloseCountdown.inSeconds > 0) {
          _poolCloseCountdown = Duration(seconds: _poolCloseCountdown.inSeconds - 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _poolCloseCountdown.inMinutes < 5;
    
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
              color: isUrgent ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_poolCloseCountdown),
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
          child: StreamBuilder<List<Pool>>(
            stream: _poolService.getPoolsByType(gameId ?? '', PoolType.quick),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final pools = snapshot.data ?? [];
              
              if (pools.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pool, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No quick play pools available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back soon or create your own!',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _createPoolForGame(PoolType.quick),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Pool'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pools.length,
                itemBuilder: (context, index) {
                  final pool = pools[index];
                  return FutureBuilder<int>(
                    future: _walletService.getCurrentBalance(),
                    builder: (context, walletSnapshot) {
                      final balance = walletSnapshot.data ?? 0;
                      final canAfford = balance >= pool.buyIn;
                      
                      return _buildQuickPlayOption(
                        pool.name,
                        '${pool.buyIn} BR',
                        '${pool.currentPlayers}/${pool.maxPlayers} players',
                        _getPoolColor(pool.tier ?? PoolTier.standard),
                        pool.buyIn,
                        canAfford,
                        poolId: pool.id,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Color _getPoolColor(PoolTier tier) {
    switch (tier) {
      case PoolTier.beginner:
        return Colors.blue;
      case PoolTier.standard:
        return Colors.green;
      case PoolTier.high:
        return Colors.orange;
      case PoolTier.vip:
        return Colors.purple;
    }
  }

  Widget _buildQuickPlayOption(
    String title,
    String buyIn,
    String players,
    Color color,
    int brRequired,
    bool canAfford, {
    String? poolId,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            '${brRequired}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buy-in: $buyIn • $players'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: 0.7,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
            ),
            const SizedBox(height: 2),
            Text(
              'Pool 70% full',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: canAfford && poolId != null ? () => _joinPool(title, brRequired, poolId) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canAfford ? color : Colors.grey,
          ),
          child: Text(
            canAfford ? 'Join' : 'Need BR',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionalTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRegionalSection('Neighborhood', RegionalLevel.neighborhood),
        _buildRegionalSection('City', RegionalLevel.city),
        _buildRegionalSection('State', RegionalLevel.state),
        _buildRegionalSection('National', RegionalLevel.national),
      ],
    );
  }

  Widget _buildRegionalSection(String title, RegionalLevel level) {
    return StreamBuilder<List<Pool>>(
      stream: _poolService.getRegionalPools(gameId ?? '', level.toString().split('.').last),
      builder: (context, snapshot) {
        final pools = snapshot.data ?? [];
        
        if (pools.isEmpty) {
          return const SizedBox.shrink();
        }
        
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
            ...pools.map((pool) => _buildPoolCard(
              pool.name,
              '${pool.buyIn} BR',
              '${pool.currentPlayers}/${pool.maxPlayers} players',
              _getRegionalColor(level),
              poolId: pool.id,
              buyInAmount: pool.buyIn,
            )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
  
  Color _getRegionalColor(RegionalLevel level) {
    switch (level) {
      case RegionalLevel.neighborhood:
        return Colors.teal;
      case RegionalLevel.city:
        return Colors.blue;
      case RegionalLevel.state:
        return Colors.purple;
      case RegionalLevel.national:
        return Colors.green;
    }
  }

  Widget _buildPrivateTab() {
    final TextEditingController _codeController = TextEditingController();
    
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
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: 'Enter pool code',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _joinWithCode(_codeController.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              const Text(
                'Friend Pools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Pool>>(
                stream: _poolService.getFriendPools(gameId ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final pools = snapshot.data ?? [];
                  
                  if (pools.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No friend pools available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    children: pools.map<Widget>((pool) => _buildFriendPoolCard(
                      pool.name,
                      '${pool.buyIn} BR',
                      '${pool.currentPlayers}/${pool.maxPlayers} friends',
                      pool.code ?? '',
                      poolId: pool.id,
                      buyInAmount: pool.buyIn,
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendPoolCard(String name, String buyIn, String friends, String code, {
    String? poolId,
    int? buyInAmount,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.people, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buy-in: $buyIn • $friends'),
            const SizedBox(height: 2),
            if (code.isNotEmpty)
              Text(
                'Code: $code',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: poolId != null && buyInAmount != null 
              ? () => _joinPool(name, buyInAmount, poolId)
              : null,
          child: const Text('Join'),
        ),
      ),
    );
  }

  Widget _buildTournamentTab() {
    return StreamBuilder<List<Pool>>(
      stream: _poolService.getTournamentPools(gameId ?? ''),
      builder: (context, snapshot) {
        final pools = snapshot.data ?? [];
        
        // Find the main championship if it exists
        Pool? championship = pools.isNotEmpty ? pools.first : null;
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (championship != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      championship.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prize Pool: ${championship.prizePool} BR',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _joinPool(
                        championship.name,
                        championship.buyIn,
                        championship.id,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange,
                      ),
                      child: Text('Enter Tournament (${championship.buyIn} BR)'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ...pools.skip(1).map((pool) => _buildTournamentCard(
              pool.name,
              '${pool.buyIn} BR',
              '${pool.currentPlayers}/${pool.maxPlayers} players',
              _formatPrizeStructure(pool.prizeStructure),
              poolId: pool.id,
              buyInAmount: pool.buyIn,
            )),
            if (pools.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.emoji_events, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No tournaments available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  String _formatPrizeStructure(Map<String, dynamic>? prizeStructure) {
    if (prizeStructure == null || prizeStructure.isEmpty) {
      return 'Winner takes all';
    }
    final firstPrize = prizeStructure['1'] ?? 0;
    return '1st: $firstPrize BR';
  }

  Widget _buildTournamentCard(String title, String buyIn, String players, String prize, {
    String? poolId,
    int? buyInAmount,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.amber,
          child: Icon(Icons.emoji_events, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entry: $buyIn • $players'),
            const SizedBox(height: 2),
            Text(
              '🏆 $prize',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: poolId != null && buyInAmount != null
              ? () => _joinPool(title, buyInAmount, poolId)
              : null,
        ),
      ),
    );
  }

  Widget _buildPoolCard(String name, String buyIn, String players, Color color, {
    String? poolId,
    int? buyInAmount,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.pool, color: color),
        ),
        title: Text(name),
        subtitle: Text('Buy-in: $buyIn • $players'),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: poolId != null && buyInAmount != null
              ? () => _joinPool(name, buyInAmount, poolId)
              : null,
        ),
      ),
    );
  }

  void _joinPool(String poolName, int buyIn, String poolId) async {
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
              'Join $poolName?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Entry: $buyIn BR',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Your balance after: ${500 - buyIn} BR',
              style: const TextStyle(fontSize: 14),
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
                      
                      // Actually join the pool
                      final success = await _poolService.joinPool(poolId, buyIn);
                      
                      if (success) {
                        // Navigate to bet selection
                        Navigator.pushNamed(
                          context,
                          '/bet-selection',
                          arguments: {
                            'gameTitle': widget.gameTitle,
                            'sport': widget.sport,
                            'poolName': poolName,
                            'poolId': poolId,
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to join pool. Please try again.'),
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

  void _createPrivatePool() {
    // TODO: Navigate to create pool screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create Private Pool - Coming Soon')),
    );
  }
  
  void _joinWithCode(String code) async {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a pool code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
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

  void _createPoolForGame(PoolType type) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Create a new pool with default settings (10 players max)
      final poolId = await _poolService.createPool(
        gameId: gameId ?? '',
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        type: type,
        name: '${widget.gameTitle} - ${type.toString().split('.').last.toUpperCase()}',
        buyIn: 25, // Default buy-in
        maxPlayers: 10, // Default 10 players as requested
        minPlayers: 2, // Minimum to start
      );

      // Close loading dialog
      Navigator.pop(context);

      if (poolId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pool created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the pools list
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create pool. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating pool: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}