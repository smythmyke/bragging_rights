import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_game_card.dart';
import '../models/game_model.dart';

class ThemeDemoScreen extends StatefulWidget {
  const ThemeDemoScreen({super.key});

  @override
  State<ThemeDemoScreen> createState() => _ThemeDemoScreenState();
}

class _ThemeDemoScreenState extends State<ThemeDemoScreen> {
  late ConfettiController _confettiController;
  bool _showVictory = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'BRAGGING RIGHTS',
                      style: AppTheme.neonText(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(
                          begin: -0.2,
                          end: 0,
                        ),
                    const SizedBox(height: 8),
                    Text(
                      'Neon Cyber Theme Demo',
                      style: TextStyle(
                        color: AppTheme.neonGreen,
                        fontSize: 16,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 30),

                    // Balance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassContainer(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOUR BALANCE',
                                style: TextStyle(
                                  color: AppTheme.primaryCyan.withOpacity(0.7),
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$1,250 BR',
                                style: AppTheme.neonText(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.neonGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.neonGreen.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: AppTheme.neonGreen,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+15.5%',
                                  style: TextStyle(
                                    color: AppTheme.neonGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(
                          begin: 0.1,
                          end: 0,
                        ),
                    const SizedBox(height: 30),

                    // Section Title
                    Text(
                      'LIVE GAMES',
                      style: TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sample Game Cards
                    NeonGameCard(
                      game: GameModel(
                        id: '1',
                        sport: 'NBA',
                        league: 'NBA',
                        homeTeam: 'Lakers',
                        awayTeam: 'Warriors',
                        gameTime: DateTime.now(),
                        homeScore: 98,
                        awayScore: 95,
                      ),
                      showLiveIndicator: true,
                      onTap: () {},
                    ),
                    NeonGameCard(
                      game: GameModel(
                        id: '2',
                        sport: 'NFL',
                        league: 'NFL',
                        homeTeam: 'Chiefs',
                        awayTeam: 'Bills',
                        gameTime: DateTime.now().add(const Duration(hours: 2)),
                        odds: '-3.5',
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 30),

                    // Buttons Section
                    Text(
                      'ACTIONS',
                      style: TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            text: 'PLACE BET',
                            icon: Icons.casino,
                            onPressed: () {
                              _showVictory = true;
                              _confettiController.play();
                              setState(() {});
                              Future.delayed(const Duration(seconds: 3), () {
                                setState(() {
                                  _showVictory = false;
                                });
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: NeonButton(
                            text: 'VIEW EDGE',
                            icon: Icons.analytics,
                            color: AppTheme.secondaryCyan,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      text: 'POWER CARD',
                      icon: Icons.bolt,
                      color: AppTheme.neonGreen,
                      width: double.infinity,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 30),

                    // Stats Grid
                    Text(
                      'YOUR STATS',
                      style: TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('WIN STREAK', '24', AppTheme.neonGreen),
                        _buildStatCard('WIN RATE', '78%', AppTheme.primaryCyan),
                        _buildStatCard('TOTAL WINS', '142', AppTheme.warningAmber),
                        _buildStatCard('RANKING', '#12', AppTheme.errorPink),
                      ],
                    ),
                  ],
                ),
              ),

              // Victory Overlay
              if (_showVictory)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'WINNER!',
                            style: AppTheme.neonText(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.neonGreen,
                            ),
                          ).animate().scale(
                                begin: const Offset(0, 0),
                                end: const Offset(1, 1),
                                duration: 500.ms,
                              ),
                          const SizedBox(height: 16),
                          Text(
                            '+\$250 BR',
                            style: TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                        ],
                      ),
                    ),
                  ),
                ),

              // Confetti
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.2,
                  colors: [
                    AppTheme.primaryCyan,
                    AppTheme.neonGreen,
                    AppTheme.warningAmber,
                    Colors.white,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassContainer(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTheme.neonText(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(
          begin: 0.2,
          end: 0,
        );
  }
}