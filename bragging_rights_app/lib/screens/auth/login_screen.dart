import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
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
  
  late AnimationController _spinController;
  late AnimationController _sparkleController;
  late Animation<double> _spinAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize spin animation
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _spinAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // Full rotation
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Initialize sparkle animation
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _sparkleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));
    
    // Start the timer for spinning every 10 seconds
    Future.delayed(const Duration(seconds: 10), _startSpinAnimation);
  }
  
  void _startSpinAnimation() {
    if (mounted) {
      _spinController.forward(from: 0).then((_) {
        _sparkleController.forward(from: 0).then((_) {
          if (mounted) {
            // Schedule next spin
            Future.delayed(const Duration(seconds: 10), _startSpinAnimation);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _sparkleController.dispose();
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
                  // Animated Trophy with Sparkles
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sparkle effects
                      AnimatedBuilder(
                        animation: _sparkleAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(120, 120),  // Reduced sparkle size
                            painter: SparklePainter(
                              progress: _sparkleAnimation.value,
                              color: Colors.amber,
                            ),
                          );
                        },
                      ),
                      // Spinning trophy
                      AnimatedBuilder(
                        animation: _spinAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _spinAnimation.value,
                            child: Icon(
                              Icons.emoji_events,
                              size: 80,  // Reduced trophy size
                              color: Colors.amber,
                              shadows: [
                                Shadow(
                                  color: Colors.amber.withOpacity(0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // No space between trophy and logo
                  Image.asset(
                    'assets/images/bragging_rights_logo.png',
                    height: 280,  // Reduced slightly to fit better
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),  // Minimal space
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join the Competition!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),  // Reduced from 32
                  
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