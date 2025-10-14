import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/mini_game_model.dart';
import '../../services/mini_games_service.dart';
import '../../theme/app_theme.dart';
import 'mini_game_play_screen.dart';

/// Mini-Games Lobby Screen
/// Displays available mini-games
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
    print('🎮 [MINI-GAMES LOBBY] initState called');
    _loadBRBalance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🎮 [MINI-GAMES LOBBY] didChangeDependencies called');
  }

  Future<void> _loadBRBalance() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 [MINI-GAMES LOBBY] Loading BR balance...');
    print('🔍 [MINI-GAMES LOBBY] Current _currentBR value: $_currentBR');

    final balance = await _gamesService.getUserBRBalance();

    print('🔍 [MINI-GAMES LOBBY] Service returned balance: $balance');
    print('🔍 [MINI-GAMES LOBBY] Widget mounted: $mounted');

    if (mounted) {
      setState(() {
        _currentBR = balance;
      });
      print('✅ [MINI-GAMES LOBBY] State updated successfully');
      print('✅ [MINI-GAMES LOBBY] New _currentBR value: $_currentBR');
    } else {
      print('❌ [MINI-GAMES LOBBY] Widget not mounted, skipping setState');
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 [MINI-GAMES LOBBY] build() called - Timestamp: ${DateTime.now()}');
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Games Grid with Featured Game
          StreamBuilder<List<MiniGameModel>>(
            stream: _gamesService.getActiveGames(),
            builder: (context, snapshot) {
              print('🎮 [MINI-GAMES LOBBY] StreamBuilder builder called - ConnectionState: ${snapshot.connectionState}');
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

              // Find featured game (or use first game as fallback)
              final featuredGame = games.firstWhere(
                (g) => g.featured,
                orElse: () => games.first,
              );

              return SliverList(
                delegate: SliverChildListDelegate([
                  // Featured Game Section
                  _buildFeaturedGame(featuredGame),

                  // Games Grid
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        return _buildGameCard(games[index]);
                      },
                    ),
                  ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    print('🎨 [MINI-GAMES LOBBY] _buildHeader() called - BR: $_currentBR');
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
        ],
      ),
    );
  }

  /// Featured Game Section
  Widget _buildFeaturedGame(MiniGameModel game) {
    print('⭐ [MINI-GAMES LOBBY] _buildFeaturedGame() called - Game: ${game.title}');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Animated background effect - Static gradient (animation removed to prevent flickering)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: isMobile
                  ? _buildFeaturedGameVertical(game)
                  : _buildFeaturedGameHorizontal(game),
            ),
          ],
        ),
      ),
    );
  }

  /// Featured Game - Horizontal Layout (Tablet/Desktop)
  Widget _buildFeaturedGameHorizontal(MiniGameModel game) {
    return Row(
      children: [
        // Left: Game info
        Expanded(
          flex: 60,
          child: _buildFeaturedGameInfo(game),
        ),
        const SizedBox(width: 20),
        // Right: Preview image
        Expanded(
          flex: 40,
          child: _buildFeaturedGamePreview(game),
        ),
      ],
    );
  }

  /// Featured Game - Vertical Layout (Mobile)
  Widget _buildFeaturedGameVertical(MiniGameModel game) {
    return Column(
      children: [
        _buildFeaturedGameInfo(game),
        const SizedBox(height: 20),
        _buildFeaturedGamePreview(game),
      ],
    );
  }

  /// Featured Game Info Section
  Widget _buildFeaturedGameInfo(MiniGameModel game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Featured Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsFill.star, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'FEATURED THIS WEEK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Game Title
        Text(
          game.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // Long Description
        Text(
          game.longDescription.isNotEmpty
              ? game.longDescription
              : game.description,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            height: 1.5,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 16),

        // Stats Row
        Row(
          children: [
            _buildFeaturedStat(
              PhosphorIconsRegular.users,
              game.playerCount > 0
                  ? '${_formatPlayerCount(game.playerCount)} players'
                  : 'Be the first!',
            ),
            const SizedBox(width: 16),
            _buildFeaturedStat(
              PhosphorIconsRegular.clock,
              '~${game.averageDuration} min',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Play Button
        ElevatedButton(
          onPressed: () => _handleGameTap(game),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF667eea),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsBold.play, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Play Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Featured Game Stat Widget
  Widget _buildFeaturedStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Featured Game Preview Section
  Widget _buildFeaturedGamePreview(MiniGameModel game) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: game.thumbnailUrl != null && game.thumbnailUrl!.isNotEmpty
            ? Image.network(
                game.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      _getIconForGame(game.icon),
                      size: 80,
                      color: Colors.white,
                    ),
                  );
                },
              )
            : Center(
                child: Icon(
                  _getIconForGame(game.icon),
                  size: 80,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildGameCard(MiniGameModel game) {
    print('🎴 [MINI-GAMES LOBBY] _buildGameCard() called - Game: ${game.title}');
    return GestureDetector(
      onTap: () => _handleGameTap(game),
      child: Stack(
        children: [
          Container(
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
            // Game Thumbnail - Larger preview
            Container(
              height: 140, // Increased from 100 to 140
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: game.thumbnailUrl != null && game.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        game.thumbnailUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackIcon(game);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildFallbackIcon(game);
                        },
                      )
                    : _buildFallbackIcon(game),
              ),
            ),

            // Game Info - Expanded area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Badge
                    _buildCategoryBadge(game.category),
                    const SizedBox(height: 3),

                    // Game Title
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Statistics Row
                    _buildStatsRow(game),

                    const SizedBox(height: 4),

                    // Play Button with Cost
                    _buildPlayButton(game),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

          // Favorite Heart Icon (top-right corner)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _handleFavoriteTap(game),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  game.isFavorited
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  color: game.isFavorited ? Colors.red : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Badge Widget
  Widget _buildCategoryBadge(String category) {
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Get category color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'trivia':
        return const Color(0xFF9b59b6); // Purple
      case 'sports':
        return const Color(0xFF3498db); // Blue
      case 'arcade':
      case 'racing':
        return const Color(0xFF2ecc71); // Green
      case 'puzzle':
        return const Color(0xFFe67e22); // Orange
      case 'casino':
      case 'cards':
        return const Color(0xFFf39c12); // Gold
      case 'strategy':
        return const Color(0xFFe74c3c); // Red
      default:
        return AppTheme.primaryCyan; // Default cyan
    }
  }

  /// Statistics Row Widget
  Widget _buildStatsRow(MiniGameModel game) {
    return Row(
      children: [
        // Player count
        if (game.playerCount > 0) ...[
          Icon(
            PhosphorIconsRegular.users,
            size: 10,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 2),
          Text(
            _formatPlayerCount(game.playerCount),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Duration
        Icon(
          PhosphorIconsRegular.clock,
          size: 10,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 2),
        Text(
          '~${game.averageDuration}m',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 9,
          ),
        ),

        const SizedBox(width: 8),

      ],
    );
  }

  /// Format player count (1234 -> 1.2k)
  String _formatPlayerCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  /// Play Button with Cost
  Widget _buildPlayButton(MiniGameModel game) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleGameTap(game),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonGreen,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsBold.play,
              size: 11,
              color: AppTheme.deepBlue,
            ),
            const SizedBox(width: 4),
            const Text(
              'PLAY',
              style: TextStyle(
                color: AppTheme.deepBlue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
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

  Future<void> _handleFavoriteTap(MiniGameModel game) async {
    print('❤️ [FAVORITE] Toggling favorite for ${game.title}');

    final isFavorited = await _gamesService.toggleFavorite(game.id);

    // Update local state
    setState(() {
      game.isFavorited = isFavorited;
    });

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorited
                ? '❤️ Added to favorites!'
                : '💔 Removed from favorites',
            style: const TextStyle(fontSize: 14),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: isFavorited ? Colors.red : Colors.grey[700],
        ),
      );
    }
  }

  void _handleGameTap(MiniGameModel game) {
    print('');
    print('╔═══════════════════════════════════════════════════╗');
    print('║        GAME TAP HANDLER - START                   ║');
    print('╚═══════════════════════════════════════════════════╝');
    print('🎮 Game tapped: ${game.title}');
    print('🎮 Game ID: ${game.id}');
    print('🎮 Game BR cost: ${game.brCost}');
    print('💰 Current _currentBR value in state: $_currentBR');
    print('💰 _currentBR type: ${_currentBR.runtimeType}');
    print('💰 game.brCost type: ${game.brCost.runtimeType}');
    print('');

    // Check BR balance with detailed logging
    print('🔍 Performing BR check:');
    print('   $_currentBR < ${game.brCost}');
    print('   Result: ${_currentBR < game.brCost}');
    print('');

    if (_currentBR < game.brCost) {
      print('╔═══════════════════════════════════════════════════╗');
      print('║   ❌ INSUFFICIENT BR - SHOWING DIALOG             ║');
      print('╚═══════════════════════════════════════════════════╝');
      print('   Required: ${game.brCost} BR');
      print('   Current: $_currentBR BR');
      print('   Deficit: ${game.brCost - _currentBR} BR');
      print('');

      _showInsufficientBRDialog(game.brCost);
      return;
    }

    print('╔═══════════════════════════════════════════════════╗');
    print('║   ✅ BR CHECK PASSED - NAVIGATING TO GAME         ║');
    print('╚═══════════════════════════════════════════════════╝');
    print('');

    // Navigate to game play screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MiniGamePlayScreen(game: game),
      ),
    ).then((_) {
      // Reload BR balance when returning
      print('🔄 [GAME TAP] Returned from game, reloading BR balance...');
      _loadBRBalance();
    });
  }


  void _showInsufficientBRDialog(int requiredBR) {
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
        content: Text(
          'You need at least $requiredBR BR to play this game. Place bets or earn BR to continue!\n\nCurrent balance: $_currentBR BR',
          style: const TextStyle(
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

  Widget _buildFallbackIcon(MiniGameModel game) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.neonGreen.withOpacity(0.3), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForGame(game.icon),
          size: 60,
          color: AppTheme.neonGreen,
        ),
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
