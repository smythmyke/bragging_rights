import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';
import '../../services/sports_api_service.dart';
import '../../services/espn_direct_service.dart';
import '../../services/pool_data_service.dart';
import '../../services/wager_service.dart';
import '../../services/purchase_service.dart';
import '../../services/card_service.dart';
import '../../models/game_model.dart';
import '../../data/card_definitions.dart';
import '../premium/edge_screen.dart';
import '../cards/card_inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _countdownTimer;
  final Map<String, Duration> _countdowns = {};
  
  // Services
  final BetService _betService = BetService();
  final WalletService _walletService = WalletService();
  final SportsApiService _sportsApiService = SportsApiService();
  final ESPNDirectService _espnService = ESPNDirectService();
  final PoolDataService _poolService = PoolDataService();
  final WagerService _wagerService = WagerService();
  final PurchaseService _purchaseService = PurchaseService();
  final CardService _cardService = CardService();
  
  // Track games with bets
  List<String> _gamesWithBets = [];
  
  // Games data
  List<GameModel> _liveGames = [];
  List<GameModel> _todayGames = [];
  List<GameModel> _tomorrowGames = [];
  List<GameModel> _thisWeekGames = [];
  List<GameModel> _nextWeekGames = [];
  GameModel? _nextGame;
  bool _isLoadingGames = true;
  
  // Track expanded sports
  Set<String> _expandedSports = {};
  List<String> _userSports = []; // User's selected sports
  
  // Pool data
  List<Map<String, dynamic>> _userPools = [];
  List<Map<String, dynamic>> _featuredPools = [];
  List<Map<String, dynamic>> _quickJoinPools = [];
  bool _isLoadingPools = false;

  @override
  void initState() {
    super.initState();
    _initializeCountdowns();
    _startCountdownTimer();
    _loadGamesWithBets();
    _loadUserSportsPreferences();
    _loadGamesData();
    _loadPoolsData();
    _initializePurchaseService();
  }
  
  Future<void> _initializePurchaseService() async {
    await _purchaseService.initialize();
    if (mounted) {
      setState(() {
        // Trigger rebuild to show products
      });
    }
  }
  
  void _loadGamesWithBets() {
    _betService.getGamesWithBets().listen((games) {
      if (mounted) {
        setState(() {
          _gamesWithBets = games;
        });
      }
    });
  }

  Future<void> _loadPoolsData() async {
    setState(() {
      _isLoadingPools = true;
    });
    
    try {
      final userPools = await _poolService.getUserActivePools();
      final featuredPools = await _poolService.getFeaturedPools();
      final quickJoinPools = await _poolService.getQuickJoinPools();
      
      if (mounted) {
        setState(() {
          _userPools = userPools;
          _featuredPools = featuredPools;
          _quickJoinPools = quickJoinPools;
          _isLoadingPools = false;
        });
      }
    } catch (e) {
      print('Error loading pools: $e');
      if (mounted) {
        setState(() {
          _isLoadingPools = false;
        });
      }
    }
  }
  
  void _initializeCountdowns() {
    // Countdowns will be populated from real game data
  }
  
  Future<void> _loadUserSportsPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && userDoc.data()?['selectedSports'] != null) {
          setState(() {
            _userSports = List<String>.from(userDoc.data()!['selectedSports']);
          });
          print('User sports preferences loaded: $_userSports');
          // Reload games to apply sorting
          _loadGamesData();
        }
      }
    } catch (e) {
      print('Error loading sports preferences: $e');
    }
  }
  
  Future<void> _loadGamesData() async {
    setState(() {
      _isLoadingGames = true;
    });
    
    try {
      // Fetch directly from ESPN API for real-time data
      print('Fetching live sports data from ESPN...');
      
      // Load all games from ESPN
      final allGames = await _espnService.fetchAllGames();
      print('Fetched ${allGames.length} total games from ESPN');
      
      // Separate live games
      final liveGames = allGames.where((game) => game.status == 'live').toList();
      
      // Get all games (including scheduled)
      final now = DateTime.now();
      final allUpcomingGames = allGames
          .where((game) => game.gameTime.isAfter(now) || game.status == 'live')
          .toList();
      
      // Sort all games by time
      allUpcomingGames.sort((a, b) => a.gameTime.compareTo(b.gameTime));
      
      // Categorize games by time period
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final tomorrowStart = todayEnd.add(const Duration(seconds: 1));
      final tomorrowEnd = tomorrowStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      final thisWeekEnd = now.add(Duration(days: 7 - now.weekday));
      final nextWeekStart = thisWeekEnd.add(const Duration(days: 1));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 7));
      
      final todayGames = <GameModel>[];
      final tomorrowGames = <GameModel>[];
      final thisWeekGames = <GameModel>[];
      final nextWeekGames = <GameModel>[];
      GameModel? nextGame;
      
      for (final game in allUpcomingGames) {
        if (game.gameTime.isBefore(todayEnd)) {
          todayGames.add(game);
        } else if (game.gameTime.isBefore(tomorrowEnd)) {
          tomorrowGames.add(game);
        } else if (game.gameTime.isBefore(thisWeekEnd)) {
          thisWeekGames.add(game);
        } else if (game.gameTime.isBefore(nextWeekEnd)) {
          nextWeekGames.add(game);
        }
        
        // Track the very next game
        if (nextGame == null && game.gameTime.isAfter(now)) {
          nextGame = game;
        }
      }
      
      setState(() {
        _liveGames = liveGames;
        _todayGames = todayGames;
        _tomorrowGames = tomorrowGames;
        _thisWeekGames = thisWeekGames;
        _nextWeekGames = nextWeekGames;
        _nextGame = nextGame;
        _isLoadingGames = false;
        
        print('Live games: ${liveGames.length}');
        print('Today\'s games: ${todayGames.length}');
        print('Tomorrow\'s games: ${tomorrowGames.length}');
        
        // Initialize countdowns for today's games
        for (final game in todayGames) {
          _countdowns[game.id] = game.timeUntilGame;
        }
      });
    } catch (e) {
      print('Error loading games: $e');
      setState(() {
        _isLoadingGames = false;
      });
    }
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

  void _showPurchaseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Get BR Coins',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchase BR Coins to place bets and join pools',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final products = _purchaseService.getProducts();
                
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No products available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: products.map((product) {
                    final bool isPopular = product.id == 'br_coins_500';
                    final productInfo = _purchaseService.getProductInfo(product.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isPopular ? Colors.green : Colors.grey[300]!,
                          width: isPopular ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isPopular ? Colors.green.withOpacity(0.05) : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.pop(context);
                            
                            // Show loading dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            );
                            
                            try {
                              final success = await _purchaseService.purchaseProduct(product.id);
                              
                              // Close loading dialog
                              if (context.mounted) Navigator.pop(context);
                              
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully purchased ${productInfo?['coins'] ?? ''} BR!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              // Close loading dialog
                              if (context.mounted) Navigator.pop(context);
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Purchase failed: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.currencyCircleDollar,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${productInfo?['coins'] ?? ''} BR',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isPopular) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'POPULAR',
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
                                      const SizedBox(height: 4),
                                      Text(
                                        productInfo?['description'] ?? product.title,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  product.price,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getSportColor(String sport) {
    switch (sport.toUpperCase()) {
      case 'NFL':
        return Colors.blue;
      case 'NBA':
        return Colors.orange;
      case 'NHL':
        return Colors.cyan;
      case 'MLB':
        return Colors.red;
      case 'MMA':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  Color _getPoolCategoryColor(String category) {
    if (category.contains('Beginner')) return Colors.green[400]!;
    if (category.contains('Standard')) return Colors.blue[400]!;
    if (category.contains('High')) return Colors.purple[400]!;
    if (category.contains('Whale')) return Colors.red[400]!;
    return Colors.grey[400]!;
  }
  
  Widget _buildEmptyPoolsCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              PhosphorIconsRegular.empty,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
        title: Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/bragging_rights_logo.png',
            height: 75,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Power Cards Indicators
          StreamBuilder<UserCardInventory>(
            stream: _cardService.getUserCardInventory(),
            builder: (context, snapshot) {
              final inventory = snapshot.data ?? UserCardInventory.empty();
              
              return Row(
                children: [
                  // Offensive Cards
                  _buildCardIndicator(
                    icon: '🎯',
                    count: inventory.offensiveCount,
                    type: CardType.offensive,
                    context: context,
                  ),
                  const SizedBox(width: 4),
                  // Defensive Cards
                  _buildCardIndicator(
                    icon: '🛡️',
                    count: inventory.defensiveCount,
                    type: CardType.defensive,
                    context: context,
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
          // BR Balance Display
          InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = 4; // Navigate to More tab (index 4)
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.coins,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  StreamBuilder<int>(
                    stream: _walletService.getBalanceStream(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0;
                      return Text(
                        '$balance',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.bell),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildGamesTab(),
          _buildBetsTab(),
          _buildPoolsTab(),
          _buildEdgeTab(),
          _buildMoreTab(),
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
            icon: Icon(PhosphorIconsRegular.gameController),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.currencyDollar),
            label: 'Bets',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.trophy),
            label: 'Pools',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.lightning),
            label: 'Edge',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.dotsThreeOutline),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildGamesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadGamesData();
      },
      child: _isLoadingGames
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Loading games...'),
                  const SizedBox(height: 8),
                  Text(
                    'Fetching latest data from ESPN',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Next Game Alert (when no games today)
                  if (_liveGames.isEmpty && _todayGames.isEmpty && _nextGame != null)
                    _buildNextGameAlert(_nextGame!),
                  
                  // Live Now Section
                  if (_liveGames.isNotEmpty) ...[
                    _buildSectionHeader('🔴 Live Now', '${_liveGames.length} game${_liveGames.length != 1 ? 's' : ''} in progress'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _liveGames.length,
                        itemBuilder: (context, index) {
                          return _buildLiveGameCard(_liveGames[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Today's Games Section
                  if (_todayGames.isNotEmpty) ...[
                    _buildSectionHeader(
                      '📅 Today',
                      '${_todayGames.length} game${_todayGames.length != 1 ? 's' : ''} starting today',
                    ),
                    const SizedBox(height: 12),
                    _buildGamesListBySport(_todayGames, showCountdown: true),
                    const SizedBox(height: 24),
                  ] else if (_liveGames.isEmpty) ...[
                    // Show "No games today" only if there are no live games either
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              PhosphorIconsRegular.calendar,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No games scheduled for today',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_nextGame != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Next game: ${_formatGameDate(_nextGame!.gameTime)}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Tomorrow's Games Section
                  if (_tomorrowGames.isNotEmpty) ...[
                    _buildSectionHeader(
                      '🌅 Tomorrow',
                      _formatDate(DateTime.now().add(const Duration(days: 1))),
                    ),
                    const SizedBox(height: 12),
                    ..._tomorrowGames.take(5).map((game) => _buildGameCard(game, showDate: false)),
                    if (_tomorrowGames.length > 5)
                      TextButton(
                        onPressed: () {
                          // TODO: Show all tomorrow's games
                        },
                        child: Text('View all ${_tomorrowGames.length} games →'),
                      ),
                    const SizedBox(height: 24),
                  ],
                  
                  // This Week Section
                  if (_thisWeekGames.isNotEmpty) ...[
                    _buildSectionHeader(
                      '📆 This Week',
                      '${_thisWeekGames.length} games',
                    ),
                    const SizedBox(height: 12),
                    ..._thisWeekGames.take(5).map((game) => _buildGameCard(game, showDate: true)),
                    if (_thisWeekGames.length > 5)
                      TextButton(
                        onPressed: () {
                          // TODO: Show all this week's games
                        },
                        child: Text('View all ${_thisWeekGames.length} games →'),
                      ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Next Week Section
                  if (_nextWeekGames.isNotEmpty) ...[
                    _buildSectionHeader(
                      '📅 Next Week',
                      '${_nextWeekGames.length} games scheduled',
                    ),
                    const SizedBox(height: 12),
                    ..._nextWeekGames.take(3).map((game) => _buildGameCard(game, showDate: true)),
                    if (_nextWeekGames.length > 3)
                      TextButton(
                        onPressed: () {
                          _showAllGames(
                            context,
                            _nextWeekGames,
                            'Next Week\'s Games',
                          );
                        },
                        child: Text('View all ${_nextWeekGames.length} games →'),
                      ),
                  ],
                  
                  // If no games at all
                  if (_liveGames.isEmpty && 
                      _todayGames.isEmpty && 
                      _tomorrowGames.isEmpty && 
                      _thisWeekGames.isEmpty && 
                      _nextWeekGames.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              PhosphorIconsRegular.warning,
                              size: 64,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No games available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Games data may be updating. Pull to refresh.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActionCard(
    String title, 
    IconData icon, 
    Color color, 
    VoidCallback onTap, 
    {bool showBadge = false, int badgeCount = 0}
  ) {
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
        child: Stack(
          children: [
            Center(
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
            if (showBadge && badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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

  Widget _buildNextGameAlert(GameModel game) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
            Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.info,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No games today',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Next: ${game.gameTitle} - ${_formatGameDate(game.gameTime)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGamesListBySport(List<GameModel> games, {bool showCountdown = false, bool showDate = false}) {
    // Group games by sport
    final gamesBySport = <String, List<GameModel>>{};
    for (final game in games) {
      gamesBySport.putIfAbsent(game.sport, () => []).add(game);
    }
    
    // Sort sports to put user's favorite sports first
    final sortedSports = gamesBySport.keys.toList()
      ..sort((a, b) {
        final aIsFavorite = _userSports.contains(a);
        final bIsFavorite = _userSports.contains(b);
        if (aIsFavorite && !bIsFavorite) return -1;
        if (!aIsFavorite && bIsFavorite) return 1;
        // If both are favorites or both are not, keep original order
        return 0;
      });
    
    // Build widgets for each sport
    final widgets = <Widget>[];
    for (final sport in sortedSports) {
      final sportGames = gamesBySport[sport]!;
      final isExpanded = _expandedSports.contains(sport);
      final gamesToShow = isExpanded ? sportGames : sportGames.take(4).toList();
      final hasMore = sportGames.length > 4;
      
      // Add sport header if there are multiple sports
      if (gamesBySport.length > 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Icon(
                  _getSportIcon(sport),
                  size: 20,
                  color: _getSportColor(sport),
                ),
                const SizedBox(width: 8),
                Text(
                  sport,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getSportColor(sport),
                  ),
                ),
                if (_userSports.contains(sport)) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber,
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSportColor(sport).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sportGames.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getSportColor(sport),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // Add games
      for (final game in gamesToShow) {
        widgets.add(_buildGameCard(game, showCountdown: showCountdown, showDate: showDate));
      }
      
      // Add expand/collapse button if there are more than 4 games
      if (hasMore) {
        widgets.add(
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSports.remove(sport);
                  } else {
                    _expandedSports.add(sport);
                  }
                });
              },
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              label: Text(
                isExpanded 
                  ? 'Show less' 
                  : 'Show ${sportGames.length - 4} more $sport games',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
      }
      
      widgets.add(const SizedBox(height: 8));
    }
    
    return Column(children: widgets);
  }
  
  Widget _buildGameCard(GameModel game, {bool showCountdown = false, bool showDate = false}) {
    final countdown = _countdowns[game.id] ?? Duration.zero;
    final hasBet = _gamesWithBets.contains(game.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/pool-selection',
            arguments: {
              'gameId': game.id,
              'gameTitle': game.gameTitle,
              'sport': game.sport,
              'homeTeam': game.homeTeam,
              'awayTeam': game.awayTeam,
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSportColor(game.sport).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(game.sport),
                  color: _getSportColor(game.sport),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.gameTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          game.sport,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (showDate) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatGameDate(game.gameTime),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (showCountdown && countdown.inSeconds > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDuration(countdown),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (game.venue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        game.venue!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasBet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'BET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/pool-selection',
                      arguments: {
                        'gameId': game.id,
                        'gameTitle': game.gameTitle,
                        'sport': game.sport,
                        'homeTeam': game.homeTeam,
                        'awayTeam': game.awayTeam,
                      },
                    );
                  },
                  child: const Text('View Pools'),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatGameDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour == 0 ? 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      // Tomorrow
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Show date
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }
  
  String _formatDate(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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
          child: Icon(PhosphorIconsRegular.stack, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Buy-in: $buyIn • $players'),
        trailing: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowRight),
          onPressed: () {
            // TODO: Navigate to pool details
          },
        ),
      ),
    );
  }
  
  Widget _buildLiveGameCard(GameModel game) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.8),
            Colors.orange.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/pool-selection',
              arguments: {
                'gameId': game.id,
                'gameTitle': game.gameTitle,
                'sport': game.sport,
                'homeTeam': game.homeTeam,
                'awayTeam': game.awayTeam,
              },
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          game.sport,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.circle, color: Colors.red, size: 8),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    game.gameTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.formattedScore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (game.period != null)
                  Text(
                    game.period!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUpcomingGameCard(GameModel game) {
    final countdown = _countdowns[game.id] ?? Duration.zero;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/pool-selection',
            arguments: {
              'gameId': game.id,
              'gameTitle': game.gameTitle,
              'sport': game.sport,
              'homeTeam': game.homeTeam,
              'awayTeam': game.awayTeam,
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSportIcon(game.sport),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.gameTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${game.sport} • ${game.venue ?? "Venue TBD"}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(countdown),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/pool-selection',
                        arguments: {
                          'gameId': game.id,
                          'gameTitle': game.gameTitle,
                          'sport': game.sport,
                          'homeTeam': game.homeTeam,
                          'awayTeam': game.awayTeam,
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 20),
                    ),
                    child: const Text('View Pools'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getSportIcon(String sport) {
    switch (sport.toUpperCase()) {
      case 'NFL':
        return Icons.sports_football;
      case 'NBA':
        return Icons.sports_basketball;
      case 'MLB':
        return Icons.sports_baseball;
      case 'NHL':
        return Icons.sports_hockey;
      case 'MMA':
      case 'BOXING':
        return Icons.sports_mma;
      case 'SOCCER':
        return Icons.sports_soccer;
      case 'TENNIS':
        return Icons.sports_tennis;
      case 'GOLF':
        return Icons.golf_course;
      default:
        return Icons.sports;
    }
  }

  Widget _buildBetsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Wagers Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 Active Wagers',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<int>(
                      stream: _getActiveWagerCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(
                          '$count active bet${count != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/active-wagers');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Active Wagers List
            StreamBuilder<List<Wager>>(
              stream: _wagerService.getActiveWagers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            PhosphorIconsRegular.currencyDollar,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No active wagers',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedIndex = 0; // Go to Games tab
                              });
                            },
                            icon: const Icon(PhosphorIconsRegular.gameController),
                            label: const Text('Browse Games'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final wagers = snapshot.data!.take(3).toList();
                return Column(
                  children: wagers.map((wager) => _buildWagerCard(wager)).toList(),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Quick Bet Section
            _buildSectionHeader('⚡ Quick Bet', 'Place a bet in seconds'),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.lightning,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Quick Play',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join a random pool for any live game',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement quick play
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text(
                        'Quick Play - 25 BR',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent History Section
            _buildSectionHeader('📊 Recent History', 'Your betting performance'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                children: [
                  _buildHistoryItem('Won', 'NFL - Chiefs vs Bills', '+150 BR', Colors.green),
                  const Divider(),
                  _buildHistoryItem('Lost', 'NBA - Lakers vs Warriors', '-50 BR', Colors.red),
                  const Divider(),
                  _buildHistoryItem('Won', 'NHL - Rangers vs Bruins', '+75 BR', Colors.green),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/transactions');
                    },
                    child: const Text('View Full History'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWagerCard(Wager wager) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: const Icon(
            PhosphorIconsRegular.chartLine,
            color: Colors.orange,
          ),
        ),
        title: Text(
          wager.poolName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${wager.wagerAmount} BR • ${wager.gameTitle}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ACTIVE',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHistoryItem(String result, String game, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  result,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolsTab() {
    return RefreshIndicator(
      onRefresh: _loadPoolsData,
      child: _isLoadingPools
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My Active Pools Section
                _buildSectionHeader('🎲 My Active Pools', 'Pools you\'ve joined'),
                const SizedBox(height: 12),
                _userPools.isEmpty
                  ? _buildEmptyPoolsCard('You haven\'t joined any pools yet')
                  : SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _userPools.length,
                        itemBuilder: (context, index) {
                          final pool = _userPools[index];
                          return _buildMyPoolCard(
                            pool['name'],
                            '${pool['buyIn']} BR',
                            '${pool['currentPlayers']}/${pool['maxPlayers']} players',
                            _getSportColor(pool['sport']),
                            pool['isLive'],
                          );
                        },
                      ),
                    ),
            
            const SizedBox(height: 24),
            
            // Featured Pools Section
            _buildSectionHeader('⭐ Featured Pools', 'Popular pools to join'),
            const SizedBox(height: 12),
            _featuredPools.isEmpty
              ? _buildEmptyPoolsCard('No featured pools available')
              : Column(
                  children: _featuredPools.map((pool) {
                    return _buildFeaturedPoolCard(
                      pool['name'],
                      pool['sport'],
                      '${pool['buyIn']} BR',
                      '${pool['currentPlayers']}/${pool['maxPlayers']}',
                      '${pool['prizePool']} BR',
                      _getSportColor(pool['sport']),
                    );
                  }).toList(),
                ),
            
            const SizedBox(height: 24),
            
            // Browse by Sport Section
            _buildSectionHeader('🏆 Browse by Sport', 'Find pools for your favorite sports'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSportChip('NFL', Icons.sports_football, Colors.brown),
                _buildSportChip('NBA', Icons.sports_basketball, Colors.orange),
                _buildSportChip('NHL', Icons.sports_hockey, Colors.blue),
                _buildSportChip('MLB', Icons.sports_baseball, Colors.red),
                _buildSportChip('MMA', Icons.sports_mma, Colors.purple),
                _buildSportChip('Soccer', Icons.sports_soccer, Colors.green),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Quick Join Section
            _buildSectionHeader('💰 Quick Join Pools', 'Jump into action'),
            const SizedBox(height: 12),
            _quickJoinPools.isEmpty
              ? _buildEmptyPoolsCard('No quick join pools available')
              : Column(
                  children: _quickJoinPools.map((pool) {
                    final color = _getPoolCategoryColor(pool['category'] ?? 'Standard');
                    return _buildQuickJoinCard(
                      pool['name'],
                      '${pool['buyIn']} BR',
                      '${pool['currentPlayers']}/${pool['maxPlayers']} players',
                      color,
                    );
                  }).toList(),
                ),
            
            const SizedBox(height: 24),
            
            // Create Pool Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    PhosphorIconsRegular.plusCircle,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create Your Own Pool',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set your own rules and invite friends',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to create pool
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Create Pool'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMyPoolCard(String name, String buyIn, String players, Color color, bool isLive) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/my-pools');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isLive) ...[
                    const Icon(Icons.circle, color: Colors.red, size: 8),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buyIn,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    players,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeaturedPoolCard(
    String name,
    String sport,
    String buyIn,
    String players,
    String prize,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to pool details
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PhosphorIconsRegular.trophy,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$sport • $buyIn • $players players',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🏆 Prize Pool: $prize',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Join pool
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSportChip(String sport, IconData icon, Color color) {
    return ActionChip(
      onPressed: () {
        // TODO: Filter pools by sport
      },
      avatar: Icon(icon, color: color, size: 20),
      label: Text(sport),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
  
  Widget _buildQuickJoinCard(String title, String buyIn, String size, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            PhosphorIconsRegular.lightning,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('$buyIn • $size'),
        trailing: TextButton(
          onPressed: () {
            // TODO: Quick join
          },
          child: const Text('Quick Join'),
        ),
      ),
    );
  }

  Widget _buildEdgeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.amber,
                  Colors.orange,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  PhosphorIconsRegular.lightning,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Edge Intelligence',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Premium insights to give you the winning edge',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to premium subscription
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Unlock All Cards',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Available Edge Cards Section
          _buildSectionHeader('🎯 Today\'s Edge Cards', 'Tap to reveal insights'),
          const SizedBox(height: 12),
          
          // Live Games Edge Cards
          if (_liveGames.isNotEmpty) ...[
            const Text(
              'Live Games',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            ..._liveGames.take(3).map((game) => _buildEdgeCard(
              game.gameTitle,
              game.sport,
              'LIVE',
              Colors.red,
              true,
            )),
            const SizedBox(height: 16),
          ],
          
          // Upcoming Games Edge Cards
          const Text(
            'Upcoming Games',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          // Combine all upcoming games for Edge display
          ...[..._todayGames, ..._tomorrowGames, ..._thisWeekGames].take(5).map((game) => _buildEdgeCard(
            game.gameTitle,
            game.sport,
            'Available',
            Colors.blue,
            false,
          )),
          
          const SizedBox(height: 24),
          
          // Edge Stats Section
          _buildSectionHeader('📊 Your Edge Stats', 'Track your premium insights'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                _buildStatRow('Cards Viewed', '47', Icons.visibility, Colors.blue),
                const Divider(),
                _buildStatRow('Win Rate with Edge', '73%', Icons.trending_up, Colors.green),
                const Divider(),
                _buildStatRow('BR Earned with Edge', '+2,450', PhosphorIconsRegular.coins, Colors.amber),
                const Divider(),
                _buildStatRow('Cards Available Today', '12', PhosphorIconsRegular.lightning, Colors.orange),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sports Coverage Section
          _buildSectionHeader('🏆 Sports Coverage', 'Premium insights for all sports'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSportCoverageChip('NFL', true),
              _buildSportCoverageChip('NBA', true),
              _buildSportCoverageChip('NHL', true),
              _buildSportCoverageChip('MLB', true),
              _buildSportCoverageChip('MMA/Boxing', true),
              _buildSportCoverageChip('Soccer', false),
              _buildSportCoverageChip('Tennis', false),
              _buildSportCoverageChip('Golf', false),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEdgeCard(String gameTitle, String sport, String status, Color statusColor, bool isLive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EdgeScreen(
                gameTitle: gameTitle,
                sport: sport,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                statusColor.withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PhosphorIconsRegular.lightning,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          sport,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.lock,
                          size: 14,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '50 BR',
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3 cards available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSportCoverageChip(String sport, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.access_time,
            size: 16,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            sport,
            style: TextStyle(
              color: isActive ? Colors.green : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
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
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    PhosphorIconsRegular.user,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Player Name',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@username',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Level 12 • Pro Player',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/profile-edit');
                  },
                  icon: const Icon(
                    PhosphorIconsRegular.pencil,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Wallet Section
          _buildSectionHeader('💰 Wallet', 'Manage your BR'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            StreamBuilder<int>(
                              stream: _walletService.getBalanceStream(),
                              builder: (context, snapshot) {
                                final balance = snapshot.data ?? 0;
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$balance BR Coins',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showPurchaseOptions(context),
                            icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                            label: const Text('Get BR Coins'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/transactions');
                            },
                            icon: const Icon(PhosphorIconsRegular.receipt, size: 16),
                            label: const Text('History'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  StreamBuilder<Map<String, int>>(
                    stream: _walletService.getWalletStatsStream(),
                    builder: (context, snapshot) {
                      final stats = snapshot.data ?? {'won': 0, 'lost': 0, 'pending': 0};
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildWalletStat('Won', '+${stats['won']} BR', Colors.green),
                          _buildWalletStat('Lost', '-${stats['lost']} BR', Colors.red),
                          _buildWalletStat('Pending', '${stats['pending']} BR', Colors.orange),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildSectionHeader('⚡ Quick Actions', 'Common tasks'),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildMenuTile(
                'Leaderboard',
                PhosphorIconsRegular.trophy,
                Colors.amber,
                () {
                  Navigator.pushNamed(context, '/leaderboard');
                },
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '#47',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildMenuTile(
                'My Pools',
                PhosphorIconsRegular.users,
                Colors.blue,
                () {
                  Navigator.pushNamed(context, '/my-pools');
                },
              ),
              _buildMenuTile(
                'Active Wagers',
                PhosphorIconsRegular.chartLine,
                Colors.green,
                () {
                  Navigator.pushNamed(context, '/active-wagers');
                },
                trailing: StreamBuilder<int>(
                  stream: _getActiveWagerCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildMenuTile(
                'Invite Friends',
                PhosphorIconsRegular.userPlus,
                Colors.purple,
                () {
                  // TODO: Share invite
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Settings Section
          _buildSectionHeader('⚙️ Settings', 'App preferences'),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildMenuTile(
                'Notifications',
                PhosphorIconsRegular.bell,
                Colors.orange,
                () {
                  Navigator.pushNamed(context, '/notifications-settings');
                },
              ),
              _buildMenuTile(
                'Sports Preferences',
                PhosphorIconsRegular.basketball,
                Colors.indigo,
                () {
                  Navigator.pushNamed(context, '/sports-selection');
                },
              ),
              _buildMenuTile(
                'Privacy & Security',
                PhosphorIconsRegular.lock,
                Colors.red,
                () {
                  Navigator.pushNamed(context, '/privacy-settings');
                },
              ),
              _buildMenuTile(
                'Help & Support',
                PhosphorIconsRegular.question,
                Colors.teal,
                () {
                  Navigator.pushNamed(context, '/help');
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // App Info Section
          _buildSectionHeader('ℹ️ About', 'App information'),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildMenuTile(
                'Terms of Service',
                PhosphorIconsRegular.fileText,
                Colors.grey,
                () {
                  // TODO: Open terms
                },
              ),
              _buildMenuTile(
                'Privacy Policy',
                PhosphorIconsRegular.shieldCheck,
                Colors.grey,
                () {
                  // TODO: Open privacy policy
                },
              ),
              _buildMenuTile(
                'Rate App',
                PhosphorIconsRegular.star,
                Colors.yellow[700]!,
                () {
                  // TODO: Open app store
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Sign out
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: const Icon(PhosphorIconsRegular.signOut),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Version Info
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWalletStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing ?? const Icon(
          PhosphorIconsRegular.caretRight,
          size: 16,
        ),
      ),
    );
  }

  Stream<int> _getActiveWagerCount() {
    return _wagerService.getActiveWagers().map((wagers) => wagers.length);
  }
  
  void _showAllGames(BuildContext context, List<GameModel> games, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${games.length} games',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Games list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  return _buildGameCard(games[index], showDate: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardIndicator({
    required String icon,
    required int count,
    required CardType type,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to card inventory page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardInventoryScreen(cardType: type),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}