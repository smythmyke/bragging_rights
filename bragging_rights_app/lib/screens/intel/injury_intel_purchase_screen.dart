import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/intel_card_service.dart';
import '../../models/intel_card_model.dart';

class InjuryIntelPurchaseScreen extends StatefulWidget {
  final String? gameId;
  final String gameTitle;
  final String sport;
  final String? homeTeamId;
  final String? awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? gameTime;
  final int homeInjuryCount;
  final int awayInjuryCount;

  const InjuryIntelPurchaseScreen({
    Key? key,
    this.gameId,
    required this.gameTitle,
    required this.sport,
    this.homeTeamId,
    this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.gameTime,
    required this.homeInjuryCount,
    required this.awayInjuryCount,
  }) : super(key: key);

  @override
  State<InjuryIntelPurchaseScreen> createState() => _InjuryIntelPurchaseScreenState();
}

class _InjuryIntelPurchaseScreenState extends State<InjuryIntelPurchaseScreen> {
  final _intelCardService = IntelCardService();
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Injury Intel',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Choose Your Coverage',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildGameContext(),
          Expanded(
            child: _buildPurchaseOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContext() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withOpacity(0.05),
        border: Border.all(
          color: AppTheme.warningAmber.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.warningAmber, Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '🏀',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.gameTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.gameTime != null
                      ? '${_formatGameTime(widget.gameTime!)} • ${widget.sport.toUpperCase()}'
                      : widget.sport.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatGameTime(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now);

    if (difference.inDays > 0) {
      return 'In ${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes}m';
    } else {
      return 'Live Now';
    }
  }

  Widget _buildPurchaseOptions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'SELECT TEAM OR BUNDLE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),

        // Home Team Card
        _buildPurchaseCard(
          teamName: widget.homeTeamName,
          teamIcon: '🟣', // TODO: Use actual team logo
          subtitle: '${widget.homeTeamName} injury report only',
          injuryCount: widget.homeInjuryCount,
          price: 30,
          isBundle: false,
          onPurchase: () => _purchaseCard('home'),
        ),

        // Away Team Card
        _buildPurchaseCard(
          teamName: widget.awayTeamName,
          teamIcon: '🔵', // TODO: Use actual team logo
          subtitle: '${widget.awayTeamName} injury report only',
          injuryCount: widget.awayInjuryCount,
          price: 30,
          isBundle: false,
          onPurchase: () => _purchaseCard('away'),
        ),

        // Bundle Card
        _buildPurchaseCard(
          teamName: 'Full Game Bundle',
          teamIcon: '⭐',
          subtitle: 'Both teams + comparative analysis',
          injuryCount: widget.homeInjuryCount + widget.awayInjuryCount,
          price: 50,
          originalPrice: 60,
          savingsBadge: 'SAVE 10 BR',
          isBundle: true,
          description: '• Complete injury reports for both teams\n• Head-to-head injury comparison\n• Game-level intel insight & betting impact\n• Impact scoring for both sides',
          onPurchase: () => _purchaseCard('bundle'),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard({
    required String teamName,
    required String teamIcon,
    required String subtitle,
    required int injuryCount,
    required int price,
    int? originalPrice,
    String? savingsBadge,
    String? description,
    bool isBundle = false,
    required VoidCallback onPurchase,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isBundle
            ? LinearGradient(
                colors: [
                  AppTheme.warningAmber.withOpacity(0.1),
                  AppTheme.warningAmber.withOpacity(0.05),
                ],
              )
            : LinearGradient(
                colors: [
                  AppTheme.surfaceBlue.withOpacity(0.8),
                  AppTheme.surfaceBlue.withOpacity(0.6),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBundle
              ? AppTheme.warningAmber.withOpacity(0.4)
              : AppTheme.primaryCyan.withOpacity(0.2),
          width: isBundle ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                teamIcon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (savingsBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.warningAmber, Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    savingsBadge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Preview or Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4B4B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF4B4B).withOpacity(0.2),
              ),
            ),
            child: description != null
                ? Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  )
                : Text(
                    'Preview: $injuryCount ${injuryCount == 1 ? "injury" : "injuries"} detected',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Purchase Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: AppTheme.primaryCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$price',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'BR',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    if (originalPrice != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$originalPrice',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBundle
                        ? AppTheme.warningAmber
                        : AppTheme.primaryCyan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isPurchasing
                        ? 'Processing...'
                        : (isBundle ? '🔥 Unlock Bundle' : 'Unlock Intel'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isBundle ? Colors.white : AppTheme.deepBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseCard(String cardType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to purchase intel')),
      );
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      // Create appropriate intel card based on selection
      IntelCard card;
      if (cardType == 'bundle') {
        card = IntelCard(
          id: '${widget.gameId}_injury_bundle',
          type: IntelCardType.gameInjuryReport,
          title: 'Full Game Injury Intel',
          description: 'Both teams + analysis',
          brCost: 50,
          gameId: widget.gameId,
          expiresAt: widget.gameTime,
          sport: widget.sport,
        );
      } else if (cardType == 'home') {
        card = IntelCard(
          id: '${widget.gameId}_injury_home',
          type: IntelCardType.teamInjuryReport,
          title: '${widget.homeTeamName} Injury Intel',
          description: 'Home team injuries',
          brCost: 30,
          gameId: widget.gameId,
          teamId: widget.homeTeamId,
          expiresAt: widget.gameTime,
          sport: widget.sport,
        );
      } else {
        card = IntelCard(
          id: '${widget.gameId}_injury_away',
          type: IntelCardType.teamInjuryReport,
          title: '${widget.awayTeamName} Injury Intel',
          description: 'Away team injuries',
          brCost: 30,
          gameId: widget.gameId,
          teamId: widget.awayTeamId,
          expiresAt: widget.gameTime,
          sport: widget.sport,
        );
      }

      final result = await _intelCardService.purchaseIntelCard(
        userId: user.uid,
        card: card,
      );

      setState(() => _isPurchasing = false);

      if (!mounted) return;

      if (result.success) {
        // Navigate to Level 3 - Report View
        Navigator.pushNamed(
          context,
          '/injury_report_view',
          arguments: {
            'userCard': result.userCard,
            'cardType': cardType,
            'homeTeamId': widget.homeTeamId,
            'awayTeamId': widget.awayTeamId,
            'homeTeamName': widget.homeTeamName,
            'awayTeamName': widget.awayTeamName,
            'sport': widget.sport,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.errorPink,
          ),
        );
      }
    } catch (e) {
      setState(() => _isPurchasing = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error purchasing intel: $e'),
          backgroundColor: AppTheme.errorPink,
        ),
      );
    }
  }
}
