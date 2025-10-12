import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/welcome_back_data.dart';
import '../services/welcome_back_service.dart';
import '../services/ad_reward_service.dart';
import '../services/br_currency_service.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Welcome Back Overlay - shows user activity since last login
class WelcomeBackOverlay extends StatefulWidget {
  final WelcomeBackData data;
  final VoidCallback onDismiss;
  final VoidCallback? onNavigateToBets;
  final VoidCallback? onNavigateToGames;

  const WelcomeBackOverlay({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onNavigateToBets,
    this.onNavigateToGames,
  });

  @override
  State<WelcomeBackOverlay> createState() => _WelcomeBackOverlayState();
}

class _WelcomeBackOverlayState extends State<WelcomeBackOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Logo pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Ad bonus services
  final AdRewardService _adService = AdRewardService();
  final BRCurrencyService _brService = BRCurrencyService();

  // Ad bonus state
  bool _isDailyAdBonusAvailable = false;
  bool _isDailyAdBonusClaimed = false;
  bool _isLoadingAdBonus = false;

  @override
  void initState() {
    super.initState();

    // Capture layout errors to debug yellow underlines
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflow') ||
          details.toString().contains('RenderFlex')) {
        debugPrint('🔴 OVERFLOW ERROR DETECTED:');
        debugPrint('   Exception: ${details.exception}');
        debugPrint('   Library: ${details.library}');
        debugPrint('   Context: ${details.context}');
        debugPrint('   Stack trace:');
        debugPrint('${details.stack}');
      }
      // Still show the error in debug mode
      FlutterError.presentError(details);
    };

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Initialize pulse animation for BR logo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000), // 3 second cycle
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.forward();
    _pulseController.repeat(); // Loop the pulse animation

    // Log when overlay is mounted
    debugPrint('🎨 WelcomeBackOverlay: Mounted and ready');
    debugPrint('   - Data: ${widget.data.wins}W-${widget.data.losses}L');
    debugPrint('   - Balance: ${widget.data.oldBalance} → ${widget.data.newBalance}');
    debugPrint('   - Settled bets: ${widget.data.settledBets.length}');

    // Check if daily ad bonus is available and preload ad
    _checkDailyAdBonusAvailability();
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();

    // Update last login data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await WelcomeBackService().updateLastLoginData(
        userId: user.uid,
        currentBalance: widget.data.newBalance,
        globalRank: widget.data.newGlobalRank,
        friendsRank: widget.data.newFriendsRank,
      );
    }

    widget.onDismiss();
  }

  Future<void> _checkDailyAdBonusAvailability() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final lastBonusDate = data['lastDailyAdBonusDate'] as String?;
      final today = _getTodayDateString();

      setState(() {
        _isDailyAdBonusAvailable = lastBonusDate != today;
        _isDailyAdBonusClaimed = lastBonusDate == today;
      });

      debugPrint('🎁 Daily Ad Bonus: Available=$_isDailyAdBonusAvailable, Claimed=$_isDailyAdBonusClaimed');
    } catch (e) {
      debugPrint('Error checking daily ad bonus: $e');
    }
  }

  Future<void> _claimDailyAdBonus() async {
    if (!_isDailyAdBonusAvailable || _isLoadingAdBonus) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingAdBonus = true;
    });

    try {
      // Check if ad is ready
      if (!_adService.isAdReady()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ad is loading... Please try again in a moment'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _adService.loadRewardedAd();
        setState(() {
          _isLoadingAdBonus = false;
        });
        return;
      }

      // Show ad
      final result = await _adService.showRewardedAd(user.uid);

      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoadingAdBonus = false;
        });
        return;
      }

      // Award bonus BR (50 BR for watching ad)
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      final currentBalance = (userDoc.data()?['brBalance'] ?? 0) as int;
      final newBalance = currentBalance + 50;

      await userRef.update({
        'brBalance': newBalance,
        'totalBrEarned': FieldValue.increment(50),
        'lastDailyAdBonusDate': _getTodayDateString(),
      });

      // Log analytics
      await FirebaseFirestore.instance.collection('daily_ad_bonuses').add({
        'userId': user.uid,
        'amount': 50,
        'claimedAt': FieldValue.serverTimestamp(),
        'source': 'welcome_back_overlay',
      });

      setState(() {
        _isDailyAdBonusAvailable = false;
        _isDailyAdBonusClaimed = true;
        _isLoadingAdBonus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎁 +50 BR claimed! Thanks for watching!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ Daily ad bonus claimed successfully!');

      // Navigate to Games page after successful ad watch
      await _dismiss();
      if (widget.onNavigateToGames != null) {
        widget.onNavigateToGames!();
      }
    } catch (e) {
      debugPrint('Error claiming daily ad bonus: $e');
      setState(() {
        _isLoadingAdBonus = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to claim bonus. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: DefaultTextStyle(
              style: const TextStyle(
                decoration: TextDecoration.none, // Remove all decorations
                shadows: [], // Remove all shadows
              ),
              child: _buildCard(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.surfaceBlue, AppTheme.cardBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryCyan, width: 2),
        boxShadow: AppTheme.neonGlow(color: AppTheme.primaryCyan, intensity: 0.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildWalletUpdate(),
              if (widget.data.settledBets.isNotEmpty) _buildSettledBets(),
              _buildPerformanceSnapshot(),
              _buildLeaderboardUpdates(),
              if (_isDailyAdBonusAvailable || _isDailyAdBonusClaimed)
                _buildCompactAdButton(),
              _buildDismissButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // BR Logo with pulse animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              // Interpolate between cyan and gold glow colors
              final glowColor = Color.lerp(
                AppTheme.primaryCyan,
                const Color(0xFFf4c542), // Gold color
                _pulseAnimation.value,
              )!;

              return Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/br_initials_icon.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          Text(
            'Welcome Back!',
            style: const TextStyle(
              color: AppTheme.primaryCyan,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [], // Explicitly remove shadows
              inherit: false, // Don't inherit theme styles
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.clockCountdown,
                color: Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Last seen: ${widget.data.timeSinceLastLogin}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAdButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isDailyAdBonusClaimed || _isLoadingAdBonus
              ? null
              : _claimDailyAdBonus,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDailyAdBonusClaimed
                ? Colors.grey
                : AppTheme.warningAmber,
            disabledBackgroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _isLoadingAdBonus
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: AppTheme.deepBlue,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(
                      _isDailyAdBonusClaimed
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsFill.videoCamera,
                      color: AppTheme.deepBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDailyAdBonusClaimed
                          ? 'Daily Ad Bonus Claimed (+50 BR)'
                          : 'Watch Ad for +50 BR Bonus',
                      style: const TextStyle(
                        color: AppTheme.deepBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWalletUpdate() {
    final isProfit = widget.data.balanceChange >= 0;
    final percentChange = widget.data.balanceChangePercentage;

    debugPrint('💰 Building Wallet Update: ${widget.data.oldBalance} → ${widget.data.newBalance} (${percentChange.toStringAsFixed(1)}%)');

    return _buildSection(
      icon: PhosphorIconsFill.wallet,
      title: 'Wallet Update',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.data.oldBalance} BR',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.lineThrough,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppTheme.primaryCyan),
              TweenAnimationBuilder<int>(
                tween: IntTween(
                  begin: widget.data.oldBalance,
                  end: widget.data.newBalance,
                ),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Text(
                    '$value BR',
                    style: TextStyle(
                      color: isProfit ? AppTheme.neonGreen : AppTheme.errorPink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [], // Explicitly remove shadows
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isProfit
                      ? AppTheme.neonGreen
                      : AppTheme.errorPink)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isProfit
                        ? AppTheme.neonGreen
                        : AppTheme.errorPink)
                    .withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  isProfit
                      ? PhosphorIconsFill.trendUp
                      : PhosphorIconsFill.trendDown,
                  color: isProfit ? AppTheme.neonGreen : AppTheme.errorPink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${isProfit ? '+' : ''}${widget.data.balanceChange} BR (${percentChange.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: isProfit ? AppTheme.neonGreen : AppTheme.errorPink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [], // Explicitly remove shadows
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettledBets() {
    final summary = widget.data.settledBetsSummary;

    debugPrint('🎯 Building Settled Bets: ${widget.data.settledBets.length} bets, Net: ${summary.netProfit} BR');

    return _buildSection(
      icon: PhosphorIconsFill.crosshair,
      title: 'While You Were Away',
      child: Column(
        children: [
          ...widget.data.settledBets.map((bet) => _buildBetItem(bet)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Net: ${summary.isProfit ? '+' : ''}${summary.netProfit} BR (${summary.record})',
              style: const TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [], // Explicitly remove shadows
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetItem(SettledBet bet) {
    debugPrint('   💵 Bet Item: "${bet.gameName}" - ${bet.betType} (${bet.isWin ? 'WON' : 'LOST'} ${bet.amount} BR)');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            bet.isWin
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsFill.xCircle,
            color: bet.isWin ? AppTheme.neonGreen : AppTheme.errorPink,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bet.gameName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [], // Explicitly remove shadows
                  ),
                ),
                Text(
                  bet.betType,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    shadows: [], // Explicitly remove shadows
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              PhosphorIcon(
                bet.isWin
                    ? PhosphorIconsFill.arrowUp
                    : PhosphorIconsFill.arrowDown,
                color: bet.isWin ? AppTheme.neonGreen : AppTheme.errorPink,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${bet.amount} BR',
                style: TextStyle(
                  color: bet.isWin ? AppTheme.neonGreen : AppTheme.errorPink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSnapshot() {
    debugPrint('📊 Building Performance Snapshot: ${widget.data.wins}-${widget.data.losses}, Streak: ${widget.data.currentStreak}');

    return _buildSection(
      icon: PhosphorIconsFill.chartLineUp,
      title: 'Performance Snapshot',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard(
            icon: PhosphorIconsRegular.listChecks,
            label: 'Record',
            value: '${widget.data.wins}-${widget.data.losses} (${widget.data.winRate.toStringAsFixed(0)}%)',
          ),
          _buildStatCard(
            icon: PhosphorIconsRegular.flame,
            label: 'Streak',
            value: widget.data.currentStreak >= 0
                ? '🔥 ${widget.data.currentStreak} wins'
                : '💧 ${widget.data.currentStreak.abs()} losses',
          ),
          _buildStatCard(
            icon: PhosphorIconsRegular.coins,
            label: 'Total Profit',
            value: '+${widget.data.totalProfit} BR',
            valueColor: AppTheme.neonGreen,
          ),
          _buildStatCard(
            icon: PhosphorIconsRegular.percent,
            label: 'Win Rate',
            value: '${widget.data.winRate.toStringAsFixed(0)}%',
            valueColor: AppTheme.primaryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    debugPrint('   📈 Stat Card: $label = "$value"');

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(icon, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [], // Explicitly remove shadows
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardUpdates() {
    final globalImproved = widget.data.globalRankChange > 0;
    final friendsImproved = widget.data.friendsRankChange > 0;

    debugPrint('🏆 Building Leaderboard: Global ${widget.data.oldGlobalRank}→${widget.data.newGlobalRank}, Friends ${widget.data.oldFriendsRank}→${widget.data.newFriendsRank}');

    return _buildSection(
      icon: PhosphorIconsFill.ranking,
      title: 'Leaderboard Updates',
      child: Column(
        children: [
          _buildRankChange(
            icon: PhosphorIconsRegular.globe,
            label: 'Global',
            oldRank: widget.data.oldGlobalRank,
            newRank: widget.data.newGlobalRank,
            improved: globalImproved,
          ),
          const SizedBox(height: 10),
          _buildRankChange(
            icon: PhosphorIconsRegular.users,
            label: 'Friends',
            oldRank: widget.data.oldFriendsRank,
            newRank: widget.data.newFriendsRank,
            improved: friendsImproved,
          ),
          if (widget.data.friendsPassed.isNotEmpty) ...[
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen.withOpacity(0.1),
                      border: Border.all(
                        color: AppTheme.neonGreen.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(
                          PhosphorIconsFill.handFist,
                          color: AppTheme.neonGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'You passed ${widget.data.friendsPassed.join(', ')}!',
                            style: const TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: [], // Explicitly remove shadows
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankChange({
    required IconData icon,
    required String label,
    required int oldRank,
    required int newRank,
    required bool improved,
  }) {
    final change = oldRank - newRank;

    debugPrint('   📍 Rank Change Widget: $label #$oldRank → #$newRank (change: ${change > 0 ? '+' : ''}$change)');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          PhosphorIcon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                shadows: [], // Explicitly remove shadows
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '#$oldRank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              shadows: [], // Explicitly remove shadows
            ),
          ),
          const SizedBox(width: 6),
          PhosphorIcon(
            improved
                ? PhosphorIconsBold.arrowUp
                : PhosphorIconsBold.arrowDown,
            color: improved ? AppTheme.neonGreen : AppTheme.errorPink,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '#$newRank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [], // Explicitly remove shadows
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${change > 0 ? '+' : ''}$change)',
            style: TextStyle(
              color: improved ? AppTheme.neonGreen : AppTheme.errorPink,
              fontSize: 12,
              shadows: [], // Explicitly remove shadows
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDismissButton() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _dismiss,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonGreen,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: AppTheme.neonGreen.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Got It, Let\'s Go!',
                style: TextStyle(
                  color: AppTheme.deepBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIconsBold.rocketLaunch,
                color: AppTheme.deepBlue,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryCyan.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, color: AppTheme.primaryCyan, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [], // Explicitly remove shadows
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
