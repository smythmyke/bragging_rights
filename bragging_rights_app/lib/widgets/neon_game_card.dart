import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import '../theme/app_theme.dart';
import '../models/game_model.dart';

class NeonGameCard extends StatefulWidget {
  final GameModel game;
  final VoidCallback onTap;
  final bool showLiveIndicator;

  const NeonGameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.showLiveIndicator = false,
  });

  @override
  State<NeonGameCard> createState() => _NeonGameCardState();
}

class _NeonGameCardState extends State<NeonGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.showLiveIndicator) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.98 : 1.0),
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (widget.showLiveIndicator)
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(
                    0.3 + (_glowController.value * 0.2),
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GlassmorphicContainer(
              width: double.infinity,
              height: 120,
              borderRadius: BorderRadius.circular(16),
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  AppTheme.surfaceBlue.withOpacity(0.1),
                  AppTheme.surfaceBlue.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderGradient: LinearGradient(
                colors: [
                  widget.showLiveIndicator
                      ? AppTheme.neonGreen.withOpacity(0.5)
                      : AppTheme.primaryCyan.withOpacity(0.3),
                  AppTheme.primaryCyan.withOpacity(0.1),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with live indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.game.sport.toUpperCase()} • ${widget.game.league}',
                            style: TextStyle(
                              color: AppTheme.primaryCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.showLiveIndicator)
                          _buildLiveIndicator(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Teams
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTeamName(widget.game.homeTeam),
                              const SizedBox(height: 4),
                              _buildTeamName(widget.game.awayTeam),
                            ],
                          ),
                        ),
                        // Scores
                        if (widget.game.homeScore != null &&
                            widget.game.awayScore != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildScore(widget.game.homeScore!),
                              const SizedBox(height: 4),
                              _buildScore(widget.game.awayScore!),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Game time or status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatGameTime(widget.game.gameTime),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (widget.game.odds != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryCyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.primaryCyan.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Odds: ${widget.game.odds}',
                              style: TextStyle(
                                color: AppTheme.primaryCyan,
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
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.neonGreen,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonGreen.withOpacity(
                  0.6 + (_glowController.value * 0.4),
                ),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.deepBlue,
                  shape: BoxShape.circle,
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(),
              ).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                duration: 1000.ms,
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: AppTheme.deepBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamName(String name) {
    return Text(
      name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildScore(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryCyan.withOpacity(0.3),
            AppTheme.secondaryCyan.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          color: AppTheme.primaryCyan,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: AppTheme.primaryCyan.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  String _formatGameTime(DateTime gameTime) {
    final now = DateTime.now();
    final difference = gameTime.difference(now);
    
    if (difference.inMinutes < 0) {
      return 'In Progress';
    } else if (difference.inHours < 1) {
      return 'Starting in ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Today ${gameTime.hour}:${gameTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${gameTime.month}/${gameTime.day} ${gameTime.hour}:${gameTime.minute.toString().padLeft(2, '0')}';
    }
  }
}