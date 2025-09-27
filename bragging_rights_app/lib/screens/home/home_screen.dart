import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../services/bet_service.dart';
import '../../services/wallet_service.dart';
import '../../services/sports_api_service.dart';
import '../../services/espn_direct_service.dart';
import '../../services/optimized_games_service.dart';
import '../../services/pool_management_service.dart';
import '../../services/pool_data_service.dart';
import '../../services/pool_service.dart';
import '../../services/wager_service.dart';
import '../../services/purchase_service.dart';
import '../../services/card_service.dart';
import '../../models/game_model.dart';
import '../../models/pool_model.dart';
import '../../data/card_definitions.dart';
import '../../widgets/power_card_widget.dart';
import '../../widgets/intel_card_widget.dart';
import '../card_detail_screen.dart';
import '../../models/intel_product.dart';
// import '../../utils/dev_tools.dart'; // Removed for production
import '../premium/edge_screen.dart';
import '../cards/card_inventory_screen.dart';
import '../games/all_games_screen.dart';
import '../games/optimized_games_screen.dart';
import '../../services/sound_service.dart';
import '../bets/active_bets_screen.dart';
import '../intel_detail_screen.dart';
import '../../widgets/bragging_rights_logo.dart';
import '../../widgets/standings_info_card.dart';
import '../../services/friend_service.dart';
import '../../services/api_call_tracker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  Timer? _countdownTimer;
  Timer? _backgroundRefreshTimer;
  final Map<String, Duration> _countdowns = {};
  bool _showStandingsCard = false;
  DateTime? _lastStandingsShown;
  
  // Services
  final BetService _betService = BetService();
  final WalletService _walletService = WalletService();
  final SportsApiService _sportsApiService = SportsApiService();
  final ESPNDirectService _espnService = ESPNDirectService();
  final OptimizedGamesService _optimizedGamesService = OptimizedGamesService();
  final PoolDataService _poolService = PoolDataService();
  final WagerService _wagerService = WagerService();
  final PurchaseService _purchaseService = PurchaseService();
  final CardService _cardService = CardService();
  final SoundService _soundService = SoundService();
  final FriendService _friendService = FriendService();
  
  // Feature flag for optimized loading
  static const bool USE_OPTIMIZED_GAMES = true;
  
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
  List<GameModel> _allGames = []; // All games cache

  // Track if MLB cache has been cleared (temporary fix)
  bool _mlbCacheCleared = false;
  
  // Pool data
  List<Map<String, dynamic>> _userPools = [];
  List<Map<String, dynamic>> _createdPools = [];
  List<Map<String, dynamic>> _joinedPools = [];
  List<Map<String, dynamic>> _featuredPools = [];
  List<Map<String, dynamic>> _quickJoinPools = [];
  bool _isLoadingPools = false;

  @override
  void initState() {
    super.initState();
    // Start API call tracking session
    APICallTracker.startSession();

    _pageController = PageController(initialPage: _selectedIndex);
    _initializeCountdowns();
    _startCountdownTimer();
    _startBackgroundRefresh();
    _loadGamesWithBets();
    _loadUserSportsPreferences();
    _loadGamesData();
    _loadPoolsData();
    _initializePurchaseService();
    _initializeSoundService();
    
    // Start pool management after authentication
    _startPoolManagement();
    
    // Check if we should show standings card
    _checkShowStandingsCard();
  }
  
  void _checkShowStandingsCard() async {
    final now = DateTime.now();
    if (_lastStandingsShown == null ||
        now.difference(_lastStandingsShown!).inHours >= 12) {
      // Check if there's actual data to display before showing the card
      try {
        // Check for friend activity and rankings
        final activityFuture = _friendService.getFriendActivityStream().first;
        final rankingsFuture = _friendService.getUserRankings();

        List<dynamic> results;
        try {
          results = await Future.wait([
            activityFuture,
            rankingsFuture,
          ]).timeout(const Duration(seconds: 3));
        } catch (e) {
          // Timeout or error - don't show the card
          debugPrint('Timeout or error loading standings data: $e');
          return;
        }

        final activity = results.length > 0 ? results[0] as FriendActivity? : null;
        final rankings = results.length > 1 ? results[1] as Map<String, dynamic>? : null;

        // Only show if there's actual data to display AND user is ranked
        final hasActivity = activity != null && activity.recentActivities.isNotEmpty;
        final hasRankings = rankings != null && rankings.isNotEmpty;

        // Check if user is actually ranked (not null and has valid rank numbers)
        final isUserRanked = rankings != null &&
            rankings['nationalRank'] != null &&
            rankings['nationalRank'] > 0 &&
            rankings['stateRank'] != null &&
            rankings['stateRank'] > 0;

        if (isUserRanked && (hasActivity || hasRankings)) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showStandingsCard = true;
                _lastStandingsShown = now;
              });
            }
          });
        } else {
          debugPrint('Skipping Today\'s Standings - user not ranked or no data to display');
        }
      } catch (e) {
        debugPrint('Error checking standings data: $e');
        // Don't show the card if we can't load data
      }
    }
  }
  
  Future<void> _startPoolManagement() async {
    // Check if user is authenticated before starting pool management
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      PoolManagementService().startPoolManagement();
      debugPrint('Pool management service started for user: ${user.uid}');
    }
  }
  
  Future<void> _initializeSoundService() async {
    await _soundService.initialize();
  }
  
  Future<void> _initializePurchaseService() async {
    await _purchaseService.initialize();
    if (mounted) {
      setState(() {
        // Trigger rebuild to show products
      });
    }
  }
  
  void _startBackgroundRefresh() {
    // Refresh games data every 2 minutes
    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        debugPrint('⏰ Background refresh triggered');
        _loadGamesData(forceRefresh: false); // This will use cache if valid
      }
    });
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
      // Fetch all pool data in parallel
      final results = await Future.wait([
        _poolService.getUserCreatedPools(),
        _poolService.getUserActivePools(),
        _poolService.getFeaturedPools(),
        _poolService.getQuickJoinPools(),
      ]);
      
      final createdPools = results[0];
      final allUserPools = results[1];
      final featuredPools = results[2];
      final quickJoinPools = results[3];
      
      // Filter joined pools (exclude created ones)
      final createdPoolIds = createdPools.map((p) => p['id']).toSet();
      final joinedPools = allUserPools.where((pool) => 
        !createdPoolIds.contains(pool['id'])
      ).toList();
      
      if (mounted) {
        setState(() {
          _createdPools = createdPools;
          _joinedPools = joinedPools;
          _userPools = allUserPools; // Keep for backwards compatibility
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
          // Don't reload games - just update the sorting of existing games
          if (_allGames.isNotEmpty && mounted) {
            _updateGameLists(_allGames);
          }
        }
      }
    } catch (e) {
      print('Error loading sports preferences: $e');
    }
  }
  
  Future<void> _loadGamesData({bool forceRefresh = false}) async {
    // Don't show loading indicator if we're just refreshing in background
    if (forceRefresh || _allGames.isEmpty) {
      setState(() {
        _isLoadingGames = true;
      });
    }

    try {
      // TEMPORARY FIX: Always clear MLB cache to ensure ESPN IDs are present
      // TODO: Remove this once ESPN IDs are confirmed working
      print('🔄 Clearing MLB cache to ensure fresh data with ESPN IDs...');
      await _optimizedGamesService.clearSportCache('MLB');

      // TEMPORARY FIX: Clear MMA cache to ensure ESPN IDs are used
      print('🔄 Clearing MMA cache to ensure fresh data with ESPN IDs...');
      await _optimizedGamesService.clearSportCache('MMA');

      // Fetch games with caching support - this will return cached data instantly if available
      print('📱 Loading games data...');

      // Use optimized service for featured games with user preferences
      final result = await _optimizedGamesService.loadFeaturedGames(forceRefresh: forceRefresh);
      final allGames = result['games'] as List<GameModel>;
      
      if (allGames.isNotEmpty) {
        // Update UI immediately with whatever games we have (cached or fresh)
        _updateGameLists(allGames);
        
        // Hide loading indicator as soon as we have some data to show
        if (mounted) {
          setState(() {
            _isLoadingGames = false;
          });
        }
      }
      
      print('✅ Games loaded: ${allGames.length} total');
      
    } catch (e) {
      print('Error loading games: $e');
      if (mounted) {
        setState(() {
          _isLoadingGames = false;
        });
      }
    }
  }
  
  void _updateGameLists(List<GameModel> allGames) {
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
    
    // Update UI with new game lists
    if (mounted) {
      setState(() {
        _allGames = allGames;
        _liveGames = liveGames;
        _todayGames = todayGames;
        _tomorrowGames = tomorrowGames;
        _thisWeekGames = thisWeekGames;
        _nextWeekGames = nextWeekGames;
        _nextGame = nextGame;
        
        print('Live games: ${liveGames.length}');
        print('Today\'s games: ${todayGames.length}');
        print('Tomorrow\'s games: ${tomorrowGames.length}');
        
        // Initialize countdowns for today's games
        for (final game in todayGames) {
          _countdowns[game.id] = game.timeUntilGame;
        }
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
    _pageController.dispose();
    _countdownTimer?.cancel();
    _backgroundRefreshTimer?.cancel();
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
        return AppTheme.primaryCyan;
      case 'NBA':
        return AppTheme.warningAmber;
      case 'NHL':
        return AppTheme.secondaryCyan;
      case 'MLB':
        return AppTheme.errorPink;
      case 'MMA':
      case 'UFC':  // UFC is a promotion within MMA
        return AppTheme.secondaryCyan;
      case 'SOCCER':
        return AppTheme.neonGreen;  // Bright green for soccer visibility
      case 'BOXING':
        return AppTheme.warningAmber;  // Bright amber for boxing visibility
      default:
        return AppTheme.surfaceBlue;
    }
  }
  
  Color _getPoolCategoryColor(String category) {
    if (category.contains('Beginner')) return AppTheme.neonGreen;
    if (category.contains('Standard')) return AppTheme.primaryCyan;
    if (category.contains('High')) return AppTheme.secondaryCyan;
    if (category.contains('Whale')) return AppTheme.errorPink;
    return AppTheme.surfaceBlue;
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        automaticallyImplyLeading: false, // Prevent back button from appearing
        title: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 0; // Navigate to Games tab
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
            },
            child: const BraggingRightsLogo(
              height: 100,
              showUnderline: true,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Victory Coins Display
          InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = 4; // Navigate to More tab
                _pageController.animateToPage(
                  4,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsDuotone.trophy,
                    color: Colors.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _walletService.getCombinedWalletStream(),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? {'br': 0, 'vc': 0};
                      final vcBalance = data['vc'] ?? 0;
                      return Text(
                        '$vcBalance VC',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // BR Balance Display
          InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = 4; // Navigate to More tab (index 4)
                _pageController.animateToPage(
                  4,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
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
          IconButton(
            icon: const Icon(PhosphorIconsRegular.gear),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/preferences');
              if (result == true) {
                // Refresh games if preferences were changed
                _loadGamesData(forceRefresh: true);
              }
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
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
    ),
        if (_showStandingsCard)
          StandingsInfoCard(
            onDismiss: () {
              setState(() {
                _showStandingsCard = false;
              });
            },
          ),
      ],
    );
  }

  Widget _buildGamesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadGamesData(forceRefresh: true);
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
                    _buildSectionHeader(
                      '🔴 Live Now', 
                      '${_liveGames.length} game${_liveGames.length != 1 ? 's' : ''} in progress',
                      buttonText: 'View Now',
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesScreen(
                              title: 'Live Games',
                              category: 'live',
                              initialGames: _liveGames,
                            ),
                          ),
                        );
                      },
                    ),
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
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesScreen(
                              title: "Today's Games",
                              category: 'today',
                              initialGames: _todayGames,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildGamesListBySport(_todayGames, showCountdown: true),
                    const SizedBox(height: 24),
                  ] else if (_liveGames.isEmpty) ...[
                    // The _buildNextGameAlert already shows the "no games" message, so we don't need another one
                    const SizedBox.shrink(),
                  ],
                  
                  // Tomorrow's Games Section
                  if (_tomorrowGames.isNotEmpty) ...[
                    _buildSectionHeader(
                      '🌅 Tomorrow',
                      _formatDate(DateTime.now().add(const Duration(days: 1))),
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesScreen(
                              title: "Tomorrow's Games",
                              category: 'tomorrow',
                              initialGames: _tomorrowGames,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._tomorrowGames.take(5).map((game) => _buildGameCard(game, showDate: false)),
                    if (_tomorrowGames.length > 5)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllGamesScreen(
                                title: "Tomorrow's Games",
                                category: 'tomorrow',
                                initialGames: _tomorrowGames,
                              ),
                            ),
                          );
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
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesScreen(
                              title: 'This Week',
                              category: 'thisweek',
                              initialGames: _thisWeekGames,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._thisWeekGames.take(5).map((game) => _buildGameCard(game, showDate: true)),
                    if (_thisWeekGames.length > 5)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllGamesScreen(
                                title: 'This Week',
                                category: 'thisweek',
                                initialGames: _thisWeekGames,
                              ),
                            ),
                          );
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
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllGamesScreen(
                              title: 'Next Week',
                              category: 'nextweek',
                              initialGames: _nextWeekGames,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._nextWeekGames.take(3).map((game) => _buildGameCard(game, showDate: true)),
                    if (_nextWeekGames.length > 3)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllGamesScreen(
                                title: 'Next Week',
                                category: 'nextweek',
                                initialGames: _nextWeekGames,
                              ),
                            ),
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
                  
                  // Optimized Version Banner - At the bottom
                  if (USE_OPTIMIZED_GAMES) 
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade800],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_score, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🏆 View All Sports',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Browse games by sport category',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade700,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OptimizedGamesScreen(),
                                ),
                              );
                            },
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildSectionHeader(String title, String subtitle, {VoidCallback? onViewAll, String buttonText = 'View All'}) {
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
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text(buttonText),
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
            '/game-details',
            arguments: {
              'gameId': game.id,
              'sport': game.sport,
              'gameData': game,
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
                OutlinedButton(
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Enter Pool'),
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
              '/game-details',
              arguments: {
                'gameId': game.id,
                'sport': game.sport,
                'gameData': game,
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
            '/game-details',
            arguments: {
              'gameId': game.id,
              'sport': game.sport,
              'gameData': game,
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
                  OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(80, 28),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: const Text('Enter Pool'),
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
      case 'UFC':  // UFC is a promotion within MMA
        return Icons.sports_mma;
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
    return const ActiveBetsScreen();
  }

  Widget _buildBetsTabOld() {
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
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
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
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Center(
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
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        print('Quick Play button pressed');
                        await _handleQuickPlay();
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
                // Pools I Created Section
                _buildSectionHeader('👑 Pools I Created', 'Manage your pools'),
                const SizedBox(height: 12),
                _createdPools.isEmpty
                  ? _buildEmptyPoolsCard('You haven\'t created any pools yet')
                  : SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _createdPools.length,
                        itemBuilder: (context, index) {
                          final pool = _createdPools[index];
                          return _buildCreatedPoolCard(
                            pool['name'],
                            '${pool['buyIn']} BR',
                            '${pool['currentPlayers']}/${pool['maxPlayers']} players',
                            _getSportColor(pool['sport']),
                            pool['isLive'],
                            pool['id'],
                          );
                        },
                      ),
                    ),
            
            const SizedBox(height: 24),
            
            // Pools I Joined Section
            _buildSectionHeader('🎯 Pools I Joined', 'Your active participations'),
            const SizedBox(height: 12),
            _joinedPools.isEmpty
              ? _buildEmptyPoolsCard('You haven\'t joined any pools yet')
              : SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _joinedPools.length,
                    itemBuilder: (context, index) {
                      final pool = _joinedPools[index];
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
  
  Widget _buildCreatedPoolCard(String name, String buyIn, String players, Color color, bool isLive, String poolId) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'OWNER',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 6),
                          SizedBox(width: 2),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monetization_on_outlined, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        buyIn,
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
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
            ],
          ),
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
          // Shop Header
          Container(
            width: double.infinity,
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
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  PhosphorIconsRegular.storefront,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Power Card Shop',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock strategic advantages with power cards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                StreamBuilder<UserCardInventory>(
                  stream: _cardService.getUserCardInventory(),
                  builder: (context, snapshot) {
                    final inventory = snapshot.data ?? UserCardInventory.empty();
                    final totalOwned = inventory.offensiveCount + 
                                      inventory.defensiveCount + 
                                      inventory.specialCount;
                    final totalCards = CardDefinitions.allCards.length;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalOwned / $totalCards Cards Owned',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.green, 'Owned'),
                _buildLegendItem(Colors.orange, 'Available'),
                _buildLegendItem(Colors.grey, 'Locked'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Offensive Cards Section
          _buildSectionHeader('⚔️ Offensive Cards', 'Double down on your strategy'),
          const SizedBox(height: 12),
          StreamBuilder<UserCardInventory>(
            stream: _cardService.getUserCardInventory(),
            builder: (context, snapshot) {
              final inventory = snapshot.data ?? UserCardInventory.empty();
              final offensiveCards = CardDefinitions.getOffensiveCards();
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: offensiveCards.length,
                itemBuilder: (context, index) {
                  final card = offensiveCards[index];
                  final owned = (inventory.cardQuantities[card.id] ?? 0) > 0;
                  final quantity = inventory.cardQuantities[card.id] ?? 0;
                  return StreamBuilder<int>(
                    stream: _walletService.getBalanceStream(),
                    builder: (context, balanceSnapshot) {
                      final balance = balanceSnapshot.data ?? 0;
                      final price = _getCardPrice(card.rarity);
                      final canAfford = balance >= price;
                      
                      return PowerCardWidget(
                        card: card.copyWith(quantity: quantity),
                        isOwned: owned,
                        canAfford: canAfford,
                        price: price,
                        showPrice: true,
                        onTap: () async {
                          // Play selection sound
                          await _soundService.playCardSelect(card.id);
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CardDetailScreen(
                                card: card,
                                isOwned: owned,
                                quantity: quantity,
                              ),
                            ),
                          );
                          
                          // Refresh if card was purchased
                          if (result == true) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Defensive Cards Section
          _buildSectionHeader('🛡️ Defensive Cards', 'Protect your position'),
          const SizedBox(height: 12),
          StreamBuilder<UserCardInventory>(
            stream: _cardService.getUserCardInventory(),
            builder: (context, snapshot) {
              final inventory = snapshot.data ?? UserCardInventory.empty();
              final defensiveCards = CardDefinitions.getDefensiveCards();
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: defensiveCards.length,
                itemBuilder: (context, index) {
                  final card = defensiveCards[index];
                  final owned = (inventory.cardQuantities[card.id] ?? 0) > 0;
                  final quantity = inventory.cardQuantities[card.id] ?? 0;
                  return StreamBuilder<int>(
                    stream: _walletService.getBalanceStream(),
                    builder: (context, balanceSnapshot) {
                      final balance = balanceSnapshot.data ?? 0;
                      final price = _getCardPrice(card.rarity);
                      final canAfford = balance >= price;
                      
                      return PowerCardWidget(
                        card: card.copyWith(quantity: quantity),
                        isOwned: owned,
                        canAfford: canAfford,
                        price: price,
                        showPrice: true,
                        onTap: () async {
                          // Play selection sound
                          await _soundService.playCardSelect(card.id);
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CardDetailScreen(
                                card: card,
                                isOwned: owned,
                                quantity: quantity,
                              ),
                            ),
                          );
                          
                          // Refresh if card was purchased
                          if (result == true) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Special Cards Section
          _buildSectionHeader('👑 Special Cards', 'Game-changing abilities'),
          const SizedBox(height: 12),
          StreamBuilder<UserCardInventory>(
            stream: _cardService.getUserCardInventory(),
            builder: (context, snapshot) {
              final inventory = snapshot.data ?? UserCardInventory.empty();
              final specialCards = CardDefinitions.getSpecialCards();
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: specialCards.length,
                itemBuilder: (context, index) {
                  final card = specialCards[index];
                  final owned = (inventory.cardQuantities[card.id] ?? 0) > 0;
                  final quantity = inventory.cardQuantities[card.id] ?? 0;
                  return StreamBuilder<int>(
                    stream: _walletService.getBalanceStream(),
                    builder: (context, balanceSnapshot) {
                      final balance = balanceSnapshot.data ?? 0;
                      final price = _getCardPrice(card.rarity);
                      final canAfford = balance >= price;
                      
                      return PowerCardWidget(
                        card: card.copyWith(quantity: quantity),
                        isOwned: owned,
                        canAfford: canAfford,
                        price: price,
                        showPrice: true,
                        onTap: () async {
                          // Play selection sound
                          await _soundService.playCardSelect(card.id);
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CardDetailScreen(
                                card: card,
                                isOwned: owned,
                                quantity: quantity,
                              ),
                            ),
                          );
                          
                          // Refresh if card was purchased
                          if (result == true) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Intel Section
          _buildSectionHeader('🔮 Edge Intel', 'Premium game insights'),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: _walletService.getBalanceStream(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: IntelProducts.all.length,
                itemBuilder: (context, index) {
                  final intel = IntelProducts.all[index];
                  final canAfford = balance >= intel.price;
                  
                  return IntelCardWidget(
                    intel: intel,
                    canAfford: canAfford,
                    onTap: () async {
                      // Play selection sound
                      await _soundService.playCardSelect('intel_${intel.id}');
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IntelDetailScreen(
                            intel: intel,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
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
                            StreamBuilder<Map<String, dynamic>>(
                              stream: _walletService.getCombinedWalletStream(),
                              builder: (context, snapshot) {
                                final data = snapshot.data ?? {'br': 0, 'vc': 0};
                                final brBalance = data['br'] ?? 0;
                                final vcBalance = data['vc'] ?? 0;
                                final vcModel = data['vcModel'];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '$brBalance BR',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          PhosphorIconsRegular.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$vcBalance Victory Coins',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                  // Victory Coins Earning Progress
                  FutureBuilder<Map<String, int>>(
                    future: _walletService.getVCStats(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      final stats = snapshot.data!;
                      if (stats['dailyEarned'] == 0 &&
                          stats['weeklyEarned'] == 0 &&
                          stats['monthlyEarned'] == 0) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          const Divider(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Victory Coin Earning Caps',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildVCProgressBar(
                                'Daily',
                                stats['dailyEarned']!,
                                stats['dailyCap']!,
                                Colors.blue,
                              ),
                              const SizedBox(height: 4),
                              _buildVCProgressBar(
                                'Weekly',
                                stats['weeklyEarned']!,
                                stats['weeklyCap']!,
                                Colors.purple,
                              ),
                              const SizedBox(height: 4),
                              _buildVCProgressBar(
                                'Monthly',
                                stats['monthlyEarned']!,
                                stats['monthlyCap']!,
                                Colors.green,
                              ),
                            ],
                          ),
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
                  Navigator.pushNamed(context, '/invite-friends');
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
  
  Widget _buildVCProgressBar(String label, int earned, int cap, Color color) {
    final progress = cap > 0 ? (earned / cap).clamp(0.0, 1.0) : 0.0;
    final remaining = (cap - earned).clamp(0, cap);

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '$earned / $cap VC',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+$remaining',
          style: TextStyle(
            fontSize: 11,
            color: progress >= 1.0 ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
  
  Widget _buildCardIndicatorWithIcon({
    required IconData icon,
    required int count,
    required CardType type,
    required BuildContext context,
  }) {
    Color iconColor;
    switch (type) {
      case CardType.offensive:
        iconColor = Colors.orange;
        break;
      case CardType.defensive:
        iconColor = Colors.blue;
        break;
      case CardType.special:
        iconColor = Colors.purple;
        break;
    }
    
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
            Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleQuickPlay() async {
    print('=== Starting Quick Play Process ===');
    
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Quick Play failed: No user logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to use Quick Play'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      print('User logged in: ${user.uid}');
      
      // Check user balance
      print('Checking user balance...');
      final balance = await _walletService.getBalance(user.uid);
      print('Current balance: $balance BR');
      
      if (balance < 25) {
        print('Quick Play failed: Insufficient balance (need 25 BR, have $balance BR)');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient BR. You need 25 BR (current: $balance BR)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check for live games
      print('Checking for live games...');
      if (_liveGames.isEmpty) {
        print('Quick Play failed: No live games available');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No live games available for Quick Play'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      print('Found ${_liveGames.length} live games');
      
      // Select a random live game
      final random = math.Random();
      final selectedGame = _liveGames[random.nextInt(_liveGames.length)];
      print('Selected game: ${selectedGame.gameTitle} (${selectedGame.id})');
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        // Try to find or create a quick play pool
        print('Looking for available quick play pools for game ${selectedGame.id}...');
        
        // First, try to find an existing open pool
        final poolsSnapshot = await FirebaseFirestore.instance
            .collection('pools')
            .where('gameId', isEqualTo: selectedGame.id)
            .where('type', isEqualTo: 'quick')
            .where('buyIn', isEqualTo: 25)
            .where('status', isEqualTo: 'open')
            .where('currentPlayers', isLessThan: 10)
            .limit(1)
            .get();
        
        print('Found ${poolsSnapshot.docs.length} existing pools');
        
        String poolId;
        bool success = false;
        final poolService = PoolService();
        
        if (poolsSnapshot.docs.isNotEmpty) {
          // Join existing pool
          poolId = poolsSnapshot.docs.first.id;
          print('Joining existing pool: $poolId');
          success = await poolService.joinPool(poolId, 25);
        } else {
          // Create new pool using PoolService
          print('No existing pools found, creating new pool...');
          
          // Create the pool using the service
          final createdPoolId = await poolService.createPool(
            gameId: selectedGame.id ?? '',
            gameTitle: selectedGame.gameTitle,
            sport: selectedGame.sport,
            type: PoolType.quick,
            name: 'Quick Play - ${selectedGame.gameTitle}',
            buyIn: 25,
            maxPlayers: 10,
            minPlayers: 2,
          );
          
          if (createdPoolId == null) {
            throw Exception('Failed to create Quick Play pool');
          }
          
          poolId = createdPoolId;
          print('Created new pool: $poolId');
          
          // Pool creation already handles joining and wallet deduction
          success = true;
        }
        
        // Dismiss loading dialog
        if (mounted) Navigator.pop(context);
        
        if (success) {
          print('Successfully joined pool!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined Quick Play pool for ${selectedGame.gameTitle}!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to the pool or bet placement screen
          // Navigator.pushNamed(context, '/pool-details', arguments: {'poolId': poolId});
        } else {
          print('Failed to join pool');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to join pool. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (poolError) {
        print('Error during pool operations: $poolError');
        print('Stack trace: ${StackTrace.current}');
        // Dismiss loading dialog
        if (mounted) Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${poolError.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Unexpected error in Quick Play: $e');
      print('Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    print('=== Quick Play Process Complete ===');
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Helper method to get card price based on rarity
  int _getCardPrice(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 100;
      case CardRarity.uncommon:
        return 250;
      case CardRarity.rare:
        return 500;
      case CardRarity.legendary:
        return 1000;
    }
  }
  
  Widget _buildPowerCardItem(PowerCard card, bool owned, int quantity) {
    // Get card prices based on rarity
    int getCardPrice(CardRarity rarity) {
      switch (rarity) {
        case CardRarity.common:
          return 100;
        case CardRarity.uncommon:
          return 250;
        case CardRarity.rare:
          return 500;
        case CardRarity.legendary:
          return 1000;
      }
    }
    
    final price = getCardPrice(card.rarity);
    
    // Get rarity color
    Color getRarityColor(CardRarity rarity) {
      switch (rarity) {
        case CardRarity.common:
          return Colors.grey;
        case CardRarity.uncommon:
          return Colors.green;
        case CardRarity.rare:
          return Colors.blue;
        case CardRarity.legendary:
          return Colors.orange;
      }
    }
    
    // Get card type color
    Color getTypeColor(CardType type) {
      switch (type) {
        case CardType.offensive:
          return Colors.red.shade400;
        case CardType.defensive:
          return Colors.blue.shade400;
        case CardType.special:
          return Colors.purple.shade400;
      }
    }
    
    return StreamBuilder<int>(
      stream: _walletService.getBalanceStream(),
      builder: (context, balanceSnapshot) {
        final balance = balanceSnapshot.data ?? 0;
        final canAfford = balance >= price;
        
        return GestureDetector(
          onTap: () {
            if (!owned && canAfford) {
              _showPurchaseDialog(card, price);
            } else if (owned) {
              _showCardDetailsDialog(card, quantity);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: owned 
                ? Colors.grey[850]
                : (canAfford ? Colors.grey[850] : Colors.grey[900]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: owned 
                  ? Colors.amber  // Gold border for owned cards
                  : (canAfford ? Colors.grey[700]! : Colors.grey[800]!),
                width: owned ? 2.5 : 1,
              ),
              boxShadow: owned ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Stack(
              children: [
                // Rarity indicator
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: getRarityColor(card.rarity),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                  ),
                ),
                
                // Quantity badge (if owned more than 1)
                if (quantity > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'x$quantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Card content
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        card.icon,
                        style: TextStyle(
                          fontSize: 32,
                          color: owned ? Colors.white : (canAfford ? Colors.white70 : Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: owned ? Colors.white : (canAfford ? Colors.white70 : Colors.grey[600]),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (!owned) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: canAfford 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.coins,
                                size: 12,
                                color: canAfford ? Colors.greenAccent : Colors.grey[500],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$price',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: canAfford ? Colors.greenAccent : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OWNED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Disabled overlay for unaffordable cards
                if (!owned && !canAfford)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildIntelProduct(String title, String icon, String description, int price, Color color) {
    return StreamBuilder<int>(
      stream: _walletService.getBalanceStream(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        final canAfford = balance >= price;
        
        return GestureDetector(
          onTap: canAfford ? () {
            // TODO: Purchase intel
          } : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canAfford ? Colors.grey[900] : Colors.grey[900]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canAfford ? color.withOpacity(0.5) : Colors.grey[850]!,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: TextStyle(
                    fontSize: 28,
                    color: canAfford ? null : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? null : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: canAfford ? Colors.grey[600] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: canAfford 
                      ? color.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.coins,
                        size: 12,
                        color: canAfford ? color : Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$price',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: canAfford ? color : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showPurchaseDialog(PowerCard card, int price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase ${card.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.effect,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(card.howToUse),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(PhosphorIconsRegular.coins, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$price BR',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close the purchase dialog first
              Navigator.pop(context);
              
              // Save the context before async operations
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context, rootNavigator: true);
              
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) => WillPopScope(
                    onWillPop: () async => false,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
                
                // Attempt purchase
                final success = await _cardService.purchaseCard(card.id, price);
                
                // Always dismiss loading dialog
                try {
                  navigator.pop();
                } catch (_) {
                  // Dialog might already be dismissed
                }
                
                // Show result using saved messenger
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Purchased ${card.name} for $price BR!' 
                        : 'Purchase failed. Check your balance.',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                
                // Force rebuild to update UI
                if (success && mounted) {
                  setState(() {});
                }
              } catch (e) {
                // Make sure to dismiss loading dialog on error
                try {
                  navigator.pop();
                } catch (_) {
                  // Dialog might already be dismissed
                }
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Purchase failed. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
                print('Purchase error: $e');
              }
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }
  
  void _showCardDetailsDialog(PowerCard card, int quantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(card.icon),
            const SizedBox(width: 8),
            Expanded(child: Text(card.name)),
            if (quantity > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x$quantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effect',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.effect,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'When to Use',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(card.whenToUse),
            const SizedBox(height: 12),
            Text(
              'How to Use',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(card.howToUse),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}