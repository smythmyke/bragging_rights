import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../theme/app_theme.dart';
import '../../services/odds_api_service.dart';
import '../../services/team_logo_service.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GameDetailsScreen extends StatefulWidget {
  final String gameId;
  final String sport;
  final GameModel? gameData;

  const GameDetailsScreen({
    Key? key,
    required this.gameId,
    required this.sport,
    this.gameData,
  }) : super(key: key);

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OddsApiService _oddsService = OddsApiService();
  final TeamLogoService _logoService = TeamLogoService();

  GameModel? _game;
  Map<String, dynamic>? _eventDetails;
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _game = widget.gameData;
    _loadEventDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetails() async {
    try {
      setState(() => _isLoading = true);

      // If game data wasn't passed, fetch it
      if (_game == null) {
        // TODO: Fetch from Firestore or API
      }

      // Fetch additional details based on sport
      // TODO: Implement ESPN API calls for detailed data

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading event details: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatEventTime(DateTime? gameTime) {
    if (gameTime == null) return '';
    final now = DateTime.now();
    final difference = gameTime.difference(now);

    if (difference.inDays > 0) {
      return DateFormat('MMM d • h:mm a').format(gameTime.toLocal());
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minutes';
    } else {
      return 'Live';
    }
  }

  bool get _isCombatSport =>
      widget.sport.toUpperCase() == 'MMA' ||
      widget.sport.toUpperCase() == 'BOXING';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surfaceBlue,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.shareNetwork),
                onPressed: _shareEvent,
              ),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.bell),
                onPressed: _setReminder,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getSportColor().withOpacity(0.8),
                      AppTheme.surfaceBlue,
                    ],
                  ),
                ),
                child: _buildHeaderContent(),
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryCyan,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryCyan,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Odds'),
                  Tab(text: 'Stats'),
                  Tab(text: 'News'),
                  Tab(text: 'Pools'),
                ],
              ),
            ),
          ),

          // Content
          SliverFillRemaining(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildOddsTab(),
                      _buildStatsTab(),
                      _buildNewsTab(),
                      _buildPoolsTab(),
                    ],
                  ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _navigateToPoolSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Pools',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryCyan),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(PhosphorIconsRegular.plus),
                color: AppTheme.primaryCyan,
                onPressed: _createPool,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    if (_game == null) return const SizedBox();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getSportColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getSportColor()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getSportIcon(), size: 16, color: _getSportColor()),
                  const SizedBox(width: 4),
                  Text(
                    widget.sport.toUpperCase(),
                    style: TextStyle(
                      color: _getSportColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Event Name
            Text(
              _isCombatSport
                  ? _game!.league ?? '${_game!.awayTeam} vs ${_game!.homeTeam}'
                  : '${_game!.awayTeam} @ ${_game!.homeTeam}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Time and Venue
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.clock,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatEventTime(_game!.gameTime),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                if (_game!.venue != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    PhosphorIconsRegular.mapPin,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _game!.venue!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCombatSport) ...[
            _buildFightCard(),
          ] else ...[
            _buildTeamMatchup(),
          ],
          const SizedBox(height: 24),
          _buildVenueInfo(),
          const SizedBox(height: 24),
          _buildBroadcastInfo(),
        ],
      ),
    );
  }

  Widget _buildFightCard() {
    if (_game?.fights == null || _game!.fights!.isEmpty) {
      return _buildSimpleFightCard();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Fight Card',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _game!.fights!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final fight = _game!.fights![index];
              final isMainEvent = index == _game!.fights!.length - 1;

              return Container(
                color: isMainEvent
                    ? AppTheme.primaryCyan.withOpacity(0.1)
                    : Colors.transparent,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (isMainEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MAIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    if (isMainEvent) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fight['fighter1'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'vs',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            fight['fighter2'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFighterInfo(_game!.awayTeam, true),
              Column(
                children: [
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_game!.league != null)
                    Text(
                      _game!.league!,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              _buildFighterInfo(_game!.homeTeam, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFighterInfo(String name, bool isAway) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            PhosphorIconsRegular.user,
            size: 40,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTeamMatchup() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo(_game!.awayTeam, _game!.awayTeamLogo, true),
          Column(
            children: [
              Text(
                '@',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_game!.league != null)
                Text(
                  _game!.league!,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          _buildTeamInfo(_game!.homeTeam, _game!.homeTeamLogo, false),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(String name, String? logo, bool isAway) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.borderCyan.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: logo != null
              ? CachedNetworkImage(
                  imageUrl: logo,
                  placeholder: (_, __) => Icon(
                    Icons.sports,
                    size: 40,
                    color: Colors.grey,
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.sports,
                    size: 40,
                    color: Colors.grey,
                  ),
                )
              : Icon(
                  Icons.sports,
                  size: 40,
                  color: Colors.grey,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVenueInfo() {
    if (_game?.venue == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.mapPin,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _game!.venue!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastInfo() {
    if (_game?.broadcast == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Broadcast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.television,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 12),
              Text(
                _game!.broadcast!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOddsTab() {
    return const Center(
      child: Text('Odds comparison coming soon'),
    );
  }

  Widget _buildStatsTab() {
    return const Center(
      child: Text('Statistics coming soon'),
    );
  }

  Widget _buildNewsTab() {
    return const Center(
      child: Text('News and updates coming soon'),
    );
  }

  Widget _buildPoolsTab() {
    return const Center(
      child: Text('Available pools coming soon'),
    );
  }

  Color _getSportColor() {
    switch (widget.sport.toUpperCase()) {
      case 'NFL':
        return AppTheme.primaryCyan;
      case 'NBA':
        return AppTheme.warningAmber;
      case 'MLB':
        return AppTheme.errorPink;
      case 'NHL':
        return AppTheme.secondaryCyan;
      case 'MMA':
      case 'UFC':
        return AppTheme.secondaryCyan;
      case 'BOXING':
        return AppTheme.warningAmber;
      case 'SOCCER':
        return AppTheme.neonGreen;
      default:
        return AppTheme.surfaceBlue;
    }
  }

  IconData _getSportIcon() {
    switch (widget.sport.toUpperCase()) {
      case 'NFL':
        return Icons.sports_football;
      case 'NBA':
        return Icons.sports_basketball;
      case 'MLB':
        return Icons.sports_baseball;
      case 'NHL':
        return Icons.sports_hockey;
      case 'MMA':
      case 'UFC':
      case 'BOXING':
        return Icons.sports_mma;
      case 'SOCCER':
        return Icons.sports_soccer;
      case 'TENNIS':
        return Icons.sports_tennis;
      default:
        return Icons.sports;
    }
  }

  void _shareEvent() {
    // TODO: Implement share functionality
  }

  void _setReminder() {
    // TODO: Implement reminder functionality
  }

  void _navigateToPoolSelection() {
    Navigator.pushNamed(
      context,
      '/pool-selection',
      arguments: {
        'gameTitle': _isCombatSport
            ? (_game!.league ?? '${_game!.awayTeam} vs ${_game!.homeTeam}')
            : '${_game!.awayTeam} @ ${_game!.homeTeam}',
        'sport': widget.sport,
        'gameId': widget.gameId,
      },
    );
  }

  void _createPool() {
    // TODO: Implement pool creation
  }
}

// Custom delegate for pinned tab bar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surfaceBlue,
      child: Column(
        children: [
          tabBar,
          Container(
            height: 1,
            color: AppTheme.borderCyan.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}