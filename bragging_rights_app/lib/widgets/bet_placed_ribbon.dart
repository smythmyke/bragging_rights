import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Corner ribbon widget to indicate a bet has been placed
class BetPlacedRibbon extends StatelessWidget {
  final bool isVisible;
  final String text;
  final bool animate;

  const BetPlacedRibbon({
    Key? key,
    this.isVisible = true,
    this.text = 'BET PLACED',
    this.animate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 0,
      child: AnimatedContainer(
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.neonGreen,
                AppTheme.neonGreen.withOpacity(0.8),
                AppTheme.primaryCyan.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonGreen.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppTheme.neonGreen.withOpacity(0.2),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 12,
                color: AppTheme.deepBlue,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: AppTheme.deepBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(1, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alternative minimal ribbon without icon
class MinimalBetRibbon extends StatelessWidget {
  final bool isVisible;

  const MinimalBetRibbon({
    Key? key,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: 0,
        height: 0,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 40,
              color: AppTheme.neonGreen,
            ),
            right: BorderSide(
              width: 40,
              color: AppTheme.neonGreen,
            ),
            bottom: const BorderSide(
              width: 40,
              color: Colors.transparent,
            ),
            left: const BorderSide(
              width: 40,
              color: Colors.transparent,
            ),
          ),
        ),
        child: Positioned(
          top: 5,
          right: 5,
          child: Transform.rotate(
            angle: 0.785398, // 45 degrees in radians
            child: Text(
              '✓',
              style: TextStyle(
                color: AppTheme.deepBlue,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}