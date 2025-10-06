import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/wallet_service.dart';
import '../screens/transactions/transaction_history_screen.dart';

/// Displays user's BR balance with animated effects
class BrBalanceWidget extends StatefulWidget {
  final bool showDetails;
  final bool compact;
  final VoidCallback? onTap;

  const BrBalanceWidget({
    super.key,
    this.showDetails = false,
    this.compact = false,
    this.onTap,
  });

  @override
  State<BrBalanceWidget> createState() => _BrBalanceWidgetState();
}

class _BrBalanceWidgetState extends State<BrBalanceWidget>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  late AnimationController _glowController;
  int? _previousBalance;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleBalanceChange(int newBalance) {
    if (_previousBalance != null && newBalance > _previousBalance!) {
      // Balance increased - show celebration animation
      _showBalanceIncrease(newBalance - _previousBalance!);
    }
    _previousBalance = newBalance;
  }

  void _showBalanceIncrease(int amount) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.trending_up, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              '+$amount BR',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToTransactionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactBalance();
    }

    return _buildFullBalance();
  }

  Widget _buildCompactBalance() {
    return StreamBuilder<int>(
      stream: _walletService.balanceStream,
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;

        // Track balance changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (snapshot.hasData) {
            _handleBalanceChange(balance);
          }
        });

        return GestureDetector(
          onTap: widget.onTap ?? _navigateToTransactionHistory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryCyan.withOpacity(0.3),
                  AppTheme.secondaryCyan.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryCyan.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.primaryCyan,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$balance BR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: AppTheme.primaryCyan.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 300.ms,
              ),
        );
      },
    );
  }

  Widget _buildFullBalance() {
    return StreamBuilder<int>(
      stream: _walletService.balanceStream,
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;

        // Track balance changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (snapshot.hasData) {
            _handleBalanceChange(balance);
          }
        });

        return GestureDetector(
          onTap: widget.onTap ?? _navigateToTransactionHistory,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surfaceBlue.withOpacity(0.3),
                      AppTheme.surfaceBlue.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCyan.withOpacity(
                        0.1 + (_glowController.value * 0.1),
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: AppTheme.primaryCyan,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BR Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (widget.showDetails)
                          Icon(
                            Icons.chevron_right,
                            color: AppTheme.primaryCyan,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: AppTheme.primaryCyan.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'BR',
                            style: TextStyle(
                              color: AppTheme.primaryCyan,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.showDetails) ...[
                      const SizedBox(height: 12),
                      const Divider(
                        color: Colors.white24,
                        height: 1,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'View Transaction History',
                        Icons.history,
                      ),
                    ],
                  ],
                ),
              );
            },
          ).animate().fadeIn(duration: 600.ms).slideY(
                begin: 0.1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }

  Widget _buildDetailRow(String text, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryCyan,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.chevron_right,
          color: Colors.white.withOpacity(0.5),
          size: 16,
        ),
      ],
    );
  }
}

/// Compact version for app bars and headers
class BrBalanceChip extends StatelessWidget {
  final VoidCallback? onTap;

  const BrBalanceChip({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return const BrBalanceWidget(
      compact: true,
    );
  }
}
