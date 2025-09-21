import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'dart:math' show sin, pi;
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Gold Rush Theme Colors
  static const Color goldPrimary = Color(0xFFFFD700);
  static const Color goldSecondary = Color(0xFFFFC107);
  static const Color darkBackground = Color(0xFF0F0C29);
  static const Color darkPurple = Color(0xFF302B63);
  static const Color darkAccent = Color(0xFF24243e);
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _authService = AuthService();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  
  late AnimationController _lottieController;
  int _animationIndex = 0;
  final List<String> _animations = [
    'assets/animations/trophy_animation.json',
    'assets/animations/medal_animation.json',
    'assets/animations/championship_animation.json',
    'assets/animations/podium_animation.json',
    'assets/animations/fireworks_animation.json',
  ];
  
  // Logo animation controllers
  late AnimationController _logoAnimationController;
  late Animation<Offset> _braggingAnimation;
  late Animation<Offset> _rightsAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _gridAnimationController;
  late AnimationController _glowAnimationController;
  late Animation<double> _glowAnimation;

  // Shake animation for failed login
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isShaking = false;

  // Success animation controllers
  late AnimationController _successController;
  late Animation<double> _successPulseAnimation;
  late Animation<double> _successShineAnimation;
  bool _isSuccessAnimating = false;

  // Video player for success animation
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    
    // Initialize Lottie animation controller
    _lottieController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Initialize logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize grid animation controller for background
    _gridAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    // Initialize glow animation controller
    _glowAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize shake animation controller for failed login
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    // Initialize success animation controller
    _successController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Pulsing animation for neon green glow
    _successPulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.easeInOut,
      ),
    );

    // Shine animation that travels around the edge
    _successShineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.linear,
      ),
    );

    // Set up animations for "Bragging" sliding from left
    _braggingAnimation = Tween<Offset>(
      begin: const Offset(-2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    
    // Set up animations for "Rights" sliding from right
    _rightsAnimation = Tween<Offset>(
      begin: const Offset(2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
    ));
    
    // Fade in animation for both
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    // Initialize video controller
    _initializeVideo();

    // Start the animations
    _playNextAnimation();
    _logoAnimationController.forward();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset(
      'assets/videos/BR_Zoom_Animation.mp4',
    );
    await _videoController!.initialize();
    _videoController!.setVolume(0.0);  // Mute the video
  }
  
  void _playNextAnimation() async {
    if (!mounted) return;
    
    // Reset the controller
    _lottieController.reset();
    
    // Play the animation
    await _lottieController.forward();
    
    if (mounted) {
      // Move to next animation
      setState(() {
        _animationIndex = (_animationIndex + 1) % _animations.length;
      });
      
      // Wait a moment before playing the next one
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Play next animation
      _playNextAnimation();
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _logoAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _gridAnimationController.dispose();
    _glowAnimationController.dispose();
    _shakeController.dispose();
    _successController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _triggerShakeAnimation() async {
    setState(() => _isShaking = true);
    await _shakeController.forward();
    await _shakeController.reverse();
    _shakeController.reset();
    setState(() => _isShaking = false);
  }

  Future<void> _playSuccessVideoAndNavigate(String route) async {
    // Start success animation
    setState(() => _isSuccessAnimating = true);
    await _successController.forward();

    // Navigate to next screen
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _handleAuth() async {
    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        // Sign in
        print('Attempting sign in for: ${_emailController.text.trim()}');
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Sign in successful');
      } else {
        // Sign up
        print('Attempting sign up for: ${_emailController.text.trim()}');
        if (_passwordController.text != _confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }
        print('Creating user with display name: ${_displayNameController.text.trim()}');
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim().isEmpty 
              ? _emailController.text.split('@')[0] 
              : _displayNameController.text.trim(),
        );
        print('Sign up successful');
      }
      
      if (mounted) {
        print('Checking if user needs sports selection');
        // Check if user has already selected sports
        final user = _authService.currentUser;
        if (user != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            final hasSelectedSports = userDoc.data()?['selectedSports'] != null && 
                (userDoc.data()?['selectedSports'] as List).isNotEmpty;
            
            if (hasSelectedSports) {
              print('User has already selected sports, going to home');
              await _playSuccessVideoAndNavigate('/home');
            } else {
              print('First time user, going to sports selection');
              await _playSuccessVideoAndNavigate('/sports-selection');
            }
          } catch (e) {
            print('Error checking sports selection: $e');
            // Default to sports selection on error
            await _playSuccessVideoAndNavigate('/sports-selection');
          }
        } else {
          await _playSuccessVideoAndNavigate('/sports-selection');
        }
      }
    } catch (e, stackTrace) {
      print('Auth error: $e');
      print('Stack trace: $stackTrace');

      // Trigger shake animation on login failure
      _triggerShakeAnimation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorPink,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final credential = await _authService.signInWithGoogle();
      
      if (credential != null && mounted) {
        // Check if user has already selected sports
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .get();
          
          final hasSelectedSports = userDoc.data()?['selectedSports'] != null && 
              (userDoc.data()?['selectedSports'] as List).isNotEmpty;
          
          if (hasSelectedSports) {
            print('User has already selected sports, going to home');
            await _playSuccessVideoAndNavigate('/home');
          } else {
            print('First time user, going to sports selection');
            await _playSuccessVideoAndNavigate('/sports-selection');
          }
        } catch (e) {
          print('Error checking sports selection: $e');
          // Default to sports selection on error
          await _playSuccessVideoAndNavigate('/sports-selection');
        }
      }
    } catch (e) {
      // Trigger shake animation on social login failure
      _triggerShakeAnimation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorPink,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gold Rush Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFF1a1a2e),
                  darkBackground,
                ],
              ),
            ),
          ),
          // Animated Neon Grid
          AnimatedBuilder(
            animation: _gridAnimationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: NeonGridPainter(
                  animation: _gridAnimationController.value,
                  glowIntensity: _glowAnimation.value,
                ),
              );
            },
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gold Rush Logo with Glow Effect
                  _buildGoldRushLogo(),
                  // Animation closer to logo with minimal spacing
                  const SizedBox(height: 8),  // Very small gap between logo and animation
                  // Lottie Animation (same as splash screen)
                  SizedBox(
                    height: 100,  // Fixed height for animation
                    width: 100,
                    child: Lottie.asset(
                      _animations[_animationIndex],
                      controller: _lottieController,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) {
                        // Fallback to trophy icon if animation fails
                        return Icon(
                          Icons.emoji_events,
                          size: 80,
                          color: Colors.amber,
                        );
                      },
                    ),
                  ),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join the Competition!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),  // Further reduced spacing
                  
                  // Neon Gold Auth Form
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          darkBackground.withOpacity(0.9),
                          darkAccent.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: goldPrimary.withOpacity(0.3),
                          blurRadius: 50,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: goldPrimary.withOpacity(0.1),
                          blurRadius: 100,
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: goldPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Email Field with Neon Gold Style
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: goldPrimary.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(
                                  color: goldPrimary.withOpacity(0.7),
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: goldPrimary.withOpacity(0.7),
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field with Neon Gold Style
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: goldPrimary.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color: goldPrimary.withOpacity(0.7),
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: goldPrimary.withOpacity(0.7),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: goldPrimary.withOpacity(0.7),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          
                          // Additional fields for Registration
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: !_isLogin ? null : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: !_isLogin ? 1.0 : 0.0,
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: goldPrimary.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _displayNameController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Display Name',
                                        labelStyle: TextStyle(
                                          color: goldPrimary.withOpacity(0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          color: goldPrimary.withOpacity(0.7),
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: goldPrimary.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        labelStyle: TextStyle(
                                          color: goldPrimary.withOpacity(0.7),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline,
                                          color: goldPrimary.withOpacity(0.7),
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Neon Gold Submit Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: goldPrimary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: goldPrimary.withOpacity(0.6),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading ? null : _handleAuth,
                                borderRadius: BorderRadius.circular(50),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(50),
                                    gradient: _isLoading
                                        ? null
                                        : LinearGradient(
                                            colors: [goldPrimary, goldSecondary],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: goldPrimary,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // OR Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppTheme.surfaceBlue.withOpacity(0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: AppTheme.primaryCyan.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppTheme.surfaceBlue.withOpacity(0.3))),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: AppTheme.surfaceBlue.withOpacity(0.3)),
                              ),
                              icon: Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.g_mobiledata, size: 24);
                                },
                              ),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Toggle Login/Register
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? "Don't have an account? Sign Up"
                                  : 'Already have an account? Login',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Starting Balance Info for New Users
                  if (!_isLogin)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Get 500 BR Starting Balance!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

      ],
    ),
    );
  }
  
  Widget _buildGoldRushLogo() {
    return Column(
      children: [
        // BR Logo Container with Shake Animation
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final sineValue = sin(4 * 2 * pi * _shakeController.value);
            return Transform.translate(
              offset: Offset(sineValue * _shakeAnimation.value, 0),
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _isSuccessAnimating ? _successShineAnimation : _glowAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _isSuccessAnimating
                  ? EdgeShinePainter(
                      progress: _successShineAnimation.value,
                      color: Color(0xFF00FF00),
                    )
                  : null,
                child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      goldPrimary.withOpacity(0.3),
                      goldSecondary.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isShaking ? Colors.red : (_isSuccessAnimating ? Color(0xFF00FF00) : goldPrimary),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isShaking
                        ? Colors.red.withOpacity(0.5 * _glowAnimation.value)
                        : (_isSuccessAnimating
                            ? Color(0xFF00FF00).withOpacity(_successPulseAnimation.value)
                            : goldPrimary.withOpacity(0.5 * _glowAnimation.value)),
                      blurRadius: 30 + (_isSuccessAnimating ? _successPulseAnimation.value * 20 : 0),
                      spreadRadius: _isSuccessAnimating ? _successPulseAnimation.value * 5 : 0,
                    ),
                    BoxShadow(
                      color: _isShaking
                        ? Colors.red.withOpacity(0.2)
                        : (_isSuccessAnimating
                            ? Color(0xFF00FF00).withOpacity(0.3)
                            : goldPrimary.withOpacity(0.2)),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isShaking
                          ? [Colors.red, Colors.redAccent, Colors.white, Colors.red]
                          : (_isSuccessAnimating
                              ? [Color(0xFF00FF00), Color(0xFF00FF88), Colors.white, Color(0xFF00FF00)]
                              : [goldSecondary, goldPrimary, Colors.white, goldPrimary]),
                        stops: [0.0, 0.3, 0.5, 1.0],
                        transform: GradientRotation(_glowAnimation.value * math.pi),
                      ).createShader(bounds);
                    },
                    child: Text(
                      'BR',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // App Name below the logo
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                goldSecondary,
                goldPrimary,
                Colors.white,
                goldPrimary,
              ],
            ).createShader(bounds);
          },
          child: Text(
            'BRAGGING RIGHTS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Tagline
        Text(
          'Own Your Predictions',
          style: TextStyle(
            fontSize: 14,
            color: goldPrimary.withOpacity(0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return ClipRect(
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // "BRAGGING" text sliding from left - positioned on top
            Positioned(
              top: 15,
              child: SlideTransition(
                position: _braggingAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'BRAGGING',
                    style: TextStyle(
                      // Varsity/Athletic font style
                      fontFamily: 'Arial Black',
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber[400],
                      letterSpacing: 4,
                      height: 1,
                      shadows: [
                        // Outer black shadow for depth
                        Shadow(
                          blurRadius: 0,
                          color: AppTheme.deepBlue,
                          offset: const Offset(4.0, 4.0),
                        ),
                        // Inner glow
                        Shadow(
                          blurRadius: 12.0,
                          color: Colors.amber.withOpacity(0.5),
                          offset: const Offset(0, 0),
                        ),
                        // Extra depth
                        Shadow(
                          blurRadius: 3.0,
                          color: Colors.orange[900]!,
                          offset: const Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // "RIGHTS" text sliding from right - positioned below
            Positioned(
              bottom: 15,
              child: SlideTransition(
                position: _rightsAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'RIGHTS',
                    style: TextStyle(
                      // Varsity/Athletic font style
                      fontFamily: 'Arial Black', 
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryCyan,
                      letterSpacing: 4,
                      height: 1,
                      shadows: [
                        // Outer black shadow for depth
                        Shadow(
                          blurRadius: 0,
                          color: AppTheme.deepBlue,
                          offset: const Offset(4.0, 4.0),
                        ),
                        // Inner glow
                        Shadow(
                          blurRadius: 12.0,
                          color: AppTheme.primaryCyan.withOpacity(0.5),
                          offset: const Offset(0, 0),
                        ),
                        // Extra depth
                        Shadow(
                          blurRadius: 3.0,
                          color: AppTheme.secondaryCyan,
                          offset: const Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for sparkle effects
class SparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  SparklePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color.withOpacity(1.0 - progress)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // Fixed seed for consistent sparkles

    // Draw sparkles
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final distance = 40 + (progress * 40);
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      final sparkleSize = (1.0 - progress) * 4;
      
      // Draw star-shaped sparkle
      final path = Path();
      for (int j = 0; j < 4; j++) {
        final sparkleAngle = (j * 90) * math.pi / 180;
        final innerRadius = sparkleSize * 0.3;
        final outerRadius = sparkleSize;
        
        if (j == 0) {
          path.moveTo(
            x + math.cos(sparkleAngle) * outerRadius,
            y + math.sin(sparkleAngle) * outerRadius,
          );
        }
        
        path.lineTo(
          x + math.cos(sparkleAngle + math.pi / 4) * innerRadius,
          y + math.sin(sparkleAngle + math.pi / 4) * innerRadius,
        );
        path.lineTo(
          x + math.cos(sparkleAngle + math.pi / 2) * outerRadius,
          y + math.sin(sparkleAngle + math.pi / 2) * outerRadius,
        );
      }
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Custom painter for neon grid background
class NeonGridPainter extends CustomPainter {
  final double animation;
  final double glowIntensity;
  
  NeonGridPainter({
    required this.animation,
    required this.glowIntensity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    // Animated gold color with glow
    final goldColor = Color(0xFFFFD700).withOpacity(0.3 + (glowIntensity * 0.2));
    paint.color = goldColor;
    
    // Draw horizontal lines
    final horizontalSpacing = 40.0;
    final verticalOffset = (animation * horizontalSpacing) % horizontalSpacing;
    
    for (double y = -horizontalSpacing + verticalOffset; y < size.height + horizontalSpacing; y += horizontalSpacing) {
      // Add perspective effect - lines get closer together towards the top
      final perspectiveFactor = (y / size.height);
      final adjustedY = y * (0.5 + perspectiveFactor * 0.5);
      
      // Vary opacity based on position
      final lineOpacity = 0.2 + (math.sin(y / 100 + animation * 2) * 0.1);
      paint.color = goldColor.withOpacity(lineOpacity);
      
      canvas.drawLine(
        Offset(0, adjustedY),
        Offset(size.width, adjustedY),
        paint,
      );
    }
    
    // Draw vertical lines
    final verticalSpacing = 40.0;
    final horizontalOffset = (animation * verticalSpacing) % verticalSpacing;
    
    for (double x = -verticalSpacing + horizontalOffset; x < size.width + verticalSpacing; x += verticalSpacing) {
      // Add perspective effect - lines converge towards center
      final centerDistance = (x - size.width / 2).abs() / (size.width / 2);
      final adjustedX = size.width / 2 + (x - size.width / 2) * (0.7 + centerDistance * 0.3);
      
      // Vary opacity based on position
      final lineOpacity = 0.2 + (math.cos(x / 100 + animation * 2) * 0.1);
      paint.color = goldColor.withOpacity(lineOpacity);
      
      canvas.drawLine(
        Offset(adjustedX, 0),
        Offset(adjustedX, size.height),
        paint,
      );
    }
    
    // Add scanning line effect
    final scanLineY = (animation * size.height * 2) % (size.height + 100) - 50;
    final scanPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFFFFD700).withOpacity(0.8),
          Colors.transparent,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanLineY - 20, size.width, 40));
      
    canvas.drawLine(
      Offset(0, scanLineY),
      Offset(size.width, scanLineY),
      scanPaint,
    );
  }
  
  @override
  bool shouldRepaint(NeonGridPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.glowIntensity != glowIntensity;
  }
}

// Custom painter for edge shine effect
class EdgeShinePainter extends CustomPainter {
  final double progress;
  final Color color;

  EdgeShinePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(20));

    // Calculate the position of the shine along the perimeter
    final perimeter = 2 * (size.width + size.height);
    final shinePosition = progress * perimeter;

    // Create gradient paint for the shine
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Draw the path
    final path = Path()..addRRect(rrect);

    // Create a gradient that moves along the edge
    Offset start, end;

    if (shinePosition < size.width) {
      // Top edge
      start = Offset(shinePosition, 0);
      end = Offset(math.max(0, shinePosition - 50), 0);
    } else if (shinePosition < size.width + size.height) {
      // Right edge
      final y = shinePosition - size.width;
      start = Offset(size.width, y);
      end = Offset(size.width, math.max(0, y - 50));
    } else if (shinePosition < 2 * size.width + size.height) {
      // Bottom edge
      final x = size.width - (shinePosition - size.width - size.height);
      start = Offset(x, size.height);
      end = Offset(math.min(size.width, x + 50), size.height);
    } else {
      // Left edge
      final y = size.height - (shinePosition - 2 * size.width - size.height);
      start = Offset(0, y);
      end = Offset(0, math.min(size.height, y + 50));
    }

    paint.shader = LinearGradient(
      colors: [
        Colors.transparent,
        color.withOpacity(0.8),
        color,
        color.withOpacity(0.8),
        Colors.transparent,
      ],
      stops: [0.0, 0.3, 0.5, 0.7, 1.0],
    ).createShader(Rect.fromPoints(start, end));

    // Draw the shine path
    canvas.save();
    canvas.clipRRect(rrect.inflate(2));
    canvas.drawPath(path, paint);
    canvas.restore();

    // Add extra glow at the shine position
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(start, 10, glowPaint);
  }

  @override
  bool shouldRepaint(EdgeShinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}