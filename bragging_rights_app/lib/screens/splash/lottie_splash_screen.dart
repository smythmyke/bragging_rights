import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

class LottieSplashScreen extends StatefulWidget {
  const LottieSplashScreen({super.key});

  @override
  State<LottieSplashScreen> createState() => _LottieSplashScreenState();
}

class _LottieSplashScreenState extends State<LottieSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Randomly select animation
  final List<String> _animations = [
    'assets/animations/trophy_animation.json',
    'assets/animations/medal_animation.json',
    'assets/animations/championship_animation.json',
    'assets/animations/podium_animation.json',
    'assets/animations/fireworks_animation.json',
  ];
  
  late String _selectedAnimation;

  @override
  void initState() {
    super.initState();
    
    // Randomly select which animation to play
    final random = Random();
    _selectedAnimation = _animations[random.nextInt(_animations.length)];
    
    print('LottieSplashScreen: Selected animation: $_selectedAnimation');
    
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Add status listener to know when animation completes
    _controller.addStatusListener((status) {
      print('LottieSplashScreen: Animation status: $status');
      if (status == AnimationStatus.completed) {
        _navigateToLogin();
      }
    });
  }

  void _navigateToLogin() {
    if (!mounted) return;
    
    print('LottieSplashScreen: Navigating to login screen...');
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('LottieSplashScreen: Building widget. Loading: $_isLoading, Error: $_errorMessage');
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark blue background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation with error handling
            SizedBox(
              width: 300,
              height: 300,
              child: Lottie.asset(
                _selectedAnimation,
                controller: _controller,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('LottieSplashScreen: Error loading animation: $error');
                  print('LottieSplashScreen: Stack trace: $stackTrace');
                  // If animation fails, navigate after delay
                  Future.delayed(const Duration(seconds: 2), _navigateToLogin);
                  return const Icon(
                    Icons.emoji_events,
                    size: 100,
                    color: Colors.amber,
                  );
                },
                onLoaded: (composition) {
                  print('LottieSplashScreen: Animation loaded successfully');
                  print('LottieSplashScreen: Duration: ${composition.duration}');
                  print('LottieSplashScreen: Bounds: ${composition.bounds}');
                  
                  setState(() {
                    _isLoading = false;
                  });
                  
                  // Set the duration and start the animation
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
              ),
            ),
            const SizedBox(height: 40),
            // App Logo
            Image.asset(
              'assets/images/bragging_rights_logo.png',
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            // Tagline
            Text(
              'Prove Your Sports Knowledge',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(
                  color: Colors.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
