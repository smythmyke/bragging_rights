import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as Math;

class BetSelectionScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  final String poolName;
  
  const BetSelectionScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
    required this.poolName,
  });

  @override
  State<BetSelectionScreen> createState() => _BetSelectionScreenState();
}

class _BetSelectionScreenState extends State<BetSelectionScreen> with TickerProviderStateMixin {
  late TabController _betTypeController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  Duration _gameStartCountdown = const Duration(hours: 1, minutes: 15);
  
  // Selected team/fighter
  String? _selectedTeam;
  
  // Multiple bets for parlay
  List<SelectedBet> _selectedBets = [];
  
  // Wager amount
  int _wagerAmount = 50;
  
  // Track picks made per tab - initialized based on sport
  late Map<String, bool> _tabPicks;
  
  // Track if we should show summary
  bool _showingSummary = false;
  
  // Live betting
  bool _isLiveBetting = false;
  
  // Available intel (for pulsing indicators)
  final Map<String, String> _availableIntel = {
    'injury': 'Lakers',
    'news': 'Celtics',
  };
  
  @override
  void initState() {
    super.initState();
    _betTypeController = _getSportSpecificTabController();
    _initializeTabPicks();
    _betTypeController.addListener(_onTabChanged);
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _startCountdownTimer();
  }
  
  void _initializeTabPicks() {
    final tabOrder = _getTabOrder();
    _tabPicks = {};
    for (var tab in tabOrder) {
      if (tab != 'live') { // Don't track live tab
        _tabPicks[tab] = false;
      }
    }
  }
  
