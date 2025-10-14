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
  DateTime? _playStartTime;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _deductEntryFee();
    _trackGameStart();
  }

  @override
  void dispose() {
    _trackGameEnd();
    super.dispose();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.deepBlue)
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

  void _trackGameStart() {
    _playStartTime = DateTime.now();
    _gamesService.trackGamePlay(widget.game.id, 'started');
    print('🎮 [GAME TRACKING] ${widget.game.title} - Started at ${_playStartTime}');
  }

  void _trackGameEnd() {
    if (_playStartTime != null) {
      final duration = DateTime.now().difference(_playStartTime!);
      _gamesService.trackGamePlay(
        widget.game.id,
        'ended',
        duration: duration,
      );
      print('🎮 [GAME TRACKING] ${widget.game.title} - Ended after ${duration.inMinutes}m ${duration.inSeconds % 60}s');
    }
  }

  Future<void> _deductEntryFee() async {
    if (_hasDeductedFee) return;

    final success = await _gamesService.deductEntryFee(
      widget.game.id,
      widget.game.brCost,
    );

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
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBlue,
        title: Text(
          widget.game.title,
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
            tooltip: 'Reload Game',
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
                      'Loading ${widget.game.title}...',
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
    );
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
        content: Text(
          'You need at least ${widget.game.brCost} BR to play this game. Place bets or earn BR to continue!',
          style: const TextStyle(
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
