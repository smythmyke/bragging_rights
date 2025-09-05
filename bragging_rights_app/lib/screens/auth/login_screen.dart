import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
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
    
    // Start the animations
    _playNextAnimation();
    _logoAnimationController.forward();
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
    super.dispose();
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
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              print('First time user, going to sports selection');
              Navigator.pushReplacementNamed(context, '/sports-selection');
            }
          } catch (e) {
            print('Error checking sports selection: $e');
            // Default to sports selection on error
            Navigator.pushReplacementNamed(context, '/sports-selection');
          }
        } else {
          Navigator.pushReplacementNamed(context, '/sports-selection');
        }
      }
    } catch (e, stackTrace) {
      print('Auth error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
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
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            print('First time user, going to sports selection');
            Navigator.pushReplacementNamed(context, '/sports-selection');
          }
        } catch (e) {
          print('Error checking sports selection: $e');
          // Default to sports selection on error
          Navigator.pushReplacementNamed(context, '/sports-selection');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo with high school lettering font
                  _buildAnimatedLogo(),
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
                  
                  // Auth Form
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Email Field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          
                          // Additional fields for Registration
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _displayNameController,
                              decoration: InputDecoration(
                                labelText: 'Display Name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      _isLogin ? 'Login' : 'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // OR Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade400)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade400)),
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
                                side: BorderSide(color: Colors.grey.shade400),
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
                        color: Colors.white.withOpacity(0.9),
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
      ),
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
                          color: Colors.black,
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
                      color: Colors.white,
                      letterSpacing: 4,
                      height: 1,
                      shadows: [
                        // Outer black shadow for depth
                        Shadow(
                          blurRadius: 0,
                          color: Colors.black,
                          offset: const Offset(4.0, 4.0),
                        ),
                        // Inner glow
                        Shadow(
                          blurRadius: 12.0,
                          color: Colors.blue.withOpacity(0.5),
                          offset: const Offset(0, 0),
                        ),
                        // Extra depth
                        Shadow(
                          blurRadius: 3.0,
                          color: Colors.blue[900]!,
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