  List<String> _getTabOrder() {
    // Return the order of tabs based on sport
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
        return ['winner', 'spread', 'totals', 'props', 'live'];
      case 'MMA':
      case 'BOXING':
        return ['winner', 'method', 'rounds', 'live'];
      case 'TENNIS':
        return ['match', 'sets', 'games', 'live'];
      default:
        return ['main', 'props', 'live'];
    }
  }
  
  void _onTabChanged() {
    // Track which tab user is currently on
    setState(() {});
  }
  
  TabController _getSportSpecificTabController() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
        return TabController(length: 5, vsync: this); // Main, Spread, Totals, Props, Live
      case 'MMA':
      case 'BOXING':
        return TabController(length: 4, vsync: this); // Main, Method, Rounds, Live
      case 'TENNIS':
        return TabController(length: 4, vsync: this); // Match, Sets, Games, Live
      default:
        return TabController(length: 3, vsync: this); // Main, Props, Live
    }
  }
  
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_gameStartCountdown.inSeconds > 0) {
            _gameStartCountdown = Duration(seconds: _gameStartCountdown.inSeconds - 1);
          } else {
            _isLiveBetting = true;
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _betTypeController.removeListener(_onTabChanged);
    _betTypeController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gameTitle, style: const TextStyle(fontSize: 14)),
            Text(
              '${widget.sport} • ${widget.poolName}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isLiveBetting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.live_tv, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _gameStartCountdown.inMinutes < 30 ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDuration(_gameStartCountdown),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Stack(
            children: [
              _buildBetTypeTabs(),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildQuickProgress(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Team/Fighter Selection
          _buildTeamSelection(),
          
          // Bet Options
          Expanded(
            child: TabBarView(
              controller: _betTypeController,
              children: _buildSportSpecificTabs(),
            ),
          ),
          
          // Bet Slip
          _buildBetSlip(),
        ],
      ),
    );
  }
  
  Widget _buildBetTypeTabs() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
        return TabBar(
          controller: _betTypeController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Winner'),
            Tab(text: 'Spread'),
            Tab(text: 'Totals'),
            Tab(text: 'Props'),
            Tab(text: 'Live'),
          ],
        );
      case 'MMA':
      case 'BOXING':
        return TabBar(
          controller: _betTypeController,
          tabs: const [
            Tab(text: 'Winner'),
            Tab(text: 'Method'),
            Tab(text: 'Rounds'),
            Tab(text: 'Live'),
          ],
        );
      default:
        return TabBar(
          controller: _betTypeController,
          tabs: const [
            Tab(text: 'Main'),
            Tab(text: 'Props'),
            Tab(text: 'Live'),
          ],
        );
    }
  }
  
  List<Widget> _buildSportSpecificTabs() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
        return [
          _buildMoneylineTab(),
          _buildSpreadTab(),
          _buildTotalsTab(),
          _buildNBAPropsTab(),
          _buildLiveBettingTab(),
        ];
      case 'MMA':
        return [
          _buildMoneylineTab(),
          _buildMethodOfVictoryTab(),
          _buildRoundBettingTab(),
          _buildLiveBettingTab(),
        ];
      default:
        return [
          _buildMoneylineTab(),
          _buildGenericPropsTab(),
          _buildLiveBettingTab(),
        ];
    }
  }
  
  Widget _buildTeamSelection() {
    // For combat sports, show fighters
    if (widget.sport == 'MMA' || widget.sport == 'BOXING') {
      return _buildFighterSelection();
    }
    
    // For team sports - just show game info, no selection
    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo('Lakers', 'LAL', Colors.purple, '-150'),
          Column(
            children: [
              const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'O/U 218.5',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          _buildTeamInfo('Celtics', 'BOS', Colors.green, '+130'),
        ],
      ),
    );
  }
  
  Widget _buildFighterSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFighterCard('McGregor', 'The Notorious', Colors.green, '-180'),
          const Column(
            children: [
              Icon(Icons.sports_mma, size: 32, color: Colors.red),
              SizedBox(height: 4),
              Text('UFC 310', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          _buildFighterCard('Chandler', 'Iron', Colors.blue, '+155'),
        ],
      ),
    );
  }
  
  Widget _buildTeamInfo(String team, String abbreviation, Color color, String odds) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Text(
              abbreviation,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(team, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              odds,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFighterCard(String name, String nickname, Color color, String odds) {
    final isSelected = _selectedTeam == name;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTeam = name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.person, size: 32),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(nickname, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                odds,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMoneylineTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Winner (Moneyline)',
          'Pick which team will win the game outright. Negative odds (-150) mean you bet more to win less (favorite). Positive odds (+130) mean you bet less to win more (underdog).',
          Icons.emoji_events,
        ),
        const SizedBox(height: 16),
        _buildBetCard(
          'Lakers to Win',
          '-150',
          'Bet 150 to win 100',
          Colors.purple,
          BetType.moneyline,
          'Lakers ML',
        ),
        _buildBetCard(
          'Celtics to Win',
          '+130',
          'Bet 100 to win 130',
          Colors.green,
          BetType.moneyline,
          'Celtics ML',
        ),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildSpreadTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Point Spread',
          'Bet on the margin of victory. Favorites (-5.5) must win by more than the spread. Underdogs (+5.5) can lose by less than the spread or win outright.',
          Icons.trending_up,
        ),
        const SizedBox(height: 16),
        _buildBetCard(
          'Lakers -5.5',
          '-110',
          'Lakers win by 6 or more',
          Colors.purple,
          BetType.spread,
          'Lakers -5.5',
        ),
        _buildBetCard(
          'Celtics +5.5',
          '-110',
          'Celtics lose by 5 or less, or win',
          Colors.green,
          BetType.spread,
          'Celtics +5.5',
        ),
        const SizedBox(height: 16),
        const Text('Alternative Spreads', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('Lakers -3.5', '+105', 'Better odds, harder to hit', Colors.purple, BetType.spread, 'Lakers -3.5'),
        _buildBetCard('Lakers -7.5', '+125', 'Best odds, hardest to hit', Colors.purple, BetType.spread, 'Lakers -7.5'),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildTotalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Over/Under (Totals)',
          'Bet on the total combined score of both teams. Over means the total will be higher than the line, Under means it will be lower.',
          Icons.add_circle_outline,
        ),
        const SizedBox(height: 16),
        const Text('Game Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard(
          'Over 218.5',
          '-110',
          'Combined score 219 or more',
          Colors.orange,
          BetType.total,
          'Over 218.5',
        ),
        _buildBetCard(
          'Under 218.5',
          '-110',
          'Combined score 218 or less',
          Colors.blue,
          BetType.total,
          'Under 218.5',
        ),
        const SizedBox(height: 16),
        const Text('Team Totals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('Lakers Over 111.5', '-105', 'Lakers score 112+', Colors.purple, BetType.total, 'LAL O111.5'),
        _buildBetCard('Celtics Over 107.5', '-115', 'Celtics score 108+', Colors.green, BetType.total, 'BOS O107.5'),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildNBAPropsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Prop Bets',
          'Bet on specific events or player performances within the game. Higher risk, but more fun and engaging throughout!',
          Icons.star_outline,
        ),
        const SizedBox(height: 16),
        
        // Player Performance Props
        const Text('⭐ Player Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('LeBron Over 27.5 Points', '-120', 'Season avg: 28.2', Colors.purple, BetType.prop, 'LeBron O27.5 Pts'),
        _buildBetCard('LeBron Triple-Double', '+250', 'Yes/No', Colors.purple, BetType.prop, 'LeBron Triple-Dbl'),
        _buildBetCard('AD Over 11.5 Rebounds', '-105', 'Season avg: 12.1', Colors.purple, BetType.prop, 'AD O11.5 Reb'),
        _buildBetCard('Tatum Over 4.5 Assists', '+110', 'Season avg: 4.8', Colors.green, BetType.prop, 'Tatum O4.5 Ast'),
        _buildBetCard('Jaylen Brown 3+ Threes', '-140', 'Made 3+ in last 5 games', Colors.green, BetType.prop, 'Brown 3+ Threes'),
        
        const SizedBox(height: 20),
        // Head to Head Props
        const Text('👥 Head-to-Head', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('LeBron vs Tatum Points', '-115', 'Who scores more?', Colors.orange, BetType.prop, 'LeBron vs Tatum Pts'),
        _buildBetCard('AD vs R.Williams Rebounds', '+105', 'Who gets more boards?', Colors.orange, BetType.prop, 'AD vs Williams Reb'),
        
        const SizedBox(height: 20),
        // Team Props
        const Text('🏀 Team Props', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('Lakers Most 3-Pointers', '+120', 'Which team hits more?', Colors.purple, BetType.prop, 'LAL Most 3s'),
        _buildBetCard('First Team to 20 Points', '-105', 'Lakers favored', Colors.purple, BetType.prop, 'LAL First to 20'),
        _buildBetCard('Highest Scoring Quarter', '+150', '3rd Quarter', Colors.blue, BetType.prop, 'Q3 Highest'),
        _buildBetCard('Total Team Turnovers O/U 13.5', '-110', 'Lakers turnovers', Colors.purple, BetType.prop, 'LAL TO O13.5'),
        
        const SizedBox(height: 20),
        // Game Flow Props
        const Text('🎯 Game Flow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('First Basket Scorer', '+350', 'Anthony Davis', Colors.purple, BetType.prop, 'AD First Basket'),
        _buildBetCard('Will There Be OT?', '+600', 'Yes pays 6-to-1', Colors.red, BetType.prop, 'Overtime Yes'),
        _buildBetCard('Race to 50 Points', '-120', 'Lakers', Colors.purple, BetType.prop, 'LAL Race to 50'),
        _buildBetCard('Largest Lead O/U 14.5', '-105', 'Any team', Colors.blue, BetType.prop, 'Lead O14.5'),
        _buildBetCard('Total Dunks O/U 7.5', '+100', 'Combined both teams', Colors.orange, BetType.prop, 'Dunks O7.5'),
        
        const SizedBox(height: 20),
        // Special Combo Props
        const Text('🔥 Combo Props', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Higher odds, bigger payouts!', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        _buildBetCard('LeBron 25+ Pts & Lakers Win', '+175', 'Player + Team combo', Colors.purple, BetType.prop, 'LBJ 25+ & LAL Win'),
        _buildBetCard('AD Double-Double & Lakers Win', '+140', '10+ pts/reb & W', Colors.purple, BetType.prop, 'AD Dbl-Dbl & Win'),
        _buildBetCard('Tatum 30+ & Celtics Cover', '+280', 'Points + Spread', Colors.green, BetType.prop, 'Tatum 30+ & Cover'),
        _buildBetCard('Both Teams 100+ Points', '-130', 'High scoring game', Colors.orange, BetType.prop, 'Both 100+'),
        
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildMethodOfVictoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Method of Victory',
          'Bet on how the fight will end: KO/TKO (knockout), Submission, or Decision (goes to judges).',
          Icons.sports_mma,
        ),
        const SizedBox(height: 16),
        _buildBetCard('McGregor by KO/TKO', '+150', 'Knockout or Technical Knockout', Colors.red, BetType.method, 'McGregor KO/TKO'),
        _buildBetCard('McGregor by Submission', '+450', 'Submission victory', Colors.orange, BetType.method, 'McGregor SUB'),
        _buildBetCard('McGregor by Decision', '+300', 'Goes to judges', Colors.blue, BetType.method, 'McGregor DEC'),
        const Divider(),
        _buildBetCard('Chandler by KO/TKO', '+200', 'Knockout or Technical Knockout', Colors.red, BetType.method, 'Chandler KO/TKO'),
        _buildBetCard('Chandler by Submission', '+550', 'Submission victory', Colors.orange, BetType.method, 'Chandler SUB'),
        _buildBetCard('Chandler by Decision', '+400', 'Goes to judges', Colors.blue, BetType.method, 'Chandler DEC'),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildRoundBettingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBetTypeInfo(
          'Round Betting',
          'Bet on when the fight will end or if it will go the full distance. Higher risk, higher reward.',
          Icons.timer,
        ),
        const SizedBox(height: 16),
        const Text('Fight Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('Over 2.5 Rounds', '-130', 'Fight goes to Round 3', Colors.blue, BetType.rounds, 'Over 2.5'),
        _buildBetCard('Under 2.5 Rounds', '+110', 'Ends in Round 1 or 2', Colors.red, BetType.rounds, 'Under 2.5'),
        const SizedBox(height: 16),
        const Text('Exact Round', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBetCard('Round 1', '+300', 'Fight ends in Round 1', Colors.red, BetType.rounds, 'Round 1'),
        _buildBetCard('Round 2', '+450', 'Fight ends in Round 2', Colors.orange, BetType.rounds, 'Round 2'),
        _buildBetCard('Round 3', '+600', 'Fight ends in Round 3', Colors.yellow[700]!, BetType.rounds, 'Round 3'),
        _buildBetCard('Goes Distance', '-150', 'Full 3 rounds', Colors.green, BetType.rounds, 'Distance'),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildLiveBettingTab() {
    if (!_isLiveBetting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Live Betting Available When Game Starts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back in ${_formatDuration(_gameStartCountdown)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red),
          ),
          child: const Row(
            children: [
              Icon(Icons.live_tv, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE BETTING - Odds update in real-time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBetCard('Next Team to Score', '+105', 'Lakers', Colors.purple, BetType.live, 'LAL Next Score'),
        _buildBetCard('Next Quarter Winner', '-110', 'Q2: Lakers', Colors.purple, BetType.live, 'Q2 Winner LAL'),
        _buildBetCard('Race to 50 Points', '-120', 'First to 50', Colors.orange, BetType.live, 'Race to 50'),
        const SizedBox(height: 24),
        _buildEdgeButton(),
      ],
    );
  }
  
  Widget _buildGenericPropsTab() {
    return const Center(
      child: Text('Sport-specific props coming soon'),
    );
  }
  
  Widget _buildEdgeButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/edge',
                arguments: {
                  'gameTitle': widget.gameTitle,
                  'sport': widget.sport,
                },
              );
            },
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get The Edge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Unlock insider intelligence',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Intel indicators
                  if (_availableIntel.containsKey('injury'))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.healing,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (_availableIntel.containsKey('news'))
                    Positioned(
                      top: 8,
                      right: _availableIntel.containsKey('injury') ? 40 : 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.newspaper,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  
  Widget _buildBetCard(
    String title,
    String odds,
    String description,
    Color color,
    BetType type,
    String betId, {
    bool isPremium = false,
  }) {
    final isSelected = _selectedBets.any((bet) => bet.id == betId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedBets.removeWhere((bet) => bet.id == betId);
            } else {
              _selectedBets.add(SelectedBet(
                id: betId,
                title: title,
                odds: odds,
                type: type,
              ));
            }
          });
        },
        leading: CircleAvatar(
          backgroundColor: isSelected ? color : color.withOpacity(0.2),
          child: Icon(
            _getBetTypeIcon(type),
            color: isSelected ? Colors.white : color,
            size: 20,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            odds,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getBetTypeIcon(BetType type) {
    switch (type) {
      case BetType.moneyline:
        return Icons.attach_money;
      case BetType.spread:
        return Icons.trending_up;
      case BetType.total:
        return Icons.add_circle;
      case BetType.prop:
        return Icons.star;
      case BetType.method:
        return Icons.sports_mma;
      case BetType.rounds:
        return Icons.timer;
      case BetType.live:
        return Icons.live_tv;
    }
  }
  
  Widget _buildBetSlip() {
    if (_selectedBets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: const Center(
          child: Text(
            'Select bets to add to your slip',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    final isParlay = _selectedBets.length > 1;
    final totalOdds = _calculateParlayOdds();
    final potentialPayout = _calculatePayout(totalOdds);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isParlay ? 'Parlay (${_selectedBets.length} legs)' : 'Single Bet',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (isParlay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${totalOdds.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._selectedBets.map((bet) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bet.title,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  bet.odds,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBets.remove(bet);
                    });
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ],
            ),
          )),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wager Amount', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '50',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _wagerAmount = int.tryParse(value) ?? 50;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Potential Payout', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$potentialPayout BR',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _placeBet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Place Bet ($_wagerAmount BR)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculateParlayOdds() {
    if (_selectedBets.length <= 1) {
      return _parseOdds(_selectedBets.first.odds);
    }
    
    // Simplified parlay calculation
    double multiplier = 1;
    for (var bet in _selectedBets) {
      multiplier *= (_parseOdds(bet.odds) / 100 + 1);
    }
    return (multiplier - 1) * 100;
  }
  
  double _parseOdds(String odds) {
    // Convert American odds to decimal for calculation
    final value = double.tryParse(odds.replaceAll('+', '').replaceAll('-', '')) ?? 100;
    if (odds.startsWith('+')) {
      return value;
    } else {
      return 100 / value * 100;
    }
  }
  
  int _calculatePayout(double odds) {
    return (_wagerAmount * (odds / 100 + 1)).toInt();
  }
  
  void _placeBet() {
    // Mark current tab as having a bet placed
    _markCurrentTabAsHavingBet();
    
    final betType = _selectedBets.length > 1 ? 'Parlay' : 'Single';
    
    // Check if all tabs have picks
    final allPicked = _tabPicks.values.every((picked) => picked);
    
    if (allPicked && !_showingSummary) {
      // Show summary screen
      _showBetSummary();
    } else {
      // Show confirmation and navigate to next unpicked tab
      _showBetConfirmationAndNavigate(betType);
    }
  }
  
  void _markCurrentTabAsHavingBet() {
    // Mark the current tab index as having a bet placed
    final currentIndex = _betTypeController.index;
    final tabOrder = _getTabOrder();
    
    if (currentIndex < tabOrder.length) {
      setState(() {
        _tabPicks[tabOrder[currentIndex]] = true;
      });
    }
  }
  
  void _showBetConfirmationAndNavigate(String betType) {
    // Find next unpicked tab
    int nextTabIndex = _getNextUnpickedTab();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Bet Placed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$betType bet placed successfully'),
            Text('Wager: $_wagerAmount BR'),
            if (_selectedBets.length > 1)
              Text('${_selectedBets.length} legs'),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            if (nextTabIndex != -1)
              const Text(
                '💡 Try the Spread next for more betting options!',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear current bets for next selection
              setState(() {
                _selectedBets.clear();
              });
              // Navigate to next tab if available
              if (nextTabIndex != -1) {
                _betTypeController.animateTo(nextTabIndex);
              }
            },
            child: Text(nextTabIndex != -1 ? 'Next Tab' : 'Continue'),
          ),
        ],
      ),
    );
  }
  
  int _getNextUnpickedTab() {
    // Map tab indices to pick status
    final tabOrder = _getTabOrder();
    
    // Only check non-live tabs (exclude the last 'live' tab)
    final checkLength = Math.min(tabOrder.length - 1, _betTypeController.length - 1);
    
    for (int i = 0; i < checkLength; i++) {
      if (tabOrder[i] != 'live' && !(_tabPicks[tabOrder[i]] ?? false)) {
        return i;
      }
    }
    return -1; // All tabs have picks
  }
  
  Widget _buildProgressIndicator() {
    final pickedCount = _tabPicks.values.where((v) => v).length;
    final totalTabs = _tabPicks.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress: $pickedCount of $totalTabs picks made',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: totalTabs > 0 ? pickedCount / totalTabs : 0,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            pickedCount == totalTabs ? Colors.green : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _buildTabStatusWidgets(),
        ),
      ],
    );
  }
  
  List<Widget> _buildTabStatusWidgets() {
    final widgets = <Widget>[];
    final tabOrder = _getTabOrder();
    final displayNames = _getTabDisplayNames();
    
    for (int i = 0; i < tabOrder.length && i < _betTypeController.length - 1; i++) {
      final tabKey = tabOrder[i];
      if (tabKey != 'live') {
        widgets.add(_buildTabStatus(
          displayNames[tabKey] ?? tabKey,
          _tabPicks[tabKey] ?? false,
        ));
      }
    }
    return widgets;
  }
  
  Map<String, String> _getTabDisplayNames() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
      case 'NFL':
      case 'NHL':
        return {
          'winner': 'Winner',
          'spread': 'Spread',
          'totals': 'O/U',
          'props': 'Props',
        };
      case 'MMA':
      case 'BOXING':
        return {
          'winner': 'Winner',
          'method': 'Method',
          'rounds': 'Rounds',
        };
      case 'TENNIS':
        return {
          'match': 'Match',
          'sets': 'Sets',
          'games': 'Games',
        };
      default:
        return {
          'main': 'Main',
          'props': 'Props',
        };
    }
  }
  
  Widget _buildTabStatus(String label, bool isPicked) {
    return Column(
      children: [
        Icon(
          isPicked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isPicked ? Colors.green : Colors.grey,
          size: 20,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isPicked ? Colors.green : Colors.grey,
            fontWeight: isPicked ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  void _showBetSummary() {
    setState(() {
      _showingSummary = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('All Picks Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              color: Colors.amber,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 You\'ve made picks for all categories!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Good luck with your bets!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to pool selection
            },
            child: const Text('View Other Games'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedBets.clear();
                _showingSummary = false;
              });
            },
            child: const Text('Review My Picks'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBetTypeInfo(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _showInfoDialog(title, description, icon);
                      },
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showInfoDialog(String title, String description, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            const Text(
              'Tips:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (title.contains('Winner'))
              const Text('• Best for beginners\n• Simple win/lose outcome\n• Check team form and head-to-head records'),
            if (title.contains('Spread'))
              const Text('• More balanced odds\n• Consider home advantage\n• Look at recent scoring margins'),
            if (title.contains('Over/Under'))
              const Text('• Study team scoring averages\n• Check pace of play\n• Weather can affect totals'),
            if (title.contains('Prop'))
              const Text('• Research player stats\n• Check injury reports\n• Consider matchup advantages'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickProgress() {
    final pickedCount = _tabPicks.values.where((v) => v).length;
    final totalTabs = _tabPicks.length;
    
    if (pickedCount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pickedCount == totalTabs ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pickedCount/$totalTabs',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.check,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }
}

enum BetType {
  moneyline,
  spread,
  total,
  prop,
  method,
  rounds,
  live,
}

class SelectedBet {
  final String id;
  final String title;
  final String odds;
  final BetType type;
  
  SelectedBet({
    required this.id,
    required this.title,
    required this.odds,
    required this.type,
  });
}