import 'package:flutter/material.dart';
import 'dart:async';

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
  String _selectedPoolType = 'quick';
  Timer? _countdownTimer;
  Duration _poolCloseCountdown = const Duration(minutes: 15, seconds: 30);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startCountdownTimer();
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuickPlayOption(
                'Beginner Pool',
                '10-25 BR',
                '234 players',
                Colors.blue,
                10,
                true,
              ),
              _buildQuickPlayOption(
                'Standard Pool',
                '50 BR',
                '156 players',
                Colors.green,
                50,
                true,
              ),
              _buildQuickPlayOption(
                'High Stakes',
                '200 BR',
                '45 players',
                Colors.orange,
                200,
                true,
              ),
              _buildQuickPlayOption(
                'VIP Pool',
                '500 BR',
                '12 players',
                Colors.purple,
                500,
                false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPlayOption(
    String title,
    String buyIn,
    String players,
    Color color,
    int brRequired,
    bool canAfford,
  ) {
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
          onPressed: canAfford ? () => _joinPool(title, brRequired) : null,
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
        _buildRegionalSection('Neighborhood (Zip: 10001)', [
          _buildPoolCard('Local Champions', '25 BR', '8/20 players', Colors.teal),
          _buildPoolCard('Block Party Pool', '10 BR', '15/30 players', Colors.indigo),
        ]),
        _buildRegionalSection('City (New York)', [
          _buildPoolCard('NYC Elite', '100 BR', '45/100 players', Colors.red),
          _buildPoolCard('Big Apple Showdown', '50 BR', '78/150 players', Colors.blue),
        ]),
        _buildRegionalSection('State (New York)', [
          _buildPoolCard('Empire State Pool', '75 BR', '234/500 players', Colors.purple),
        ]),
        _buildRegionalSection('National', [
          _buildPoolCard('USA Championship', '200 BR', '1,234/5,000 players', Colors.green),
        ]),
      ],
    );
  }

  Widget _buildRegionalSection(String title, List<Widget> pools) {
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
        ...pools,
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
              _buildFriendPoolCard('Mike\'s Pool', '50 BR', '5/10 friends', 'MIK123'),
              _buildFriendPoolCard('Office League', '25 BR', '12/20 friends', 'OFF456'),
              _buildFriendPoolCard('Family Throwdown', '10 BR', '8/15 friends', 'FAM789'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendPoolCard(String name, String buyIn, String friends, String code) {
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
          onPressed: () => _joinPool(name, 50),
          child: const Text('Join'),
        ),
      ),
    );
  }

  Widget _buildTournamentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              const Text(
                'Championship Tournament',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Top 3 win massive BR prizes!',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange,
                ),
                child: const Text('Enter Tournament (100 BR)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTournamentCard('Weekly Championship', '50 BR', '128/256 players', '1st: 5000 BR'),
        _buildTournamentCard('Daily Bracket', '25 BR', '45/64 players', '1st: 1000 BR'),
        _buildTournamentCard('Survivor Pool', '100 BR', '89/100 players', 'Last one standing wins all'),
      ],
    );
  }

  Widget _buildTournamentCard(String title, String buyIn, String players, String prize) {
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
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildPoolCard(String name, String buyIn, String players, Color color) {
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
          onPressed: () => _joinPool(name, 50),
        ),
      ),
    );
  }

  void _joinPool(String poolName, int buyIn) {
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
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/bet-selection',
                        arguments: {
                          'gameTitle': widget.gameTitle,
                          'sport': widget.sport,
                          'poolName': poolName,
                        },
                      );
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
}