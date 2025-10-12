import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/mini_game_model.dart';
import '../../services/mini_games_service.dart';
import '../../services/ad_reward_service.dart';
import '../../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Screen for playing a mini-game in a WebView
class MiniGamePlayScreen extends StatefulWidget {
  final MiniGameModel game;

  const MiniGamePlayScreen({
    super.key,
    required this.game,
  });

  @override
  State<MiniGamePlayScreen> createState() => _MiniGamePlayScreenState();
}

class _MiniGamePlayScreenState extends State<MiniGamePlayScreen> {
  final MiniGamesService _gamesService = MiniGamesService();
  final AdRewardService _adService = AdRewardService();
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasDeductedFee = false;
  bool _hasSubmittedScore = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _deductEntryFee();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.deepBlue)
      ..addJavaScriptChannel(
        'FlutterGameBridge',
        onMessageReceived: (JavaScriptMessage message) {
          // Auto-capture score from game
          final score = int.tryParse(message.message);
          if (score != null && !_hasSubmittedScore) {
            _submitScore(score);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            _showErrorDialog('Failed to load game: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.game.embedUrl));
  }

  Future<void> _deductEntryFee() async {
    if (_hasDeductedFee) return;

    final success = await _gamesService.deductEntryFee();
    if (!success) {
      if (mounted) {
        _showInsufficientBRDialog();
      }
      return;
    }

    setState(() {
      _hasDeductedFee = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_hasSubmittedScore) {
          return await _showExitConfirmation();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepBlue,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceBlue,
          title: Text(
            widget.game.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                PhosphorIconsRegular.arrowClockwise,
                color: AppTheme.primaryCyan,
              ),
              onPressed: () {
                _webViewController.reload();
              },
            ),
            IconButton(
              icon: Icon(
                PhosphorIconsRegular.checkCircle,
                color: AppTheme.neonGreen,
              ),
              onPressed: _showSubmitScoreDialog,
            ),
          ],
        ),
        body: Stack(
          children: [
            // WebView
            WebViewWidget(controller: _webViewController),

            // Loading Indicator
            if (_isLoading)
              Container(
                color: AppTheme.deepBlue,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.primaryCyan,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading ${widget.game.name}...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
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
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.info,
                color: AppTheme.primaryCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Play the game and tap ✓ when done to submit your score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmitScoreDialog() {
    final scoreController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlue,
        title: Row(
          children: [
            Icon(
              PhosphorIconsRegular.trophy,
              color: AppTheme.neonGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Submit Score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your final score:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                ),
                filled: true,
                fillColor: AppTheme.cardBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryCyan,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neonGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.shieldCheck,
                    color: AppTheme.neonGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top 3 may need screenshot verification',
                      style: TextStyle(
                        color: AppTheme.neonGreen.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final scoreText = scoreController.text.trim();
              if (scoreText.isEmpty) {
                return;
              }

              final score = int.tryParse(scoreText);
              if (score == null || score < 0) {
                _showErrorDialog('Please enter a valid score');
                return;
              }

              Navigator.pop(context);
              await _submitScore(score);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(
                color: AppTheme.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScore(int score) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(height: 16),
              const Text(
                'Submitting score...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Get username
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? user?.email?.split('@')[0] ?? 'Player';

    // Submit score
    final success = await _gamesService.submitScore(
      gameId: widget.game.id,
      score: score,
      username: username,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        setState(() {
          _hasSubmittedScore = true;
        });

        // Show success and offer ad reward
        await _showSuccessDialog(score);
      } else {
        _showErrorDialog('Failed to submit score. Please try again.');
      }
    }
  }

  Future<void> _showSuccessDialog(int score) async {
    // Get user's rank
    final userRank = await _gamesService.getUserRank(widget.game.id);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlue,
        title: Row(
          children: [
            Icon(
              PhosphorIconsFill.checkCircle,
              color: AppTheme.neonGreen,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Score Submitted!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Score',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              score.toString(),
              style: const TextStyle(
                color: AppTheme.neonGreen,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Show rank if available
            if (userRank != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: userRank <= 10
                      ? AppTheme.neonGreen.withOpacity(0.2)
                      : AppTheme.primaryCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: userRank <= 10
                        ? AppTheme.neonGreen
                        : AppTheme.primaryCyan.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      userRank <= 3
                          ? PhosphorIconsFill.crown
                          : PhosphorIconsRegular.trophy,
                      color: userRank <= 10 ? AppTheme.neonGreen : AppTheme.primaryCyan,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userRank <= 10
                          ? 'Rank #$userRank - You\'re in the prize zone! 🎉'
                          : 'Current Rank: #$userRank',
                      style: TextStyle(
                        color: userRank <= 10 ? AppTheme.neonGreen : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryCyan.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.videoCamera,
                    color: AppTheme.primaryCyan,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Watch an ad to play again for free!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to lobby
            },
            child: const Text(
              'Back to Lobby',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _watchAdAndPlayAgain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Watch Ad',
              style: TextStyle(
                color: AppTheme.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAdAndPlayAgain() async {
    // Show rewarded ad
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final adResult = await _adService.showRewardedAd(user.uid);

    if (adResult.success && mounted) {
      // Reset state for new game
      setState(() {
        _hasDeductedFee = true; // Already paid via ad
        _hasSubmittedScore = false;
      });

      // Reload game
      _webViewController.reload();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.neonGreen,
          content: Row(
            children: [
              Icon(
                PhosphorIconsFill.checkCircle,
                color: AppTheme.deepBlue,
              ),
              const SizedBox(width: 12),
              const Text(
                'Free play unlocked! Good luck!',
                style: TextStyle(
                  color: AppTheme.deepBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
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
              'Exit Game?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'You haven\'t submitted your score yet. Your 5 BR entry fee won\'t be refunded.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Playing',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Exit Anyway',
              style: TextStyle(
                color: AppTheme.errorPink,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showInsufficientBRDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to lobby
            },
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

  void _showErrorDialog(String message) {
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
              'Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          message,
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
}
