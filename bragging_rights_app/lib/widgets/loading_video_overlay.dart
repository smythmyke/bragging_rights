import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LoadingVideoOverlay extends StatefulWidget {
  final bool isLoading;
  final Widget? child;
  final String loadingText;
  
  const LoadingVideoOverlay({
    super.key,
    required this.isLoading,
    this.child,
    this.loadingText = 'Analyzing data...',
  });

  @override
  State<LoadingVideoOverlay> createState() => _LoadingVideoOverlayState();
}

class _LoadingVideoOverlayState extends State<LoadingVideoOverlay>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isVideoReady = false;
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize video when widget is created
    _initializeVideo();
  }
  
  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/videos/edge_loading_video.mp4',
      );
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoReady = true;
        });
        
        // Configure video
        _controller!.setLooping(true);
        _controller!.setVolume(0); // Mute the video
      }
    } catch (e) {
      print('LoadingVideoOverlay: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }
  
  @override
  void didUpdateWidget(LoadingVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isLoading && !oldWidget.isLoading) {
      // Start loading
      _fadeController.forward();
      if (_isVideoReady && _controller != null) {
        _controller!.play();
      }
    } else if (!widget.isLoading && oldWidget.isLoading) {
      // Stop loading
      _fadeController.reverse().then((_) {
        if (_controller != null) {
          _controller!.pause();
          _controller!.seekTo(Duration.zero);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _controller?.dispose();
    super.dispose();
  }
  
  Widget _buildLoadingOverlay() {
    if (_hasError || !_isVideoReady) {
      // Fallback to standard loading indicator
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.amber,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                widget.loadingText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Video loading overlay
    return Container(
      color: Colors.black87,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video background
          if (_controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          
          // Semi-transparent overlay for better visibility
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          
          // Loading text and progress indicator at bottom
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Small progress indicator
                Container(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.amber.withOpacity(0.8),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 16),
                // Loading text
                Text(
                  widget.loadingText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main content
        if (widget.child != null) widget.child!,
        
        // Loading overlay
        if (widget.isLoading)
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildLoadingOverlay(),
          ),
      ],
    );
  }
}