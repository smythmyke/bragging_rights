import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/bet_service.dart';
import '../../models/game_model.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stats
  int _totalWins = 0;
  int _totalLosses = 0;
  double _totalProfit = 0;
  int _currentStreak = 0;

  // Cache for game details
  final Map<String, GameModel?> _gameCache = {};
  
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

      // Run one-time cleanup of expired bets (30+ days old)
      _runOneTimeCleanup();
    } else {
      debugPrint('[ActiveBetsScreen] No user logged in');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runOneTimeCleanup() async {
    try {
      debugPrint('🧹 Running one-time cleanup of expired bets...');

      final result = await _betService.cleanupExpiredBets();

      debugPrint('✅ Cleanup complete:');
      debugPrint('   Total old bets found: ${result['total']}');
      debugPrint('   Expired: ${result['expired']}');
      debugPrint('   Refunded: ${result['totalRefundAmount']} BR');
      debugPrint('   Errors: ${result['errors']}');

      // Show a brief snackbar if bets were cleaned up
      if (result['expired'] > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cleaned up ${result['expired']} old bets. Refunded ${result['totalRefundAmount']} BR',
            ),
            backgroundColor: AppTheme.neonGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cleanup failed: $e');
      // Silent fail - don't show error to user since this is automatic
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
      } else if (bet.status == 'lost' || bet.status == 'cancelled' || bet.status == 'cashed_out') {
        // Count cancellations and cash-outs as losses
        _totalLosses++;
        // For cancelled/cashed out: Loss is the penalty amount (wager - refund)
        if (bet.status == 'cancelled' || bet.status == 'cashed_out') {
          // User gave up on the bet, counts as a loss
          // Profit impact: they lost the wager but got some/all back (handled by wallet)
          // Don't double-count in profit calculation
        } else {
          // Regular loss: lost full wager
          _totalProfit -= bet.wagerAmount;
        }
      }
      // Note: 'expired' bets are refunded in full, so they don't count as wins or losses
    }

    // Calculate current streak
    if (pastBets.isNotEmpty) {
      final sortedBets = List<BetModel>.from(pastBets)
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

      // Filter out expired/refunded bets for streak calculation
      final betsForStreak = sortedBets.where((b) =>
        b.status == 'won' || b.status == 'lost' || b.status == 'cancelled' || b.status == 'cashed_out'
      ).toList();

      if (betsForStreak.isNotEmpty) {
        final streakType = betsForStreak.first.status == 'won';
        for (final bet in betsForStreak) {
          if ((bet.status == 'won') == streakType) {
            _currentStreak++;
          } else {
            break;
          }
        }
        if (!streakType) _currentStreak = -_currentStreak;
      }
    }
  }

  /// Fetch game details for a bet
  Future<GameModel?> _fetchGameDetails(String gameId) async {
    // Check cache first
    if (_gameCache.containsKey(gameId)) {
      return _gameCache[gameId];
    }

    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      if (gameDoc.exists) {
        final game = GameModel.fromFirestore(gameDoc);
        _gameCache[gameId] = game;
        return game;
      }
    } catch (e) {
      debugPrint('Error fetching game details for $gameId: $e');
    }

    _gameCache[gameId] = null;
    return null;
  }

  /// Format game time display
  String _formatGameTime(DateTime gameTime, String status) {
    final now = DateTime.now();
    final difference = gameTime.difference(now);

    if (status == 'final') {
      // Game ended
      final formatter = DateFormat('MMM d, h:mm a');
      return formatter.format(gameTime);
    } else if (status == 'live') {
      return 'Live Now';
    } else {
      // Scheduled game
      if (difference.isNegative) {
        // Game time has passed but status not updated
        return 'Pending Settlement';
      } else if (difference.inHours < 24) {
        return 'Starts in ${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
      } else {
        final formatter = DateFormat('MMM d, h:mm a');
        return formatter.format(gameTime);
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
          debugPrint('🔄 [ACTIVE BETS TAB] Waiting for active bets stream...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('❌ [ACTIVE BETS TAB] Error loading active bets: ${snapshot.error}');
          return Center(
            child: Text('Error loading bets: ${snapshot.error}'),
          );
        }

        final activeBets = snapshot.data ?? [];
        debugPrint('📊 [ACTIVE BETS TAB] Received ${activeBets.length} active bets');

        // Log each bet's details
        for (int i = 0; i < activeBets.length; i++) {
          final bet = activeBets[i];
          debugPrint('   [$i] ${bet.gameTitle}');
          debugPrint('       Status: ${bet.status}');
          debugPrint('       Game ID: ${bet.gameId}');
          debugPrint('       Placed: ${bet.placedAt}');
          debugPrint('       Wager: ${bet.wagerAmount} BR');
        }

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
            return FutureBuilder<GameModel?>(
              future: _fetchGameDetails(bet.gameId),
              builder: (context, gameSnapshot) {
                final game = gameSnapshot.data;
                final gameStatus = game?.status ?? 'scheduled';

                return GestureDetector(
                  onLongPress: () async {
                    // Haptic feedback
                    HapticFeedback.mediumImpact();
                    await _showCancelBetDialog(context, bet, gameStatus);
                  },
                  child: Card(
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
                        // Display game time and status
                        if (game != null) ...[
                          Row(
                            children: [
                              Icon(
                                game.status == 'live'
                                    ? PhosphorIconsRegular.broadcast
                                    : game.status == 'final'
                                        ? PhosphorIconsRegular.checkCircle
                                        : PhosphorIconsRegular.clock,
                                size: 12,
                                color: game.status == 'live'
                                    ? AppTheme.errorPink
                                    : game.status == 'final'
                                        ? AppTheme.neonGreen
                                        : AppTheme.primaryCyan.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatGameTime(game.gameTime, game.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: game.status == 'live'
                                      ? AppTheme.errorPink
                                      : game.status == 'final'
                                          ? AppTheme.neonGreen
                                          : AppTheme.primaryCyan.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
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
                  ),
                );
              },
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
          debugPrint('🔄 [PAST BETS TAB] Waiting for past bets stream...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('❌ [PAST BETS TAB] Error loading past bets: ${snapshot.error}');
          return Center(
            child: Text('Error loading bet history: ${snapshot.error}'),
          );
        }

        final pastBets = snapshot.data ?? [];
        debugPrint('📊 [PAST BETS TAB] Received ${pastBets.length} past bets');

        // Log each past bet's details
        for (int i = 0; i < pastBets.length; i++) {
          final bet = pastBets[i];
          debugPrint('   [$i] ${bet.gameTitle}');
          debugPrint('       Status: ${bet.status}');
          debugPrint('       Game ID: ${bet.gameId}');
          debugPrint('       Placed: ${bet.placedAt}');
          debugPrint('       Settled: ${bet.settledAt}');
          debugPrint('       Wager: ${bet.wagerAmount} BR | Payout: ${bet.potentialPayout} BR');
        }

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

            return GestureDetector(
              onLongPress: () async {
                // Haptic feedback
                HapticFeedback.mediumImpact();
                await _showHideBetDialog(context, bet);
              },
              child: Card(
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
                    // Display settlement date
                    if (bet.settledAt != null) ...[
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.calendarCheck,
                            size: 12,
                            color: AppTheme.primaryCyan.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Settled ${DateFormat('MMM d, h:mm a').format(bet.settledAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryCyan.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'Wager: ${bet.wagerAmount} BR • ${bet.status == 'won' ? 'Won: ${bet.potentialPayout} BR' : bet.status == 'lost' ? 'Lost' : bet.status == 'expired' ? 'Refunded: ${bet.wagerAmount} BR' : bet.status == 'cashed_out' ? 'Cashed Out (25% penalty)' : 'Cancelled'}',
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
      case 'expired':
        return Colors.orange;
      case 'cashed_out':
        return Colors.deepOrange;
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
      case 'expired':
        return 'REFUNDED';
      case 'cashed_out':
        return 'CASHED OUT';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

  /// Show dialog for cancelling/cashing out active bet
  Future<void> _showCancelBetDialog(BuildContext context, BetModel bet, String gameStatus) async {
    // Block deletion if game has finished
    if (gameStatus == 'final') {
      _showCannotDeleteDialog(context);
      return;
    }

    // Calculate penalty
    final isLive = gameStatus == 'live';
    final penaltyPercent = isLive ? 25 : 0;
    final penaltyAmount = (bet.wagerAmount * (penaltyPercent / 100)).round();
    final refundAmount = bet.wagerAmount - penaltyAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLive ? '⚠️ Cash Out Early?' : 'Cancel Bet?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bet.gameTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            if (isLive)
              Text(
                'Status: LIVE',
                style: TextStyle(
                  color: AppTheme.errorPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16),
            Text('Original Wager: ${bet.wagerAmount} BR'),
            if (isLive) ...[
              Text(
                'Cash Out Penalty: -$penaltyAmount BR (25%)',
                style: TextStyle(color: AppTheme.errorPink),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'You\'ll Receive: $refundAmount BR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isLive ? AppTheme.warningAmber : AppTheme.neonGreen,
              ),
            ),
            if (isLive) ...[
              const SizedBox(height: 12),
              Text(
                '⚠️ This cannot be undone',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningAmber,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isLive ? 'Keep Betting' : 'Keep Bet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? AppTheme.errorPink : AppTheme.neonGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(isLive ? 'Cash Out' : 'Cancel Bet'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _processCancellation(bet.id, gameStatus);
    }
  }

  /// Show error dialog when trying to delete finished game
  void _showCannotDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Cannot Delete'),
        content: const Text(
          'This game has finished.\n\n'
          'Settlement is pending. Please wait for automatic settlement or expiration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Process bet cancellation
  Future<void> _processCancellation(String betId, String gameStatus) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing cancellation...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final result = await _betService.cancelBet(betId, gameStatus);
      final refundAmount = result['refundAmount'] as int;
      final penaltyAmount = result['penaltyAmount'] as int;
      final status = result['status'] as String;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'cashed_out'
                  ? 'Cashed out! Refunded $refundAmount BR (${penaltyAmount} BR penalty)'
                  : 'Bet cancelled! Refunded $refundAmount BR',
            ),
            backgroundColor: AppTheme.neonGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorPink,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show dialog for hiding past bet
  Future<void> _showHideBetDialog(BuildContext context, BetModel bet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from History?'),
        content: const Text(
          'This will hide this bet from your history.\n\n'
          'Your stats and wallet will NOT be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _processHideBet(bet.id);
    }
  }

  /// Process hiding a bet
  Future<void> _processHideBet(String betId) async {
    try {
      // Haptic feedback
      HapticFeedback.lightImpact();

      await _betService.hideBet(betId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bet hidden from history'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorPink,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

}