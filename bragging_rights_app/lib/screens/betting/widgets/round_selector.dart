import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class RoundSelector extends StatelessWidget {
  final int? currentRound;
  final int maxRounds;
  final bool isActive;
  final VoidCallback? onTap;

  const RoundSelector({
    Key? key,
    this.currentRound,
    required this.maxRounds,
    required this.isActive,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ROUND PREDICTION label
        Text(
          'ROUND PREDICTION',
          style: TextStyle(
            color: AppTheme.primaryCyan.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        // Round selector button
        GestureDetector(
          onTap: isActive ? onTap : () {
            // Visual feedback that fighter must be selected first
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Select a fighter first'),
                duration: Duration(seconds: 1),
                backgroundColor: AppTheme.warningAmber,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive && currentRound != null && currentRound! > 0
                    ? [AppTheme.primaryCyan.withOpacity(0.3), AppTheme.primaryCyan.withOpacity(0.1)]
                    : [Colors.transparent, Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              color: !isActive || currentRound == null || currentRound == 0
                  ? AppTheme.surfaceBlue.withOpacity(0.3)
                  : null,
              border: Border.all(
                color: isActive && currentRound != null && currentRound! > 0
                    ? AppTheme.primaryCyan
                    : AppTheme.borderCyan.withOpacity(0.3),
                width: isActive && currentRound != null && currentRound! > 0 ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive && currentRound != null && currentRound! > 0
                  ? AppTheme.neonGlow(
                      color: AppTheme.primaryCyan,
                      intensity: 0.3,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isActive && currentRound != null && currentRound! > 0
                      ? AppTheme.primaryCyan
                      : AppTheme.primaryCyan.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  currentRound != null && currentRound! > 0
                      ? 'Round $currentRound'
                      : 'Select Round',
                  style: TextStyle(
                    color: isActive && currentRound != null && currentRound! > 0
                        ? AppTheme.primaryCyan
                        : AppTheme.primaryCyan.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: AppTheme.primaryCyan.withOpacity(0.3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}