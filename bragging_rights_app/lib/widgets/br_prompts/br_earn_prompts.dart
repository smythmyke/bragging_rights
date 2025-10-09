import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Custom themed popups for encouraging users to watch ads and earn BR
/// Matches the neon cyber theme of the app
class BREarnPrompts {
  /// Show Insufficient Funds Dialog (Center Screen)
  /// Triggered when user tries to place bet but doesn't have enough BR
  static Future<bool> showInsufficientFundsDialog(
    BuildContext context, {
    required int currentBalance,
    required int required_amount,
    required int shortfall,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _InsufficientFundsDialog(
        currentBalance: currentBalance,
        requiredAmount: required_amount,
        shortfall: shortfall,
      ),
    );
    return result ?? false; // false = user dismissed or clicked cancel
  }

  /// Show Low Balance Banner (Top of Screen)
  /// Triggered when BR balance drops below 25 BR
  static void showLowBalanceBanner(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _LowBalanceBanner(
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Show Daily Login Bottom Sheet
  /// Triggered once per day on first app open
  static Future<bool> showDailyLoginSheet(
    BuildContext context, {
    required int adsAvailable,
    required int maxBRToday,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DailyLoginSheet(
        adsAvailable: adsAvailable,
        maxBRToday: maxBRToday,
      ),
    );
    return result ?? false;
  }

  /// Show Post-Loss Floating Card
  /// Triggered after user loses a bet
  static void showPostLossCard(
    BuildContext context, {
    required int brLost,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _PostLossFloatingCard(
        brLost: brLost,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    // Wait 3 seconds after loss before showing (let user process)
    Future.delayed(const Duration(seconds: 3), () {
      overlay.insert(overlayEntry);

      // Auto-dismiss after 7 seconds
      Future.delayed(const Duration(seconds: 7), () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    });
  }
}

/// Insufficient Funds Dialog - Center Screen
class _InsufficientFundsDialog extends StatelessWidget {
  final int currentBalance;
  final int requiredAmount;
  final int shortfall;

  const _InsufficientFundsDialog({
    required this.currentBalance,
    required this.requiredAmount,
    required this.shortfall,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceBlue,
              AppTheme.deepPurple,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.neonGreen,
            width: 2,
          ),
          boxShadow: AppTheme.neonGlow(color: AppTheme.neonGreen),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.neonGreen.withOpacity(0.2),
                      boxShadow: AppTheme.neonGlow(
                        color: AppTheme.neonGreen.withOpacity(0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: AppTheme.neonGreen,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Not Enough BR!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Balance Info
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                children: [
                  const TextSpan(text: 'You have '),
                  TextSpan(
                    text: '$currentBalance BR',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.neonGreen,
                    ),
                  ),
                  const TextSpan(text: '\nYou need '),
                  TextSpan(
                    text: '$requiredAmount BR',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const TextSpan(text: '\n\nShort by '),
                  TextSpan(
                    text: '$shortfall BR',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Call to Action
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.neonGreen.withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline,
                      color: AppTheme.neonGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Watch 1 video = 50 BR',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      Navigator.of(context).pushNamed('/br-shop');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: AppTheme.neonGreen,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Watch Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
}

/// Low Balance Banner - Top of Screen
class _LowBalanceBanner extends StatefulWidget {
  final VoidCallback onDismiss;

  const _LowBalanceBanner({required this.onDismiss});

  @override
  State<_LowBalanceBanner> createState() => _LowBalanceBannerState();
}

class _LowBalanceBannerState extends State<_LowBalanceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/br-shop');
                _dismiss();
              },
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.neonGreen.withOpacity(0.9),
                      AppTheme.neonGreen.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.neonGlow(
                    color: AppTheme.neonGreen.withOpacity(0.6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.black, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Low on BR! Tap to watch videos and earn up to 150 BR today ⚡',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: _dismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Daily Login Bottom Sheet
class _DailyLoginSheet extends StatelessWidget {
  final int adsAvailable;
  final int maxBRToday;

  const _DailyLoginSheet({
    required this.adsAvailable,
    required this.maxBRToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.deepPurple,
            AppTheme.surfaceBlue,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.neonGreen.withOpacity(0.3),
                  AppTheme.neonGreen.withOpacity(0.1),
                ],
              ),
              boxShadow: AppTheme.neonGlow(color: AppTheme.neonGreen),
            ),
            child: const Icon(
              Icons.monetization_on,
              size: 56,
              color: AppTheme.neonGreen,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Text(
            '💰 Daily Free BR!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Message
          Text(
            'Watch up to $adsAvailable videos today',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Earning potential
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: AppTheme.neonGreen, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Earn up to $maxBRToday BR FREE',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.neonGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Watch Now Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).pushNamed('/br-shop');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: AppTheme.neonGreen,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_filled, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Watch Now',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Later button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Post-Loss Floating Card
class _PostLossFloatingCard extends StatefulWidget {
  final int brLost;
  final VoidCallback onDismiss;

  const _PostLossFloatingCard({
    required this.brLost,
    required this.onDismiss,
  });

  @override
  State<_PostLossFloatingCard> createState() => _PostLossFloatingCardState();
}

class _PostLossFloatingCardState extends State<_PostLossFloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.black38,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/br-shop');
                  _dismiss();
                },
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.deepPurple,
                        AppTheme.surfaceBlue,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.neonPurple,
                      width: 2,
                    ),
                    boxShadow: AppTheme.neonGlow(color: AppTheme.neonPurple),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: AppTheme.neonPurple,
                      ),
                      const SizedBox(height: 16),
                      // Title
                      const Text(
                        'Tough Loss! 💪',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Lost amount
                      Text(
                        'Lost ${widget.brLost} BR',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Encouragement
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neonGreen.withOpacity(0.3),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Earn it back FREE!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neonGreen,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Watch videos to get back in the game',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tap to open
                      const Text(
                        'Tap anywhere to watch now',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
