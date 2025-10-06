import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/br_currency_service.dart';
import '../../widgets/br_app_bar.dart';

/// Daily bonus claim screen with login streak display
class DailyBonusScreen extends StatefulWidget {
  const DailyBonusScreen({super.key});

  @override
  State<DailyBonusScreen> createState() => _DailyBonusScreenState();
}

class _DailyBonusScreenState extends State<DailyBonusScreen>
    with SingleTickerProviderStateMixin {
  final BRCurrencyService _currencyService = BRCurrencyService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _pulseController;
  bool _isClaiming = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _claimDailyBonus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _showErrorSnackbar('Please log in to claim bonus');
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final result = await _currencyService.claimDailyBonusAsMap(userId);

      if (result['success'] == true) {
        setState(() => _claimed = true);

        // Show success animation
        _showSuccessDialog(
          amount: result['amount'] ?? 50,
          isStreakBonus: result['streakBonus'] == true,
          newStreak: result['newStreak'] ?? 1,
        );
      } else {
        _showErrorSnackbar(result['message'] ?? 'Unable to claim bonus');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to claim bonus: $e');
    } finally {
      setState(() => _isClaiming = false);
    }
  }

  void _showSuccessDialog({
    required int amount,
    required bool isStreakBonus,
    required int newStreak,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceBlue.withOpacity(0.95),
                AppTheme.deepBlue.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryCyan.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                color: AppTheme.neonGreen,
                size: 64,
              ).animate(onPlay: (controller) => controller.repeat()).scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.2, 1.2),
                    duration: 800.ms,
                  ),
              const SizedBox(height: 16),
              Text(
                'Bonus Claimed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+$amount BR',
                style: TextStyle(
                  color: AppTheme.neonGreen,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppTheme.neonGreen.withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              if (isStreakBonus) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentPurple.withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: AppTheme.accentPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '7-Day Streak Bonus!',
                        style: TextStyle(
                          color: AppTheme.accentPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '$newStreak day streak',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: const BRAppBar(title: 'Daily Rewards'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _auth.currentUser != null
            ? _currencyService.getDailyBonusStatus(_auth.currentUser!.uid)
            : Future.value({'canClaim': false, 'currentStreak': 0, 'longestStreak': 0}),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading bonus status',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final status = snapshot.data ?? {};
          final canClaim = status['canClaim'] ?? false;
          final currentStreak = status['currentStreak'] ?? 0;
          final longestStreak = status['longestStreak'] ?? 0;
          final nextBonusAt = status['nextBonusAt'] as DateTime?;
          final dailyAmount = 50;
          final streakBonusAmount = 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Daily Bonus Card
                _buildDailyBonusCard(
                  canClaim: canClaim && !_claimed,
                  nextBonusAt: nextBonusAt,
                  dailyAmount: dailyAmount,
                ),
                const SizedBox(height: 20),

                // Current Streak Display
                _buildStreakCard(
                  currentStreak: currentStreak,
                  longestStreak: longestStreak,
                ),
                const SizedBox(height: 20),

                // Streak Calendar
                _buildStreakCalendar(currentStreak),
                const SizedBox(height: 20),

                // Rewards Info
                _buildRewardsInfo(dailyAmount, streakBonusAmount),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyBonusCard({
    required bool canClaim,
    required DateTime? nextBonusAt,
    required int dailyAmount,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceBlue.withOpacity(0.3),
                AppTheme.surfaceBlue.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canClaim
                  ? AppTheme.neonGreen.withOpacity(0.5)
                  : AppTheme.primaryCyan.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: canClaim
                ? [
                    BoxShadow(
                      color: AppTheme.neonGreen.withOpacity(
                        0.2 + (_pulseController.value * 0.3),
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                Icons.card_giftcard,
                color: canClaim ? AppTheme.neonGreen : AppTheme.primaryCyan,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                canClaim ? 'Daily Bonus Available!' : 'Come Back Tomorrow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+$dailyAmount BR',
                style: TextStyle(
                  color: canClaim ? AppTheme.neonGreen : Colors.white70,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!canClaim && nextBonusAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Next bonus: ${_formatTimeUntil(nextBonusAt)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canClaim && !_isClaiming ? _claimDailyBonus : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canClaim
                        ? AppTheme.neonGreen
                        : Colors.grey.shade700,
                    disabledBackgroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isClaiming
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          canClaim ? 'Claim Bonus' : 'Already Claimed',
                          style: TextStyle(
                            color: canClaim ? AppTheme.deepBlue : Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 400.ms,
            );
      },
    );
  }

  Widget _buildStreakCard({
    required int currentStreak,
    required int longestStreak,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 140,
      borderRadius: BorderRadius.circular(16),
      blur: 20,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          AppTheme.surfaceBlue.withOpacity(0.1),
          AppTheme.surfaceBlue.withOpacity(0.05),
        ],
      ),
      borderGradient: LinearGradient(
        colors: [
          AppTheme.accentPurple.withOpacity(0.5),
          AppTheme.primaryCyan.withOpacity(0.3),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: AppTheme.accentPurple,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentStreak',
                    style: TextStyle(
                      color: AppTheme.accentPurple,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    currentStreak == 1 ? 'day' : 'days',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: AppTheme.neonGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Best Streak',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$longestStreak',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    longestStreak == 1 ? 'day' : 'days',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideX(
          begin: -0.1,
          end: 0,
          duration: 400.ms,
        );
  }

  Widget _buildStreakCalendar(int currentStreak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-Day Progress',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayNumber = index + 1;
              final isCompleted = dayNumber <= currentStreak;
              final isToday = dayNumber == currentStreak;
              final isStreakBonus = dayNumber == 7;

              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? (isStreakBonus
                              ? AppTheme.accentPurple
                              : AppTheme.primaryCyan)
                          : Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.neonGreen
                            : (isCompleted
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.3)),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? Icon(
                              isStreakBonus
                                  ? Icons.local_fire_department
                                  : Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Day $dayNumber',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
        );
  }

  Widget _buildRewardsInfo(int dailyAmount, int streakBonusAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Reward Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRewardRow(
            icon: Icons.calendar_today,
            title: 'Daily Login',
            amount: '+$dailyAmount BR',
            color: AppTheme.primaryCyan,
          ),
          const SizedBox(height: 12),
          _buildRewardRow(
            icon: Icons.local_fire_department,
            title: '7-Day Streak Bonus',
            amount: '+$streakBonusAmount BR',
            color: AppTheme.accentPurple,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.neonGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Login every day to build your streak and earn bonus rewards!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
        );
  }

  Widget _buildRewardRow({
    required IconData icon,
    required String title,
    required String amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTimeUntil(DateTime target) {
    final now = DateTime.now();
    final difference = target.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Soon';
    }
  }
}
