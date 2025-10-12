import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/game_model.dart';
import '../../theme/app_theme.dart';
import '../watch/watch_live_screen.dart';

/// Live Game Detail Screen
/// Displays current score, status, and provides quick access to watch the game live
class GameDetailScreen extends StatefulWidget {
  final String gameId;

  const GameDetailScreen({
    super.key,
    required this.gameId,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBlue,
        title: const Text(
          'Live Game',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.gameId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryCyan,
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState();
          }

          final game = GameModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
          return _buildLiveGameContent(game);
        },
      ),
    );
  }

  Widget _buildLiveGameContent(GameModel game) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Live Status Badge
          _buildLiveStatusBadge(game),
          const SizedBox(height: 30),

          // Team Scores
          _buildTeamScores(game),
          const SizedBox(height: 30),

          // Game Info
          _buildGameInfo(game),
          const SizedBox(height: 30),

          // Watch Live Button
          _buildWatchLiveButton(game),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBadge(GameModel game) {
    final isLive = _isGameLive(game);
    final statusText = _getStatusText(game);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLive
              ? [Colors.red, Colors.red.shade700]
              : [Colors.orange, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: (isLive ? Colors.red : Colors.orange).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          if (isLive) const SizedBox(width: 10),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScores(GameModel game) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.surfaceBlue, AppTheme.cardBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Home Team
          _buildTeamRow(
            teamName: game.homeTeam,
            score: game.homeScore,
            logoUrl: game.homeTeamLogo,
            isHome: true,
          ),

          const SizedBox(height: 20),

          // VS Divider
          Text(
            'VS',
            style: TextStyle(
              color: AppTheme.primaryCyan.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // Away Team
          _buildTeamRow(
            teamName: game.awayTeam,
            score: game.awayScore,
            logoUrl: game.awayTeamLogo,
            isHome: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow({
    required String teamName,
    int? score,
    String? logoUrl,
    required bool isHome,
  }) {
    return Row(
      children: [
        // Team Logo
        if (logoUrl != null)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  PhosphorIconsRegular.shieldStar,
                  color: AppTheme.primaryCyan,
                  size: 40,
                );
              },
            ),
          )
        else
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              PhosphorIconsRegular.shieldStar,
              color: AppTheme.primaryCyan,
              size: 40,
            ),
          ),

        const SizedBox(width: 16),

        // Team Name
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(width: 16),

        // Score
        Text(
          score?.toString() ?? '-',
          style: const TextStyle(
            color: AppTheme.neonGreen,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGameInfo(GameModel game) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Venue
          if (game.venue != null)
            _buildInfoRow(
              icon: PhosphorIconsRegular.mapPin,
              label: game.venue!,
            ),

          if (game.venue != null && game.broadcast != null)
            const SizedBox(height: 12),

          // Broadcast
          if (game.broadcast != null)
            _buildInfoRow(
              icon: PhosphorIconsRegular.television,
              label: game.broadcast!,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryCyan,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWatchLiveButton(GameModel game) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WatchLiveScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: AppTheme.neonGreen.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsFill.playCircle,
              color: AppTheme.deepBlue,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'WATCH LIVE NOW',
              style: TextStyle(
                color: AppTheme.deepBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 80,
              color: AppTheme.errorPink,
            ),
            const SizedBox(height: 24),
            const Text(
              'Game Not Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load game information',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  color: AppTheme.deepBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if game is currently live
  bool _isGameLive(GameModel game) {
    final status = game.status.toLowerCase();
    return status == 'in_progress' ||
           status == 'live' ||
           status == 'active' ||
           status.contains('quarter') ||
           status.contains('half') ||
           status.contains('period') ||
           status.contains('inning');
  }

  /// Get status text for display
  String _getStatusText(GameModel game) {
    if (_isGameLive(game)) {
      // Show period/quarter info if available
      if (game.period != null && game.timeRemaining != null) {
        return '🔴 LIVE - ${game.period} ${game.timeRemaining}';
      } else if (game.period != null) {
        return '🔴 LIVE - ${game.period}';
      }
      return '🔴 LIVE';
    } else if (game.status.toLowerCase() == 'final') {
      return 'FINAL';
    }
    return game.status.toUpperCase();
  }
}
