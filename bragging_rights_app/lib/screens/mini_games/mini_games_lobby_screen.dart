import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/mini_game_model.dart';
import '../../services/mini_games_service.dart';
import '../../theme/app_theme.dart';
import 'mini_game_play_screen.dart';
import 'leaderboard_screen.dart';

/// Mini-Games Lobby Screen
/// Displays available games, leaderboards, and user stats
class MiniGamesLobbyScreen extends StatefulWidget {
  const MiniGamesLobbyScreen({super.key});

  @override
  State<MiniGamesLobbyScreen> createState() => _MiniGamesLobbyScreenState();
}

class _MiniGamesLobbyScreenState extends State<MiniGamesLobbyScreen> {
  final MiniGamesService _gamesService = MiniGamesService();
  int _currentBR = 0;

  @override
  void initState() {
    super.initState();
    _loadBRBalance();
  }

  Future<void> _loadBRBalance() async {
    final balance = await _gamesService.getUserBRBalance();
    if (mounted) {
      setState(() {
        _currentBR = balance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Games Grid
          StreamBuilder<List<MiniGameModel>>(
            stream: _gamesService.getActiveGames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyState(),
                );
              }

              final games = snapshot.data!;

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildGameCard(games[index]);
                    },
                    childCount: games.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surfaceBlue, AppTheme.deepBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.gameController,
                color: AppTheme.neonGreen,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Mini-Games Arena',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // BR Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryCyan, AppTheme.primaryCyan.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsFill.star,
                  color: AppTheme.deepBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_currentBR BR',
                  style: const TextStyle(
                    color: AppTheme.deepBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.info,
                  color: AppTheme.neonGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '5 BR per play • Weekly prizes for top 10 players!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(MiniGameModel game) {
    return GestureDetector(
      onTap: () => _handleGameTap(game),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.surfaceBlue, AppTheme.cardBlue],
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
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Icon
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.neonGreen.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Center(
                child: Icon(
                  _getIconForGame(game.icon),
                  size: 60,
                  color: AppTheme.neonGreen,
                ),
              ),
            ),

            // Game Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Game Name
                    Text(
                      game.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Actions
                    Row(
                      children: [
                        // Play Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleGameTap(game),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonGreen,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'PLAY',
                              style: TextStyle(
                                color: AppTheme.deepBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Leaderboard Button
                        IconButton(
                          onPressed: () => _showLeaderboard(game),
                          icon: Icon(
                            PhosphorIconsRegular.trophy,
                            color: AppTheme.primaryCyan,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryCyan.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.gameController,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 24),
          Text(
            'No Games Available',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Check back soon for new games!',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleGameTap(MiniGameModel game) {
    // Check BR balance
    if (_currentBR < 5) {
      _showInsufficientBRDialog();
      return;
    }

    // Navigate to game play screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MiniGamePlayScreen(game: game),
      ),
    ).then((_) {
      // Reload BR balance when returning
      _loadBRBalance();
    });
  }

  void _showLeaderboard(MiniGameModel game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaderboardScreen(game: game),
      ),
    );
  }

  void _showInsufficientBRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlue,
        title: Row(
          children: [
            Icon(
              PhosphorIconsRegular.warning,
              color: AppTheme.errorPink,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Insufficient BR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'You need at least 5 BR to play this game. Place bets or earn BR to continue!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForGame(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'basketball':
        return PhosphorIconsFill.basketball;
      case 'football':
        return PhosphorIconsFill.footballHelmet;
      case 'soccer':
        return PhosphorIconsFill.soccerBall;
      case 'brain':
      case 'trivia':
        return PhosphorIconsFill.brain;
      case 'cards':
        return PhosphorIconsFill.cards;
      case 'target':
        return PhosphorIconsFill.target;
      default:
        return PhosphorIconsFill.gameController;
    }
  }
}
