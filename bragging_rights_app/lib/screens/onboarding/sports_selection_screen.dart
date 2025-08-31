import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SportsSelectionScreen extends StatefulWidget {
  const SportsSelectionScreen({super.key});

  @override
  State<SportsSelectionScreen> createState() => _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends State<SportsSelectionScreen> 
    with TickerProviderStateMixin {
  final Set<String> _selectedSports = {};
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  final List<SportItem> sports = [
    SportItem('NBA', Icons.sports_basketball, const Color(0xFFF97316)),
    SportItem('NFL', Icons.sports_football, const Color(0xFF8B4513)),
    SportItem('NHL', Icons.sports_hockey, const Color(0xFF3B82F6)),
    SportItem('Tennis', Icons.sports_tennis, const Color(0xFF10B981)),
    SportItem('MMA', Icons.sports_mma, const Color(0xFFEF4444)),
    SportItem('MLB', Icons.sports_baseball, const Color(0xFF6366F1)),
    SportItem('Soccer', Icons.sports_soccer, const Color(0xFFA855F7)),
    SportItem('Boxing', Icons.sports_kabaddi, const Color(0xFFFBBF24)),
  ];

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
    
    _loadExistingPreferences();
  }
  
  Future<void> _loadExistingPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && userDoc.data()?['selectedSports'] != null) {
          setState(() {
            _selectedSports.addAll(
              List<String>.from(userDoc.data()!['selectedSports'])
            );
          });
          print('Loaded existing sports preferences: $_selectedSports');
        }
      }
    } catch (e) {
      print('Error loading existing preferences: $e');
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  void _toggleSport(String sport) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSports.contains(sport)) {
        _selectedSports.remove(sport);
      } else {
        _selectedSports.add(sport);
      }
    });
  }

  void _continueToApp() async {
    if (_selectedSports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one sport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Save selected sports to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'selectedSports': _selectedSports,
          'favoriteSports': _selectedSports,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sports preferences saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error saving sports preferences: $e');
      // Continue anyway - preferences can be updated later
    }
    
    // Navigate to home screen
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                    _backgroundAnimation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF334155),
                    const Color(0xFF1E293B),
                    _backgroundAnimation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF475569),
                    const Color(0xFF334155),
                    _backgroundAnimation.value,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'Choose Your Sports',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 32,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your favorite sports appear first in games and pools',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedSports.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.greenAccent.withOpacity(0.8),
                              Colors.tealAccent.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${_selectedSports.length} sport${_selectedSports.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Sports Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: sports.length,
                    itemBuilder: (context, index) {
                      final sport = sports[index];
                      final isSelected = _selectedSports.contains(sport.name);
                      
                      return GestureDetector(
                        onTap: () => _toggleSport(sport.name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          transform: Matrix4.identity()
                            ..scale(isSelected ? 1.05 : 1.0),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      sport.color.withOpacity(0.3),
                                      sport.color.withOpacity(0.1),
                                    ],
                                  )
                                : null,
                            color: !isSelected
                                ? Colors.white.withOpacity(0.1)
                                : null,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected 
                                  ? sport.color 
                                  : Colors.white.withOpacity(0.3),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: sport.color.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.transparent,
                                      blurRadius: 0,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.2 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutBack,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            sport.color.withOpacity(0.8),
                                            sport.color,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: sport.color.withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        sport.icon,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    sport.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected 
                                          ? Colors.white 
                                          : Colors.white70,
                                      shadows: isSelected
                                          ? [
                                              Shadow(
                                                color: Colors.black26,
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.greenAccent.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.tealAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _continueToApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue to App',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SportItem {
  final String name;
  final IconData icon;
  final Color color;

  SportItem(this.name, this.icon, this.color);
}