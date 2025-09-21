import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isVideoReady = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    // Setup fade animation for smooth video appearance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);
    
    _initializeVideo();
    
    // Fallback navigation after 4 seconds if video fails
    Future.delayed(const Duration(seconds: 4), () {
      if (!_hasNavigated && mounted) {
        _navigateToLogin();
      }
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/splash_video.mp4');
      
      // Initialize the video controller
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoReady = true;
        });
        
        // Start fade in animation
        _fadeController.forward();
        
        // Set video properties
        _controller!.setLooping(false);
        _controller!.setVolume(0); // Mute the video
        
        // Add listener for when video is near completion (stop 0.2 seconds early)
        _controller!.addListener(() {
          final duration = _controller!.value.duration;
          final position = _controller!.value.position;
          final stopTime = duration - const Duration(milliseconds: 200);

          if (position >= stopTime &&
              duration > Duration.zero &&
              !_hasNavigated) {
            _controller!.pause(); // Pause to avoid choppy ending
            _navigateToLogin();
          }
        });
        
        // Start playing
        await _controller!.play();
      }
    } catch (e) {
      print('VideoSplashScreen: Error initializing video: $e');
      // If video fails, navigate after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_hasNavigated) {
          _navigateToLogin();
        }
      });
    }
  }

  void _navigateToLogin() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    if (!mounted) return;
    
    print('VideoSplashScreen: Navigating to login screen...');
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark blue background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background with fade animation
          if (_isVideoReady && _controller != null)
            FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain, // Back to original
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
          
        ],
      ),
    );
  }
}