import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/pool_service.dart';
import '../../services/wallet_service.dart';
import '../../services/game_odds_enrichment_service.dart';
import '../../models/pool_model.dart';
import '../../models/game_model.dart';
import '../../utils/sport_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PoolSelectionScreen extends StatefulWidget {
  final String? gameId;  // Real game ID from ESPN/Firestore
  final String gameTitle;
  final String sport;
  
  const PoolSelectionScreen({
    super.key,
    this.gameId,
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
  final GameOddsEnrichmentService _oddsService = GameOddsEnrichmentService();
  String _selectedPoolType = 'quick';
  Timer? _countdownTimer;
  Duration _poolCloseCountdown = const Duration(minutes: 15, seconds: 30);
  String? gameId;
  bool _isLoadingOdds = false;
  
  // Cache wallet balance to prevent flickering
  int? _cachedBalance;
  StreamSubscription? _balanceSubscription;
  
  // Cache streams to prevent recreation
  Stream<List<Pool>>? _quickPlayStream;
  Stream<List<Pool>>? _tournamentStream;
  
  // Track user's joined pools and submission status
  Set<String> _userJoinedPools = {};
  Map<String, bool> _userPoolSubmissions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startCountdownTimer();
    // Use the real game ID passed from navigation, or generate one as fallback
    gameId = widget.gameId ?? '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase();
    
    // Initialize streams once to prevent recreation
    _quickPlayStream = _poolService.getPoolsByType(gameId!, PoolType.quick).distinct();
    _tournamentStream = _poolService.getTournamentPools(gameId!).distinct();
    
    // Load initial balance and listen for changes
    _loadBalance();
    _listenToBalanceChanges();
    
    // Load user's pool status
    _loadUserPoolStatus();
    
    // Load odds on-demand when user enters pool selection
    if (widget.gameId != null) {
      _loadOddsOnDemand();
    }
  }
  
  void _loadBalance() async {
    final balance = await _walletService.getCurrentBalance();
    if (mounted) {
      setState(() {
        _cachedBalance = balance;
      });
    }
  }
  
  Future<void> _loadOddsOnDemand() async {
    if (_isLoadingOdds) return;
    
    setState(() {
      _isLoadingOdds = true;
    });
    
    try {
      // Check if odds already exist for this game
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .get();
      
      if (gameDoc.exists) {
        final data = gameDoc.data();
        final oddsAvailable = data?['oddsAvailable'] as Map<String, dynamic>?;
        final oddsLastUpdated = data?['oddsLastUpdated'] as Timestamp?;
        
        // Check if odds are missing or stale (older than 30 minutes)
        bool needsUpdate = false;
        
        if (oddsAvailable == null || 
            !(oddsAvailable['moneyline'] == true || 
              oddsAvailable['spread'] == true || 
              oddsAvailable['total'] == true)) {
          needsUpdate = true;
          debugPrint('📊 No odds available for game ${widget.gameId}, fetching...');
        } else if (oddsLastUpdated != null) {
          final lastUpdate = oddsLastUpdated.toDate();
          final minutesSinceUpdate = DateTime.now().difference(lastUpdate).inMinutes;
          if (minutesSinceUpdate > 30) {
            needsUpdate = true;
            debugPrint('📊 Odds are ${minutesSinceUpdate} minutes old, refreshing...');
          }
        }
        
        if (needsUpdate) {
          // Fetch fresh odds
          final gameModel = await _reconstructGameModel(gameDoc);
          if (gameModel != null) {
            await _oddsService.enrichGameWithOdds(gameModel);
            debugPrint('✅ Odds loaded on-demand for ${widget.gameTitle}');
          }
        } else {
          debugPrint('✅ Using cached odds for ${widget.gameTitle}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading odds on-demand: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOdds = false;
        });
      }
    }
  }
  
  // Helper to reconstruct GameModel from Firestore document
  dynamic _reconstructGameModel(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      // Import GameModel if needed
      return GameModel(
        id: doc.id,
        sport: data['sport'] ?? widget.sport,
        homeTeam: data['homeTeam'] ?? '',
        awayTeam: data['awayTeam'] ?? '',
        gameTime: data['gameTime'] is Timestamp 
          ? (data['gameTime'] as Timestamp).toDate()
          : data['gameTime'] is int
            ? DateTime.fromMillisecondsSinceEpoch(data['gameTime'])
            : DateTime.now(),
        status: data['status'] ?? 'scheduled',
        homeScore: data['homeScore'],
        awayScore: data['awayScore'],
        venue: data['venue'],
      );
    } catch (e) {
      debugPrint('Error reconstructing game model: $e');
      return null;
    }
  }
  
  Future<void> _loadUserPoolStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Get user's joined pools from the user_pools collection
      final userPoolsSnapshot = await FirebaseFirestore.instance
          .collection('user_pools')
          .where('userId', isEqualTo: user.uid)
          .where('gameId', isEqualTo: widget.gameId)
          .get();
      
      final joinedPools = <String>{};
      final submissions = <String, bool>{};
      
      debugPrint('Found ${userPoolsSnapshot.docs.length} pools for user ${user.uid} and game ${widget.gameId}');
      
      for (final doc in userPoolsSnapshot.docs) {
        final poolId = doc.data()['poolId'] as String?;
        if (poolId != null) {
          joinedPools.add(poolId);
          
          // Check if user has submitted selections
          final hasSubmitted = doc.data()['hasSubmittedSelections'] ?? false;
          submissions[poolId] = hasSubmitted;
          
          debugPrint('User joined pool $poolId, hasSubmitted: $hasSubmitted');
        }
      }
      
      if (mounted) {
        setState(() {
          _userJoinedPools = joinedPools;
          _userPoolSubmissions = submissions;
        });
      }
    } catch (e) {
      debugPrint('Error loading user pool status: $e');
    }
  }
  
  void _listenToBalanceChanges() {
    // Listen to wallet balance changes from a stream if available
    // For now, we'll just update periodically less frequently
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _loadBalance();
    });
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
    debugPrint('=== POOL SELECTION SCREEN DISPOSING ===');
    debugPrint('Tab controller: ${_tabController}');
    debugPrint('Countdown timer: ${_countdownTimer}');
    debugPrint('Balance subscription: ${_balanceSubscription}');
    
    _tabController.dispose();
    _countdownTimer?.cancel();
    _balanceSubscription?.cancel();
    super.dispose();
    
    debugPrint('=== POOL SELECTION SCREEN DISPOSED ===');
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
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
      body: _isLoadingOdds 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading latest odds...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        : TabBarView(
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
            stream: _quickPlayStream,
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
                  final balance = _cachedBalance ?? 0;
                  final canAfford = balance >= pool.buyIn;
                  final isJoined = _userJoinedPools.contains(pool.id);
                  final hasSubmitted = _userPoolSubmissions[pool.id] ?? false;
                  final isFull = pool.currentPlayers >= pool.maxPlayers;
                  
                  return _buildQuickPlayOption(
                    pool.name,
                    '${pool.buyIn} BR',
                    '${pool.currentPlayers}/${pool.maxPlayers} players',
                    _getPoolColor(pool.tier ?? PoolTier.standard),
                    pool.buyIn,
                    canAfford,
                    poolId: pool.id,
                    isJoined: isJoined,
                    hasSubmitted: hasSubmitted,
                    isFull: isFull,
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
    bool isJoined = false,
    bool hasSubmitted = false,
    bool isFull = false,
  }) {
    // Parse current and max players from the string
    final playerParts = players.split('/');
    int currentPlayers = 0;
    int maxPlayers = 10;
    
    if (playerParts.length == 2) {
      try {
        currentPlayers = int.parse(playerParts[0].trim());
        maxPlayers = int.parse(playerParts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {
        // Default values if parsing fails
      }
    }
    
    final progress = maxPlayers > 0 ? currentPlayers / maxPlayers : 0.0;
    final percentage = (progress * 100).round();
    
    // Determine button state and text
    String buttonText = 'Join';
    bool isEnabled = canAfford && poolId != null && !isFull;
    Color buttonColor = color;
    VoidCallback? onPressed;
    
    if (isFull && !isJoined) {
      buttonText = 'Full';
      isEnabled = false;
      buttonColor = Colors.grey;
    } else if (isJoined && !hasSubmitted) {
      buttonText = 'Complete';
      isEnabled = true;
      buttonColor = Colors.orange;
      onPressed = () => _completeSelections(poolId!);
    } else if (isJoined && hasSubmitted) {
      buttonText = 'Joined';
      isEnabled = false;
      buttonColor = Colors.green;
    } else if (!canAfford) {
      buttonText = 'Need BR';
      isEnabled = false;
      buttonColor = Colors.grey;
    } else {
      onPressed = () => _joinPool(title, brRequired, poolId!);
    }
    
    // Determine card appearance based on state
    Color? cardColor;
    Color? borderColor;
    double borderWidth = 1.0;
    
    if (isJoined && hasSubmitted) {
      // Completed state - grayed out
      cardColor = Colors.grey[100];
    } else if (isJoined && !hasSubmitted) {
      // Joined but not completed - highlighted
      cardColor = Colors.orange.withOpacity(0.05);
      borderColor = Colors.orange;
      borderWidth = 2.0;
    } else if (isFull && !isJoined) {
      // Full pool - grayed out
      cardColor = Colors.grey[100];
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderColor != null 
          ? BorderSide(color: borderColor, width: borderWidth)
          : BorderSide.none,
      ),
      child: ListTile(
        enabled: !(isJoined && hasSubmitted), // Disable if completed
        leading: CircleAvatar(
          backgroundColor: isJoined && !hasSubmitted 
            ? Colors.orange.withOpacity(0.2)
            : (isFull && !isJoined ? Colors.grey : color).withOpacity(0.2),
          child: Text(
            '${brRequired}',
            style: TextStyle(
              color: isJoined && !hasSubmitted 
                ? Colors.orange
                : (isFull && !isJoined || (isJoined && hasSubmitted) ? Colors.grey : color),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: (isFull && !isJoined) || (isJoined && hasSubmitted) 
              ? Colors.grey[600] 
              : null,
            fontWeight: isJoined && !hasSubmitted ? FontWeight.bold : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    'Buy-in: $buyIn • $players',
                    style: TextStyle(
                      color: (isFull && !isJoined) || (isJoined && hasSubmitted) 
                        ? Colors.grey[500] 
                        : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (isFull && !isJoined) ...[  
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FULL',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isJoined && !hasSubmitted) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INCOMPLETE',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isJoined && hasSubmitted) ...[  
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(
                isJoined && hasSubmitted ? Colors.grey :
                isJoined && !hasSubmitted ? Colors.orange :
                isFull ? Colors.red : color
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isFull ? 'Pool 100% full' : 'Pool $percentage% full',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? buttonColor : Colors.grey[400],
          ),
          child: Text(
            buttonText,
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
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $title pools available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _createRegionalPool(level),
                      icon: const Icon(Icons.add_circle),
                      label: Text('Create $title Pool'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getRegionalColor(level),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
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
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buy-in: $buyIn • $friends',
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (code.isNotEmpty)
              Text(
                'Code: $code',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
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
      stream: _tournamentStream,
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
    // Parse current and max players from the string
    final playerParts = players.split('/');
    int currentPlayers = 0;
    int maxPlayers = 10;
    
    if (playerParts.length == 2) {
      try {
        currentPlayers = int.parse(playerParts[0].trim());
        maxPlayers = int.parse(playerParts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {
        // Default values if parsing fails
      }
    }
    
    final progress = maxPlayers > 0 ? currentPlayers / maxPlayers : 0.0;
    final percentage = (progress * 100).round();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.pool, color: color),
        ),
        title: Text(
          name,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buy-in: $buyIn • $players',
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
            ),
            const SizedBox(height: 2),
            Text(
              'Pool $percentage% full',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: poolId != null && buyInAmount != null
              ? () => _joinPool(name, buyInAmount, poolId)
              : null,
        ),
      ),
    );
  }

  void _completeSelections(String poolId) async {
    // Navigate to appropriate screen based on sport type
    if (SportUtils.isCombatSport(widget.sport)) {
      Navigator.pushNamed(
        context,
        '/fight-card-grid',
        arguments: {
          'gameId': widget.gameId,
          'gameTitle': widget.gameTitle,
          'sport': widget.sport,
          'poolId': poolId,
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        '/bet-selection',
        arguments: {
          'gameId': widget.gameId,
          'gameTitle': widget.gameTitle,
          'sport': widget.sport,
          'poolId': poolId,
        },
      );
    }
  }
  
  void _joinPool(String poolName, int buyIn, String poolId) async {
    try {
      // Add timeout to prevent infinite waiting
      final isInPool = await _poolService.isUserInPool(poolId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Network request timed out');
      });
      
      if (isInPool) {
        final hasSubmittedPicks = await _poolService.hasUserSubmittedPicks(poolId)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw TimeoutException('Network request timed out');
        });
      
        if (hasSubmittedPicks) {
          print('[POOL JOIN] User has already submitted picks, navigating to active bets');
          Navigator.pushNamed(context, '/active-bets');
        } else {
        print('[POOL JOIN] User has not submitted picks, checking sport type...');
        
        // Check if this is a combat sport
        if (SportUtils.isCombatSport(widget.sport)) {
          print('[POOL JOIN] Combat sport detected, navigating to fight card grid');
          Navigator.pushNamed(
            context,
            '/fight-card-grid',
            arguments: {
              'gameId': this.gameId ?? widget.gameId ?? '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase(),  // Pass the real game ID!
              'gameTitle': widget.gameTitle,
              'sport': widget.sport,
              'poolName': poolName,
              'poolId': poolId,
            },
          );
        } else {
          print('[POOL JOIN] Team sport detected, navigating to standard bet selection');
          Navigator.pushNamed(
            context,
            '/bet-selection',
            arguments: {
              'gameId': this.gameId ?? widget.gameId ?? '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase(),  // Pass the real game ID!
              'gameTitle': widget.gameTitle,
              'sport': widget.sport,
              'poolName': poolName,
              'poolId': poolId,
            },
          );
        }
        }
        return; // Exit early since user is already in pool
      }
    } catch (e) {
      // Handle any errors from the initial pool check
      print('[POOL JOIN] Error checking pool status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              'Your balance after: ${(_cachedBalance ?? 500) - buyIn} BR',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      print('[POOL JOIN] User cancelled join dialog');
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      print('[POOL JOIN] User confirmed - attempting to join pool...');
                      Navigator.pop(context);
                      
                      // Show loading indicator - Use root navigator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext dialogContext) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                      
                      try {
                        // Actually join the pool
                        print('[POOL JOIN] Calling pool service to join pool ID: $poolId');
                        final result = await _poolService.joinPoolWithResult(poolId, buyIn);
                        
                        // Hide loading - Use root navigator to ensure we pop the dialog
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                        
                        // Check if result is null
                        if (result == null) {
                          throw Exception('Failed to get response from pool service');
                        }
                        
                        if (result['success'] == true) {
                          print('[POOL JOIN] ✅ Successfully joined pool!');
                          print('[POOL JOIN] Navigating to bet selection screen...');
                          
                          // Update balance and pool status after successful join
                          _loadBalance();
                          await _loadUserPoolStatus();
                          
                          // Check if this is a combat sport
                          if (SportUtils.isCombatSport(widget.sport)) {
                            // Navigate to fight card grid for combat sports
                            Navigator.pushNamed(
                              context,
                              '/fight-card-grid',
                              arguments: {
                                'gameId': this.gameId ?? widget.gameId ?? '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase(),  // Pass the real game ID!
                                'gameTitle': widget.gameTitle,
                                'sport': widget.sport,
                                'poolName': poolName,
                                'poolId': poolId,
                              },
                            );
                          } else {
                            // Navigate to standard bet selection for team sports
                            Navigator.pushNamed(
                              context,
                              '/bet-selection',
                              arguments: {
                                'gameId': this.gameId ?? widget.gameId ?? '${widget.gameTitle}_${widget.sport}'.replaceAll(' ', '_').toLowerCase(),  // Pass the real game ID!
                                'gameTitle': widget.gameTitle,
                                'sport': widget.sport,
                                'poolName': poolName,
                                'poolId': poolId,
                              },
                            );
                          }
                        } else {
                          final errorCode = result['code'] ?? 'UNKNOWN_ERROR';
                          final errorMessage = result['message'] ?? 'Failed to join pool';
                          
                          print('[POOL JOIN] ❌ Failed to join pool - Code: $errorCode, Message: $errorMessage');
                          
                          // Show specific message for different error types
                          if (mounted) {
                            if (errorCode == 'ALREADY_IN_POOL') {
                              // This shouldn't happen anymore due to pre-check, but keep as fallback
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(errorMessage)),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                  action: SnackBarAction(
                                    label: 'Go to My Bets',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      if (mounted) {
                                        Navigator.pushNamed(context, '/active-bets');
                                      }
                                    },
                                  ),
                                ),
                              );
                            } else if (errorCode == 'POOL_FULL') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.block, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('This pool is full. Try another one!')),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else if (errorCode == 'INSUFFICIENT_BALANCE') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Not enough BR balance')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        print('[POOL JOIN] ❌ Exception occurred while joining pool: $e');
                        // Hide loading if still showing - Use root navigator to avoid context issues
                        if (mounted) {
                          try {
                            Navigator.of(context, rootNavigator: true).pop();
                          } catch (_) {
                            // Dialog may already be closed
                          }
                          
                          // Only show snackbar if widget is still mounted
                          // Use Future.delayed to ensure context is valid
                          if (mounted) {
                            Future.delayed(Duration.zero, () {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error joining pool: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            });
                          }
                        }
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

  void _createRegionalPool(RegionalLevel level) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final regionName = level.toString().split('.').last;
      // Create a new regional pool
      final poolId = await _poolService.createPool(
        gameId: gameId ?? '',
        gameTitle: widget.gameTitle,
        sport: widget.sport,
        type: PoolType.regional,
        name: '${widget.gameTitle} - $regionName REGIONAL',
        buyIn: 50, // Higher buy-in for regional
        maxPlayers: 20, // More players for regional
        minPlayers: 4,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (poolId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regional pool created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the pools list
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create regional pool. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error creating regional pool: $e');
      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
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
      builder: (BuildContext dialogContext) => const Center(
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
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

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
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating pool: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}