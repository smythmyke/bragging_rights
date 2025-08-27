import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _countdownTimer;
  Duration _gameStartCountdown = const Duration(hours: 1, minutes: 30);
  
  // Wagering
  String? _selectedTeam;
  int _wagerAmount = 50;
  final TextEditingController _customWagerController = TextEditingController();
  
  // Community picks - will be populated from real data
  final double _team1Percentage = 0;
  double get _team2Percentage => 0;

  // Odds - will be populated from real data
  final Map<String, double> _odds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_gameStartCountdown.inSeconds > 0) {
            _gameStartCountdown = Duration(seconds: _gameStartCountdown.inSeconds - 1);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    _customWagerController.dispose();
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
        title: const Text('Game Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Wager'),
            Tab(text: 'Stats'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWagerTab(),
          _buildStatsTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  Widget _buildWagerTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Game Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Countdown Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _gameStartCountdown.inMinutes < 30 ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Game starts in: ${_formatDuration(_gameStartCountdown)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Teams
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.sports, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Game data loading...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Team information will appear when connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Community Picks
          _buildCommunityPicks(),
          
          // Wager Amount Selection
          _buildWagerAmountSection(),
          
          // Potential Payout
          if (_selectedTeam != null) _buildPotentialPayout(),
          
          // Place Wager Button
          _buildPlaceWagerButton(),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String team, String abbreviation, Color color, double odds) {
    final isSelected = _selectedTeam == team;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTeam = team;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              child: Text(
                abbreviation,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              team,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'x${odds.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPicks() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Community Picks',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: _team1Percentage.toInt(),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_team1Percentage.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _team2Percentage.toInt(),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_team2Percentage.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1,234 total wagers',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWagerAmountSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wager Amount',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildWagerChip(10),
              _buildWagerChip(25),
              _buildWagerChip(50),
              _buildWagerChip(100),
              _buildWagerChip(200),
              _buildCustomWagerChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWagerChip(int amount) {
    final isSelected = _wagerAmount == amount;
    final canAfford = amount <= 500; // Current balance
    
    return GestureDetector(
      onTap: canAfford
          ? () {
              setState(() {
                _wagerAmount = amount;
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : canAfford
                  ? Colors.white
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : canAfford
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Text(
          '$amount BR',
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : canAfford
                    ? Colors.black
                    : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomWagerChip() {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400, width: 2),
      ),
      child: TextField(
        controller: _customWagerController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Custom',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _wagerAmount = int.tryParse(value) ?? 0;
          });
        },
      ),
    );
  }

  Widget _buildPotentialPayout() {
    final odds = _odds[_selectedTeam] ?? 1.0;
    final payout = (_wagerAmount * odds).toInt();
    final profit = payout - _wagerAmount;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Potential Payout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Profit: +$profit BR',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          Text(
            '$payout BR',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceWagerButton() {
    final canPlaceWager = _selectedTeam != null && _wagerAmount > 0 && _wagerAmount <= 500;
    
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canPlaceWager ? _placeWager : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          canPlaceWager ? 'Place Wager ($_wagerAmount BR)' : 'Select Team & Amount',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No stats available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Game statistics will appear when data is available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, List<Widget> stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...stats,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label1, String label2, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label1, style: TextStyle(color: Colors.grey.shade600)),
          Text(label2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to start the conversation!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ].reversed.toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessage(String sender, String message, bool isMe, {bool isSystem = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSystem
              ? Colors.grey.shade200
              : isMe
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSystem)
              Text(
                sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isMe ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            Text(
              message,
              style: TextStyle(
                color: isSystem
                    ? Colors.grey.shade700
                    : isMe
                        ? Colors.white
                        : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _placeWager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wager Placed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('You wagered $_wagerAmount BR on $_selectedTeam'),
            const SizedBox(height: 8),
            Text(
              'Good luck!',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}