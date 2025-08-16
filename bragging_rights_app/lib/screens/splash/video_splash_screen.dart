import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // Randomly select video
  final List<String> _videos = [
    'assets/videos/trophy_animation.mp4',
    'assets/videos/braggy_face_animation.mp4',
  ];
  
  late String _selectedVideo;

  @override
  void initState() {
    super.initState();
    
    // Randomly select which video to play
    final random = Random();
    _selectedVideo = _videos[random.nextInt(_videos.length)];
    
    print('VideoSplashScreen: Selected video: $_selectedVideo');
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('VideoSplashScreen: Initializing video controller...');
      _videoController = VideoPlayerController.asset(_selectedVideo);
      await _videoController!.initialize();
      
      print('VideoSplashScreen: Video initialized. Duration: ${_videoController!.value.duration}');
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Play video
        print('VideoSplashScreen: Starting video playback...');
        await _videoController!.play();
        
        // Listen for video completion
        _videoController!.addListener(_checkVideoProgress);
      }
    } catch (e) {
      print('VideoSplashScreen: Error loading video: $e');
      // If video fails to load, navigate to login immediately
      _navigateToLogin();
    }
  }

  void _checkVideoProgress() {
    if (_videoController != null && 
        _videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.duration > Duration.zero) {
      print('VideoSplashScreen: Video completed. Navigating to login...');
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    
    print('VideoSplashScreen: Navigating to login screen...');
    // Remove listener to prevent multiple navigations
    _videoController?.removeListener(_checkVideoProgress);
    
    // Navigate to login screen
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _videoController?.removeListener(_checkVideoProgress);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('VideoSplashScreen: Building widget. Video initialized: $_isVideoInitialized');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player - Full Screen
          if (_isVideoInitialized && _videoController != null)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            // Black screen while loading
            Container(
              color: Colors.black,
            ),
        ],
      ),
    );
  }
}