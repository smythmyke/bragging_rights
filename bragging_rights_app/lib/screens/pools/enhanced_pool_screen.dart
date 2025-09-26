import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/pool_service.dart';
import '../../services/wager_service.dart';
import '../../models/pool_model.dart';
import '../../models/game_model.dart';
import '../../widgets/br_app_bar.dart';
import '../../utils/sport_utils.dart';
import 'package:intl/intl.dart';

class EnhancedPoolScreen extends StatefulWidget {
  final String poolId;
  final String gameTitle;
  
  const EnhancedPoolScreen({
    super.key,
    required this.poolId,
    required this.gameTitle,
  });

  @override
  State<EnhancedPoolScreen> createState() => _EnhancedPoolScreenState();
}

class _EnhancedPoolScreenState extends State<EnhancedPoolScreen>
    with SingleTickerProviderStateMixin {
  final PoolService _poolService = PoolService();
  final WagerService _wagerService = WagerService();
  late TabController _tabController;
  
  Pool? _pool;
  GameModel? _game;
  bool _isLoading = true;
  bool _hasJoined = false;
  bool _hasWagered = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadPoolData();
  }

  Future<void> _loadPoolData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch pool data from Firestore
      final poolDoc = await FirebaseFirestore.instance
          .collection('pools')
          .doc(widget.poolId)
          .get();

      if (!poolDoc.exists) {
        throw Exception('Pool not found');
      }

      final pool = Pool.fromFirestore(poolDoc);

      // Fetch game data
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(pool.gameId)
          .get();

      GameModel? game;
      if (gameDoc.exists) {
        game = GameModel.fromFirestore(gameDoc.data()!, gameDoc.id);
      }

      // Check if current user has joined
      bool hasJoined = false;
      if (_currentUserId != null) {
        hasJoined = pool.playerIds.contains(_currentUserId);
      }

      setState(() {
        _pool = pool;
        _game = game;
        _hasJoined = hasJoined;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pool data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pool: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: BRAppBar(
        title: widget.gameTitle,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePool,
            tooltip: 'Share Pool',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Pool Header Card
                SliverToBoxAdapter(
                  child: _buildPoolHeader(theme),
                ),

                // Action Buttons
                SliverToBoxAdapter(
                  child: _buildActionButtons(theme),
                ),

                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Players'),
                        Tab(text: 'Activity'),
                      ],
                    ),
                  ),
                ),

                // Tab Content
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildPlayersTab(),
                      _buildActivityTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPoolHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pool Name & Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'High Stakes Pool',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PUBLIC POOL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // Pool Code
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'POOL CODE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'ABC123',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Prize Pool & Players
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: PhosphorIconsRegular.coins,
                label: 'Prize Pool',
                value: '500 BR',
                color: Colors.amber,
              ),
              _buildStatItem(
                icon: PhosphorIconsRegular.users,
                label: 'Players',
                value: '8/10',
                color: Colors.white,
              ),
              _buildStatItem(
                icon: PhosphorIconsRegular.timer,
                label: 'Closes In',
                value: '02:15:30',
                color: Colors.redAccent,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '80% Full',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '2 spots left',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (!_hasJoined) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _joinPool,
                icon: const Icon(PhosphorIconsRegular.signIn),
                label: const Text('Join Pool (50 BR)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            if (!_hasWagered)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _placeWager,
                  icon: const Icon(PhosphorIconsRegular.coins),
                  label: const Text('Place Wager'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _viewWager,
                  icon: const Icon(PhosphorIconsRegular.checkCircle),
                  label: const Text('Wager Placed'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _leavePool,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.red,
              ),
              child: const Icon(PhosphorIconsRegular.signOut),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Prize Structure
        _buildCard(
          title: 'Prize Structure',
          icon: PhosphorIconsRegular.trophy,
          child: Column(
            children: [
              _buildPrizeRow('1st Place', '250 BR', Colors.amber),
              _buildPrizeRow('2nd Place', '150 BR', Colors.grey),
              _buildPrizeRow('3rd Place', '100 BR', Colors.brown),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Pool Rules
        _buildCard(
          title: 'Pool Rules',
          icon: PhosphorIconsRegular.info,
          child: Column(
            children: [
              _buildRuleRow('Min Buy-in', '50 BR'),
              _buildRuleRow('Max Players', '10'),
              _buildRuleRow('Wager Deadline', '15 min before game'),
              _buildRuleRow('Settlement', 'Automatic after game'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Current Odds
        _buildCard(
          title: 'Community Picks',
          icon: PhosphorIconsRegular.chartBar,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'Community picks will appear when betting starts',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.primaries[index % Colors.primaries.length],
              child: Text('P${index + 1}'),
            ),
            title: Text('Player ${index + 1}'),
            subtitle: Text('Joined ${index + 1} hours ago'),
            trailing: index == 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CREATOR',
                      style: TextStyle(
                        color: Colors.amber[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text('50 BR'),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActivityItem(
          'Player 3 placed a wager',
          '5 minutes ago',
          PhosphorIconsRegular.coins,
          Colors.green,
        ),
        _buildActivityItem(
          'Player 7 joined the pool',
          '1 hour ago',
          PhosphorIconsRegular.userPlus,
          Colors.blue,
        ),
        _buildActivityItem(
          'Player 2 placed a wager',
          '2 hours ago',
          PhosphorIconsRegular.coins,
          Colors.green,
        ),
        _buildActivityItem(
          'Pool created by Player 1',
          '5 hours ago',
          PhosphorIconsRegular.sparkle,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeRow(String position, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.medal,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(position),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOddsRow(String team, String percentage, Color color) {
    final value = double.parse(percentage.replaceAll('%', '')) / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(team),
              Text(
                percentage,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Text(time),
      ),
    );
  }

  void _joinPool() async {
    if (_pool == null || _currentUserId == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Join the pool using the pool service
      final result = await _poolService.joinPoolWithResult(
        widget.poolId,
        _pool!.buyInAmount,
      );

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result != null && result['success'] == true) {
        setState(() => _hasJoined = true);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined pool!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload pool data to get updated state
        await _loadPoolData();
      } else {
        final errorMessage = result?['message'] ?? 'Failed to join pool';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      print('Error joining pool: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining pool: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _leavePool() async {
    if (_pool == null || _currentUserId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Leave Pool?'),
        content: const Text('Are you sure you want to leave this pool?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Leave the pool using the pool service
      await _poolService.leavePool(widget.poolId);

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _hasJoined = false;
        _hasWagered = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully left the pool'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Reload pool data to get updated state
      await _loadPoolData();
    } catch (e) {
      // Hide loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      print('Error leaving pool: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving pool: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _placeWager() {
    if (_pool == null || _game == null) return;

    // Check if this is a combat sport
    final sport = _game!.sport.toLowerCase();
    print('🎮 _placeWager called in EnhancedPoolScreen');
    print('   Sport: $sport');
    print('   Game ID: ${_game!.id}');
    print('   Game Title: ${widget.gameTitle}');
    print('   Pool Name: ${_pool!.name}');
    print('   Is Combat Sport: ${SportUtils.isCombatSport(sport)}');

    if (SportUtils.isCombatSport(sport)) {
      // Navigate to fight card grid for combat sports
      print('   ➡️ Navigating to /fight-card-grid');
      Navigator.pushNamed(
        context,
        '/fight-card-grid',
        arguments: {
          'gameId': _game!.id,
          'gameTitle': widget.gameTitle,
          'sport': sport,
          'poolName': _pool!.name,
          'poolId': widget.poolId,
        },
      );
    } else {
      // Navigate to standard bet selection for team sports
      print('   ➡️ Navigating to /bet-selection');
      Navigator.pushNamed(
        context,
        '/bet-selection',
        arguments: {
          'gameId': _game!.id,
          'gameTitle': widget.gameTitle,
          'sport': sport,
          'poolName': _pool!.name,
          'poolId': widget.poolId,
        },
      );
    }
  }

  void _viewWager() {
    Navigator.pushNamed(context, '/active-wagers');
  }

  void _sharePool() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pool code copied to clipboard!')),
    );
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}