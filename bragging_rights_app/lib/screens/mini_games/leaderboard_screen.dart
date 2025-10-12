import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mini_game_model.dart';
import '../../services/mini_games_service.dart';
import '../../theme/app_theme.dart';

/// Leaderboard Screen for a specific mini-game
class LeaderboardScreen extends StatefulWidget {
  final MiniGameModel game;

  const LeaderboardScreen({
    super.key,
    required this.game,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final MiniGamesService _gamesService = MiniGamesService();
  int? _userRank;

  @override
  void initState() {
    super.initState();
    _loadUserRank();
  }

  Future<void> _loadUserRank() async {
    final rank = await _gamesService.getUserRank(widget.game.id);
    if (mounted) {
      setState(() {
        _userRank = rank;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBlue,
        title: Text(
          '${widget.game.name} - Leaderboard',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header with prize info
          _buildHeader(),

          // Leaderboard
          Expanded(
            child: StreamBuilder<GameLeaderboard?>(
              stream: _gamesService.getGameLeaderboard(widget.game.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryCyan,
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return _buildEmptyState();
                }

                final leaderboard = snapshot.data!;
                final sortedScores = leaderboard.getSortedScores();

                if (sortedScores.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildLeaderboardList(sortedScores);
              },
            ),
          ),

          // User's stats footer
          _buildUserStatsFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surfaceBlue, AppTheme.deepBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.trophy,
                color: AppTheme.neonGreen,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Countdown timer
          StreamBuilder<GameLeaderboard?>(
            stream: _gamesService.getGameLeaderboard(widget.game.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final weekEnd = snapshot.data!.weekEnd;
                final now = DateTime.now();
                final difference = weekEnd.difference(now);

                if (difference.isNegative) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorPink.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.errorPink,
                      ),
                    ),
                    child: const Text(
                      '⏰ Week ended - Prizes being distributed!',
                      style: TextStyle(
                        color: AppTheme.errorPink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                final days = difference.inDays;
                final hours = difference.inHours % 24;
                final minutes = difference.inMinutes % 60;

                String timeLeft;
                if (days > 0) {
                  timeLeft = '$days day${days > 1 ? 's' : ''} ${hours}h left';
                } else if (hours > 0) {
                  timeLeft = '${hours}h ${minutes}m left';
                } else {
                  timeLeft = '${minutes}m left';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.neonGreen,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.clock,
                        color: AppTheme.neonGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeLeft,
                        style: const TextStyle(
                          color: AppTheme.neonGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(height: 16),

          // Prize pool info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Prize Pool Distribution',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPrizeItem('1st', '500 BR', Colors.amber),
                    _buildPrizeItem('2nd', '250 BR', Colors.grey[400]!),
                    _buildPrizeItem('3rd', '100 BR', Colors.brown[400]!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '4th-10th: 50 BR each',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(String place, String prize, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            place,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          prize,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> scores) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scores.length,
      itemBuilder: (context, index) {
        final entry = scores[index];
        final rank = index + 1;
        final isCurrentUser = entry.userId == currentUserId;
        final isTopThree = rank <= 3;

        return _buildLeaderboardEntry(
          entry: entry,
          rank: rank,
          isCurrentUser: isCurrentUser,
          isTopThree: isTopThree,
        );
      },
    );
  }

  Widget _buildLeaderboardEntry({
    required LeaderboardEntry entry,
    required int rank,
    required bool isCurrentUser,
    required bool isTopThree,
  }) {
    Color rankColor;
    IconData? rankIcon;

    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = PhosphorIconsFill.crown;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = PhosphorIconsFill.medal;
    } else if (rank == 3) {
      rankColor = Colors.brown[400]!;
      rankIcon = PhosphorIconsFill.medal;
    } else {
      rankColor = AppTheme.primaryCyan;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isCurrentUser
            ? LinearGradient(
                colors: [
                  AppTheme.primaryCyan.withOpacity(0.3),
                  AppTheme.surfaceBlue,
                ],
              )
            : null,
        color: isCurrentUser ? null : AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryCyan
              : isTopThree
                  ? rankColor.withOpacity(0.5)
                  : AppTheme.primaryCyan.withOpacity(0.2),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          if (isTopThree)
            BoxShadow(
              color: rankColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 50,
            child: Column(
              children: [
                if (rankIcon != null)
                  Icon(
                    rankIcon,
                    color: rankColor,
                    size: 28,
                  )
                else
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: AppTheme.deepBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(entry.timestamp),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.5),
              ),
            ),
            child: Text(
              entry.score.toString(),
              style: const TextStyle(
                color: AppTheme.neonGreen,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: StreamBuilder<UserGameStats?>(
        stream: _gamesService.getUserGameStats(widget.game.id),
        builder: (context, snapshot) {
          final stats = snapshot.data;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: PhosphorIconsRegular.target,
                label: 'Your Rank',
                value: _userRank != null ? '#$_userRank' : '-',
              ),
              _buildStatItem(
                icon: PhosphorIconsRegular.chartBar,
                label: 'Best Score',
                value: stats?.bestScore.toString() ?? '-',
              ),
              _buildStatItem(
                icon: PhosphorIconsRegular.repeat,
                label: 'Attempts',
                value: stats?.attempts.toString() ?? '0',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: AppTheme.primaryCyan,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.trophy,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'No Scores Yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to play and set the record!',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}
